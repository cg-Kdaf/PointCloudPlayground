import Metal
import Laszip

final class PointCloudRenderer: RenderPass {
  private let device: MTLDevice
  private let pipelineState: MTLRenderPipelineState
  private var pointCloud: PointCloudFile? = nil
  private var pointCloudBuffer: MTLBuffer? = nil

  init?(device: MTLDevice,
        library: MTLLibrary,
        colorPixelFormat: MTLPixelFormat,
        depthPixelFormat: MTLPixelFormat) {
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
  }

  func loadCloud(filepath: String) {
    pointCloud = .init()
    guard pointCloud!.createFrom(filePath: filepath) else {
      pointCloud = nil
      pointCloudBuffer = nil
      return
    }
    pointCloud!.points?.withUnsafeBytes { data in
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