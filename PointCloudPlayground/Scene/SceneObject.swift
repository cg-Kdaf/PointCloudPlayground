//
//  SceneObject.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 7/03/2026.
//

import SwiftUI
import Combine
import simd

class DataBlock: Codable {}

enum DataBlockType: String, Codable {
  case pointCloud
  case camera
  case volume
  
  var name: String {
    switch self {
    case .pointCloud:
      return "Point Cloud"
    case .camera:
      return "Camera"
    case .volume:
      return "Volume"
    }
  }
}

final class SceneObject: Codable, ObservableObject, Identifiable, Transformable {
  let id: UUID = .init()
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
  
  var asVolumeData: VolumeDataBlock? {
    guard dataBlockType == .volume else { return nil }
    return data as? VolumeDataBlock
  }
  
  enum CodingKeys: String, CodingKey {
    case id
    case name
    case isVisible
    case translation
    case rotation
    case scale
    
    case dataBlockType
    case data
  }
  
  required init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    name = try values.decode(String.self, forKey: .name)
    data = try values.decode(DataBlock.self, forKey: .data)
    dataBlockType = try values.decode(DataBlockType.self, forKey: .dataBlockType)
    isVisible = try values.decode(Bool.self, forKey: .isVisible)
    translation = try values.decode(SIMD3<Float>.self, forKey: .translation)
    rotation = try values.decode(SIMD3<Float>.self, forKey: .rotation)
    scale = try values.decode(SIMD3<Float>.self, forKey: .scale)
  }
  
  func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(name, forKey: .name)
    try values.encode(isVisible, forKey: .isVisible)
    try values.encode(translation, forKey: .translation)
    try values.encode(rotation, forKey: .rotation)
    try values.encode(scale, forKey: .scale)
    try values.encode(data, forKey: .data)
    try values.encode(dataBlockType, forKey: .dataBlockType)
  }
}
