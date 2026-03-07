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

@Model
final class PointCloudEntry {
  var filePath: String
  var createdAt: Date
  
  init(filePath: String,
       createdAt: Date = .now) {
    self.filePath = filePath
    self.createdAt = createdAt
  }
}

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \PointCloudEntry.createdAt) private var pointClouds: [PointCloudEntry]
  
  @State private var selectedPath: String?
  @StateObject private var scene = PlaygroundScene()
  @State private var isLazImporterPresented = false
  @State private var isColmapFolderPresented = false
  @State private var transformReferenceMode: TransformReferenceMode = .objectCenter
  
  private let lazType = UTType(filenameExtension: "laz") ?? .data
  
  private var selectedCloud: PointCloudEntry? {
    pointClouds.first { $0.filePath == selectedPath }
  }
  
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
    
    // Check if already loaded in scene
    if scene.filePaths.contains(path) {
      return
    }
    
    // Check if already in database
    if let existing = pointClouds.first(where: { $0.filePath == path }) {
      scene.addCloud(filepath: path)
      return
    }
    
    // Add to database
    let entry = PointCloudEntry(filePath: path)
    modelContext.insert(entry)
    
    do {
      try modelContext.save()
    } catch {
      print("Failed to save database entry: \(error)")
    }
    
    // Add to scene
    scene.addCloud(filepath: path)
  }
}

#Preview {
  ContentView()
}
