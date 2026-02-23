import Foundation
import simd

// Half time in seconds
fileprivate let intertiaHalfLife: Float = 0.1

struct CameraUniforms {
  var viewProjectionMatrix: simd_float4x4
}

final class OrbitCamera {
  private var aspectRatio: Float
  private var yaw: Float = 0.5
  private var pitch: Float = 0.4
  private var yaw_speed: Float = 0.0
  private var pitch_speed: Float = 0.0
  private var radius: Float = 10.0
  private var freeOrbit: Bool = false
  private let target = SIMD3<Float>(0, 0, 0)
  
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
    if (yaw_speed != 0.0 && pitch_speed != 0.0) {
      // Speed is not null, continue to make the orbit evolve
      yaw += yaw_speed * dt
      pitch += pitch_speed * dt
      
      // Exponential decay
      yaw_speed *= pow(0.5, dt / intertiaHalfLife)
      pitch_speed *= pow(0.5, dt / intertiaHalfLife)
      if (abs(yaw_speed) < 0.01) {
        yaw_speed = 0.0
      }
      if (abs(pitch_speed) < 0.01) {
        pitch_speed = 0.0
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
  
  func startInertia() {
    freeOrbit = true
  }
  
  func makeUniforms() -> CameraUniforms {
    let cameraPosition = SIMD3<Float>(
      radius * cos(pitch) * sin(yaw),
      radius * sin(pitch),
      radius * cos(pitch) * cos(yaw)
    )
    
    let projection = simd_float4x4.perspectiveFovRH(fovY: 60.0 * (.pi / 180.0),
                                                    aspect: aspectRatio,
                                                    nearZ: 0.1,
                                                    farZ: 100.0)
    let viewMatrix = simd_float4x4.lookAtRH(eye: cameraPosition,
                                            center: target,
                                            up: SIMD3<Float>(0, 1, 0))
    return CameraUniforms(viewProjectionMatrix: projection * viewMatrix)
  }
}

private extension simd_float4x4 {
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
}
