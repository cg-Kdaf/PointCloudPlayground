//
//  SceneObject.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 7/03/2026.
//

import SwiftUI
import Combine
import simd

protocol DataBlock {}

enum DataBlockType {
  case pointCloud
  case camera
  
  var name: String {
    switch self {
    case .pointCloud:
      return "Point Cloud"
    case .camera:
      return "Camera"
    }
  }
}

final class SceneObject: ObservableObject, Identifiable, Transformable {
  let id: UUID
  let dataBlockType: DataBlockType
  let data: DataBlock
  
  @Published var name: String
  @Published var isVisible: Bool = true
  @Published var translation: SIMD3<Float> = .zero
  @Published var rotation: SIMD3<Float> = .zero    // Euler angles in radians (X, Y, Z)
  @Published var scale: SIMD3<Float> = .one
  
  var modelMatrix: simd_float4x4 {
    simd_float4x4.translation(translation) *
    simd_float4x4.fromEulerZYX(rotation) *
    simd_float4x4.scaling(scale)
  }
  
  init(name: String, dataBlock: DataBlock, type: DataBlockType) {
    self.id = UUID()
    self.name = name
    self.data = dataBlock
    self.dataBlockType = type
  }
  
  // Helpers for accessing typed data
  var asPointCloudData: PointCloudDataBlock? {
    guard dataBlockType == .pointCloud else { return nil }
    return data as? PointCloudDataBlock
  }
  
  var asCameraData: CameraDataBlock? {
    guard dataBlockType == .camera else { return nil }
    return data as? CameraDataBlock
  }
}
