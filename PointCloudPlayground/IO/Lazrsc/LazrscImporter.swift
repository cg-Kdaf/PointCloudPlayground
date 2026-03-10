//
//  LazrscImporter.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 09/03/2026.
//

import Lazrsc
import Foundation

final class LazrscImporter {
  func importFrom(filePath path: String) -> PointCloudDataBlock? {
    
    // 1. Open the file
    guard let lasFile = path.withCString({ las_file_open($0) }) else {
      print("Import failed: Could not open file at \(path)")
      return nil
    }
    // Swift will automatically call this when the function exits (success or fail!)
    defer { las_file_close(lasFile) }
    
    let header = lasFile.pointee.header
    
    // 2. Find the LASZIP VLR
    guard let vlrPtr = find_laszip_vlr(&lasFile.pointee.header) else {
      print("Import failed: No laszip VLR found")
      return nil
    }
    let vlr = vlrPtr.pointee
    
    // 3. Setup the Decompressor Parameters
    var params = Lazrs_DecompressorParams()
    if let mutableData = vlr.data {
      params.laszip_vlr.data = UnsafePointer(mutableData)
    }
    params.laszip_vlr.len = UInt(vlr.record_len)
    params.source_type = LAZRS_SOURCE_CFILE
    params.source.file = lasFile.pointee.file
    params.source_offset = UInt64(header.offset_to_point_data)
    
    // 4. Create the Decompressor
    var decompressor: OpaquePointer?
    let preferParallel: Bool = true
    let result = lazrs_decompressor_new(params, preferParallel, &decompressor)
    
    guard result == LAZRS_OK, let decompressor = decompressor else {
      print("Import failed: Failed to create decompressor")
      return nil
    }
    defer { lazrs_decompressor_delete(decompressor) }
    
    // --- TODO: Uncomment this once you add min/max/scale/offset to your C las_header! ---
    /*
     var center = SIMD4<Double>(
     (header.max_x + header.min_x) / 2.0,
     (header.max_y + header.min_y) / 2.0,
     (header.max_z + header.min_z) / 2.0,
     0.0
     )
     
     let boundingBox = BoundingBox(
     max_x: Float(header.max_x - center.x),
     min_x: Float(header.min_x - center.x),
     // ... add the rest
     )
     */
    
    // Fallbacks until the C struct is fixed
    let center = SIMD4<Double>.zero
    let boundingBox: BoundingBox? = nil
    
    // 5. Allocate memory for a single point record
    let pointSize = Int(header.point_size)
    var pointData = [UInt8](repeating: 0, count: pointSize)
    
    var points: [PointVertex] = []
    let pointsCount = Int(header.point_count)
    points.reserveCapacity(pointsCount)
    var point_id = 0
    
    // 6. Decompression Loop
    var firstPoint: PointVertex = .init(position: .zero)
    for _ in 0..<pointsCount {
      
      // Decompress one point into our byte buffer
      let decompressResult = pointData.withUnsafeMutableBytes { ptr in
        lazrs_decompressor_decompress_one(decompressor, ptr.baseAddress, pointSize)
      }
      
      if decompressResult != LAZRS_OK {
        print("Warning: Error during decompression, stopping early.")
        break
      }
      // Extact the raw X, Y, Z integers from the first 12 bytes of the point data
      let rawX = pointData.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Int32.self) }
      let rawY = pointData.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }
      let rawZ = pointData.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Int32.self) }
      
      // --- TODO: Apply scale and offset once added to C las_header ---
      // let x = Float(Double(rawX) * header.x_scale_factor + header.x_offset - center.x)
      if point_id == 0 {
        let position = SIMD4<Float>(Float(rawX), Float(rawY), Float(rawZ), 0.0)
        firstPoint = PointVertex(position: position)
      }
      let x = Float(rawX) // Dummy value
      let y = Float(rawY) // Dummy value
      let z = Float(rawZ) // Dummy value
      
      let position = SIMD4<Float>(x, y, z, 0.0)
      points.append(PointVertex(position: position - firstPoint.position))
      point_id += 1
    }
    
    return PointCloudDataBlock(
      points: points,
      pointsCount: point_id,
      center: center,
      boundingBox: boundingBox,
      filePath: path
    )
  }
}
