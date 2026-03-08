//
//  SceneGroup.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 24/02/2026.
//

import Foundation
import Combine
import simd

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

  // Transformation properties
  @Published var translation: SIMD3<Float> = .zero
  @Published var rotation: SIMD3<Float> = .zero // Euler angles in radians (X, Y, Z)
  @Published var scale: SIMD3<Float> = .one

  var modelMatrix: simd_float4x4 {
    simd_float4x4.translation(translation) *
    simd_float4x4.fromEulerZYX(rotation) *
    simd_float4x4.scaling(scale)
  }

  /// Computed bounding box that encloses all objects in this group and all child groups
  var boundingBox: BoundingBox? {
    var minX = Float.greatestFiniteMagnitude
    var maxX = -Float.greatestFiniteMagnitude
    var minY = Float.greatestFiniteMagnitude
    var maxY = -Float.greatestFiniteMagnitude
    var minZ = Float.greatestFiniteMagnitude
    var maxZ = -Float.greatestFiniteMagnitude
    var hasAnyBBox = false

    // Collect bounding boxes from all direct objects
    for object in objects {
      if let objectBBox = object.asPointCloudData?.boundingBox {
        for p in objectBBox.toPoints() {
          let transformedP = object.modelMatrix * p
          minX = min(minX, transformedP.x)
          maxX = max(maxX, transformedP.x)
          minY = min(minY, transformedP.y)
          maxY = max(maxY, transformedP.y)
          minZ = min(minZ, transformedP.z)
          maxZ = max(maxZ, transformedP.z)
        }
        hasAnyBBox = true
      }
    }

    // Recursively collect bounding boxes from all child groups
    for childGroup in childGroups {
      if let childBBox = childGroup.boundingBox {
        for p in childBBox.toPoints() {
          let transformedP = childGroup.modelMatrix * p
          minX = min(minX, transformedP.x)
          maxX = max(maxX, transformedP.x)
          minY = min(minY, transformedP.y)
          maxY = max(maxY, transformedP.y)
          minZ = min(minZ, transformedP.z)
          maxZ = max(maxZ, transformedP.z)
        }
        hasAnyBBox = true
      }
    }

    return hasAnyBBox ? BoundingBox(max_x: maxX, min_x: minX, max_y: maxY, min_y: minY, max_z: maxZ, min_z: minZ) : nil
  }

  var allGroups: [SceneGroup] {[self] + childGroups.flatMap(\.allGroups)}
  var allObjects: [SceneObject] {objects + childGroups.flatMap(\.allObjects)}

  init(name: String,
       childGroups: [SceneGroup] = [],
       objects: [SceneObject] = []) {
    self.name = name
    self.childGroups = childGroups
    self.objects = objects
    self.translation = .zero
    self.rotation = .zero
    self.scale = .one
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
  
  /// Find the direct group containing the given object (searches this group and all descendants)
  func parentGroup(ofObjectId objectId: UUID) -> SceneGroup? {
    if objects.contains(where: { $0.id == objectId }) {
      return self
    }
    
    for childGroup in childGroups {
      if let parent = childGroup.parentGroup(ofObjectId: objectId) {
        return parent
      }
    }
    
    return nil
  }
  
  /// Calculate the accumulated transformation matrix from root to an object (including object matrix)
  /// Calculate the accumulated transformation matrix from root to an group (including group matrix)
  func hierarchicalMatrix(forItemId itemId: UUID, in rootGroup: SceneGroup) -> simd_float4x4 {
    var objectItem: SceneObject? = nil
    
    // Find all groups from root down to the object
    var groupPath: [SceneGroup] = []
    func findPath(in group: SceneGroup) -> Bool {
      if group.id == itemId {
        groupPath.append(group)
        return true
      }
      if let obj = group.objects.first(where: { $0.id == itemId }) {
        objectItem = obj
        groupPath.append(group)
        return true
      }
      
      for childGroup in group.childGroups {
        if findPath(in: childGroup) {
          groupPath.insert(group, at: 0)
          return true
        }
      }
      
      return false
    }
    
    let _ = findPath(in: rootGroup)
    
    // Multiply all parent matrices together
    var result = simd_float4x4.translation(SIMD3<Float>(0, 0, 0))
    for group in groupPath {
      result = result * group.modelMatrix
    }
    
    if let objectItem {
      // Finally multiply by the object's own matrix
      result = result * objectItem.modelMatrix
    }
    
    return result
  }
}
