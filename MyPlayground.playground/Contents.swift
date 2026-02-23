import Cocoa

var greeting = "Hello, playground"

var loader: PointCloudLoader = .init()
// Warning : this can be very expensive

func printFirstPoints(from pointBuffer: PointCloudBuffer, limit: Int = 100) {
  let pointsToRead = min(Int(pointBuffer.pointCount), limit)
  let floatCount = pointsToRead * 3
  
  pointBuffer.buffer.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
    // 1. Bind the raw memory to Floats
    let floatPointer = rawBuffer.bindMemory(to: Float.self)
    
    print("--- First \(pointsToRead) Points ---")
    
    for i in 0..<pointsToRead {
      let x = floatPointer[i * 3 + 0]
      let y = floatPointer[i * 3 + 1]
      let z = floatPointer[i * 3 + 2]
      
      print(String(format: "[%d] x: %.3f, y: %.3f, z: %.3f", i, x, y, z))
    }
  }
}

var test = loader.loadLazFile(at: "/Users/colin/Src/PointCloudPlayground/Data/LHD_FXX_0641_6847_PTS_LAMB93_IGN69.copc.laz")
printFirstPoints(from: test!)

