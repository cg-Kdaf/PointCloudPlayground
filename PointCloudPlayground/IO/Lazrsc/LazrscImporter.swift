//
//  LazrscImporter.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 09/03/2026.
//

import Lazrsc
import Laszip
import Foundation

final class LazrscImporter {
  
  func importFrom(filePath path: String) -> PointCloudDataBlock? {
    
    // Measure time
    let clockStartBegining = ContinuousClock().now
    // ==========================================
    // STEP 1: Parse Metadata using LASzip
    // ==========================================
    var laszipHandle: laszip_POINTER?
    guard laszip_create(&laszipHandle) == 0, let handle = laszipHandle else {
      print("Import failed: laszip_create failed")
      return nil
    }
    defer { laszip_destroy(handle) }
    
    var isCompressed: laszip_BOOL = 0
    let openStatus = path.withCString { laszip_open_reader(handle, $0, &isCompressed) }
    
    guard openStatus == 0 else {
      print("Import failed: laszip_open_reader failed")
      return nil
    }
    
    var headerPointer: UnsafeMutablePointer<laszip_header_struct>?
    guard laszip_get_header_pointer(handle, &headerPointer) == 0, let header = headerPointer?.pointee else {
      print("Import failed: laszip_get_header_pointer failed")
      laszip_close_reader(handle)
      return nil
    }
    
    // Grab the scale, offset, and bounding box from the virtualized header
    let pointsCount = Int(header.extended_number_of_point_records > 0 ? header.extended_number_of_point_records : UInt64(header.number_of_point_records))
    let pointSize = Int(header.point_data_record_length)
    
    let center = SIMD4<Double>(
      (header.max_x + header.min_x) / 2.0,
      (header.max_y + header.min_y) / 2.0,
      (header.max_z + header.min_z) / 2.0,
      0.0
    )
    
    let boundingBox = BoundingBox(
      max_x: Float(header.max_x - center.x),
      min_x: Float(header.min_x - center.x),
      max_y: Float(header.max_y - center.y),
      min_y: Float(header.min_y - center.y),
      max_z: Float(header.max_z - center.z),
      min_z: Float(header.min_z - center.z)
    )
    
    // Close LASzip so it releases the file lock!
    laszip_close_reader(handle)
    
    // ==========================================
    // STEP 2: Extract the REAL Binary Offsets
    // ==========================================
    guard let file = path.withCString({ fopen($0, "rb") }) else {
      print("Import failed: Could not open C file pointer for laz-rs")
      return nil
    }
    defer { fclose(file) }
    
    // Start reading exactly at byte 94 (Header Size)
    fseek(file, 94, SEEK_SET)
    
    // We only need 10 bytes: Size (2) + Offset (4) + VLR Count (4)
    var rawHeaderData = [UInt8](repeating: 0, count: 10)
    rawHeaderData.withUnsafeMutableBytes { ptr in
      fread(ptr.baseAddress, 1, 10, file)
    }
    
    // Parse the true binary values from the 10-byte buffer using loadUnaligned
    let rawHeaderSize = rawHeaderData.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt16.self) }
    let rawOffsetToPoints = rawHeaderData.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 2, as: UInt32.self) }
    let rawNumVLRs = rawHeaderData.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 6, as: UInt32.self) }
    
    // ==========================================
    // STEP 3: Find the LASzip VLR manually
    // ==========================================
    // Seek exactly to the end of the public header block
    fseek(file, Int(rawHeaderSize), SEEK_SET)
    
    var vlrFound = false
    var vlrData = [UInt8]()
    
    for _ in 0..<rawNumVLRs {
      var vlrHeader = [UInt8](repeating: 0, count: 54)
      vlrHeader.withUnsafeMutableBytes { fread($0.baseAddress, 1, 54, file) }
      
      let recordId = vlrHeader.withUnsafeBytes { $0.load(fromByteOffset: 18, as: UInt16.self) }
      let recordLen = vlrHeader.withUnsafeBytes { $0.load(fromByteOffset: 20, as: UInt16.self) }
      
      if recordId == 22204 {
        // We found the LASzip VLR! Grab its data payload.
        vlrData = [UInt8](repeating: 0, count: Int(recordLen))
        vlrData.withUnsafeMutableBytes { fread($0.baseAddress, 1, Int(recordLen), file) }
        vlrFound = true
        break
      } else {
        // Not the one we want. Skip over its data payload to the next VLR header.
        fseek(file, Int(recordLen), SEEK_CUR)
      }
    }
    
    guard vlrFound else {
      print("Import failed: No LASzip VLR (Record 22204) found in file")
      return nil
    }
    
    // ==========================================
    // STEP 4: Decompress and Parse in Parallel Chunks
    // ==========================================
    
    fseek(file, Int(rawOffsetToPoints), SEEK_SET)
    
    var points: [PointVertex] = [PointVertex](repeating: .init(position: .zero), count: pointsCount)
    
    var pointDataBuffer = [UInt8](repeating: 0, count: pointsCount * pointSize)
    
    vlrData.withUnsafeBytes { vlrPtr in
      
      var params = Lazrs_DecompressorParams()
      params.laszip_vlr.data = vlrPtr.baseAddress?.assumingMemoryBound(to: UInt8.self)
      params.laszip_vlr.len = UInt(vlrData.count)
      params.source_type = LAZRS_SOURCE_CFILE
      params.source.file = file
      params.source_offset = UInt64(rawOffsetToPoints)
      
      var decompressor: OpaquePointer?
      
      // USE THE DEDICATED PARALLEL DECOMPRESSOR API
      let result = lazrs_par_laszip_decompressor_new(params, &decompressor)
      
      guard result == LAZRS_OK, let validDecompressor = decompressor else {
        print("Import failed: lazrs_par_laszip_decompressor_new failed")
        return
      }
      // USE THE DEDICATED PARALLEL DELETE FUNCTION
      defer { lazrs_par_laszip_decompressor_delete(validDecompressor) }
      
      // Measure time
      let clockStart = ContinuousClock().now
      let readSuccess = pointDataBuffer.withUnsafeMutableBytes { ptr -> Bool in
        return lazrs_par_laszip_decompressor_decompress_many(validDecompressor,
                                                             ptr.baseAddress!,
                                                             pointSize * pointsCount) == LAZRS_OK
      }
      
      var time_result = clockStart.duration(to: .now)
      print("The import in swift structure took \(time_result), or the equivalent of \(Double(pointsCount) / Double(time_result.attoseconds) * 1e12) milion points per second.")
      let clockStartSwiftMapping = ContinuousClock().now
      
      if !readSuccess {
        print("Warning: Decompression failed at chunk. Stopping early.")
        return
      }
      
      pointDataBuffer.withUnsafeBytes { bufferPtr in
        let baseAddress = bufferPtr.baseAddress!
        
        points.withUnsafeMutableBufferPointer { parsedBuffer in
          // 1. Grab the raw mutable pointer to bypass Swift's exclusivity checker
          let parsedPtr = parsedBuffer.baseAddress!
          
          // 2. Execute parallel loop across all P-Cores and E-Cores
          DispatchQueue.concurrentPerform(iterations: pointsCount) { i in
            let pointOffset = i * pointSize
            let rawX = baseAddress.loadUnaligned(fromByteOffset: pointOffset + 0, as: Int32.self)
            let rawY = baseAddress.loadUnaligned(fromByteOffset: pointOffset + 4, as: Int32.self)
            let rawZ = baseAddress.loadUnaligned(fromByteOffset: pointOffset + 8, as: Int32.self)
            
            let x = Float(Double(rawX) * header.x_scale_factor + header.x_offset - center.x)
            let y = Float(Double(rawY) * header.y_scale_factor + header.y_offset - center.y)
            let z = Float(Double(rawZ) * header.z_scale_factor + header.z_offset - center.z)
            
            // 3. Thread-Safe Write: Advance the raw pointer exactly `i` steps
            // and write the struct directly to memory. No overlapping writes!
            parsedPtr.advanced(by: i).pointee = PointVertex(position: SIMD4<Float>(x, y, z, 0.0))
          }
        }
      }
      
      
      time_result = clockStartSwiftMapping.duration(to: .now)
      print("The import in swift structure took \(time_result), or the equivalent of \(Double(pointsCount) / Double(time_result.attoseconds) * 1e12) milion points per second.")
    }
    
    let totaltime_result = clockStartBegining.duration(to: .now)
    print("The import in swift structure took \(totaltime_result), or the equivalent of \(Double(pointsCount) / Double(totaltime_result.attoseconds) * 1e12) milion points per second.")
    return PointCloudDataBlock(
      points: points,
      pointsCount: pointsCount,
      center: center,
      boundingBox: boundingBox,
      filePath: path
    )
  }
}
