//
//  PointCloud.swift
//  PointCloudPlayground
//

import SwiftUI

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

final class PointCloud {
  var boundingBox: BoundingBox? = nil
  var color: Color = .white
  var pointSize: Float = 1.0
  var points: [PointVertex] = []
  var pointsCount: Int = 0
  private(set) var center: SIMD4<Double> = .zero
  
  init(points: [PointVertex], pointsCount: Int, center: SIMD4<Double>, boundingBox: BoundingBox?) {
    self.points = points
    self.pointsCount = pointsCount
    self.center = center
    self.boundingBox = boundingBox
  }
}
