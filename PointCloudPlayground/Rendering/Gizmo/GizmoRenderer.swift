import Metal
import simd

private struct GizmoVertex {
  var position: SIMD3<Float>
  var color: SIMD3<Float>
}

final class GizmoRenderer {
  private let device: MTLDevice
  private let pipelineState: MTLRenderPipelineState
  private let axisVertexBuffer: MTLBuffer
  private let axisVertexCount: Int
  private var bboxVertexBuffer: MTLBuffer?
  private var bboxVertexCount: Int = 0
  private let scene: PlaygroundScene

  init?(device: MTLDevice,
        library: MTLLibrary,
        colorPixelFormat: MTLPixelFormat,
        depthPixelFormat: MTLPixelFormat,
        scene: PlaygroundScene) {
    guard let vertexFunction = library.makeFunction(name: "gizmo_vertex"),
          let fragmentFunction = library.makeFunction(name: "gizmo_fragment") else {
      return nil
    }

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = depthPixelFormat
    pipelineDescriptor.vertexDescriptor = Self.makeVertexDescriptor()

    guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
      return nil
    }

    let vertices = Self.makeAxisVertices()
    guard let axisVertexBuffer = device.makeBuffer(bytes: vertices,
                                                   length: MemoryLayout<GizmoVertex>.stride * vertices.count,
                                                   options: .storageModeShared) else {
      return nil
    }

    self.device = device
    self.pipelineState = pipelineState
    self.axisVertexBuffer = axisVertexBuffer
    self.axisVertexCount = vertices.count
    self.scene = scene

    scene.sceneModifiedCallbacks["GizmoRenderer"] = { [weak self] s in
      self?.updateBoundingBox(scene: s)
    }
    updateBoundingBox(scene: scene)
  }

  deinit {
    scene.sceneModifiedCallbacks.removeValue(forKey: "GizmoRenderer")
  }

  func draw(encoder: MTLRenderCommandEncoder, frame: FrameContext) {
    encoder.setViewport(frame.viewport)
    encoder.setRenderPipelineState(pipelineState)
    encoder.setDepthStencilState(frame.depth.overlayDepthStencilState)
    encoder.setCullMode(.none)

    // Draw axis lines
    encoder.setVertexBuffer(axisVertexBuffer, offset: 0, index: 0)
    encoder.setVertexBuffer(frame.cameraBuffer, offset: 0, index: 1)
    encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: axisVertexCount)

    // Draw bounding box wireframe for selected object
    if let bboxBuffer = bboxVertexBuffer, bboxVertexCount > 0 {
      encoder.setVertexBuffer(bboxBuffer, offset: 0, index: 0)
      encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: bboxVertexCount)
    }
  }

  private func updateBoundingBox(scene: PlaygroundScene) {
    guard let selectedId = scene.selectedObjectId,
          let selectedObject = scene.objects.first(where: { $0.id == selectedId }),
          let pointCloudData = selectedObject.asPointCloudData,
          let bbox = pointCloudData.boundingBox else {
      bboxVertexBuffer = nil
      bboxVertexCount = 0
      return
    }

    let vertices = Self.makeBoundingBoxVertices(bbox: bbox, modelMatrix: selectedObject.modelMatrix)
    bboxVertexCount = vertices.count
    bboxVertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: MemoryLayout<GizmoVertex>.stride * vertices.count,
                                         options: .storageModeShared)
  }

  private static func makeVertexDescriptor() -> MTLVertexDescriptor {
    let descriptor = MTLVertexDescriptor()
    descriptor.attributes[0].format = .float3
    descriptor.attributes[0].offset = 0
    descriptor.attributes[0].bufferIndex = 0
    descriptor.attributes[1].format = .float3
    descriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
    descriptor.attributes[1].bufferIndex = 0
    descriptor.layouts[0].stride = MemoryLayout<GizmoVertex>.stride
    descriptor.layouts[0].stepFunction = .perVertex
    return descriptor
  }

  private static func makeAxisVertices() -> [GizmoVertex] {
    let axisExtent: Float = 1_000_000
    return [
      GizmoVertex(position: SIMD3<Float>(-axisExtent, 0, 0), color: SIMD3<Float>(1, 0, 0)),
      GizmoVertex(position: SIMD3<Float>( axisExtent, 0, 0), color: SIMD3<Float>(1, 0, 0)),
      GizmoVertex(position: SIMD3<Float>(0, -axisExtent, 0), color: SIMD3<Float>(0, 1, 0)),
      GizmoVertex(position: SIMD3<Float>(0,  axisExtent, 0), color: SIMD3<Float>(0, 1, 0)),
      GizmoVertex(position: SIMD3<Float>(0, 0, -axisExtent), color: SIMD3<Float>(0, 0, 1)),
      GizmoVertex(position: SIMD3<Float>(0, 0,  axisExtent), color: SIMD3<Float>(0, 0, 1))
    ]
  }

  private static func makeBoundingBoxVertices(bbox: BoundingBox, modelMatrix: simd_float4x4) -> [GizmoVertex] {
    let color = SIMD3<Float>(1, 1, 0)
    let lo = SIMD3<Float>(bbox.min_x, bbox.min_y, bbox.min_z)
    let hi = SIMD3<Float>(bbox.max_x, bbox.max_y, bbox.max_z)

    // 8 corners: iterate over each bit pattern of (x, y, z) = lo/hi
    let corners = (0..<8).map { i -> SIMD3<Float> in
      let local = SIMD3<Float>(
        (i & 1) != 0 ? hi.x : lo.x,
        (i & 2) != 0 ? hi.y : lo.y,
        (i & 4) != 0 ? hi.z : lo.z
      )
      let w = modelMatrix * SIMD4<Float>(local, 1.0)
      return SIMD3<Float>(w.x, w.y, w.z)
    }

    // 12 edges: pairs that differ by exactly one bit
    let edges: [(Int, Int)] = [
      (0,1),(2,3),(4,5),(6,7), // differ in bit 0 (x)
      (0,2),(1,3),(4,6),(5,7), // differ in bit 1 (y)
      (0,4),(1,5),(2,6),(3,7), // differ in bit 2 (z)
    ]
    return edges.flatMap { (a, b) in
      [GizmoVertex(position: corners[a], color: color),
       GizmoVertex(position: corners[b], color: color)]
    }
  }
}

extension GizmoRenderer: RenderPass {}
