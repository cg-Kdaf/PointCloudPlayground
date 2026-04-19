//
//  PlaygroundScene.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 24/02/2026.
//

import Foundation
import Combine

final class PlaygroundScene: ObservableObject {
  @Published var rootGroup: SceneGroup = .init(name: "Root")
  @Published var selectedIds: [UUID] = []
  
  var activeDragPayload: SceneTreeDragPayload?
  
  var allObjects: [SceneObject] {rootGroup.allObjects}
  var allVisibleObjects: [SceneObject] {allObjects.filter { $0.isVisible }}
  var allGroups: [SceneGroup] {rootGroup.allGroups}
  
  var selectableIds: [UUID] {allGroups.map(\.id) + allObjects.map(\.id)}
  
  var selectedObject: SceneObject? {
    guard selectedIds.count == 1,
          let selectedId = selectedIds.first else {
      return nil
    }
    return rootGroup.object(withId: selectedId)
  }
  
  var selectedGroup: SceneGroup? {
    guard selectedIds.count == 1,
          let selectedId = selectedIds.first else {
      return nil
    }
    return rootGroup.group(withId: selectedId)
  }
  
  var selectedPointCloudObject: SceneObject? {
    guard let selectedObject,
          selectedObject.asPointCloudData != nil else {
      return nil
    }
    return selectedObject
  }
  
  private var dataBlockObservations: [UUID: AnyCancellable] = [:]
  
  @discardableResult
  func addGroup(named name: String = "New Group", parentGroupId: UUID? = nil) -> UUID {
    let group = SceneGroup(name: name)
    
    let observationPublishers: [AnyPublisher<Void, Never>] = [
      group.$scale.map { _ in () }.eraseToAnyPublisher(),
      group.$rotation.map { _ in () }.eraseToAnyPublisher(),
      group.$translation.map { _ in () }.eraseToAnyPublisher(),
    ]
    
    let observation = Publishers.MergeMany(observationPublishers)
      .receive(on: DispatchQueue.main)
      .sink { [] _ in
        SceneUpdate.postGroupChanged(groupUUID: group.id)
      }
    dataBlockObservations[group.id] = observation
    
    if let parentGroupId {
      if rootGroup.appendGroup(group, toGroupWithId: parentGroupId) {
        SceneUpdate.postGroupChanged(groupUUID: group.id)
        return group.id
      }
    }

    rootGroup.childGroups.append(group)
    SceneUpdate.postGroupChanged(groupUUID: group.id)
    return group.id
  }
  
  func addCloud(filepath: String, toGroupId: UUID? = nil) -> SceneObject? {
    print("Adding cloud from filepath", filepath)
    let data: PointCloudDataBlock?
    
    if filepath.hasSuffix(".laz") || filepath.hasSuffix(".las") {
      let importer = LazrscImporter()
      data = importer.importFrom(filePath: filepath)
    } else {
      let importer = ColmapImporter()
      data = importer.importPointCloud(fromDirectory: filepath)
    }
    
    guard let data else {
      return nil
    }
    
    let name = URL(fileURLWithPath: filepath).lastPathComponent
    let object = SceneObject(name: name, dataBlock: data, type: .pointCloud)
    
    let observationPublishers: [AnyPublisher<Void, Never>] = [
      data.$color.map { _ in () }.eraseToAnyPublisher(),
      data.$pointSize.map { _ in () }.eraseToAnyPublisher(),
      object.$name.map { _ in () }.eraseToAnyPublisher(),
      object.$isVisible.map { _ in () }.eraseToAnyPublisher(),
      object.$translation.map { _ in () }.eraseToAnyPublisher(),
      object.$rotation.map { _ in () }.eraseToAnyPublisher(),
      object.$scale.map { _ in () }.eraseToAnyPublisher()
    ]
    
    let observation = Publishers.MergeMany(observationPublishers)
      .receive(on: DispatchQueue.main)
      .sink { [] _ in
        SceneUpdate.postObjectDataBlockChanged(objectUUID: object.id)
      }
    
    dataBlockObservations[object.id] = observation

    if let targetId = toGroupId {
      if rootGroup.appendObject(object, toGroupWithId: targetId) {
        SceneUpdate.postObjectChanged(objectUUID: object.id)
        SceneUpdate.postObjectDataBlockChanged(objectUUID: object.id)
        return object
      }
    }

    rootGroup.objects.append(object)
    SceneUpdate.postObjectChanged(objectUUID: object.id)
    SceneUpdate.postObjectDataBlockChanged(objectUUID: object.id)
    return object
  }
  
  func removeObject(_ id: UUID) {
    if rootGroup.removeObject(withId: id) != nil {
      dataBlockObservations.removeValue(forKey: id)
      selectedIds.removeAll { $0 == id }
      SceneUpdate.postObjectChanged(objectUUID: id)
      return
    }
  }

