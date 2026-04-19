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
  var fixedCameraId: UUID?
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
    
    var cameraUniforms: CameraUniforms
    if let fixedCameraId = fixedCameraId,
       let cameraObj = scene.rootGroup.object(withId: fixedCameraId),
       let camData = cameraObj.asCameraData {
      
      let hierarchical_matrix = scene.rootGroup.hierarchicalMatrix(forItemId: fixedCameraId, in: scene.rootGroup)
      
      // Transform camera position through hierarchy
      let localPos = SIMD4<Float>(camData.position.x, camData.position.y, camData.position.z, 1.0)
      let worldPos = hierarchical_matrix * localPos
      let transformedPosition = SIMD3<Float>(worldPos.x, worldPos.y, worldPos.z) / worldPos.w
      
      // Transform camera orientation through hierarchy
      let q = simd_quatf(vector: camData.orientation)
      
      // Extract rotation from hierarchical matrix
      let col0 = SIMD3<Float>(hierarchical_matrix.columns.0.x, hierarchical_matrix.columns.0.y, hierarchical_matrix.columns.0.z)
      let col1 = SIMD3<Float>(hierarchical_matrix.columns.1.x, hierarchical_matrix.columns.1.y, hierarchical_matrix.columns.1.z)
      let col2 = SIMD3<Float>(hierarchical_matrix.columns.2.x, hierarchical_matrix.columns.2.y, hierarchical_matrix.columns.2.z)
      
      let scaleX = length(col0)
      let scaleY = length(col1)
      let scaleZ = length(col2)
      
      let rotationMatrix = simd_float3x3(
        col0 / scaleX,
        col1 / scaleY,
        col2 / scaleZ
      )
      
      let hierarchicalQuat = simd_quatf(rotationMatrix)
      let transformedOrientation = hierarchicalQuat * q
      
      // Build camera matrix from transformed position and orientation
      let positionMatrix = simd_float4x4.translation(transformedPosition)
      let rotationMatrixFinal = simd_float4x4(transformedOrientation)
      let cameraMatrix = positionMatrix * rotationMatrixFinal
      
      // View matrix is the inverse of camera matrix
      let viewMatrix = cameraMatrix.inverse
      
      let drawableSize = view.drawableSize
      let aspect = drawableSize.height > 0 ? Float(drawableSize.width / drawableSize.height) : 1.0
      let projection = simd_float4x4.perspectiveFovRH(fovY: 90.0 * (.pi / 180.0),
                                                      aspect: aspect,
                                                      nearZ: 0.001,
                                                      farZ: 300.0)
      cameraUniforms = CameraUniforms(viewProjectionMatrix: projection * viewMatrix)
    } else {
      orbitCamera.updateOrbit()
      transformController.cameraDistance = orbitCamera.radius
      transformController.cameraRight = orbitCamera.right
      transformController.cameraUp = orbitCamera.up
      transformController.cameraForward = orbitCamera.forward
      cameraUniforms = orbitCamera.makeUniforms()
    }
    
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
