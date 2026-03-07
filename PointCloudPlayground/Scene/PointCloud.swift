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
}

final class PointCloudDataBlock: DataBlock, ObservableObject {
  let points: [PointVertex]
  let pointsCount: Int
  let center: SIMD4<Double>
  let boundingBox: BoundingBox?
  
  @Published var color: Color = .white
  @Published var pointSize: Float = 1.0
  
  init(points: [PointVertex], pointsCount: Int, center: SIMD4<Double>, boundingBox: BoundingBox?) {
    self.points = points
    self.pointsCount = pointsCount
    self.center = center
    self.boundingBox = boundingBox
  }
}
