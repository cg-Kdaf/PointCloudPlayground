//
//  SceneOutlinerView.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 7/03/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct SceneOutlinerView: View {
  @ObservedObject var scene: PlaygroundScene
  @State private var isRootDropTargeted = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack(spacing: 12) {
        Text("Outliner")
          .font(.headline.bold())
        
        Spacer()
        
        Button(action: { scene.addGroup() }) {
          Image(systemName: "folder.badge.plus")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        
        Menu {
          Button("Add Group", action: { scene.addGroup() })
          Button("Select All", action: { scene.setSelection(ids: scene.selectableIds) })
          Button("Deselect All", action: { scene.setSelection(ids: []) })
          Menu("Visibility") {
            Button("Show All", action: {
              for object in scene.allObjects {
                scene.setVisibility(true, for: object.id)
              }
            })
            Button("Hide All", action: {
              for object in scene.allObjects {
                scene.setVisibility(false, for: object.id)
              }
            })
          }
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      
      Divider()
      
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 4) {
          SceneGroupRowView(scene: scene, group: scene.rootGroup, depth: -1, flattenHeadLess: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
      }
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isRootDropTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
      )
      .onDrop(of: [UTType.plainText], delegate: SceneGroupDropDelegate(scene: scene, targetGroupId: scene.rootGroup.id, isTargeted: $isRootDropTargeted))
      
      Divider()
      
      if let selectedGroup = scene.selectedGroup {
        ScenePropertyPanelView(
          object: nil,
          pointCloudData: nil,
          group: selectedGroup
        )
      } else if let selectedObject = scene.selectedPointCloudObject {
        if let pointCloudData = selectedObject.asPointCloudData {
          ScenePropertyPanelView(
            object: selectedObject,
            pointCloudData: pointCloudData,
            group: nil
          )
        }
      }
    }
    .background(Color(nsColor: .controlBackgroundColor))
  }
}

#Preview {
  let scene = PlaygroundScene()
  SceneOutlinerView(scene: scene)
}
