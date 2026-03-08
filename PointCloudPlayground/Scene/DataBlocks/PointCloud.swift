//
//  PointCloud.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 7/03/2026.
//

import SwiftUI
import Combine

struct PointVertex {
  let position: SIMD4<Float>
}

struct BoundingBox {
  let max_x: Float
  let min_x: Float
  let max_y: Float
  let min_y: Float
  let max_z: Float
  let min_z: Float
  
  func toPoints() -> [simd_float4] {
    [
      simd_float4(min_x, min_y, min_z, 1.0),
      simd_float4(max_x, min_y, min_z, 1.0),
      simd_float4(min_x, min_y, max_z, 1.0),
      simd_float4(max_x, min_y, max_z, 1.0),
      simd_float4(min_x, max_y, min_z, 1.0),
      simd_float4(max_x, max_y, min_z, 1.0),
      simd_float4(min_x, max_y, max_z, 1.0),
      simd_float4(max_x, max_y, max_z, 1.0),
    ]
  }
}

final class PointCloudDataBlock: DataBlock, ObservableObject {
  let points: [PointVertex]
  let pointsCount: Int
  let center: SIMD4<Double>
  let boundingBox: BoundingBox?
  let filePath: String?
  
  @Published var color: Color = .white
  @Published var pointSize: Float = 1.0
  
  init(points: [PointVertex], pointsCount: Int, center: SIMD4<Double>, boundingBox: BoundingBox?, filePath: String? = nil) {
    self.points = points
    self.pointsCount = pointsCount
    self.center = center
    self.boundingBox = boundingBox
    self.filePath = filePath
    super.init()
  }
  
  required init(from decoder: any Decoder) throws {
    fatalError("init(from:) has not been implemented")
  }
  
  override func encode(to encoder: any Encoder) throws {
    fatalError("encode(to:) has not been implemented")
  }
}
