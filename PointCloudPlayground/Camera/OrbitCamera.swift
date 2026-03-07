import Foundation
import simd

// Half time in seconds
fileprivate let intertiaHalfLife: Float = 0.1
fileprivate let nearCamera: Float = 1.0
fileprivate let farCamera: Float = 3000.0

struct CameraUniforms {
  var viewProjectionMatrix: simd_float4x4
}

final class OrbitCamera {
  private var aspectRatio: Float
  private var yaw: Float = 0.5
  private var pitch: Float = 0.4
  private var yaw_speed: Float = 0.0
  private var pitch_speed: Float = 0.0
  private(set) var radius: Float = 30.0
  private var radius_speed: Float = 0.0
  private var target = SIMD3<Float>(0, 0, 0)
  private var target_speed = SIMD3<Float>(0, 0, 0)
  private let minRadius: Float = nearCamera
  private let maxRadius: Float = farCamera
  private var freeOrbit: Bool = false
  
  init(aspectRatio: Float) {
    self.aspectRatio = aspectRatio
  }
  
  private func clampOrbit() {
    let maxPitch: Float = .pi / 2 - 0.05
    pitch = max(-maxPitch, min(maxPitch, pitch))
  }
  
  func setDrawableSize(_ size: CGSize) {
    guard size.height > 0 else { return }
    aspectRatio = Float(size.width / size.height)
  }
  
  func updateOrbit() {
    if !freeOrbit {return}
    let dt: Float = 0.016
    if (yaw_speed != 0.0 || pitch_speed != 0.0 || radius_speed != 0.0 || length(target_speed) > 0.0) {
      // Speed is not null, continue to make the orbit evolve
      yaw += yaw_speed * dt
      pitch += pitch_speed * dt
      radius += radius_speed * dt
      radius = min(maxRadius, max(minRadius, radius))
      target += target_speed * dt
      
      // Exponential decay
      yaw_speed *= pow(0.5, dt / intertiaHalfLife)
      pitch_speed *= pow(0.5, dt / intertiaHalfLife)
      radius_speed *= pow(0.5, dt / intertiaHalfLife)
      target_speed *= pow(0.5, dt / intertiaHalfLife)
      if (abs(yaw_speed) < 0.01) {
        yaw_speed = 0.0
      }
      if (abs(pitch_speed) < 0.01) {
        pitch_speed = 0.0
      }
      if (abs(radius_speed) < 0.01) {
        radius_speed = 0.0
      }
      if (length(target_speed) < 0.01) {
        target_speed = SIMD3<Float>(0, 0, 0)
      }
      clampOrbit()
    }
  }
  
  func orbit(deltaX: Float, deltaY: Float) {
    let dt: Float = 0.016
    let sensitivity: Float = 0.01
    yaw += deltaX * sensitivity
    pitch += deltaY * sensitivity
    // A bit of filtering of the speed
    yaw_speed = yaw_speed * 0.7 + 0.3 * deltaX * sensitivity / dt
    pitch_speed = pitch_speed * 0.7 + 0.3 * deltaY * sensitivity / dt
    clampOrbit()
    freeOrbit = false
  }
  
  func moveTarget(deltaX: Float, deltaY: Float) {
    let dt: Float = 0.016
    let sensitivity: Float = 0.01
    
    // Compute camera's right and up vectors
    let forward = simd_normalize(SIMD3<Float>(
      cos(pitch) * sin(yaw),
      cos(pitch) * cos(yaw),
      sin(pitch)
    ))
    let worldUp = SIMD3<Float>(0, 0, 1)
    let right = simd_normalize(simd_cross(worldUp, forward))
    let up = simd_cross(forward, right)
    
    // Movement scaled by radius for natural feel at different zoom levels
    let movement = (right * deltaX + up * deltaY) * radius * 0.1
    
    target += movement * sensitivity
    // A bit of filtering of the speed
    target_speed = target_speed * 0.7 + 0.3 * movement * sensitivity / dt
    freeOrbit = false
  }
  
  func startInertia() {
    freeOrbit = true
  }
  
  func zoom(delta: Float) {
    let dt: Float = 0.016
    let sensitivity: Float = 0.06
    let radiusDelta = delta * sensitivity
    radius += radiusDelta
    radius = min(maxRadius, max(minRadius, radius))
    // A bit of filtering of the speed
    radius_speed = radius_speed * 0.7 + 0.3 * radiusDelta / dt
    freeOrbit = false
  }
  
