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
  @State private var displayedPaths: [String] = []
  @State private var isImporterPresented = false
  private let scene = PlaygroundScene()
  
  private let lazType = UTType(filenameExtension: "laz") ?? .data
  
  private var selectedCloud: PointCloudEntry? {
    pointClouds.first { $0.filePath == selectedPath }
  }
  
  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Point Clouds")
          .font(.headline)
        
        Picker("Available Files", selection: $selectedPath) {
          Text("None")
            .tag(Optional<String>.none)
          ForEach(pointClouds, id: \.persistentModelID) { cloud in
            Text(URL(fileURLWithPath: cloud.filePath).lastPathComponent)
              .tag(Optional(cloud.filePath))
          }
        }
        
        if let selectedCloud {
          Button("Add to Displayed") {
            let path = selectedCloud.filePath
            guard !displayedPaths.contains(path) else {
              return
            }
            displayedPaths.append(path)
            scene.addCloud(filepath: path)
          }
          
          Button("Remove", role: .destructive) {
            if displayedPaths.contains(selectedCloud.filePath) {
              displayedPaths.removeAll { $0 == selectedCloud.filePath }
              scene.removeCloud(filepath: selectedCloud.filePath)
            }
            modelContext.delete(selectedCloud)
            selectedPath = nil
          }
        }
        
        if !displayedPaths.isEmpty {
          Divider()
          
          Text("Displayed in Session")
            .font(.subheadline)
          
          ForEach(displayedPaths, id: \.self) { path in
            HStack {
              Text(URL(fileURLWithPath: path).lastPathComponent)
                .lineLimit(1)
              Spacer()
              Button("Remove") {
                displayedPaths.removeAll { $0 == path }
                scene.removeCloud(filepath: path)
              }
            }
          }
        }
        
        Divider()
        
        Button("Add .laz file") {
          isImporterPresented = true
        }
        
        Spacer()
      }
      .padding(12)
      .frame(width: 300)
      
      Divider()
      
      MetalView(scene: scene)
    }
    .fileImporter(isPresented: $isImporterPresented,
                  allowedContentTypes: [lazType],
                  allowsMultipleSelection: false,
                  onCompletion: handleImportResult)
    .onAppear {
      if selectedPath == nil {
        selectedPath = pointClouds.first?.filePath
      }
    }
  }
  
  private func handleImportResult(_ result: Result<[URL], Error>) {
    guard case let .success(urls) = result,
          let url = urls.first else {
      return
    }
    
    if let existing = pointClouds.first(where: { $0.filePath == url.path }) {
      selectedPath = existing.filePath
      return
    }
    
    let entry = PointCloudEntry(filePath: url.path)
    modelContext.insert(entry)
    selectedPath = entry.filePath
  }
}

#Preview {
  ContentView()
}
