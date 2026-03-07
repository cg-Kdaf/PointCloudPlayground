//
//  PlaygroundScene.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 24/02/2026.
//

import SwiftUI

final class PlaygroundScene {
  private(set) var pointClouds: [PointCloud] = []
  private(set) var filePaths: [String] = []
  var sceneModifiedCallbacks: [String: (PlaygroundScene) -> Void] = [:]
  
  func color(for filepath: String) -> Color? {
    guard let index = filePaths.firstIndex(of: filepath) else {
      return nil
    }
    return pointClouds[index].color
  }
  
  func pointSize(for filepath: String) -> Float? {
    guard let index = filePaths.firstIndex(of: filepath) else {
      return nil
    }
    return pointClouds[index].pointSize
  }
  
  func updateColor(_ color: Color, for filepath: String) {
    guard let index = filePaths.firstIndex(of: filepath) else {
      return
    }
    pointClouds[index].color = color
    notifySceneModified()
  }
  
  func updatePointSize(_ pointSize: Float, for filepath: String) {
    guard let index = filePaths.firstIndex(of: filepath) else {
      return
    }
    pointClouds[index].pointSize = pointSize
    notifySceneModified()
  }
  
  func addCloud(filepath: String) {
    guard !filePaths.contains(filepath) else {
      return
    }
    
    let pointCloud: PointCloud?
    
    if filepath.hasSuffix(".laz") || filepath.hasSuffix(".las") {
      let importer = LaszipImporter()
      pointCloud = importer.importFrom(filePath: filepath)
    } else {
      // Treat as a COLMAP text export directory
      let importer = ColmapImporter()
      pointCloud = importer.importPointCloud(fromDirectory: filepath)
    }
    
    guard let pointCloud else {
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
