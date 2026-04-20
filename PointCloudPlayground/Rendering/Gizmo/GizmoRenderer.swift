import Metal
import simd

private struct GizmoVertex {
  var position: SIMD3<Float>
  var color: SIMD3<Float>
}

final class GizmoRenderer {
  private let device: MTLDevice
  private let pipelineState: MTLRenderPipelineState
  private let axisVertexBuffer: MTLBuffer
  private let axisVertexCount: Int
  private var bboxVertexBuffer: MTLBuffer?
  private var bboxVertexCount: Int = 0
  private var cameraVertexBuffer: MTLBuffer?
  private var cameraVertexCount: Int = 0
  private var volumeVertexBuffer: MTLBuffer?
  private var volumeVertexCount: Int = 0
  private let scene: PlaygroundScene
  
  init?(device: MTLDevice,
        library: MTLLibrary,
        colorPixelFormat: MTLPixelFormat,
        depthPixelFormat: MTLPixelFormat,
        scene: PlaygroundScene) {
    guard let vertexFunction = library.makeFunction(name: "gizmo_vertex"),
          let fragmentFunction = library.makeFunction(name: "gizmo_fragment") else {
      return nil
    }
    
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = depthPixelFormat
    pipelineDescriptor.vertexDescriptor = Self.makeVertexDescriptor()
    
    guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
      return nil
    }
    
    let vertices = Self.makeAxisVertices()
    guard let axisVertexBuffer = device.makeBuffer(bytes: vertices,
                                                   length: MemoryLayout<GizmoVertex>.stride * vertices.count,
                                                   options: .storageModeShared) else {
      return nil
    }
    
