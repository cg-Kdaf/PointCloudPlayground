//
//  pointCloudImporter.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 23/02/2026.
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

struct laszip_point_shader {
  let position: SIMD4<Float>
}

final class PointCloudFile {
  var header: laszip_header? = nil
  var points: [laszip_point_shader]? = nil
  var pointsCount: Int = 0
  private(set) var center: SIMD4<Double> = .zero
  
  private var handle: laszip_POINTER?
  private var isReaderOpen = false
  
  init() {
  }
  
  func createFrom(filePath: String) -> Bool {
    do {
      var pointer: laszip_POINTER?
      guard laszip_create(&pointer) == 0, pointer != nil else {
        throw LAZImportError.message("laszip_create failed")
      }
      handle = pointer
      
      let url = URL(fileURLWithPath: filePath)
      var point_id = 0
      try readFile(fileURL: url,
                   forheader: { header_ in
        header = header_
        points = .init()
        pointsCount = Int(header!.extended_number_of_point_records)
        points!.reserveCapacity(pointsCount)
        center.x = header!.max_x + header!.min_x
        center.y = header!.max_y + header!.min_y
        center.z = header!.max_z + header!.min_z
        center /= 2.0
      }, foreachpoint: { p in
        let x = Float(Double(p.X) * header!.x_scale_factor + header!.x_offset - center.x)
        let y = Float(Double(p.Y) * header!.y_scale_factor + header!.y_offset - center.y)
        let z = Float(Double(p.Z) * header!.z_scale_factor + header!.z_offset - center.z)
        let position = SIMD4<Float>(x, y, z, 0.0)
        points!.append(laszip_point_shader.init(position: position))
        if point_id > 7000000 {
          throw LAZImportError.message("Stop here")
        }
        point_id += 1
      })
      return true
    } catch {
      print("Import failed: \(error.localizedDescription)")
    }
    return false
  }
  
  deinit {
    // Can happen only if the object is destroyed while opening the file
    if isReaderOpen, let handle {
      _ = laszip_close_reader(handle)
    }
    if let handle {
      _ = laszip_destroy(handle)
    }
  }
  
  func readFile(fileURL: URL, forheader: (laszip_header) throws -> Void, foreachpoint: (laszip_point) throws -> Void) throws {
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
    
    let header_ = headerPointer.pointee
    try forheader(header_)
    
    let totalPointCount: Int
    if header_.extended_number_of_point_records > 0 {
      totalPointCount = Int(header_.extended_number_of_point_records)
    } else {
      totalPointCount = Int(header_.number_of_point_records)
    }
    
    let pointsToRead = max(0, totalPointCount)
    
    for index in 0..<pointsToRead {
      let readStatus = laszip_read_point(handle)
      guard readStatus == 0 else {
        throw LAZImportError.message("laszip_read_point failed at index \(index): \(lastErrorMessage())")
      }
      
      let point = pointPointer.pointee
      do {
        try foreachpoint(point)
      } catch {
        break
      }
    }
    
    _ = laszip_close_reader(handle)
    isReaderOpen = false
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
}
