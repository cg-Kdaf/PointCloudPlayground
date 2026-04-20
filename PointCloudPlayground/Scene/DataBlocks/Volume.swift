//
//  Volume.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 20/04/2026.
//

import SwiftUI
import Combine

final class VolumeDataBlock: DataBlock, ObservableObject {
  @Published var color: Color = .blue
  
  init(color: Color = .blue) {
    self.color = color
    super.init()
  }
  
  required init(from decoder: any Decoder) throws {
    fatalError("init(from:) has not been implemented")
  }
  
  override func encode(to encoder: any Encoder) throws {
    fatalError("encode(to:) has not been implemented")
  }
}
