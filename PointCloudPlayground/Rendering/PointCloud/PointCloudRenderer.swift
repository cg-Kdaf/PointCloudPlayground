import Metal
import AppKit
import SwiftUI

final class PointCloudRenderer: RenderPass {
  private struct RenderCloud {
    let pointCount: Int
    let buffer: MTLBuffer
    let uniformsBuffer: MTLBuffer
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
    guard let pointVertexFunction = library.makeFunction(name: "point_vertex_shader"),
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
      let points = pointCloud.points
      guard !points.isEmpty else {
        return nil
      }
      
      let color = NSColor(pointCloud.color).usingColorSpace(.sRGB) ?? .white
      let bbox = pointCloud.boundingBox
      let uniforms = PointCloudRenderUniforms(
        bboxMaxX: bbox?.max_x ?? 1.0,
        bboxMinX: bbox?.min_x ?? 0.0,
        bboxMaxY: bbox?.max_y ?? 1.0,
        bboxMinY: bbox?.min_y ?? 0.0,
        bboxMaxZ: bbox?.max_z ?? 1.0,
        bboxMinZ: bbox?.min_z ?? 0.0,
        pointSize: pointCloud.pointSize,
        colorR: Float(color.redComponent),
        colorG: Float(color.greenComponent),
        colorB: Float(color.blueComponent),
        colorA: Float(color.alphaComponent)
      )
      
      return points.withUnsafeBytes { data in
        guard let baseAddress = data.baseAddress,
              let buffer = device.makeBuffer(bytes: baseAddress,
                                             length: data.count,
                                             options: .storageModeShared),
              let uniformsBuffer = device.makeBuffer(bytes: [uniforms],
                                                     length: MemoryLayout<PointCloudRenderUniforms>.stride,
                                                     options: .storageModeShared) else {
          return nil
        }
        return RenderCloud(pointCount: points.count, buffer: buffer, uniformsBuffer: uniformsBuffer)
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
      encoder.setVertexBuffer(renderCloud.uniformsBuffer, offset: 0, index: 2)
      encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: renderCloud.pointCount)
    }
  }
}
