import Metal
import Laszip

final class PointCloudRenderer: RenderPass {
  private let device: MTLDevice
  private let pipelineState: MTLRenderPipelineState
  private var pointCloud: PointCloudFile? = nil
  private var pointCloudBuffer: MTLBuffer? = nil
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
  }
  
  deinit {
    scene.sceneModifiedCallbacks.removeValue(forKey: "PointCloudRenderer")
  }
  
  private func updateFromScene(s: PlaygroundScene) {
    guard let pc = s.pointCloud else {
      pointCloud = nil
      pointCloudBuffer = nil
      return
    }
    pointCloud = pc
    pc.points?.withUnsafeBytes { data in
      pointCloudBuffer = device.makeBuffer(bytes: data.baseAddress!,
                                           length: data.count,
                                           options: .storageModeShared)
    }
  }

  func draw(encoder: MTLRenderCommandEncoder, frame: FrameContext) {
    guard let pointCloudBuffer, let pointCloud else {
      return
    }

    encoder.setViewport(frame.viewport)
    encoder.setRenderPipelineState(pipelineState)
    encoder.setDepthStencilState(frame.depth.sceneDepthStencilState)
    encoder.setVertexBuffer(pointCloudBuffer, offset: 0, index: 0)
    encoder.setVertexBuffer(frame.cameraBuffer, offset: 0, index: 1)
    encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: Int(pointCloud.pointsCount))
  }
}
