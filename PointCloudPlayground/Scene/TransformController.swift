import Foundation
import simd

enum TransformMode { case translate, rotate, scale }
enum AxisConstraint { case none, x, y, z }
enum TransformReferenceMode: String, CaseIterable, Identifiable {
  case objectCenter = "Object Center"
  case worldOrigin = "World Origin"
  var id: String { rawValue }
}

final class TransformController {
  private(set) var isActive = false
  private(set) var mode: TransformMode = .translate
  private(set) var axis: AxisConstraint = .none

  private weak var scene: PlaygroundScene?
  private var target: SceneObject?
  private var savedTranslation: SIMD3<Float> = .zero
  private var savedRotation: SIMD3<Float> = .zero
  private var savedScale: SIMD3<Float> = .one

  var referenceMode: TransformReferenceMode = .objectCenter

  // Set each frame by the renderer
  var cameraDistance: Float = 30.0
  var cameraRight: SIMD3<Float> = SIMD3(1, 0, 0)
  var cameraUp: SIMD3<Float> = SIMD3(0, 0, 1)
  var cameraForward: SIMD3<Float> = SIMD3(0, 1, 0)

  init(scene: PlaygroundScene) { self.scene = scene }

  func begin(mode: TransformMode) -> Bool {
    guard let scene,
        let obj = scene.selectedObject else { return false }
    self.mode = mode
    self.axis = .none
    self.target = obj
    self.savedTranslation = obj.translation
    self.savedRotation = obj.rotation
    self.savedScale = obj.scale
    self.isActive = true
    return true
  }

  func setAxis(_ a: AxisConstraint) {
    guard isActive else { return }
    resetToSaved()
    axis = a
  }

  func applyMouseDelta(deltaX: Float, deltaY: Float) {
    guard isActive, let obj = target else { return }
    let screenDelta = SIMD2<Float>(deltaX, -deltaY)
    let speed = cameraDistance * 0.001

    switch mode {
    case .translate:
      let worldDelta: SIMD3<Float>
      if axis == .none {
        worldDelta = (cameraRight * screenDelta.x + cameraUp * screenDelta.y) * speed
      } else {
        worldDelta = worldAxis(axis) * projectedDelta(worldAxis: worldAxis(axis), screenDelta: screenDelta) * speed
      }
      obj.translation = obj.translation + worldDelta

    case .rotate:
      let angle: Float
      if axis == .none {
        angle = screenDelta.x * 0.005
      } else {
        angle = projectedDelta(worldAxis: worldAxis(axis), screenDelta: screenDelta) * 0.005
      }
      let rotAxis = axis == .none ? cameraForward : worldAxis(axis)
      let current = simd_float4x4.fromEulerZYX(obj.rotation)
      let delta = simd_float4x4.rotation(axis: rotAxis, angle: angle)
      if referenceMode == .objectCenter {
        obj.rotation = simd_float4x4.eulerAnglesZYX(from: delta * current)
      } else {
        // Rotate object and its position around world origin.
        let next = delta * current
        obj.rotation = simd_float4x4.eulerAnglesZYX(from: next)
        let p = delta * SIMD4<Float>(obj.translation, 1)
        obj.translation = SIMD3<Float>(p.x, p.y, p.z)
      }

    case .scale:
      let d: Float
      if axis == .none {
        d = screenDelta.x * speed * 0.01
        let f = 1.0 + d
        obj.scale = obj.scale * f
        if referenceMode == .worldOrigin {
          obj.translation = obj.translation * f
        }
      } else {
        d = projectedDelta(worldAxis: worldAxis(axis), screenDelta: screenDelta) * speed * 0.01
        let mask = worldAxis(axis)
        obj.scale = obj.scale + mask * d * obj.scale
        if referenceMode == .worldOrigin {
          obj.translation = obj.translation + mask * d * obj.translation
        }
      }
    }
  }

  func confirm() { isActive = false; target = nil }
  func cancel() { resetToSaved(); isActive = false; target = nil }

  var statusText: String {
    guard isActive else { return "" }
    let m = mode == .translate ? "Grab" : mode == .rotate ? "Rotate" : "Scale"
    let a = axis == .x ? " X" : axis == .y ? " Y" : axis == .z ? " Z" : ""
    let r = referenceMode == .objectCenter ? "Object" : "World"
    return "\(m)\(a) [\(r)]  |  X/Y/Z  |  Enter/Click  |  Esc/RClick"
  }

  private func worldAxis(_ a: AxisConstraint) -> SIMD3<Float> {
    switch a {
    case .x: return SIMD3(1, 0, 0)
    case .y: return SIMD3(0, 1, 0)
    case .z: return SIMD3(0, 0, 1)
    case .none: return SIMD3(0, 0, 0)
    }
  }

  /// Project a world axis onto the screen plane (camera right/up) and dot with screen delta.
  private func projectedDelta(worldAxis: SIMD3<Float>, screenDelta: SIMD2<Float>) -> Float {
    let screenDir = SIMD2<Float>(simd_dot(worldAxis, cameraRight),
                                 simd_dot(worldAxis, cameraUp))
    let len = simd_length(screenDir)
    guard len > 0.001 else { return 0 }
    return simd_dot(simd_normalize(screenDir), screenDelta)
  }

  private func resetToSaved() {
    guard let obj = target else { return }
    obj.translation = savedTranslation
    obj.rotation = savedRotation
    obj.scale = savedScale
  }
}
