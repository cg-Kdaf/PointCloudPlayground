import Foundation
import Metal
import MetalKit
import Laszip

private struct MeshVertex {
  var position: SIMD3<Float>
  var color: SIMD3<Float>
}

final class MetalRenderer: NSObject, MTKViewDelegate {
  private let commandQueue: MTLCommandQueue
  private let pointPipelineState: MTLRenderPipelineState
  private let coloredPipelineState: MTLRenderPipelineState
  private let sceneDepthStencilState: MTLDepthStencilState
  private let gizmoVertexBuffer: MTLBuffer
  private let gizmoVertexCount: Int
  private let cameraBuffer: MTLBuffer
  private let orbitCamera: OrbitCamera
  private var pointCloud: PointCloudFile? = nil
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
          let pointVertexFunction = library.makeFunction(name: "point_vertex"),
          let coloredVertexFunction = library.makeFunction(name: "colored_vertex"),
          let fragmentFunction = library.makeFunction(name: "basic_fragment") else {
      return nil
    }
    
    let pointPipelineDescriptor = MTLRenderPipelineDescriptor()
    pointPipelineDescriptor.vertexFunction = pointVertexFunction
    pointPipelineDescriptor.fragmentFunction = fragmentFunction
    pointPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
    pointPipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat

    guard let pointPipelineState = try? device.makeRenderPipelineState(descriptor: pointPipelineDescriptor) else {
      return nil
    }

    let coloredPipelineDescriptor = MTLRenderPipelineDescriptor()
    coloredPipelineDescriptor.vertexFunction = coloredVertexFunction
    coloredPipelineDescriptor.fragmentFunction = fragmentFunction
    coloredPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
    coloredPipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
    coloredPipelineDescriptor.vertexDescriptor = Self.makeColoredVertexDescriptor()

    guard let coloredPipelineState = try? device.makeRenderPipelineState(descriptor: coloredPipelineDescriptor) else {
      return nil
    }
    
    let sceneDepthDescriptor = MTLDepthStencilDescriptor()
    sceneDepthDescriptor.depthCompareFunction = .less
    sceneDepthDescriptor.isDepthWriteEnabled = true

    guard let sceneDepthStencilState = device.makeDepthStencilState(descriptor: sceneDepthDescriptor) else {
      return nil
    }

    let gizmoDepthDescriptor = MTLDepthStencilDescriptor()
    gizmoDepthDescriptor.depthCompareFunction = .less
    gizmoDepthDescriptor.isDepthWriteEnabled = false
    
    guard let cameraBuffer = device.makeBuffer(length: MemoryLayout<CameraUniforms>.stride) else {
      return nil
    }

    let gizmoVertices = Self.makeGizmoVertices()
    guard let gizmoVertexBuffer = device.makeBuffer(bytes: gizmoVertices,
                                                    length: MemoryLayout<MeshVertex>.stride * gizmoVertices.count,
                                                    options: .storageModeShared) else {
      return nil
    }
    
    let drawableSize = mtkView.drawableSize
    let initialAspectRatio = drawableSize.height > 0
    ? Float(drawableSize.width / drawableSize.height)
    : 1.0
    let orbitCamera = OrbitCamera(aspectRatio: initialAspectRatio)
    
    self.commandQueue = commandQueue
    self.pointPipelineState = pointPipelineState
    self.coloredPipelineState = coloredPipelineState
    self.sceneDepthStencilState = sceneDepthStencilState
    self.gizmoVertexBuffer = gizmoVertexBuffer
    self.gizmoVertexCount = gizmoVertices.count
    self.cameraBuffer = cameraBuffer
    self.orbitCamera = orbitCamera
    super.init()
  }

  private static func makeColoredVertexDescriptor() -> MTLVertexDescriptor {
    let descriptor = MTLVertexDescriptor()
    descriptor.attributes[0].format = .float3
    descriptor.attributes[0].offset = 0
    descriptor.attributes[0].bufferIndex = 0
    descriptor.attributes[1].format = .float3
    descriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
    descriptor.attributes[1].bufferIndex = 0
    descriptor.layouts[0].stride = MemoryLayout<MeshVertex>.stride
    descriptor.layouts[0].stepFunction = .perVertex
    return descriptor
  }

  private static func makeGizmoVertices() -> [MeshVertex] {
    let axisExtent: Float = 1_000_000
    return [
      MeshVertex(position: SIMD3<Float>(-axisExtent, 0, 0), color: SIMD3<Float>(1, 0, 0)),
      MeshVertex(position: SIMD3<Float>( axisExtent, 0, 0), color: SIMD3<Float>(1, 0, 0)),
      MeshVertex(position: SIMD3<Float>(0, -axisExtent, 0), color: SIMD3<Float>(0, 1, 0)),
      MeshVertex(position: SIMD3<Float>(0,  axisExtent, 0), color: SIMD3<Float>(0, 1, 0)),
      MeshVertex(position: SIMD3<Float>(0, 0, -axisExtent), color: SIMD3<Float>(0, 0, 1)),
      MeshVertex(position: SIMD3<Float>(0, 0,  axisExtent), color: SIMD3<Float>(0, 0, 1))
    ]
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
    pointCloud = .init()
    guard pointCloud!.createFrom(filePath: filepath) else {
      pointCloud = nil
      return
    }
    pointCloud!.points?.withUnsafeBytes { data in
      pointCloudBuffer = commandQueue.device.makeBuffer(bytes: data.baseAddress!, length: data.count, options: .storageModeShared)
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

    renderEncoder.setRenderPipelineState(coloredPipelineState)
    renderEncoder.setDepthStencilState(sceneDepthStencilState)
    renderEncoder.setCullMode(.none)
    renderEncoder.setVertexBuffer(gizmoVertexBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(cameraBuffer, offset: 0, index: 1)
    renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: gizmoVertexCount)

    if let pointCloudBuffer, let pointCloud {
      renderEncoder.setRenderPipelineState(pointPipelineState)
      renderEncoder.setDepthStencilState(sceneDepthStencilState)
      // Pass the buffer we created from NSData
      renderEncoder.setVertexBuffer(pointCloudBuffer, offset: 0, index: 0)
      renderEncoder.setVertexBuffer(cameraBuffer, offset: 0, index: 1)
      renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: Int(pointCloud.pointsCount))
    }

    renderEncoder.endEncoding()
    
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
