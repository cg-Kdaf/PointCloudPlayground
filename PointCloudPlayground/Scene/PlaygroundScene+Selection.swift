//
//  PlaygroundScene+Selection.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 7/03/2026.
//

import Foundation

extension PlaygroundScene {
  func selectOnly(id: UUID) {
    setSelection(ids: [id])
  }

  func setSelection(ids: [UUID]) {
    let validIds = Set(selectableIds)
    var uniqueIds: [UUID] = []

    for id in ids where validIds.contains(id) && !uniqueIds.contains(id) {
      uniqueIds.append(id)
    }

    guard uniqueIds != selectedIds else {
      return
    }

    selectedIds = uniqueIds
    notifySceneModified()
  }

  func addToSelection(id: UUID) {
    guard !selectedIds.contains(id) else {
      return
    }

    selectedIds.append(id)
    notifySceneModified()
  }

  func removeFromSelection(id: UUID) {
    let updatedIds = selectedIds.filter { $0 != id }
    guard updatedIds.count != selectedIds.count else {
      return
    }

    selectedIds = updatedIds
    notifySceneModified()
  }

  func toggleSelection(id: UUID) {
    if isSelected(id: id) {
      removeFromSelection(id: id)
    } else {
      addToSelection(id: id)
    }
  }

  func isSelected(id: UUID) -> Bool {
    selectedIds.contains(id)
  }
}
