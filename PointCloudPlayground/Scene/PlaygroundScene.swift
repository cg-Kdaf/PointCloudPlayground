//
//  PlaygroundScene.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 24/02/2026.
//

final class PlaygroundScene {
  private(set) var pointClouds: [PointCloudFile] = []
  private(set) var filePaths: [String] = []
  var sceneModifiedCallbacks: [String: (PlaygroundScene) -> Void] = [:]
  
  func addCloud(filepath: String) {
    guard !filePaths.contains(filepath) else {
      return
    }
    
    let pointCloud = PointCloudFile()
    guard pointCloud.createFrom(filePath: filepath) else {
      return
    }
    
    pointClouds.append(pointCloud)
    filePaths.append(filepath)
    notifySceneModified()
  }
  
  func removeCloud(filepath: String) {
    guard let index = filePaths.firstIndex(of: filepath) else {
      return
    }
    
    filePaths.remove(at: index)
    pointClouds.remove(at: index)
    notifySceneModified()
  }
  
  private func notifySceneModified() {
    for cb in sceneModifiedCallbacks.values { cb(self) }
  }
}
