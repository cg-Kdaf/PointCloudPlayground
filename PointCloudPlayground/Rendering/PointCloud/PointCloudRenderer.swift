import Metal
import AppKit
import SwiftUI
import simd

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
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(updatePointClouds(_:)),
      name: SceneUpdate.ObjectDataBlockChanged,
      object: nil
    )
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self, name: SceneUpdate.ObjectDataBlockChanged, object: nil)
  }
  
  @objc private func updatePointClouds(_ n: Notification) {
    renderClouds = scene.allVisibleObjects.compactMap { sceneObject in
      guard let pointCloudData = sceneObject.asPointCloudData else {
        return nil
      }
      
      let points = pointCloudData.points
      guard !points.isEmpty else {
        return nil
      }
      
      let color = NSColor(pointCloudData.color).usingColorSpace(.sRGB) ?? .white
      let bbox = pointCloudData.boundingBox
      let uniforms = PointCloudRenderUniforms(
        modelMatrix: sceneObject.modelMatrix,
        bboxMaxX: bbox?.max_x ?? 1.0,
        bboxMinX: bbox?.min_x ?? 0.0,
        bboxMaxY: bbox?.max_y ?? 1.0,
        bboxMinY: bbox?.min_y ?? 0.0,
        bboxMaxZ: bbox?.max_z ?? 1.0,
        bboxMinZ: bbox?.min_z ?? 0.0,
        pointSize: pointCloudData.pointSize,
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
    
    // Update model matrix per cloud each frame (transforms may change)
    // Calculate hierarchical transformation: parent groups multiplied by object transform
    var cloudIndex = 0
    for sceneObject in scene.allVisibleObjects {
      guard sceneObject.asPointCloudData != nil, cloudIndex < renderClouds.count else {
        continue
      }
      var hierarchicalMatrix = scene.rootGroup.hierarchicalMatrix(forItemId: sceneObject.id, in: scene.rootGroup)
      renderClouds[cloudIndex].uniformsBuffer.contents()
        .copyMemory(from: &hierarchicalMatrix, byteCount: MemoryLayout<simd_float4x4>.stride)
      cloudIndex += 1
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
