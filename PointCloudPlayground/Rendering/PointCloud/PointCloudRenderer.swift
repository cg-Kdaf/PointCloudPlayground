import Metal
import Laszip

final class PointCloudRenderer: RenderPass {
  private struct RenderCloud {
    let pointCount: Int
    let buffer: MTLBuffer
  }

  private let device: MTLDevice
  private let pipelineState: MTLRenderPipelineState
  private var renderClouds: [RenderCloud] = []
  var scene: PlaygroundScene

  init?(device: MTLDevice,
        library: MTLLibrary,
        colorPixelFormat: MTLPixelFormat,
        depthPixelFormat: MTLPixelFormat,
        scene: PlaygroundScene) {
    guard let pointVertexFunction = library.makeFunction(name: "point_vertex"),
          let fragmentFunction = library.makeFunction(name: "point_fragment") else {
      return nil
    }

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = pointVertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = depthPixelFormat

    guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
      return nil
    }

    self.device = device
    self.pipelineState = pipelineState
    self.scene = scene
    scene.sceneModifiedCallbacks["PointCloudRenderer"] = {
      self.updateFromScene(s: $0)
    }
    updateFromScene(s: scene)
  }
  
  deinit {
    scene.sceneModifiedCallbacks.removeValue(forKey: "PointCloudRenderer")
  }
  
  private func updateFromScene(s: PlaygroundScene) {
    renderClouds = s.pointClouds.compactMap { pointCloud in
      guard let points = pointCloud.points, !points.isEmpty else {
        return nil
      }

      return points.withUnsafeBytes { data in
        guard let baseAddress = data.baseAddress,
              let buffer = device.makeBuffer(bytes: baseAddress,
                                             length: data.count,
                                             options: .storageModeShared) else {
          return nil
        }

        return RenderCloud(pointCount: points.count, buffer: buffer)
      }
    }
  }

  func draw(encoder: MTLRenderCommandEncoder, frame: FrameContext) {
    guard !renderClouds.isEmpty else {
      return
    }

    encoder.setViewport(frame.viewport)
    encoder.setRenderPipelineState(pipelineState)
    encoder.setDepthStencilState(frame.depth.sceneDepthStencilState)
    encoder.setVertexBuffer(frame.cameraBuffer, offset: 0, index: 1)

    for renderCloud in renderClouds {
      encoder.setVertexBuffer(renderCloud.buffer, offset: 0, index: 0)
      encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: renderCloud.pointCount)
    }
  }
}
