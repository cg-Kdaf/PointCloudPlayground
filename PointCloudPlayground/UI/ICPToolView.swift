import SwiftUI
import simd

struct ICPToolView: View {
  @ObservedObject var scene: PlaygroundScene
  
  @State private var statusText: String = "Ready"
  @State private var isRunning: Bool = false
  
  @State private var sourceId: UUID?
  @State private var targetId: UUID?
  @State private var volumeId: UUID?
  @State private var originalTransform: (translation: SIMD3<Float>, rotation: SIMD3<Float>, scale: SIMD3<Float>)?
  @State private var lastModifiedSourceObjId: UUID?
  
  private var allPointClouds: [SceneObject] {
    var result: [SceneObject] = []
    func traverse(_ group: SceneGroup) {
      result.append(contentsOf: group.objects.filter { $0.dataBlockType == .pointCloud })
      for child in group.childGroups {
        traverse(child)
      }
    }
    traverse(scene.rootGroup)
    return result
  }

  private var allVolumes: [SceneObject] {
    var result: [SceneObject] = []
    func traverse(_ group: SceneGroup) {
      result.append(contentsOf: group.objects.filter { $0.dataBlockType == .volume })
      for child in group.childGroups {
        traverse(child)
      }
    }
    traverse(scene.rootGroup)
    return result
  }
  
  var body: some View {
    VStack(spacing: 20) {
      let clouds = allPointClouds
      let volumes = allVolumes
      
      Form {
        Picker("Source", selection: $sourceId) {
          Text("Select Source").tag(UUID?.none)
          ForEach(clouds) { obj in
            Text(obj.name).tag(UUID?.some(obj.id))
          }
        }
        
        Picker("Target", selection: $targetId) {
          Text("Select Target").tag(UUID?.none)
          ForEach(clouds) { obj in
            Text(obj.name).tag(UUID?.some(obj.id))
          }
        }

        Picker("Bounding Volume (Mask)", selection: $volumeId) {
          Text("None").tag(UUID?.none)
          ForEach(volumes) { obj in
            Text(obj.name).tag(UUID?.some(obj.id))
          }
        }
      }
      .padding()
      
      let sourceObj = clouds.first { $0.id == sourceId }
      let targetObj = clouds.first { $0.id == targetId }
      let sourceData = sourceObj?.asPointCloudData
      let targetData = targetObj?.asPointCloudData
      
      if let sourceObj = sourceObj, let targetObj = targetObj, let sourceData = sourceData, let targetData = targetData {
        if sourceObj.id == targetObj.id {
          Text("Source and Target must be different point clouds.")
            .foregroundColor(.red)
        } else {
          Text("Align \(sourceObj.name) onto \(targetObj.name)")
            .font(.headline)
          
          Text("Source: \(sourceObj.name) (\(sourceData.pointsCount) points)")
          Text("Target: \(targetObj.name) (\(targetData.pointsCount) points)")
          
          HStack {
            Button(action: {
              let selectedVol = allVolumes.first { $0.id == volumeId }
              runICP(sourceObj: sourceObj, targetObj: targetObj, sourceData: sourceData, targetData: targetData, volumeObj: selectedVol)
            }) {
              Text(isRunning ? "Running ICP..." : "Start ICP")
            }
            .disabled(isRunning)

            Button(action: { cancelICP() }) {
              Text("Cancel")
            }
            .disabled(isRunning || originalTransform == nil || lastModifiedSourceObjId != sourceObj.id)
            
            Button("Cancel Running ICP") {
                ICPToolContext.shared.isCancelled = true
            }
            .disabled(!isRunning)
          }
          
          Text(statusText)
            .foregroundColor(isRunning ? .secondary : .primary)
            .font(.caption)
        }
      } else {
        Text("Please select two point clouds to proceed.")
          .foregroundColor(.secondary)
      }
    }
    .padding(30)
    .frame(minWidth: 400, minHeight: 300)
    .onAppear {
      // Auto-select from scene outliner if possible
      let selectedClouds = scene.selectedIds
        .compactMap { scene.rootGroup.object(withId: $0) }
        .filter { $0.dataBlockType == .pointCloud }
      
      let selectedVolumes = scene.selectedIds
        .compactMap { scene.rootGroup.object(withId: $0) }
        .filter { $0.dataBlockType == .volume }
      
      if selectedClouds.count >= 1 && sourceId == nil {
        sourceId = selectedClouds[0].id
      }
      if selectedClouds.count >= 2 && targetId == nil {
        targetId = selectedClouds[1].id
      }
      if let vol = selectedVolumes.first, volumeId == nil {
        volumeId = vol.id
      }
    }
  }
  
