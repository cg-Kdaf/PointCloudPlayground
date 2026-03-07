//
//  SceneOutlinerView.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 7/03/2026.
//

import SwiftUI
import Combine

struct SceneOutlinerView: View {
  @ObservedObject var scene: PlaygroundScene
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack(spacing: 12) {
        Text("Outliner")
          .font(.headline.bold())
        
        Spacer()
        
        Menu {
          Button("Select All", action: selectAll)
          Button("Deselect All", action: { scene.deselectAll() })
          Menu("Visibility") {
            Button("Show All", action: showAll)
            Button("Hide All", action: hideAll)
            Button("Isolate Selected", action: isolateSelected)
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
      
      // Scene tree
      if scene.objects.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "square.3.layers.3d")
            .font(.system(size: 32))
            .foregroundColor(.secondary)
          Text("No objects in scene")
            .foregroundColor(.secondary)
          Text("Import a point cloud to get started")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(scene.objects, id: \.id) { object in
              SceneNodeRowView(
                object: object,
                isSelected: scene.selectedObjectId == object.id,
                onSelect: { scene.selectObject(id: object.id) },
                onToggleVisibility: { scene.toggleVisibility(for: object.id) }
              )
              
              if scene.objects.last?.id != object.id {
                Divider()
                  .padding(.horizontal, 8)
                  .padding(.vertical, 0)
              }
            }
          }
          .padding(.vertical, 4)
        }
      }
      
      Divider()
      
      // Properties panel for selected object
      if let selectedId = scene.selectedObjectId,
         let selectedObject = scene.objects.first(where: { $0.id == selectedId }) {
        if let pointCloudData = selectedObject.asPointCloudData {
          ScenePropertyPanelView(object: selectedObject, pointCloudData: pointCloudData, filePath: getFilePath(for: selectedId))
        }
      }
    }
    .background(Color(nsColor: .controlBackgroundColor))
  }
  
  private func selectAll() {
    // Select all objects (since single-select model, select the last one)
    if let lastObject = scene.objects.last {
      scene.selectObject(id: lastObject.id)
    }
  }
  
  private func showAll() {
    for object in scene.objects {
      scene.setVisibility(true, for: object.id)
    }
  }
  
  private func hideAll() {
    for object in scene.objects {
      scene.setVisibility(false, for: object.id)
    }
  }
  
  private func isolateSelected() {
    hideAll()
    if let selectedId = scene.selectedObjectId {
      scene.setVisibility(true, for: selectedId)
    }
  }  
  private func getFilePath(for objectId: UUID) -> String {
    if let index = scene.objects.firstIndex(where: { $0.id == objectId }) {
      return scene.filePaths[index]
    }
    return ""
  }}

struct SceneNodeRowView: View {
  let object: SceneObject
  let isSelected: Bool
  let onSelect: () -> Void
  let onToggleVisibility: () -> Void
  @State private var isHovered = false
  
  var body: some View {
    HStack(spacing: 8) {
      // Visibility toggle (eye icon)
      Button(action: onToggleVisibility) {
        Image(systemName: object.isVisible ? "eye.fill" : "eye.slash.fill")
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(object.isVisible ? .blue : .gray)
          .frame(width: 24, height: 24)
      }
      .buttonStyle(PlainButtonStyle())
      
      // Object icon
      Image(systemName: "cube.fill")
        .font(.system(size: 13))
        .foregroundColor(.orange)
        .frame(width: 18)
      
      // Object name
      Text(object.name)
        .lineLimit(1)
        .truncationMode(.tail)
        .font(.system(.body, design: .default))
        .foregroundColor(isSelected ? .blue : .primary)
      
      Spacer()
      
      // Selection indicator
      if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 13))
          .foregroundColor(.blue)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture(count: 1) { _ in handleSelection() }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      isSelected
        ? Color.blue.opacity(0.15)
        : isHovered
        ? Color.gray.opacity(0.08)
        : Color.clear
    )
    .cornerRadius(6)
    .onHover { hovering in isHovered = hovering }
  }
  
  private func handleSelection() {
    let modifierFlags = NSEvent.modifierFlags
    if modifierFlags.contains(.command) {
      // CMD+click: toggle selection
      if isSelected {
        // Deselect would happen through parent
      } else {
        onSelect()
      }
    } else {
      // Regular click: select this node
      onSelect()
    }
  }
}

struct ScenePropertyPanelView: View {
  @ObservedObject var object: SceneObject
  @ObservedObject var pointCloudData: PointCloudDataBlock
  let filePath: String
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      Text("Properties")
        .font(.subheadline.bold())
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
      
      Divider()
      
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          // Name
          VStack(alignment: .leading, spacing: 6) {
            Text("Name")
              .font(.caption.bold())
              .foregroundColor(.secondary)
            TextField("Object name", text: $object.name)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .font(.system(.body, design: .default))
          }
          
          Divider().padding(.vertical, 4)
          
          // Appearance Section
          VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
              .font(.caption.bold())
              .foregroundColor(.secondary)
            
            // Color
            VStack(alignment: .leading, spacing: 8) {
              Text("Color")
                .font(.caption)
                .foregroundColor(.secondary)
              HStack(spacing: 12) {
                ColorPicker("", selection: $pointCloudData.color, supportsOpacity: true)
                  .labelsHidden()
                  .frame(width: 40, height: 40)
                
                HStack(spacing: 8) {
                  Circle()
                    .fill(pointCloudData.color)
                    .frame(width: 12, height: 12)
                  Text("Selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
            }
            
            // Point Size
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("Point Size")
                  .font(.caption)
                  .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1f", pointCloudData.pointSize))
                  .font(.caption.monospacedDigit())
                  .fontWeight(.medium)
              }
              Slider(value: $pointCloudData.pointSize, in: 0.5...20.0)
            }
          }
          
          Divider().padding(.vertical, 4)
          
          // Information Section
          VStack(alignment: .leading, spacing: 10) {
            Text("Information")
              .font(.caption.bold())
              .foregroundColor(.secondary)
            
            InfoRow(label: "Points", value: String(format: "%d", pointCloudData.pointsCount))
            InfoRow(label: "Size", value: String(format: "%.2f MB", Double(pointCloudData.pointsCount) * 16 / 1_000_000))
          }
          
          Divider().padding(.vertical, 4)
          
          // File Path
          VStack(alignment: .leading, spacing: 6) {
            Text("File Path")
              .font(.caption.bold())
              .foregroundColor(.secondary)
            Text(filePath)
              .font(.system(.caption2, design: .monospaced))
              .foregroundColor(.secondary)
              .lineLimit(2)
              .truncationMode(.middle)
          }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
      }
    }
    .background(Color(nsColor: .controlBackgroundColor))
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

#Preview {
  let scene = PlaygroundScene()
  SceneOutlinerView(scene: scene)
}
