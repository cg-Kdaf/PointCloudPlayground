import Foundation
import Metal
import MetalKit

final class MetalRenderer: NSObject, MTKViewDelegate {
  private let commandQueue: MTLCommandQueue
  private let pointCloudRenderer: PointCloudRenderer
  private let renderPasses: [RenderPass]
  private let depthConfig: FrameDepthConfig
  private let cameraBuffer: MTLBuffer
  private let orbitCamera: OrbitCamera
  private let scene: PlaygroundScene
  let transformController: TransformController
  
  init?(mtkView: MTKView, scene: PlaygroundScene) {
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
    
    guard let library = device.makeDefaultLibrary() else {
      return nil
    }
    
    guard let pointCloudRenderer = PointCloudRenderer(device: device,
                                                      library: library,
                                                      colorPixelFormat: mtkView.colorPixelFormat,
                                                      depthPixelFormat: mtkView.depthStencilPixelFormat,
                                                      scene: scene) else {
      return nil
    }
    
    let sceneDepthDescriptor = MTLDepthStencilDescriptor()
    sceneDepthDescriptor.depthCompareFunction = .less
    sceneDepthDescriptor.isDepthWriteEnabled = true
    
    guard let sceneDepthStencilState = device.makeDepthStencilState(descriptor: sceneDepthDescriptor) else {
      return nil
    }
    
    let overlayDepthDescriptor = MTLDepthStencilDescriptor()
    overlayDepthDescriptor.depthCompareFunction = .lessEqual
    overlayDepthDescriptor.isDepthWriteEnabled = false
    
    guard let overlayDepthStencilState = device.makeDepthStencilState(descriptor: overlayDepthDescriptor) else {
      return nil
    }
    
    guard let gizmoRenderer = GizmoRenderer(device: device,
                                            library: library,
                                            colorPixelFormat: mtkView.colorPixelFormat,
                                            depthPixelFormat: mtkView.depthStencilPixelFormat,
                                            scene: scene) else {
      return nil
    }
    
    guard let cameraBuffer = device.makeBuffer(length: MemoryLayout<CameraUniforms>.stride) else {
      return nil
    }
    
    let drawableSize = mtkView.drawableSize
    let initialAspectRatio = drawableSize.height > 0
    ? Float(drawableSize.width / drawableSize.height)
    : 1.0
    let orbitCamera = OrbitCamera(aspectRatio: initialAspectRatio)
    
    self.commandQueue = commandQueue
    self.pointCloudRenderer = pointCloudRenderer
    self.renderPasses = [pointCloudRenderer, gizmoRenderer]
    self.depthConfig = FrameDepthConfig(sceneDepthStencilState: sceneDepthStencilState,
                                        overlayDepthStencilState: overlayDepthStencilState)
    self.cameraBuffer = cameraBuffer
    self.orbitCamera = orbitCamera
    self.scene = scene
    self.transformController = TransformController(scene: scene)
    super.init()
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
    transformController.cameraDistance = orbitCamera.radius
    transformController.cameraRight = orbitCamera.right
    transformController.cameraUp = orbitCamera.up
    transformController.cameraForward = orbitCamera.forward
    var cameraUniforms = orbitCamera.makeUniforms()
    cameraBuffer.contents().copyMemory(from: &cameraUniforms, byteCount: MemoryLayout<CameraUniforms>.stride)
    
    let frame = FrameContext(cameraUniforms: cameraUniforms,
                             cameraBuffer: cameraBuffer,
                             viewport: MTLViewport(originX: 0,
                                                   originY: 0,
                                                   width: Double(view.drawableSize.width),
                                                   height: Double(view.drawableSize.height),
                                                   znear: 0,
                                                   zfar: 1),
                             depth: depthConfig)
    
    for renderPass in renderPasses {
      renderPass.draw(encoder: renderEncoder, frame: frame)
    }
    
    renderEncoder.endEncoding()
    
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}

/// Coordinators
extension MetalRenderer {
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
}
