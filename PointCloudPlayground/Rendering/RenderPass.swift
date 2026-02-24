import Metal

struct FrameDepthConfig {
  let sceneDepthStencilState: MTLDepthStencilState
  let overlayDepthStencilState: MTLDepthStencilState
}

struct FrameContext {
  let cameraUniforms: CameraUniforms
  let cameraBuffer: MTLBuffer
  let viewport: MTLViewport
  let depth: FrameDepthConfig
}

protocol RenderPass {
  func draw(encoder: MTLRenderCommandEncoder, frame: FrameContext)
}