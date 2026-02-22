import SwiftUI
import MetalKit
import AppKit

struct MetalView: NSViewRepresentable {
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
    return mtkView
  }
  
  func updateNSView(_ nsView: OrbitMTKView, context: Context) {}
  
  func makeCoordinator() -> Coordinator {
    Coordinator()
  }
  
  final class Coordinator {
    var renderer: MetalRenderer?
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
