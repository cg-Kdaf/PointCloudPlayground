//
//  PlaygroundScene+Tree.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 7/03/2026.
//

import Foundation

extension PlaygroundScene {
  func toggleVisibility(for id: UUID, _ visible: Bool? = nil) {
    if let object = rootGroup.object(withId: id) {
      if let visible {
        object.isVisible = visible
      } else {
        object.isVisible.toggle()
      }
      SceneUpdate.postObjectChanged(objectUUID: id)
    }
  }
  
  func moveItem(kind: SceneTreeItemKind, id: UUID, toGroupId: UUID?) -> Bool {
    switch kind {
    case .group:
      return moveGroup(withId: id, toGroupId: toGroupId)
    case .object:
      guard let toGroupId else {
        return false
      }
      return moveObject(withId: id, toGroupId: toGroupId)
    }
  }
  
  private func moveObject(withId id: UUID, toGroupId: UUID) -> Bool {
    guard let targetGroup = rootGroup.group(withId: toGroupId),
          let object = rootGroup.removeObject(withId: id) else {
      return false
    }
    
    targetGroup.objects.append(object)
    SceneUpdate.postObjectChanged(objectUUID: id)
    return true
  }
  
  private func moveGroup(withId id: UUID, toGroupId: UUID?) -> Bool {
    guard let movingGroup = rootGroup.group(withId: id) else {
      return false
    }
    
    if let toGroupId {
      guard let targetGroup = rootGroup.group(withId: toGroupId),
            targetGroup.id != movingGroup.id,
            movingGroup.group(withId: toGroupId) == nil,
            let detachedGroup = rootGroup.removeGroup(withId: id) else {
        return false
      }
      
      targetGroup.childGroups.append(detachedGroup)
      SceneUpdate.postGroupChanged(groupUUID: id)
      return true
    }
    
    guard let detachedGroup = rootGroup.removeGroup(withId: id) else {
      return false
    }
    
    rootGroup.childGroups.append(detachedGroup)
    SceneUpdate.postGroupChanged(groupUUID: id)
    return true
  }
}
