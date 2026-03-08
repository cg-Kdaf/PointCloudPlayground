//
//  SceneGroup.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 24/02/2026.
//

import Foundation
import Combine

enum SceneTreeItemKind: String, Codable {
  case group
  case object
}

struct SceneTreeDragPayload: Codable, Equatable {
  let kind: SceneTreeItemKind
  let id: UUID
}

final class SceneGroup: ObservableObject, Identifiable {
  let id = UUID()
  @Published var name: String
  @Published var childGroups: [SceneGroup]
  @Published var objects: [SceneObject]
  
  var allGroups: [SceneGroup] {[self] + childGroups.flatMap(\.allGroups)}
  var allObjects: [SceneObject] {objects + childGroups.flatMap(\.allObjects)}
  
  init(name: String,
       childGroups: [SceneGroup] = [],
       objects: [SceneObject] = []) {
    self.name = name
    self.childGroups = childGroups
    self.objects = objects
  }
  
  func object(withId id: UUID) -> SceneObject? {
    if let object = objects.first(where: { $0.id == id }) {
      return object
    }
    
    for childGroup in childGroups {
      if let object = childGroup.object(withId: id) {
        return object
      }
    }
    
    return nil
  }
  
  func group(withId id: UUID) -> SceneGroup? {
    if self.id == id {
      return self
    }
    
    for childGroup in childGroups {
      if let group = childGroup.group(withId: id) {
        return group
      }
    }
    
    return nil
  }
  
  func appendGroup(_ group: SceneGroup, toGroupWithId targetGroupId: UUID) -> Bool {
    if id == targetGroupId {
      childGroups.append(group)
      return true
    }
    
    for index in childGroups.indices {
      if childGroups[index].appendGroup(group, toGroupWithId: targetGroupId) {
        return true
      }
    }
    
    return false
  }
  
  func appendObject(_ object: SceneObject, toGroupWithId targetGroupId: UUID) -> Bool {
    if id == targetGroupId {
      objects.append(object)
      return true
    }
    
    for index in childGroups.indices {
      if childGroups[index].appendObject(object, toGroupWithId: targetGroupId) {
        return true
      }
    }
    
    return false
  }
  
  func removeObject(withId objectId: UUID) -> SceneObject? {
    if let index = objects.firstIndex(where: { $0.id == objectId }) {
      return objects.remove(at: index)
    }
    
    for index in childGroups.indices {
      if let removedObject = childGroups[index].removeObject(withId: objectId) {
        return removedObject
      }
    }
    
    return nil
  }
  
  func removeGroup(withId groupId: UUID) -> SceneGroup? {
    if let index = childGroups.firstIndex(where: { $0.id == groupId }) {
      return childGroups.remove(at: index)
    }
    
    for childGroup in childGroups {
      if let removedGroup = childGroup.removeGroup(withId: groupId) {
        return removedGroup
      }
    }
    
    return nil
  }
}
