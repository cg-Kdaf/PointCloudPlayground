//
//  Camera.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 7/03/2026.
//

import SwiftUI
import Combine

struct CameraIntrinsics: Codable, Equatable {
  var width: Int
  var height: Int
  var fx: Float
  var fy: Float
  var cx: Float
  var cy: Float
}

final class CameraDataBlock: DataBlock, ObservableObject {
  @Published var position: SIMD3<Float> = .zero
  @Published var orientation: SIMD4<Float> = SIMD4<Float>(0.0, 0.0, 0.0, 1.0) // Identity quaternion
  @Published var fov: Float = 45.0 // Field of view in degrees
  @Published var imagePath: String?
  @Published var intrinsics: CameraIntrinsics?
  @Published var zoom: Float = 1.0
  
  init(position: SIMD3<Float> = .zero, orientation: SIMD4<Float>, fov: Float = 45.0, imagePath: String? = nil, intrinsics: CameraIntrinsics? = nil) {
    self.position = position
    self.orientation = orientation
    self.fov = fov
    self.imagePath = imagePath
    self.intrinsics = intrinsics
    self.zoom = 1.0
    super.init()
  }
  
  required init(from decoder: any Decoder) throws {
    fatalError("init(from:) has not been implemented")
  }
  
  override func encode(to encoder: any Encoder) throws {
    fatalError("encode(to:) has not been implemented")
  }
}
