import Foundation
import Metal
import MetalKit

final class MetalRenderer: NSObject, MTKViewDelegate {
  private let commandQueue: MTLCommandQueue
  private let pipelineState: MTLRenderPipelineState
  private let depthStencilState: MTLDepthStencilState
  private let cubeMesh: CubeMesh
  private let cameraBuffer: MTLBuffer
  private let orbitCamera: OrbitCamera
  
  init?(mtkView: MTKView) {
    guard let device = MTLCreateSystemDefaultDevice() else {
      return nil
    }
    
    mtkView.device = device
    mtkView.colorPixelFormat = .bgra8Unorm
    mtkView.depthStencilPixelFormat = .depth32Float
    mtkView.clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.1, alpha: 1.0)
    mtkView.clearDepth = 1.0
    
    guard let commandQueue = device.makeCommandQueue() else {
      return nil
    }
    
    guard let library = device.makeDefaultLibrary(),
          let vertexFunction = library.makeFunction(name: "basic_vertex"),
          let fragmentFunction = library.makeFunction(name: "basic_fragment") else {
      return nil
    }
    
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
    
    guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
      return nil
    }
    
    let depthDescriptor = MTLDepthStencilDescriptor()
    depthDescriptor.depthCompareFunction = .less
    depthDescriptor.isDepthWriteEnabled = true
    
    guard let depthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor) else {
      return nil
    }
    
    guard let cubeMesh = CubeMesh(device: device),
          let cameraBuffer = device.makeBuffer(length: MemoryLayout<CameraUniforms>.stride) else {
      return nil
    }
    
    let drawableSize = mtkView.drawableSize
    let initialAspectRatio = drawableSize.height > 0
    ? Float(drawableSize.width / drawableSize.height)
    : 1.0
    let orbitCamera = OrbitCamera(aspectRatio: initialAspectRatio)
    
    self.commandQueue = commandQueue
    self.pipelineState = pipelineState
    self.depthStencilState = depthStencilState
    self.cubeMesh = cubeMesh
    self.cameraBuffer = cameraBuffer
    self.orbitCamera = orbitCamera
    super.init()
  }
  
  func orbit(deltaX: Float, deltaY: Float) {
    orbitCamera.orbit(deltaX: deltaX, deltaY: deltaY)
  }
  
  func startInertia() {
    orbitCamera.startInertia()
  }
  
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    orbitCamera.setDrawableSize(size)
  }
  
  func draw(in view: MTKView) {
    guard let descriptor = view.currentRenderPassDescriptor,
          let drawable = view.currentDrawable,
          let commandBuffer = commandQueue.makeCommandBuffer(),
          let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
      return
    }
    orbitCamera.updateOrbit()
    var cameraUniforms = orbitCamera.makeUniforms()
    cameraBuffer.contents().copyMemory(from: &cameraUniforms, byteCount: MemoryLayout<CameraUniforms>.stride)
    
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setDepthStencilState(depthStencilState)
    renderEncoder.setCullMode(.back)
    renderEncoder.setFrontFacing(.counterClockwise)
    renderEncoder.setVertexBuffer(cubeMesh.vertexBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(cameraBuffer, offset: 0, index: 1)
    renderEncoder.drawIndexedPrimitives(type: .triangle,
                                        indexCount: cubeMesh.indexCount,
                                        indexType: .uint16,
                                        indexBuffer: cubeMesh.indexBuffer,
                                        indexBufferOffset: 0)
    renderEncoder.endEncoding()
    
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
