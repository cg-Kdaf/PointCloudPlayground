//
//  SceneOutlinerRows.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 7/03/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct SceneGroupRowView: View {
  @ObservedObject var scene: PlaygroundScene
  @ObservedObject var group: SceneGroup
  var depth: Int = 0
  var flattenHeadLess: Bool = false
  @Binding var cameraIdBinding: UUID?
  @State private var isExpanded = true
  @State private var isHovered = false
  @State private var isDropTargeted = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if (!flattenHeadLess) {
        SceneTreeRowContainer(
          depth: depth,
          isSelected: scene.isSelected(id: group.id),
          isDropTargeted: isDropTargeted,
          isHovered: isHovered,
          action: handleRowClick,
          dragProvider: {
            scene.activeDragPayload = SceneTreeDragPayload(kind: .group, id: group.id)
            return makeDragProvider(kind: .group, id: group.id)
          }
        ) {
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(width: 12)
          
          Image(systemName: "folder.fill")
            .font(.system(size: 13))
            .foregroundColor(.accentColor)
            .frame(width: 18)
          
          Text(group.name)
            .font(.system(.body, design: .default).weight(.medium))
            .lineLimit(1)
            .foregroundColor(scene.isSelected(id: group.id) ? .blue : .primary)
          
          Spacer()
          
          Text("\(group.objects.count)")
            .font(.caption.monospacedDigit())
            .foregroundColor(.secondary)
          
          Button(action: { scene.addGroup(parentGroupId: group.id) }) {
            Image(systemName: "folder.badge.plus")
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
          .opacity(isHovered ? 1.0 : 0.65)
        }
        .onDrop(of: [UTType.plainText], delegate: SceneGroupDropDelegate(scene: scene, targetGroupId: group.id, isTargeted: $isDropTargeted))
        .onHover { hovering in
          isHovered = hovering
        }
      }
      
      if isExpanded || flattenHeadLess {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(group.childGroups) { childGroup in
            SceneGroupRowView(scene: scene, group: childGroup, depth: depth + 1, cameraIdBinding: $cameraIdBinding)
          }
          
          ForEach(group.objects) { object in
            SceneNodeRowView(
              scene: scene,
              object: object,
              depth: depth + 1,
              isSelected: scene.isSelected(id: object.id),
              cameraIdBinding: $cameraIdBinding,
              onSelect: { append in
                if append {
                  scene.toggleSelection(id: object.id)
                } else {
                  scene.selectOnly(id: object.id)
                }
              },
              onToggleVisibility: { scene.toggleVisibility(for: object.id) }
            )
          }
          
          if group.childGroups.isEmpty && group.objects.isEmpty {
            Text("Empty group")
              .font(.caption)
              .foregroundColor(.secondary)
              .padding(.leading, CGFloat(depth + 1) * 16 + 40)
              .padding(.vertical, 4)
          }
        }
      }
    }
  }
  
  private func handleRowClick() {
    isExpanded.toggle()
    let modifierFlags = NSEvent.modifierFlags
    if modifierFlags.contains(.command) {
      scene.toggleSelection(id: group.id)
    } else {
      scene.selectOnly(id: group.id)
    }
  }
}

struct SceneNodeRowView: View {
  @Environment(\.openWindow) private var openWindow
  @ObservedObject var scene: PlaygroundScene
  @ObservedObject var object: SceneObject
  var depth: Int = 0
  let isSelected: Bool
  @Binding var cameraIdBinding: UUID?
  let onSelect: (Bool) -> Void
  let onToggleVisibility: () -> Void
  @State private var isHovered = false
  
  var body: some View {
    SceneTreeRowContainer(
      depth: depth,
      isSelected: isSelected,
      isDropTargeted: false,
      isHovered: isHovered,
      action: handleSelection,
      dragProvider: {
        scene.activeDragPayload = SceneTreeDragPayload(kind: .object, id: object.id)
        return makeDragProvider(kind: .object, id: object.id)
      }
    ) {
      Button(action: onToggleVisibility) {
        Image(systemName: object.isVisible ? "eye.fill" : "eye.slash.fill")
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(object.isVisible ? .blue : .gray)
          .frame(width: 24, height: 24)
      }
      .buttonStyle(.plain)
      
      Image(systemName: "cube.fill")
        .font(.system(size: 13))
        .foregroundColor(.orange)
        .frame(width: 18)
      
      Text(object.name)
        .lineLimit(1)
        .truncationMode(.tail)
        .font(.system(.body, design: .default))
        .foregroundColor(isSelected ? .blue : .primary)
      
      Spacer()
      
      if object.dataBlockType == .camera {
        Button(action: {
          openWindow(id: "camera")
          cameraIdBinding = object.id
        }) {
          Image(systemName: "camera.viewfinder")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .opacity(isHovered ? 1.0 : 0.65)
      }
    }
    .onHover { hovering in isHovered = hovering }
  }
  
  private func handleSelection() {
    let modifierFlags = NSEvent.modifierFlags
    if modifierFlags.contains(.command) {
      onSelect(true)
    } else {
      onSelect(false)
    }
  }
}