    self.device = device
    self.pipelineState = pipelineState
    self.axisVertexBuffer = axisVertexBuffer
    self.axisVertexCount = vertices.count
    self.scene = scene
  
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(updateBoundingBox(_:)),
      name: SceneUpdate.ObjectDataBlockChanged,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(updateBoundingBox(_:)),
      name: SceneUpdate.GroupChanged,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(updateBoundingBox(_:)),
      name: SceneUpdate.ObjectChanged,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(updateBoundingBox(_:)),
      name: SceneUpdate.GizmoChanged,
      object: nil
    )
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self, name: SceneUpdate.ObjectDataBlockChanged, object: nil)
    NotificationCenter.default.removeObserver(self, name: SceneUpdate.GroupChanged, object: nil)
    NotificationCenter.default.removeObserver(self, name: SceneUpdate.ObjectChanged, object: nil)
    NotificationCenter.default.removeObserver(self, name: SceneUpdate.GizmoChanged, object: nil)
  }
  
  func draw(encoder: MTLRenderCommandEncoder, frame: FrameContext) {
    encoder.setViewport(frame.viewport)
    encoder.setRenderPipelineState(pipelineState)
    encoder.setDepthStencilState(frame.depth.overlayDepthStencilState)
    encoder.setCullMode(.none)
    
    // Draw axis lines
    encoder.setVertexBuffer(axisVertexBuffer, offset: 0, index: 0)
    encoder.setVertexBuffer(frame.cameraBuffer, offset: 0, index: 1)
    encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: axisVertexCount)
    
    // Draw bounding box wireframe for selected object
    if let bboxBuffer = bboxVertexBuffer, bboxVertexCount > 0 {
      encoder.setVertexBuffer(bboxBuffer, offset: 0, index: 0)
      encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: bboxVertexCount)
    }

    // Draw camera gizmos
    if let camBuffer = cameraVertexBuffer, cameraVertexCount > 0 {
      encoder.setVertexBuffer(camBuffer, offset: 0, index: 0)
      encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: cameraVertexCount)
    }

    // Draw volume gizmos
    if let volBuffer = volumeVertexBuffer, volumeVertexCount > 0 {
      encoder.setVertexBuffer(volBuffer, offset: 0, index: 0)
      encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: volumeVertexCount)
    }
  }
  
  @objc private func updateBoundingBox(_ n: Notification) {
    updateInternalBoundingBox()
    updateCameras()
    updateVolumes()
  }

  private func updateVolumes() {
    var allVolumeVertices: [GizmoVertex] = []
    
    let visibleVolumes = scene.allVisibleObjects.filter { $0.dataBlockType == .volume }
    for volume in visibleVolumes {
      let isSelected = scene.selectedObject?.id == volume.id
      let matrix = scene.rootGroup.hierarchicalMatrix(forItemId: volume.id, in: scene.rootGroup)
      
      let volVertices = Self.makeVolumeVertices(modelMatrix: matrix, isSelected: isSelected)
      allVolumeVertices.append(contentsOf: volVertices)
    }
    
    volumeVertexCount = allVolumeVertices.count
    if volumeVertexCount > 0 {
      volumeVertexBuffer = device.makeBuffer(bytes: allVolumeVertices,
                                             length: MemoryLayout<GizmoVertex>.stride * allVolumeVertices.count,
                                             options: .storageModeShared)
    } else {
      volumeVertexBuffer = nil
    }
  }

  private func updateCameras() {
    var allCameraVertices: [GizmoVertex] = []
    
    let visibleCameras = scene.allVisibleObjects.filter { $0.dataBlockType == .camera }
    for camera in visibleCameras {
      let isSelected = scene.selectedObject?.id == camera.id
      var matrix = scene.rootGroup.hierarchicalMatrix(forItemId: camera.id, in: scene.rootGroup)
      
      if let camData = camera.asCameraData {
        let q = simd_quatf(vector: camData.orientation)
        matrix = matrix * simd_float4x4(q)
      }
      
      let camVertices = Self.makeCameraVertices(modelMatrix: matrix, isSelected: isSelected)
      allCameraVertices.append(contentsOf: camVertices)
    }
    
    cameraVertexCount = allCameraVertices.count
    if cameraVertexCount > 0 {
      cameraVertexBuffer = device.makeBuffer(bytes: allCameraVertices,
                                             length: MemoryLayout<GizmoVertex>.stride * allCameraVertices.count,
                                             options: .storageModeShared)
    } else {
      cameraVertexBuffer = nil
    }
  }

  private func updateInternalBoundingBox() {
    var bboxMatrix: simd_float4x4?
    var bbox: BoundingBox?
    
    // Check if a group is selected
    if let selectedGroup = scene.selectedGroup,
       let bbox_ = selectedGroup.boundingBox {
      bboxMatrix = selectedGroup.modelMatrix
      bbox = bbox_
    }
    
    // Check if a point cloud object is selected
    if let selectedObject = scene.selectedPointCloudObject,
       let pointCloudData = selectedObject.asPointCloudData,
       let bbox_ = pointCloudData.boundingBox {
      bboxMatrix = scene.rootGroup.hierarchicalMatrix(forItemId: selectedObject.id, in: scene.rootGroup)
      bbox = bbox_
    }
    
    guard let bboxMatrix, let bbox else {return}
    bboxVertexBuffer = nil
    bboxVertexCount = 0
    
    // Use hierarchical transformation: account for parent group transforms
    let vertices = Self.makeBoundingBoxVertices(bbox: bbox, modelMatrix: bboxMatrix)
    bboxVertexCount = vertices.count
    bboxVertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: MemoryLayout<GizmoVertex>.stride * vertices.count,
                                         options: .storageModeShared)
  }
  
  private static func makeCameraVertices(modelMatrix: simd_float4x4, isSelected: Bool) -> [GizmoVertex] {
    let color: SIMD3<Float> = isSelected ? SIMD3<Float>(1, 0.8, 0) : SIMD3<Float>(0.2, 0.6, 1.0)
    
    // In Colmap, local camera +Z points forward, Y points down, X points right
    let z: Float = 1.0
    let x: Float = 0.5
    let y: Float = 0.35
    
    let localPoints: [SIMD3<Float>] = [
      .zero,
      SIMD3<Float>(-x, -y, z), // Top Left
      SIMD3<Float>( x, -y, z), // Top Right
      SIMD3<Float>( x,  y, z), // Bottom Right
      SIMD3<Float>(-x,  y, z)  // Bottom Left
    ]
    
    let worldPoints = localPoints.map {
      let w = modelMatrix * SIMD4<Float>($0, 1.0)
      return SIMD3<Float>(w.x, w.y, w.z)
    }
    
    let lineIndices: [(Int, Int)] = [
      (0, 1), (0, 2), (0, 3), (0, 4), // Pyramid lines
      (1, 2), (2, 3), (3, 4), (4, 1)  // Base rectangle lines
    ]
    
    return lineIndices.flatMap { (a, b) in
      [GizmoVertex(position: worldPoints[a], color: color),
       GizmoVertex(position: worldPoints[b], color: color)]
    }
  }

  private static func makeVolumeVertices(modelMatrix: simd_float4x4, isSelected: Bool) -> [GizmoVertex] {
    let color: SIMD3<Float> = isSelected ? SIMD3<Float>(1, 0.8, 0) : SIMD3<Float>(0.2, 0.8, 0.2)
    let lo = SIMD3<Float>(-0.5, -0.5, -0.5)
    let hi = SIMD3<Float>( 0.5,  0.5,  0.5)
    
    // 8 corners: iterate over each bit pattern of (x, y, z) = lo/hi
    let corners = (0..<8).map { i -> SIMD3<Float> in
      let local = SIMD3<Float>(
        (i & 1) != 0 ? hi.x : lo.x,
        (i & 2) != 0 ? hi.y : lo.y,
        (i & 4) != 0 ? hi.z : lo.z
      )
      let w = modelMatrix * SIMD4<Float>(local, 1.0)
      return SIMD3<Float>(w.x, w.y, w.z)
    }
    
    // 12 edges: pairs that differ by exactly one bit
    let edges: [(Int, Int)] = [
      (0,1),(2,3),(4,5),(6,7), // differ in bit 0 (x)
      (0,2),(1,3),(4,6),(5,7), // differ in bit 1 (y)
      (0,4),(1,5),(2,6),(3,7), // differ in bit 2 (z)
    ]
    return edges.flatMap { (a, b) in
      [GizmoVertex(position: corners[a], color: color),
       GizmoVertex(position: corners[b], color: color)]
    }
  }

  private static func makeVertexDescriptor() -> MTLVertexDescriptor {
    let descriptor = MTLVertexDescriptor()
    descriptor.attributes[0].format = .float3
    descriptor.attributes[0].offset = 0
    descriptor.attributes[0].bufferIndex = 0
    descriptor.attributes[1].format = .float3
    descriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
    descriptor.attributes[1].bufferIndex = 0
    descriptor.layouts[0].stride = MemoryLayout<GizmoVertex>.stride
    descriptor.layouts[0].stepFunction = .perVertex
    return descriptor
  }
  
  private static func makeAxisVertices() -> [GizmoVertex] {
    let axisExtent: Float = 1_000_000
    return [
      GizmoVertex(position: SIMD3<Float>(-axisExtent, 0, 0), color: SIMD3<Float>(1, 0, 0)),
      GizmoVertex(position: SIMD3<Float>( axisExtent, 0, 0), color: SIMD3<Float>(1, 0, 0)),
      GizmoVertex(position: SIMD3<Float>(0, -axisExtent, 0), color: SIMD3<Float>(0, 1, 0)),
      GizmoVertex(position: SIMD3<Float>(0,  axisExtent, 0), color: SIMD3<Float>(0, 1, 0)),
      GizmoVertex(position: SIMD3<Float>(0, 0, -axisExtent), color: SIMD3<Float>(0, 0, 1)),
      GizmoVertex(position: SIMD3<Float>(0, 0,  axisExtent), color: SIMD3<Float>(0, 0, 1))
    ]
  }
  
  private static func makeBoundingBoxVertices(bbox: BoundingBox, modelMatrix: simd_float4x4) -> [GizmoVertex] {
    let color = SIMD3<Float>(1, 1, 0)
    let lo = SIMD3<Float>(bbox.min_x, bbox.min_y, bbox.min_z)
    let hi = SIMD3<Float>(bbox.max_x, bbox.max_y, bbox.max_z)
    
    // 8 corners: iterate over each bit pattern of (x, y, z) = lo/hi
    let corners = (0..<8).map { i -> SIMD3<Float> in
      let local = SIMD3<Float>(
        (i & 1) != 0 ? hi.x : lo.x,
        (i & 2) != 0 ? hi.y : lo.y,
        (i & 4) != 0 ? hi.z : lo.z
      )
      let w = modelMatrix * SIMD4<Float>(local, 1.0)
      return SIMD3<Float>(w.x, w.y, w.z)
    }
    
    // 12 edges: pairs that differ by exactly one bit
    let edges: [(Int, Int)] = [
      (0,1),(2,3),(4,5),(6,7), // differ in bit 0 (x)
      (0,2),(1,3),(4,6),(5,7), // differ in bit 1 (y)
      (0,4),(1,5),(2,6),(3,7), // differ in bit 2 (z)
    ]
    return edges.flatMap { (a, b) in
      [GizmoVertex(position: corners[a], color: color),
       GizmoVertex(position: corners[b], color: color)]
    }
  }
}

extension GizmoRenderer: RenderPass {}
