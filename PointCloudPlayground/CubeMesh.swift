import Foundation
import Metal
import simd

struct MeshVertex {
  var position: SIMD3<Float>
  var color: SIMD3<Float>
}

final class CubeMesh {
  let vertexBuffer: MTLBuffer
  let indexBuffer: MTLBuffer
  let indexCount: Int
  
  init?(device: MTLDevice) {
    let vertices: [MeshVertex] = [
      MeshVertex(position: SIMD3(-1, -1,  1), color: SIMD3(1, 0, 0)),
      MeshVertex(position: SIMD3( 1, -1,  1), color: SIMD3(0, 1, 0)),
      MeshVertex(position: SIMD3( 1,  1,  1), color: SIMD3(0, 0, 1)),
      MeshVertex(position: SIMD3(-1,  1,  1), color: SIMD3(1, 1, 0)),
      MeshVertex(position: SIMD3(-1, -1, -1), color: SIMD3(1, 0, 1)),
      MeshVertex(position: SIMD3( 1, -1, -1), color: SIMD3(0, 1, 1)),
      MeshVertex(position: SIMD3( 1,  1, -1), color: SIMD3(1, 0.5, 0)),
      MeshVertex(position: SIMD3(-1,  1, -1), color: SIMD3(0.5, 0.2, 1))
    ]
    
    let indices: [UInt16] = [
      0, 1, 2,  2, 3, 0,
      1, 5, 6,  6, 2, 1,
      5, 4, 7,  7, 6, 5,
      4, 0, 3,  3, 7, 4,
      3, 2, 6,  6, 7, 3,
      4, 5, 1,  1, 0, 4
    ]
    
    guard let vertexBuffer = device.makeBuffer(bytes: vertices,
                                               length: MemoryLayout<MeshVertex>.stride * vertices.count),
          let indexBuffer = device.makeBuffer(bytes: indices,
                                              length: MemoryLayout<UInt16>.stride * indices.count) else {
      return nil
    }
    
    self.vertexBuffer = vertexBuffer
    self.indexBuffer = indexBuffer
    self.indexCount = indices.count
  }
}
