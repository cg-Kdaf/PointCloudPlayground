//
//  ScenePropertyPanelView.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 7/03/2026.
//

import SwiftUI

struct ScenePropertyPanelView: View {
  var object: SceneObject?
  var pointCloudData: PointCloudDataBlock?
  var volumeData: VolumeDataBlock?
  var group: SceneGroup?
  
  var body: some View {
    if let group = group {
      GroupPropertiesView(group: group)
    } else if let object = object {
      let volData = object.asVolumeData
      ObjectPropertiesView(object: object, pointCloudData: pointCloudData, volumeData: volData)
    }
  }
}

struct InfoRow: View {
  let label: String
  let value: String
  
  var body: some View {
    HStack {
      Text(label)
        .font(.caption)
        .foregroundColor(.secondary)
      Spacer()
      Text(value)
        .font(.caption.monospacedDigit())
        .fontWeight(.medium)
    }
  }
}
