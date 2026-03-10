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
  
  func addGroup(named name: String = "New Group", parentGroupId: UUID? = nil) {
    let group = SceneGroup(name: name)
    
    let observationPublishers: [AnyPublisher<Void, Never>] = [
      group.$scale.map { _ in () }.eraseToAnyPublisher(),
      group.$rotation.map { _ in () }.eraseToAnyPublisher(),
      group.$translation.map { _ in () }.eraseToAnyPublisher(),
    ]
    
    let observation = Publishers.MergeMany(observationPublishers)
      .sink { [] _ in
        SceneUpdate.postGroupChanged(groupUUID: group.id)
      }
    dataBlockObservations[group.id] = observation
    
    if let parentGroupId {
      if rootGroup.appendGroup(group, toGroupWithId: parentGroupId) {
        SceneUpdate.postGroupChanged(groupUUID: group.id)
        return
      }
    }
    
    rootGroup.childGroups.append(group)
    SceneUpdate.postGroupChanged(groupUUID: group.id)
  }
  
  func addCloud(filepath: String, toGroupId: UUID? = nil) {
    let data: PointCloudDataBlock?
    
    if filepath.hasSuffix(".laz") || filepath.hasSuffix(".las") {
      let importer = LazrscImporter()
      data = importer.importFrom(filePath: filepath)
    } else {
      let importer = ColmapImporter()
      data = importer.importPointCloud(fromDirectory: filepath)
    }
    
    guard let data else {
      return
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
      .sink { [] _ in
        SceneUpdate.postObjectDataBlockChanged(objectUUID: object.id)
      }
    
    dataBlockObservations[object.id] = observation
    
    rootGroup.objects.append(object)
    SceneUpdate.postObjectChanged(objectUUID: object.id)
    SceneUpdate.postObjectDataBlockChanged(objectUUID: object.id)
  }
  
  func removeObject(_ id: UUID) {
    if rootGroup.removeObject(withId: id) != nil {
      dataBlockObservations.removeValue(forKey: id)
      selectedIds.removeAll { $0 == id }
      SceneUpdate.postObjectChanged(objectUUID: id)
      return
    }
  }
}
