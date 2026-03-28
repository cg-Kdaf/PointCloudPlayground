//
//  ContentView.swift
//  PointCloudPlayground
//
//  Created by Colin Marmond on 22/02/2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
import simd

struct ContentView: View {
  @State private var selectedPath: String?
  @StateObject private var scene = PlaygroundScene()
  @State private var isLazImporterPresented = false
  @State private var isColmapFolderPresented = false
  @State private var transformReferenceMode: TransformReferenceMode = .objectCenter
  
  private let lazType = UTType(filenameExtension: "laz") ?? .data
  private let jsonType = UTType(filenameExtension: "json") ?? .data
  
  var body: some View {
    HStack(spacing: 0) {
      VStack(spacing: 0) {
        // Top section: Import buttons
        VStack(alignment: .leading, spacing: 8) {
          Text("Import")
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.top, 12)
          
          HStack(spacing: 8) {
            Button(action: { isLazImporterPresented = true }) {
              Label("LAZ File", systemImage: "doc.badge.plus")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .fileImporter(isPresented: $isLazImporterPresented,
                          allowedContentTypes: [lazType],
                          allowsMultipleSelection: false,
                          onCompletion: handleImportResult)
            
            Button(action: { isColmapFolderPresented = true }) {
              Label("COLMAP", systemImage: "folder.badge.plus")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .fileImporter(isPresented: $isColmapFolderPresented,
                          allowedContentTypes: [.folder],
                          allowsMultipleSelection: false,
                          onCompletion: handleImportResult)

            Button(action: { StartupImporter.run(scene: scene) }) {
              Label("Startup Import", systemImage: "play.circle")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
          }
          .padding(.horizontal, 12)
          .padding(.bottom, 12)
        }
        
        Divider()
        
        // Transform tool panel
        TransformToolPanel(referenceMode: $transformReferenceMode)
        
        Divider()
        
        // Main outliner
        SceneOutlinerView(scene: scene)
      }
      .frame(width: 320)
      .background(Color(nsColor: .controlBackgroundColor))
      
      Divider()
      
      MetalView(scene: scene, transformReferenceMode: $transformReferenceMode)
    }
  }
  
  private func handleImportResult(_ result: Result<[URL], Error>) {
    guard case let .success(urls) = result,
          let url = urls.first else {
      return
    }
    
    let path = url.path
    
    // Add to scene
    if path.hasSuffix(".laz") || path.hasSuffix(".las") {
      scene.addCloud(filepath: path)
    } else {
      scene.addColmapScene(fromDirectory: path)
    }
  }
}

#Preview {
  ContentView()
}
