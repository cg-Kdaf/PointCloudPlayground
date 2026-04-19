//
//  PointCloudPlaygroundApp.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 22/02/2026.
//

import SwiftUI
import SwiftData

@main
struct PointCloudPlaygroundApp: App {
//  private var sharedModelContainer: ModelContainer = {
//    let schema = Schema([
//      PointCloudEntry.self,
//    ])
//    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//
//    do {
//      return try ModelContainer(for: schema, configurations: [modelConfiguration])
//    } catch {
//      fatalError("Could not create ModelContainer: \(error)")
//    }
//  }()
//
  @StateObject private var scene = PlaygroundScene()
  @State private var cameraId: UUID?
  
  var body: some Scene {
    WindowGroup {
      ContentView(scene: scene, cameraIdBinding: $cameraId)
    }
//    .modelContainer(sharedModelContainer)

    Window("Camera details", id: "camera") {
      if let cameraId = cameraId {
        CameraOverlayView(scene: scene, cameraId: cameraId)
      } else {
        Text("No camera selected")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(nsColor: .controlBackgroundColor))
      }
    }
    .keyboardShortcut("1")
  }
}
