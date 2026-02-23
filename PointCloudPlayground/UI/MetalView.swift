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
    mtkView.onPan = { [weak renderer] deltaX, deltaY in
      renderer?.moveTarget(deltaX: deltaX, deltaY: deltaY)
    }
    mtkView.onMouseUp = { [weak renderer] in
      renderer?.startInertia()
    }
    mtkView.onScroll = { [weak renderer] delta in
      renderer?.zoom(delta: delta)
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
  var onPan: ((Float, Float) -> Void)?
  var onMouseUp: (() -> Void)?
  var onScroll: ((Float) -> Void)?
  private var previousLocation: CGPoint?
  private var scrollTimer: Timer?
  
  override func mouseDown(with event: NSEvent) {
    previousLocation = convert(event.locationInWindow, from: nil)
  }
  
  override func mouseDragged(with event: NSEvent) {
    let currentLocation = convert(event.locationInWindow, from: nil)
    if let previousLocation {
      let deltaX = Float(previousLocation.x - currentLocation.x)
      let deltaY = Float(previousLocation.y - currentLocation.y)
      onMouseDrag?(-deltaX, deltaY)
    }
    previousLocation = currentLocation
  }
  
  override func mouseUp(with event: NSEvent) {
    onMouseUp?()
    previousLocation = nil
  }
  
  override func scrollWheel(with event: NSEvent) {
    let deltaX = Float(event.scrollingDeltaX)
    let deltaY = Float(event.scrollingDeltaY)
    if event.modifierFlags.contains(.shift) {
      onPan?(-deltaX, deltaY)
    } else {
      onScroll?(-deltaY)
    }
    
    // Reset timer to detect when scrolling stops
    scrollTimer?.invalidate()
    scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
      self?.onMouseUp?()
    }
  }
}
