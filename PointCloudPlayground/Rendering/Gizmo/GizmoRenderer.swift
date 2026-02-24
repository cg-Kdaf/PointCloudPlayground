import Metal

private struct GizmoVertex {
  var position: SIMD3<Float>
  var color: SIMD3<Float>
}

final class GizmoRenderer {
  private let pipelineState: MTLRenderPipelineState
  private let vertexBuffer: MTLBuffer
  private let vertexCount: Int

  init?(device: MTLDevice,
        library: MTLLibrary,
        colorPixelFormat: MTLPixelFormat,
        depthPixelFormat: MTLPixelFormat) {
    guard let vertexFunction = library.makeFunction(name: "gizmo_vertex"),
          let fragmentFunction = library.makeFunction(name: "gizmo_fragment") else {
      return nil
    }

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = depthPixelFormat
    pipelineDescriptor.vertexDescriptor = Self.makeVertexDescriptor()

    guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
      return nil
    }

    let vertices = Self.makeVertices()
    guard let vertexBuffer = device.makeBuffer(bytes: vertices,
                                               length: MemoryLayout<GizmoVertex>.stride * vertices.count,
                                               options: .storageModeShared) else {
      return nil
    }

    self.pipelineState = pipelineState
    self.vertexBuffer = vertexBuffer
    self.vertexCount = vertices.count
  }

  func draw(encoder: MTLRenderCommandEncoder, frame: FrameContext) {
    encoder.setViewport(frame.viewport)
    encoder.setRenderPipelineState(pipelineState)
    encoder.setDepthStencilState(frame.depth.overlayDepthStencilState)
    encoder.setCullMode(.none)
    encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    encoder.setVertexBuffer(frame.cameraBuffer, offset: 0, index: 1)
    encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount)
  }

  private static func makeVertexDescriptor() -> MTLVertexDescriptor {
    let descriptor = MTLVertexDescriptor()
    descriptor.attributes[0].format = .float3
    descriptor.attributes[0].offset = 0
    descriptor.attributes[0].bufferIndex = 0
    descriptor.attributes[1].format = .float3
    descriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
    descriptor.attributes[1].bufferIndex = 0
    descriptor.layouts[0].stride = MemoryLayout<GizmoVertex>.stride
    descriptor.layouts[0].stepFunction = .perVertex
    return descriptor
  }

  private static func makeVertices() -> [GizmoVertex] {
    let axisExtent: Float = 1_000_000
    return [
      GizmoVertex(position: SIMD3<Float>(-axisExtent, 0, 0), color: SIMD3<Float>(1, 0, 0)),
      GizmoVertex(position: SIMD3<Float>( axisExtent, 0, 0), color: SIMD3<Float>(1, 0, 0)),
      GizmoVertex(position: SIMD3<Float>(0, -axisExtent, 0), color: SIMD3<Float>(0, 1, 0)),
      GizmoVertex(position: SIMD3<Float>(0,  axisExtent, 0), color: SIMD3<Float>(0, 1, 0)),
      GizmoVertex(position: SIMD3<Float>(0, 0, -axisExtent), color: SIMD3<Float>(0, 0, 1)),
      GizmoVertex(position: SIMD3<Float>(0, 0,  axisExtent), color: SIMD3<Float>(0, 0, 1))
    ]
  }
}

extension GizmoRenderer: RenderPass {}