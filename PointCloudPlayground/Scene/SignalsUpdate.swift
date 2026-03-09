//
//  SignalsUpdate.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 08/03/2026.
//

import Foundation

struct SceneUpdate {
  // Only object accepted here is UUID of an object
  static let ObjectDataBlockChanged = Notification.Name("ODBC")
  static let ObjectChanged = Notification.Name("OC")
  
  // Only object accepted here is UUID of an group
  static let GroupChanged = Notification.Name("GrC")
  
  // Only object accepted here is UUID of an group
  static let GizmoChanged = Notification.Name("GiC")
}

extension SceneUpdate {
  static func postObjectDataBlockChanged(objectUUID: UUID) {
    NotificationCenter.default.post(name: ObjectDataBlockChanged, object: objectUUID)
  }
  
  static func postObjectChanged(objectUUID: UUID) {
    NotificationCenter.default.post(name: ObjectChanged, object: objectUUID)
  }
  
  static func postGroupChanged(groupUUID: UUID) {
    NotificationCenter.default.post(name: GroupChanged, object: groupUUID)
  }
  
  static func postGizmoChanged() {
    NotificationCenter.default.post(name: GizmoChanged, object: nil)
  }
}