  func makeUniforms() -> CameraUniforms {
    let cameraPosition = SIMD3<Float>(
      radius * cos(pitch) * sin(yaw),
      radius * cos(pitch) * cos(yaw),
      radius * sin(pitch)
    )
    
    let projection = simd_float4x4.perspectiveFovRH(fovY: 60.0 * (.pi / 180.0),
                                                    aspect: aspectRatio,
                                                    nearZ: nearCamera,
                                                    farZ: farCamera)
    let viewMatrix = simd_float4x4.lookAtRH(eye: cameraPosition + target,
                                            center: target,
                                            up: SIMD3<Float>(0, 0, 1))
    return CameraUniforms(viewProjectionMatrix: projection * viewMatrix)
  }

  /// Camera basis vectors in world space
  var forward: SIMD3<Float> {
    simd_normalize(SIMD3<Float>(
      cos(pitch) * sin(yaw),
      cos(pitch) * cos(yaw),
      sin(pitch)
    ))
  }
  var right: SIMD3<Float> {
    simd_normalize(simd_cross(SIMD3<Float>(0, 0, 1), forward))
  }
  var up: SIMD3<Float> {
    simd_cross(forward, right)
  }
}

extension simd_float4x4 {
  static func perspectiveFovRH(fovY: Float, aspect: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
    let yScale = 1 / tan(fovY * 0.5)
    let xScale = yScale / aspect
    let zRange = farZ - nearZ
    let zScale = -(farZ + nearZ) / zRange
    let wzScale = -2 * farZ * nearZ / zRange
    
    return simd_float4x4(columns: (
      SIMD4<Float>(xScale, 0, 0, 0),
      SIMD4<Float>(0, yScale, 0, 0),
      SIMD4<Float>(0, 0, zScale, -1),
      SIMD4<Float>(0, 0, wzScale, 0)
    ))
  }
  
  static func lookAtRH(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    let forward = simd_normalize(eye - center)
    let right = simd_normalize(simd_cross(up, forward))
    let cameraUp = simd_cross(forward, right)
    
    let rotation = simd_float4x4(columns: (
      SIMD4<Float>(right.x, cameraUp.x, forward.x, 0),
      SIMD4<Float>(right.y, cameraUp.y, forward.y, 0),
      SIMD4<Float>(right.z, cameraUp.z, forward.z, 0),
      SIMD4<Float>(0, 0, 0, 1)
    ))
    
    let translation = simd_float4x4(columns: (
      SIMD4<Float>(1, 0, 0, 0),
      SIMD4<Float>(0, 1, 0, 0),
      SIMD4<Float>(0, 0, 1, 0),
      SIMD4<Float>(-eye.x, -eye.y, -eye.z, 1)
    ))
    
    return rotation * translation
  }

  static func translation(_ t: SIMD3<Float>) -> simd_float4x4 {
    var m = matrix_identity_float4x4
    m.columns.3 = SIMD4<Float>(t, 1)
    return m
  }

  static func rotation(axis: SIMD3<Float>, angle: Float) -> simd_float4x4 {
    let a = simd_normalize(axis)
    let c = cos(angle); let s = sin(angle); let t = 1 - c
    return simd_float4x4(columns: (
      SIMD4<Float>(t*a.x*a.x + c,     t*a.x*a.y + s*a.z, t*a.x*a.z - s*a.y, 0),
      SIMD4<Float>(t*a.x*a.y - s*a.z, t*a.y*a.y + c,     t*a.y*a.z + s*a.x, 0),
      SIMD4<Float>(t*a.x*a.z + s*a.y, t*a.y*a.z - s*a.x, t*a.z*a.z + c,     0),
      SIMD4<Float>(0, 0, 0, 1)
    ))
  }

  static func scaling(_ s: SIMD3<Float>) -> simd_float4x4 {
    var m = matrix_identity_float4x4
    m.columns.0.x = s.x; m.columns.1.y = s.y; m.columns.2.z = s.z
    return m
  }

  static func eulerAnglesZYX(from m: simd_float4x4) -> SIMD3<Float> {
    let sy = -m.columns.0.z
    let y = asin(simd_clamp(sy, -1, 1))
    if abs(sy) < 0.9999 {
      return SIMD3(atan2(m.columns.1.z, m.columns.2.z), y, atan2(m.columns.0.y, m.columns.0.x))
    }
    return SIMD3(atan2(-m.columns.2.y, m.columns.1.y), y, 0)
  }

  static func fromEulerZYX(_ e: SIMD3<Float>) -> simd_float4x4 {
    rotation(axis: SIMD3(0,0,1), angle: e.z) *
    rotation(axis: SIMD3(0,1,0), angle: e.y) *
    rotation(axis: SIMD3(1,0,0), angle: e.x)
  }
}
