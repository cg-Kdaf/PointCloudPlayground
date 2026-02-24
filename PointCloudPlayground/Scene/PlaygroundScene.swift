//
//  PlaygroundScene.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 24/02/2026.
//

final class PlaygroundScene {
  private(set) var pointCloud: PointCloudFile? = nil
  var sceneModifiedCallbacks: [String: (PlaygroundScene) -> Void] = [:]
  
  func loadCloud(filepath: String) {
    pointCloud = .init()
    guard pointCloud!.createFrom(filePath: filepath) else {
      pointCloud = nil
      return
    }
    for cb in sceneModifiedCallbacks.values { cb(self) }
  }
}
