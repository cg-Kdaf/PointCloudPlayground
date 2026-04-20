import SwiftUI
import MetalKit
import AppKit
import simd

struct MetalView: NSViewRepresentable {
  let scene: PlaygroundScene
  @Binding var transformReferenceMode: TransformReferenceMode
  var fixedCameraId: UUID? = nil
  
  func makeNSView(context: Context) -> OrbitMTKView {
    let mtkView = OrbitMTKView(frame: .zero)
    mtkView.preferredFramesPerSecond = 60
    mtkView.enableSetNeedsDisplay = false
    mtkView.isPaused = false
    
    guard let renderer = MetalRenderer(mtkView: mtkView, scene: scene) else {
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
    renderer.fixedCameraId = fixedCameraId
    mtkView.transformController = renderer.transformController
    context.coordinator.renderer = renderer
    return mtkView
  }
  
  func updateNSView(_ nsView: OrbitMTKView, context: Context) {
    nsView.transformController?.referenceMode = transformReferenceMode
    context.coordinator.renderer?.fixedCameraId = fixedCameraId
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator()
  }
  
  final class Coordinator {
    var renderer: MetalRenderer?
  }
}

final class OrbitMTKView: MTKView {
  var onMouseDrag: ((Float, Float) -> Void)?
  var onPan: ((Float, Float) -> Void)?
  var onMouseUp: (() -> Void)?
  var onScroll: ((Float) -> Void)?
  var transformController: TransformController?
  private var previousLocation: CGPoint?
  private var scrollTimer: Timer?
  private var statusLabel: NSTextField?

  override var acceptsFirstResponder: Bool { true }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    window?.makeFirstResponder(self)

    if statusLabel == nil {
      let label = NSTextField(labelWithString: "")
      label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
      label.textColor = .white
      label.backgroundColor = .black.withAlphaComponent(0.6)
      label.isBezeled = false
      label.drawsBackground = true
      label.translatesAutoresizingMaskIntoConstraints = false
      label.isHidden = true
      addSubview(label)
      label.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
      label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12).isActive = true
      statusLabel = label
    }

    addTrackingArea(NSTrackingArea(rect: .zero,
                                   options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                   owner: self, userInfo: nil))
  }
  
  override func mouseDown(with event: NSEvent) {
    if let tc = transformController, tc.isActive {
      // Click confirms the transform
      tc.confirm()
      updateStatusLabel()
      return
    }
    previousLocation = convert(event.locationInWindow, from: nil)
  }
  
  override func mouseDragged(with event: NSEvent) {
    if let tc = transformController, tc.isActive {
      return // Don't orbit while transforming
    }
    let currentLocation = convert(event.locationInWindow, from: nil)
    if let previousLocation {
      let deltaX = Float(previousLocation.x - currentLocation.x)
      let deltaY = Float(previousLocation.y - currentLocation.y)
      onMouseDrag?(-deltaX, deltaY)
    }
    previousLocation = currentLocation
  }
  
  override func mouseUp(with event: NSEvent) {
    if let tc = transformController, tc.isActive {
      return
    }
    onMouseUp?()
    previousLocation = nil
  }

  override func mouseMoved(with event: NSEvent) {
    guard let tc = transformController, tc.isActive else { return }
    tc.applyMouseDelta(deltaX: Float(event.deltaX), deltaY: Float(event.deltaY))
  }

  override func rightMouseDown(with event: NSEvent) {
    if let tc = transformController, tc.isActive {
      tc.cancel()
      updateStatusLabel()
      return
    }
    previousLocation = convert(event.locationInWindow, from: nil)
  }

  override func rightMouseDragged(with event: NSEvent) {
    if let tc = transformController, tc.isActive {
      return
    }
    let currentLocation = convert(event.locationInWindow, from: nil)
    if let previousLocation {
      let deltaX = Float(previousLocation.x - currentLocation.x)
      let deltaY = Float(previousLocation.y - currentLocation.y)
      onPan?(deltaX, deltaY)
    }
    previousLocation = currentLocation
  }

  override func rightMouseUp(with event: NSEvent) {
    if let tc = transformController, tc.isActive {
      return
    }
    onMouseUp?()
    previousLocation = nil
  }

  override func keyDown(with event: NSEvent) {
    guard let tc = transformController, let ch = event.charactersIgnoringModifiers?.lowercased() else {
      super.keyDown(with: event)
      return
    }

    if tc.isActive {
      switch ch {
      case "x": tc.setAxis(.x)
      case "y": tc.setAxis(.y)
      case "z": tc.setAxis(.z)
      case "\r": tc.confirm()
      case "\u{1B}": tc.cancel()
      default: break
      }
      updateStatusLabel()
      return
    }

    switch ch {
    case "g": if tc.begin(mode: .translate) { updateStatusLabel() }
    case "r": if tc.begin(mode: .rotate) { updateStatusLabel() }
    case "s": if tc.begin(mode: .scale) { updateStatusLabel() }
    default: super.keyDown(with: event)
    }
  }
  
  override func scrollWheel(with event: NSEvent) {
    if let tc = transformController, tc.isActive {
      return // Don't scroll while transforming
    }
    let deltaY = Float(event.scrollingDeltaY)
    onScroll?(-deltaY)
    
    // Reset timer to detect when scrolling stops
    scrollTimer?.invalidate()
    scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
      self?.onMouseUp?()
    }
  }

  private func updateStatusLabel() {
    guard let tc = transformController else { return }
    let text = tc.statusText
    statusLabel?.stringValue = text
    statusLabel?.isHidden = text.isEmpty
  }
}

struct CameraOverlayImage: View {
  @ObservedObject var camData: CameraDataBlock
  let imagePath: String
  let overlayOpacity: Double
  
  var body: some View {
    if let nsImage = NSImage(contentsOfFile: imagePath) {
      Image(nsImage: nsImage)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .opacity(overlayOpacity)
        .allowsHitTesting(false)
        .scaleEffect(CGFloat(camData.zoom))
    }
  }
}

struct CameraOverlayView: View {
  @ObservedObject var scene: PlaygroundScene
  let cameraId: UUID?
  @State private var transformReferenceMode: TransformReferenceMode = .objectCenter
  @State private var overlayOpacity: Double = 0.5
  
  var body: some View {
    ZStack {
      MetalView(scene: scene, transformReferenceMode: $transformReferenceMode, fixedCameraId: cameraId)
      
      if let cameraId = cameraId,
         let obj = scene.rootGroup.object(withId: cameraId),
         let camData = obj.asCameraData,
         let imagePath = camData.imagePath {
        CameraOverlayImage(camData: camData, imagePath: imagePath, overlayOpacity: overlayOpacity)
      }
      
      VStack {
        Spacer()
        HStack {
          Text("Overlay Opacity")
            .foregroundColor(.white)
            .shadow(color: .black, radius: 2)
          Slider(value: $overlayOpacity, in: 0...1)
            .frame(width: 150)
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
        .padding()
      }
    }
  }
}

