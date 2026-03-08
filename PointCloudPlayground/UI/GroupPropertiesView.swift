//
//  GroupPropertiesView.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 8/03/2026.
//

import SwiftUI

struct GroupPropertiesView: View {
  @ObservedObject var group: SceneGroup
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Group Properties")
        .font(.subheadline.bold())
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
      
      Divider()
      
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Name")
              .font(.caption.bold())
              .foregroundColor(.secondary)
            TextField("Group name", text: $group.name)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .font(.system(.body, design: .default))
          }
          
          Divider().padding(.vertical, 4)
          
          VStack(alignment: .leading, spacing: 10) {
            Text("Transform")
              .font(.caption.bold())
              .foregroundColor(.secondary)
            
            TransformEditorView(
              translation: $group.translation,
              rotation: $group.rotation,
              scale: $group.scale
            )
          }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
      }
    }
    .background(Color(nsColor: .controlBackgroundColor))
  }
}

#Preview {
  GroupPropertiesView(group: SceneGroup(name: "Test Group"))
}
