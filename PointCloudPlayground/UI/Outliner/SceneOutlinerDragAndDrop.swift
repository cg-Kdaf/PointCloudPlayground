//
//  SceneOutlinerDragAndDrop.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 7/03/2026.
//

import SwiftUI
import UniformTypeIdentifiers

func makeDragProvider(kind: SceneTreeItemKind, id: UUID) -> NSItemProvider {
  let payload = SceneTreeDragPayload(kind: kind, id: id)
  let encodedPayload = (try? JSONEncoder().encode(payload))
    .flatMap { String(data: $0, encoding: .utf8) } ?? ""
  return NSItemProvider(object: NSString(string: encodedPayload))
}

struct SceneTreeRowContainer<Content: View>: View {
  let depth: Int
  let isSelected: Bool
  let isDropTargeted: Bool
  let isHovered: Bool
  let action: () -> Void
  let dragProvider: () -> NSItemProvider
  let content: Content

  init(
    depth: Int,
    isSelected: Bool,
    isDropTargeted: Bool,
    isHovered: Bool,
    action: @escaping () -> Void,
    dragProvider: @escaping () -> NSItemProvider,
    @ViewBuilder content: () -> Content
  ) {
    self.depth = depth
    self.isSelected = isSelected
    self.isDropTargeted = isDropTargeted
    self.isHovered = isHovered
    self.action = action
    self.dragProvider = dragProvider
    self.content = content()
  }

  var body: some View {
    HStack(spacing: 8) {
      content
    }
    .frame(minHeight: 32)
    .contentShape(Rectangle())
    .onTapGesture(perform: action)
    .onDrag(dragProvider)
    .padding(.leading, CGFloat(depth) * 8)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(backgroundColor)
    .cornerRadius(6)
  }

  private var backgroundColor: Color {
    if isDropTargeted {
      return Color.accentColor.opacity(0.18)
    }
    if isSelected {
      return Color.blue.opacity(0.15)
    }
    if isHovered {
      return Color.gray.opacity(0.08)
    }
    return Color.clear
  }
}

struct SceneGroupDropDelegate: DropDelegate {
  let scene: PlaygroundScene
  let targetGroupId: UUID
  @Binding var isTargeted: Bool

  func validateDrop(info: DropInfo) -> Bool {
    guard let payload = scene.activeDragPayload else {
      return false
    }

    switch payload.kind {
    case .group:
      guard payload.id != targetGroupId,
            let movingGroup = scene.rootGroup.group(withId: payload.id) else {
        return false
      }
      return movingGroup.group(withId: targetGroupId) == nil
    case .object:
      return scene.rootGroup.object(withId: payload.id) != nil
    }
  }

  func dropEntered(info: DropInfo) {
    isTargeted = validateDrop(info: info)
  }

  func dropExited(info: DropInfo) {
    isTargeted = false
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    validateDrop(info: info) ? DropProposal(operation: .move) : DropProposal(operation: .forbidden)
  }

  func performDrop(info: DropInfo) -> Bool {
    defer {
      isTargeted = false
      scene.activeDragPayload = nil
    }

    guard let payload = scene.activeDragPayload,
          validateDrop(info: info) else {
      return false
    }

    return scene.moveItem(kind: payload.kind, id: payload.id, toGroupId: targetGroupId)
  }
}
