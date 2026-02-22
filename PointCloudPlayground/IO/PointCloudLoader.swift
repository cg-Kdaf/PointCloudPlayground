//
//  PointCloudLoader.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 22/02/2026.
//

import Foundation
import simd

class PointCloudLoader {
  let wrapper = LASWrapper()
  
  func loadLazFile(at path: String) -> [SIMD3<Float>]? {
    var count: Int32 = 0
    
    guard let data = wrapper.loadPoints(fromPath: path, count: &count) else {
      return nil
    }
    
    // 1. Convert Data to a simple array of Floats (no padding issues)
    let floatCount = Int(count) * 3
    let floats = data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> [Float] in
      let baseAddress = pointer.bindMemory(to: Float.self)
      return Array(baseAddress.prefix(floatCount))
    }
    
    // 2. Map the flat Float array into SIMD3
    var points: [SIMD3<Float>] = []
    points.reserveCapacity(Int(count))
    
    for i in stride(from: 0, to: floats.count, by: 3) {
      points.append(SIMD3<Float>(floats[i], floats[i+1], floats[i+2]))
    }
    
    print("Requested \(count) points. Correctly parsed \(points.count) points.")
    return points
  }
}
