//
//  PointCloudLoader.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 22/02/2026.
//

import Foundation
import simd

struct PointCloudBuffer {
  var pointCount: Int32
  /// The  buffer is composed of coordinates (x, y, z, x, y, z, ...)
  /// Warning: Simd3 is physically 4 float4 (cannot be casted directly)
  var buffer: Data
}

class PointCloudLoader {
  let wrapper = LASWrapper()
  
  /// The returned Data is a buffer of coordinates (x, y, z, x, y, z, ...)
  func loadLazFile(at path: String) -> PointCloudBuffer? {
    var pointCount: Int32 = 0
    
    guard let rawData = wrapper.loadPoints(fromPath: path, count: &pointCount) else {
      return nil
    }
    
    print("Buffer contains \(pointCount) points")
    return PointCloudBuffer(pointCount: pointCount, buffer: rawData)
  }
}
