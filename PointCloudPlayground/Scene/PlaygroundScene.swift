//
//  PlaygroundScene.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 24/02/2026.
//

import SwiftUI
import Combine

final class PlaygroundScene: ObservableObject {
  @Published private(set) var objects: [SceneObject] = []
  private(set) var filePaths: [String] = []
  var sceneModifiedCallbacks: [String: (PlaygroundScene) -> Void] = [:]
  private var dataBlockObservations: [UUID: AnyCancellable] = [:]
  
  @Published var selectedObjectId: UUID? = nil
  
  func addCloud(filepath: String) {
    guard !filePaths.contains(filepath) else {
      return
    }
    
    let data: PointCloudDataBlock?
    
    if filepath.hasSuffix(".laz") || filepath.hasSuffix(".las") {
      let importer = LaszipImporter()
      data = importer.importFrom(filePath: filepath)
    } else {
      // Treat as a COLMAP text export directory
      let importer = ColmapImporter()
      data = importer.importPointCloud(fromDirectory: filepath)
    }
    
    guard let data else {
      return
    }
    
    let name = URL(fileURLWithPath: filepath).lastPathComponent
    let object = SceneObject(name: name, dataBlock: data, type: .pointCloud)
    
    // Subscribe to changes in PointCloudDataBlock properties
    let dataObservation = Publishers.Merge(
      data.$color.map { _ in () },
      data.$pointSize.map { _ in () }
    )
    
    // Subscribe to changes in SceneObject transform properties
    let transformObservation = Publishers.Merge3(
      object.$translation.map { _ in () },
      object.$rotation.map { _ in () },
      object.$scale.map { _ in () }
    )
    
    let observation = Publishers.Merge(dataObservation, transformObservation)
    .sink { [weak self] _ in
      self?.notifySceneModified()
    }
    
    dataBlockObservations[object.id] = observation
    objects.append(object)
    filePaths.append(filepath)
    
    notifySceneModified()
  }
  
  func removeObject(_ id: UUID) {
    guard let index = objects.firstIndex(where: { $0.id == id }) else {
      return
    }
    
    // Clean up observation
    dataBlockObservations.removeValue(forKey: id)
    
    filePaths.remove(at: index)
    objects.remove(at: index)
    
    if selectedObjectId == id {
      selectedObjectId = nil
    }
    
    notifySceneModified()
  }
  
  func selectObject(id: UUID) {
    selectedObjectId = id
    notifySceneModified()
  }
  
  func deselectAll() {
    selectedObjectId = nil
    notifySceneModified()
  }
  
  func toggleVisibility(for id: UUID) {
    if let object = objects.first(where: { $0.id == id }) {
      object.isVisible.toggle()
      notifySceneModified()
    }
  }
  
  func setVisibility(_ visible: Bool, for id: UUID) {
    if let object = objects.first(where: { $0.id == id }) {
      object.isVisible = visible
      notifySceneModified()
    }
  }
  
  func getVisibleObjects() -> [SceneObject] {
    objects.filter { $0.isVisible }
  }
  
  private func notifySceneModified() {
    for cb in sceneModifiedCallbacks.values { cb(self) }
    DispatchQueue.main.async {
      self.objectWillChange.send()
    }
  }
}
