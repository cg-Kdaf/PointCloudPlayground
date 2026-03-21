//
//  LaszipImporter.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 07/03/2026.
//

import Laszip
import Foundation

enum LAZImportError: Error, LocalizedError {
  case message(String)
  
  var errorDescription: String? {
    switch self {
    case let .message(message):
      return message
    }
  }
}

final class LaszipImporter {
  
  private var handle: laszip_POINTER?
  private var isReaderOpen = false
  
  func importFrom(filePath: String) -> PointCloudDataBlock? {
    // Measure time
    let clockStartBegining = ContinuousClock().now
    do {
      var pointer: laszip_POINTER?
      guard laszip_create(&pointer) == 0, pointer != nil else {
        throw LAZImportError.message("laszip_create failed")
      }
      handle = pointer
      
      let url = URL(fileURLWithPath: filePath)
      var points: [PointVertex] = []
      var pointsCount: Int = 0
      var center: SIMD4<Double> = .zero
      var boundingBox: BoundingBox?
      var point_id = 0
      
      try readFile(fileURL: url,
                   forheader: { header in
        pointsCount = Int(header.extended_number_of_point_records)
        points.reserveCapacity(pointsCount)
        center.x = header.max_x + header.min_x
        center.y = header.max_y + header.min_y
        center.z = header.max_z + header.min_z
        center /= 2.0
        boundingBox = BoundingBox(max_x: Float(header.max_x - center.x),
                                  min_x: Float(header.min_x - center.x),
                                  max_y: Float(header.max_y - center.y),
                                  min_y: Float(header.min_y - center.y),
                                  max_z: Float(header.max_z - center.z),
                                  min_z: Float(header.min_z - center.z))
      }, foreachpoint: { (p, header) in
        let x = Float(Double(p.X) * header.x_scale_factor + header.x_offset - center.x)
        let y = Float(Double(p.Y) * header.y_scale_factor + header.y_offset - center.y)
        let z = Float(Double(p.Z) * header.z_scale_factor + header.z_offset - center.z)
        let position = SIMD4<Float>(x, y, z, 0.0)
        points.append(PointVertex(position: position))
        point_id += 1
      })
      
      cleanup()
      let totaltime_result = clockStartBegining.duration(to: .now)
      print("The import in swift structure took \(totaltime_result), or the equivalent of \(Double(pointsCount) / Double(totaltime_result.attoseconds) * 1e12) milion points per second.")
      return PointCloudDataBlock(points: points, pointsCount: pointsCount, center: center, boundingBox: boundingBox, filePath: filePath)
    } catch {
      print("Import failed: \(error.localizedDescription)")
      cleanup()
    }
    return nil
  }
  
  private func readFile(fileURL: URL,
                        forheader: (laszip_header) throws -> Void,
                        foreachpoint: (laszip_point, laszip_header) throws -> Void) throws {
    guard let handle else {
      throw LAZImportError.message("LASzip handle is nil")
    }
    
    var isCompressed: laszip_BOOL = 0
    let openStatus = fileURL.path.withCString { fileName in
      laszip_open_reader(handle, fileName, &isCompressed)
    }
    guard openStatus == 0 else {
      throw LAZImportError.message("laszip_open_reader failed: \(lastErrorMessage())")
    }
    isReaderOpen = true
    
    var headerPointer: UnsafeMutablePointer<laszip_header_struct>?
    guard laszip_get_header_pointer(handle, &headerPointer) == 0,
          let headerPointer else {
      throw LAZImportError.message("laszip_get_header_pointer failed: \(lastErrorMessage())")
    }
    
    var pointPointer: UnsafeMutablePointer<laszip_point_struct>?
    guard laszip_get_point_pointer(handle, &pointPointer) == 0,
          let pointPointer else {
      throw LAZImportError.message("laszip_get_point_pointer failed: \(lastErrorMessage())")
    }
    
    let header = headerPointer.pointee
    try forheader(header)
    
    let totalPointCount: Int
    if header.extended_number_of_point_records > 0 {
      totalPointCount = Int(header.extended_number_of_point_records)
    } else {
      totalPointCount = Int(header.number_of_point_records)
    }
    
    let pointsToRead = max(0, totalPointCount)
    
    for index in 0..<pointsToRead {
      let readStatus = laszip_read_point(handle)
      guard readStatus == 0 else {
        throw LAZImportError.message("laszip_read_point failed at index \(index): \(lastErrorMessage())")
      }
      
      let point = pointPointer.pointee
      do {
        try foreachpoint(point, header)
      } catch {
        break
      }
    }
    
    _ = laszip_close_reader(handle)
    isReaderOpen = false
  }
  
  private func cleanup() {
    if isReaderOpen, let handle {
      _ = laszip_close_reader(handle)
      isReaderOpen = false
    }
    if let handle {
      _ = laszip_destroy(handle)
    }
    handle = nil
  }
  
  private func lastErrorMessage() -> String {
    guard let handle else { return "Unknown LASzip error" }
    var errorPointer: UnsafeMutablePointer<laszip_CHAR>?
    let status = laszip_get_error(handle, &errorPointer)
    guard status == 0, let errorPointer else {
      return "Unknown LASzip error"
    }
    return String(cString: errorPointer)
  }
  
  deinit {
    cleanup()
  }
}
