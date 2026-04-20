//
//  ColmapImporter.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 07/03/2026.
//

import Foundation

struct CameraPose {
  let imageId: Int
  let qw, qx, qy, qz: Double // Rotation Quaternion
  let tx, ty, tz: Double     // Translation Vector
  let cameraId: Int
  let imageName: String
}

struct CameraCalibration {
  let cameraId: Int
  let model: String
  let width: Int
  let height: Int
  let params: [Double]
}

final class ColmapImporter {
  
  /// Imports a point cloud from a COLMAP text export directory containing points3D.txt.
  /// `path` should be the directory path (e.g. .../sparse/text_export/).
  func importPointCloud(fromDirectory path: String) -> PointCloudDataBlock? {
    let pointsFile = (path as NSString).appendingPathComponent("points3D.txt")
    guard let content = try? String(contentsOfFile: pointsFile, encoding: .utf8) else {
      print("ColmapImporter: could not read \(pointsFile)")
      return nil
    }
    
    var vertices: [PointVertex] = []
    var minX = Double.greatestFiniteMagnitude, maxX = -Double.greatestFiniteMagnitude
    var minY = Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
    var minZ = Double.greatestFiniteMagnitude, maxZ = -Double.greatestFiniteMagnitude
    
    content.enumerateLines { line, _ in
      if line.hasPrefix("#") || line.isEmpty { return }
      let parts = line.split(separator: " ")
      guard parts.count >= 7,
            let x = Double(parts[1]),
            let y = Double(parts[2]),
            let z = Double(parts[3]) else { return }
      
      minX = min(minX, x); maxX = max(maxX, x)
      minY = min(minY, y); maxY = max(maxY, y)
      minZ = min(minZ, z); maxZ = max(maxZ, z)
      // Store raw positions; we'll center them in a second pass
      vertices.append(PointVertex(position: SIMD4<Float>(Float(x), Float(y), Float(z), 0.0)))
    }
    
    guard !vertices.isEmpty else {
      print("ColmapImporter: no points found in \(pointsFile)")
      return nil
    }
    
    let center = SIMD4<Double>(
      (maxX + minX) / 2.0,
      (maxY + minY) / 2.0,
      (maxZ + minZ) / 2.0,
      0.0
    )
    
    // Center the points
    let offset = SIMD4<Float>(Float(center.x), Float(center.y), Float(center.z), 0.0)
    for i in vertices.indices {
      vertices[i] = PointVertex(position: vertices[i].position - offset)
    }
    
    let boundingBox = BoundingBox(
      max_x: Float(maxX - center.x), min_x: Float(minX - center.x),
      max_y: Float(maxY - center.y), min_y: Float(minY - center.y),
      max_z: Float(maxZ - center.z), min_z: Float(minZ - center.z)
    )
    
    return PointCloudDataBlock(points: vertices, pointsCount: vertices.count, center: center, boundingBox: boundingBox, filePath: path)
  }
  
  // Parses images.txt to get Camera Poses
  func parseImages(fromDirectory path: String) -> [CameraPose] {
    let imagesFile = (path as NSString).appendingPathComponent("images.txt")
    guard let content = try? String(contentsOfFile: imagesFile, encoding: .utf8) else { return [] }
    var poses = [CameraPose]()
    var isCameraLine = true // COLMAP uses 2 lines per image
    
    content.enumerateLines { line, _ in
      if line.hasPrefix("#") || line.isEmpty { return }
      
      if isCameraLine {
        let parts = line.split(separator: " ")
        if parts.count >= 10 {
          let pose = CameraPose(
            imageId: Int(parts[0]) ?? 0,
            qw: Double(parts[1]) ?? 0,
            qx: Double(parts[2]) ?? 0,
            qy: Double(parts[3]) ?? 0,
            qz: Double(parts[4]) ?? 0,
            tx: Double(parts[5]) ?? 0,
            ty: Double(parts[6]) ?? 0,
            tz: Double(parts[7]) ?? 0,
            cameraId: Int(parts[8]) ?? 0,
            imageName: String(parts[9])
          )
          poses.append(pose)
        }
        isCameraLine = false
      } else {
        // The second line contains the 2D keypoint data (skip for now)
        isCameraLine = true
      }
    }
    return poses
  }

  // Parses cameras.txt to get Camera Calibrations
  func parseCameras(fromDirectory path: String) -> [Int: CameraCalibration] {
    let camerasFile = (path as NSString).appendingPathComponent("cameras.txt")
    guard let content = try? String(contentsOfFile: camerasFile, encoding: .utf8) else { return [:] }
    
    var cameras = [Int: CameraCalibration]()
    
    content.enumerateLines { line, _ in
      if line.hasPrefix("#") || line.isEmpty { return }
      let parts = line.split(separator: " ")
      if parts.count >= 4, let camId = Int(parts[0]) {
        let model = String(parts[1])
        let width = Int(parts[2]) ?? 0
        let height = Int(parts[3]) ?? 0
        let params = parts[4...].compactMap { Double($0) }
        
        cameras[camId] = CameraCalibration(
          cameraId: camId,
          model: model,
          width: width,
          height: height,
          params: params
        )
      }
    }
    return cameras
  }
}
