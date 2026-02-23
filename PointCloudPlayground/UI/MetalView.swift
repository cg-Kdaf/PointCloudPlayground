import SwiftUI
import MetalKit
import AppKit
import simd

struct MetalView: NSViewRepresentable {
  let selectedFilePath: String?
  let selectedColor: SIMD3<Float>?
  let loadRequestID: Int
  let loadFilepath: String?

  func makeNSView(context: Context) -> OrbitMTKView {
    let mtkView = OrbitMTKView(frame: .zero)
    mtkView.preferredFramesPerSecond = 60
    mtkView.enableSetNeedsDisplay = false
    mtkView.isPaused = false
    
    guard let renderer = MetalRenderer(mtkView: mtkView) else {
      return mtkView
    }
    
    mtkView.delegate = renderer
    mtkView.onMouseDrag = { [weak renderer] deltaX, deltaY in
      renderer?.orbit(deltaX: deltaX, deltaY: deltaY)
    }
    mtkView.onMouseUp = { [weak renderer] in
      renderer?.startInertia()
    }
    context.coordinator.renderer = renderer
    context.coordinator.updateSelection(filePath: selectedFilePath, color: selectedColor)
    context.coordinator.updateLoadRequest(requestID: loadRequestID, filepath: loadFilepath)
    return mtkView
  }
  
  func updateNSView(_ nsView: OrbitMTKView, context: Context) {
    context.coordinator.updateSelection(filePath: selectedFilePath, color: selectedColor)
    context.coordinator.updateLoadRequest(requestID: loadRequestID, filepath: loadFilepath)
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator()
  }
  
  final class Coordinator {
    var renderer: MetalRenderer?
    private var lastFilePath: String?
    private var lastColor: SIMD3<Float>?
    private var lastLoadRequestID: Int?

    func updateSelection(filePath: String?, color: SIMD3<Float>?) {
      guard lastFilePath != filePath || lastColor != color else {
        return
      }

      lastFilePath = filePath
      lastColor = color

      guard let renderer,
            let filePath,
            let color else {
//        renderer?.clearPointCloud()
        return
      }

//      renderer.loadPointCloud(at: filePath, color: color)
    }

    func updateLoadRequest(requestID: Int, filepath: String?) {
      guard lastLoadRequestID != requestID else {
        return
      }

      lastLoadRequestID = requestID

      guard let renderer,
            let filepath else {
        return
      }

      renderer.loadCloud(filepath: filepath)
    }
  }
}

final class OrbitMTKView: MTKView {
  var onMouseDrag: ((Float, Float) -> Void)?
  var onMouseUp: (() -> Void)?
  private var previousLocation: CGPoint?
  
  override func mouseDown(with event: NSEvent) {
    previousLocation = convert(event.locationInWindow, from: nil)
  }
  
  override func mouseDragged(with event: NSEvent) {
    let currentLocation = convert(event.locationInWindow, from: nil)
    if let previousLocation {
      let deltaX = Float(previousLocation.x - currentLocation.x)
      let deltaY = Float(previousLocation.y - currentLocation.y)
      onMouseDrag?(deltaX, deltaY)
    }
    previousLocation = currentLocation
  }
  
  override func mouseUp(with event: NSEvent) {
    onMouseUp?()
    previousLocation = nil
  }
}
