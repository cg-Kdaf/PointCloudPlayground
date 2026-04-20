import Foundation
import Accelerate
import simd

class ICPTool {
  
  static func runICP(source: PointCloudDataBlock, target: PointCloudDataBlock, sourceWorld: simd_float4x4, targetWorld: simd_float4x4, volumeWorldMatrix: simd_float4x4? = nil) -> simd_float4x4 {
    // Basic ICP implementation skeleton.
    var transform = matrix_identity_float4x4
    
    // We will limit points to randomly sample them for speed vs exhaustive matching.
    let sampleSize = 2000
    if source.points.isEmpty || target.points.isEmpty { return transform }
    
    var validSourcePoints = source.points
    if let volumeWorldMatrix = volumeWorldMatrix {
      let invVolumeWorld = volumeWorldMatrix.inverse
      validSourcePoints = source.points.filter { pt in
        let worldPt = sourceWorld * pt.position
        let localPt = invVolumeWorld * worldPt
        let xyz = localPt.xyz
        return xyz.x >= -1.0 && xyz.x <= 1.0 &&
               xyz.y >= -1.0 && xyz.y <= 1.0 &&
               xyz.z >= -1.0 && xyz.z <= 1.0
      }
    }
    
    if validSourcePoints.isEmpty { return transform }
    
    var srcPts = stride(from: 0, to: validSourcePoints.count, by: max(1, validSourcePoints.count / sampleSize))
      .map { (sourceWorld * validSourcePoints[$0].position).xyz }
    let tgtPts = stride(from: 0, to: target.points.count, by: max(1, target.points.count / sampleSize))
      .map { (targetWorld * target.points[$0].position).xyz }
    
    // Iterations
    for _ in 0..<15 {
      if ICPToolContext.shared.isCancelled { break }
      
      // 1. Find nearest neighbors (brute force for small sample for now, could be Kd-Tree)
      var matchedTgt = [SIMD3<Float>]()
      for s in srcPts {
        var bestDist = Float.greatestFiniteMagnitude
        var bestPt = tgtPts[0]
        for t in tgtPts {
          let d = distance_squared(s, t)
          if d < bestDist {
            bestDist = d
            bestPt = t
          }
        }
        matchedTgt.append(bestPt)
      }
      
      // 2. Compute centroids
      let cSrc = srcPts.reduce(SIMD3<Float>.zero, +) / Float(srcPts.count)
      let cTgt = matchedTgt.reduce(SIMD3<Float>.zero, +) / Float(matchedTgt.count)
      
      // 3. Compute cross covariance matrix
      var h: matrix_float3x3 = matrix_float3x3(0)
      for i in 0..<srcPts.count {
        let pSrc = srcPts[i] - cSrc
        let pTgt = matchedTgt[i] - cTgt
        h.columns.0 += pSrc * pTgt.x
        h.columns.1 += pSrc * pTgt.y
        h.columns.2 += pSrc * pTgt.z
      }
      
      // Construct components for 4x4 symmetric matrix for Horn's Method (Quaternion extraction)
      let Sxx = h.columns.0.x; let Sxy = h.columns.0.y; let Sxz = h.columns.0.z
      let Syx = h.columns.1.x; let Syy = h.columns.1.y; let Syz = h.columns.1.z
      let Szx = h.columns.2.x; let Szy = h.columns.2.y; let Szz = h.columns.2.z
      
      let N11 = Sxx + Syy + Szz
      let N12 = Syz - Szy; let N13 = Szx - Sxz; let N14 = Sxy - Syx
      let N22 = Sxx - Syy - Szz; let N23 = Sxy + Syx; let N24 = Sxz + Szx
      let N33 = -Sxx + Syy - Szz; let N34 = Syz + Szy
      let N44 = -Sxx - Syy + Szz
      
      let N = simd_float4x4(
        SIMD4<Float>(N11, N12, N13, N14),
        SIMD4<Float>(N12, N22, N23, N24),
        SIMD4<Float>(N13, N23, N33, N34),
        SIMD4<Float>(N14, N24, N34, N44)
      )
      
      // To get the max eigenvalue, a simple power iteration is enough
      var q = SIMD4<Float>(1, 0, 0, 0)
      for _ in 0..<20 {
        q = normalize(N * q)
      }
      
      let rotScale = simd_quaternion(q.w, q.x, q.y, q.z)
      let rotMatrix = simd_matrix4x4(rotScale)
      let t = cTgt - simd_make_float3(rotMatrix * simd_make_float4(cSrc, 0))
      
      var deltaTransform = matrix_identity_float4x4
      deltaTransform.columns.0 = rotMatrix.columns.0
      deltaTransform.columns.1 = rotMatrix.columns.1
      deltaTransform.columns.2 = rotMatrix.columns.2
      deltaTransform.columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
      
      transform = deltaTransform * transform
      
      // Update srcPts for next iteration
      for i in 0..<srcPts.count {
        let p = deltaTransform * simd_make_float4(srcPts[i], 1.0)
        srcPts[i] = simd_make_float3(p)
      }
    }
    
    return transform
  }
}

extension SIMD4 where Scalar == Float {
  var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}