  private func cancelICP() {
    if let sourceObj = allPointClouds.first(where: { $0.id == lastModifiedSourceObjId }),
       let orig = originalTransform {
        sourceObj.translation = orig.translation
        sourceObj.rotation = orig.rotation
        sourceObj.scale = orig.scale
        originalTransform = nil
        statusText = "Restored original transformation."
        SceneUpdate.postGizmoChanged()
    }
  }
  
  private func runICP(sourceObj: SceneObject, targetObj: SceneObject, sourceData: PointCloudDataBlock, targetData: PointCloudDataBlock, volumeObj: SceneObject?) {
    ICPToolContext.shared.isCancelled = false
    isRunning = true
    statusText = "Calculating transformation in background..."
    
    originalTransform = (sourceObj.translation, sourceObj.rotation, sourceObj.scale)
    lastModifiedSourceObjId = sourceObj.id
    
    let sourceWorld = scene.rootGroup.hierarchicalMatrix(forItemId: sourceObj.id, in: scene.rootGroup)
    let targetWorld = scene.rootGroup.hierarchicalMatrix(forItemId: targetObj.id, in: scene.rootGroup)
    let volumeWorld = volumeObj.map { scene.rootGroup.hierarchicalMatrix(forItemId: $0.id, in: scene.rootGroup) }
    
    DispatchQueue.global(qos: .userInitiated).async {
      // Basic random subsample matching in world space
      let deltaTWorld = ICPTool.runICP(
        source: sourceData,
        target: targetData,
        sourceWorld: sourceWorld,
        targetWorld: targetWorld,
        volumeWorldMatrix: volumeWorld
      )
      
      DispatchQueue.main.async {
        let sourceLocalOld = sourceObj.modelMatrix
        let parentWorld = sourceWorld * sourceLocalOld.inverse
        let newLocal = parentWorld.inverse * deltaTWorld * parentWorld * sourceLocalOld
        
        // Decompose translation, rotation, scale from newLocal
        var scale = SIMD3<Float>(
          length(newLocal.columns.0.xyz),
          length(newLocal.columns.1.xyz),
          length(newLocal.columns.2.xyz)
        )
        // Avoid division by zero
        scale.x = scale.x == 0 ? 1 : scale.x
        scale.y = scale.y == 0 ? 1 : scale.y
        scale.z = scale.z == 0 ? 1 : scale.z
        
        let rotMatrix = simd_float4x4(
          SIMD4<Float>(newLocal.columns.0.xyz / scale.x, 0),
          SIMD4<Float>(newLocal.columns.1.xyz / scale.y, 0),
          SIMD4<Float>(newLocal.columns.2.xyz / scale.z, 0),
          SIMD4<Float>(0, 0, 0, 1)
        )
        
        sourceObj.translation = newLocal.columns.3.xyz
        sourceObj.rotation = simd_float4x4.eulerAnglesZYX(from: rotMatrix)
        sourceObj.scale = scale
        
        self.isRunning = false
        
        if ICPToolContext.shared.isCancelled {
            self.statusText = "ICP cancelled."
            self.cancelICP()
            return
        }

        self.statusText = "ICP finished successfully!\nAligned \(sourceObj.name) to \(targetObj.name)."
        SceneUpdate.postGizmoChanged()
      }
    }
  }
}

class ICPToolContext {
    static let shared = ICPToolContext()
    var isCancelled: Bool = false
}