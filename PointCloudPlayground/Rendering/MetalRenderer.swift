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
  private let loader: PointCloudLoader = .init()
  private var pointCloudData: PointCloudBuffer? = nil
  private var pointCloudBuffer: MTLBuffer? = nil
  
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
  
  func moveTarget(deltaX: Float, deltaY: Float) {
    orbitCamera.moveTarget(deltaX: deltaX, deltaY: deltaY)
  }
  
  func startInertia() {
    orbitCamera.startInertia()
  }
  
  func zoom(delta: Float) {
    orbitCamera.zoom(delta: delta)
  }
  
  func loadCloud(filepath: String) {
    pointCloudData = loader.loadLazFile(at: filepath)
    
    guard let pointCloudData else { return }
    
    pointCloudData.buffer.withUnsafeBytes {
      pointCloudBuffer = commandQueue.device.makeBuffer(bytes: $0,
                                                        length: pointCloudData.buffer.count,
                                                        options: .storageModeShared)
    }
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
    
    if let pointCloudBuffer, let pointCloudData {
      renderEncoder.setRenderPipelineState(pipelineState)
      renderEncoder.setDepthStencilState(depthStencilState)
      // Pass the buffer we created from NSData
      renderEncoder.setVertexBuffer(pointCloudBuffer, offset: 0, index: 0)
      renderEncoder.setVertexBuffer(cameraBuffer, offset: 0, index: 1)
      renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: Int(pointCloudData.pointCount))
      renderEncoder.endEncoding()
    } else {
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
    }
    
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
