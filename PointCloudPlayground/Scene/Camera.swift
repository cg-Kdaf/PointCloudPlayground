//
//  Camera.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 7/03/2026.
//

import SwiftUI
import Combine

final class CameraDataBlock: DataBlock, ObservableObject {
  @Published var position: SIMD3<Float> = .zero
  @Published var orientation: SIMD4<Float> = SIMD4<Float>(0.0, 0.0, 0.0, 1.0) // Identity quaternion
  @Published var fov: Float = 45.0 // Field of view in degrees
  
  init(position: SIMD3<Float> = .zero, orientation: SIMD4<Float>, fov: Float = 45.0) {
    self.position = position
    self.orientation = orientation
    self.fov = fov
  }
}