  func addColmapScene(fromDirectory path: String, toGroupId: UUID? = nil) {
    let groupName = URL(fileURLWithPath: path).lastPathComponent
    let colmapGroupId = addGroup(named: groupName, parentGroupId: toGroupId)

    let importer = ColmapImporter()
    
    // 1. Add Point Cloud (Features)
    var cloudCenter = SIMD3<Float>.zero
    if let cloudData = importer.importPointCloud(fromDirectory: path) {
      cloudCenter = SIMD3<Float>(Float(cloudData.center.x), Float(cloudData.center.y), Float(cloudData.center.z))
      
      let cloudObject = SceneObject(name: "Features", dataBlock: cloudData, type: .pointCloud)
      
      let cloudObservationPublishers: [AnyPublisher<Void, Never>] = [
        cloudData.$color.map { _ in () }.eraseToAnyPublisher(),
        cloudData.$pointSize.map { _ in () }.eraseToAnyPublisher(),
        cloudObject.$name.map { _ in () }.eraseToAnyPublisher(),
        cloudObject.$isVisible.map { _ in () }.eraseToAnyPublisher(),
        cloudObject.$translation.map { _ in () }.eraseToAnyPublisher(),
        cloudObject.$rotation.map { _ in () }.eraseToAnyPublisher(),
        cloudObject.$scale.map { _ in () }.eraseToAnyPublisher()
      ]
      
      dataBlockObservations[cloudObject.id] = Publishers.MergeMany(cloudObservationPublishers)
        .receive(on: DispatchQueue.main)
        .sink { _ in
        SceneUpdate.postObjectDataBlockChanged(objectUUID: cloudObject.id)
      }
      
      if rootGroup.appendObject(cloudObject, toGroupWithId: colmapGroupId) {
        SceneUpdate.postObjectChanged(objectUUID: cloudObject.id)
      } else {
        rootGroup.objects.append(cloudObject)
        SceneUpdate.postObjectChanged(objectUUID: cloudObject.id)
      }
    }
    
    // 2. Add Cameras as a New Object Type
    let camerasGroupId = addGroup(named: "Cameras", parentGroupId: colmapGroupId)
    let poses = importer.parseImages(fromDirectory: path)
    
    for pose in poses {
      // Colmap poses represent World-to-Camera transformations
      let q = simd_quatf(ix: Float(pose.qx), iy: Float(pose.qy), iz: Float(pose.qz), r: Float(pose.qw))
      let t = SIMD3<Float>(Float(pose.tx), Float(pose.ty), Float(pose.tz))
      
      // Calculate Camera-to-World
      let qInv = q.inverse
      let cWorld = qInv.act(-t)
      
      // Translate to the centered coordinates used by the point cloud
      let finalPosition = cWorld - cloudCenter
      let orientation = SIMD4<Float>(qInv.vector.x, qInv.vector.y, qInv.vector.z, qInv.vector.w)
      
      let baseDirUrl = URL(fileURLWithPath: path).deletingLastPathComponent().deletingLastPathComponent()
      let imgPath1 = baseDirUrl.appendingPathComponent("images").appendingPathComponent(pose.imageName).path
      let imgPath2 = baseDirUrl.appendingPathComponent("aiguille_midi_images").appendingPathComponent(pose.imageName).path
      let imgPath = FileManager.default.fileExists(atPath: imgPath1) ? imgPath1 : (FileManager.default.fileExists(atPath: imgPath2) ? imgPath2 : nil)
      
      let cameraData = CameraDataBlock(position: finalPosition, orientation: orientation, imagePath: imgPath)
      let cameraObject = SceneObject(name: pose.imageName, dataBlock: cameraData, type: .camera)
      cameraObject.translation = finalPosition // Bind object's translation to its position
      
      let camObservationPublishers: [AnyPublisher<Void, Never>] = [
        cameraData.$position.map { _ in () }.eraseToAnyPublisher(),
        cameraData.$orientation.map { _ in () }.eraseToAnyPublisher(),
        cameraData.$fov.map { _ in () }.eraseToAnyPublisher(),
        cameraObject.$name.map { _ in () }.eraseToAnyPublisher(),
        cameraObject.$isVisible.map { _ in () }.eraseToAnyPublisher(),
        cameraObject.$translation.map { _ in () }.eraseToAnyPublisher(),
        cameraObject.$rotation.map { _ in () }.eraseToAnyPublisher(),
        cameraObject.$scale.map { _ in () }.eraseToAnyPublisher()
      ]
      
//      dataBlockObservations[cameraObject.id] = Publishers.MergeMany(camObservationPublishers)
//        .receive(on: DispatchQueue.main)
//        .sink { _ in
//       SceneUpdate.postObjectDataBlockChanged(objectUUID: cameraObject.id)
//      }
      
      if !rootGroup.appendObject(cameraObject, toGroupWithId: camerasGroupId) {
        rootGroup.objects.append(cameraObject)
      }
    }
  }
}
