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
  @Environment(\.openWindow) var openWindow
  
  var body: some Scene {
    WindowGroup {
      ContentView(scene: scene, cameraIdBinding: $cameraId)
    }
    .commands {
      CommandMenu("Tools") {
        Button("Run ICP on Selection") {
          openWindow(id: "icp_tool")
        }
        .keyboardShortcut("I", modifiers: [.command, .shift])
      }
    }
//    .modelContainer(sharedModelContainer)

    Window("ICP Tool", id: "icp_tool") {
      ICPToolView(scene: scene)
    }
    .restorationBehavior(.disabled)

    Window("Camera details", id: "camera") {
      if let cameraId = cameraId {
        if let obj = scene.rootGroup.object(withId: cameraId),
           let camData = obj.asCameraData,
           let intrinsics = camData.intrinsics,
           intrinsics.width > 0, intrinsics.height > 0 {
          CameraOverlayView(scene: scene, cameraId: cameraId)
        } else {
          CameraOverlayView(scene: scene, cameraId: cameraId)
        }
      } else {
        Text("No camera selected")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(nsColor: .controlBackgroundColor))
      }
    }
    .keyboardShortcut("1")
    .restorationBehavior(.disabled)
  }
}
