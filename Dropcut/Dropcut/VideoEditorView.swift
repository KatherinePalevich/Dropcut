//
//  VideoEditorView.swift
//  Dropcut
//

import SwiftUI
import AVKit
import Photos
import AVFoundation
import SwiftData
import UniformTypeIdentifiers

struct VideoEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @Binding var selectedVideos: [VideoClip]
    @Binding var editingProject: Project?
    @Binding var customInstructions: String
    
    @State private var activePlayer: AVPlayer? = nil
    @State private var selectedClip: VideoClip? = nil
    @State private var draggingClip: VideoClip? = nil
    
    @State private var isExporting = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Video Preview Area
            ZStack {
                Color.black
                
                if let player = activePlayer {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                } else {
                    // Mock preview image/shape
                    VStack(spacing: 12) {
                        Image(systemName: "play.slash.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        
                        Text("No Video Selected")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .cornerRadius(12)
            .padding()
            .onAppear {
                if let first = selectedVideos.first {
                    selectedClip = first
                    let player = AVPlayer(url: first.url)
                    
                    // Loop player play
                    NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: player.currentItem,
                        queue: .main
                    ) { _ in
                        player.seek(to: .zero)
                        player.play()
                    }
                    activePlayer = player
                    player.play()
                }
            }
            .onDisappear {
                activePlayer?.pause()
                activePlayer = nil
            }
            
            // Timeline Tracks
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    // Video Track
                    HStack(spacing: 8) {
                        Image(systemName: "film")
                            .foregroundColor(.accentColor)
                            .padding(.leading, 8)
                        
                        if selectedVideos.isEmpty {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 200, height: 40)
                                .overlay(
                                    Text("No clips imported")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                )
                        } else {
                            ForEach(selectedVideos) { video in
                                TimelineClipView(
                                    video: video,
                                    isSelected: selectedClip == video
                                ) {
                                    activePlayer?.pause()
                                    selectedClip = video
                                    let player = AVPlayer(url: video.url)
                                    NotificationCenter.default.addObserver(
                                        forName: .AVPlayerItemDidPlayToEndTime,
                                        object: player.currentItem,
                                        queue: .main
                                    ) { _ in
                                        player.seek(to: .zero)
                                        player.play()
                                    }
                                    activePlayer = player
                                    player.play()
                                }
                                .onDrag {
                                    self.draggingClip = video
                                    return NSItemProvider(object: video.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: ClipDropDelegate(
                                    item: video,
                                    items: $selectedVideos,
                                    draggedItem: $draggingClip
                                ))
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            
            Spacer()
            
            // Download Button
            Button(action: {
                exportAndUploadVideo()
            }) {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.headline)
                    }
                    
                    Text(isExporting ? "Combining & Saving..." : "Download Video")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    selectedVideos.isEmpty || isExporting
                        ? AnyView(Color.gray.opacity(0.5))
                        : AnyView(LinearGradient(gradient: Gradient(colors: [.accentColor, .purple]), startPoint: .leading, endPoint: .trailing))
                )
                .cornerRadius(16)
                .shadow(color: !selectedVideos.isEmpty && !isExporting ? .accentColor.opacity(0.4) : .clear, radius: 10, x: 0, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(selectedVideos.isEmpty || isExporting)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("Editor")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false) // Let native back button show
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if alertTitle == "Success!" {
                    navigationPath = NavigationPath()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // Combine selected video clips and save to device Photos Library
    private func exportAndUploadVideo() {
        guard !selectedVideos.isEmpty else { return }
        isExporting = true
        
        Task {
            do {
                let composition = AVMutableComposition()
                guard let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    throw NSError(domain: "Dropcut", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create video composition track."])
                }
                
                guard let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    throw NSError(domain: "Dropcut", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create audio composition track."])
                }
                
                var currentTime = CMTime.zero
                var isFirst = true
                
                for clip in selectedVideos {
                    let asset = AVAsset(url: clip.url)
                    
                    // Load tracks and duration asynchronously
                    let videoTracks = try await asset.loadTracks(withMediaType: .video)
                    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                    let duration = try await asset.load(.duration)
                    
                    guard let assetVideoTrack = videoTracks.first else { continue }
                    
                    // Apply preferredTransform from the first video track to preserve correct rotation
                    if isFirst {
                        let transform = try await assetVideoTrack.load(.preferredTransform)
                        compositionVideoTrack.preferredTransform = transform
                        isFirst = false
                    }
                    
                    let timeRange = CMTimeRange(start: .zero, duration: duration)
                    try compositionVideoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
                    
                    if let assetAudioTrack = audioTracks.first {
                        try compositionAudioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                    }
                    
                    currentTime = CMTimeAdd(currentTime, duration)
                }
                
                guard currentTime.seconds > 0 else {
                    throw NSError(domain: "Dropcut", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video content found to export."])
                }
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")
                
                guard let exportSession = AVAssetExportSession(
                    asset: composition,
                    presetName: AVAssetExportPresetHighestQuality
                ) else {
                    throw NSError(domain: "Dropcut", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create export session."])
                }
                
                exportSession.outputURL = tempURL
                exportSession.outputFileType = .mp4
                exportSession.shouldOptimizeForNetworkUse = true
                
                await exportSession.export()
                
                if exportSession.status == .completed {
                    // Check and request Photo Library authorization
                    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                    guard status == .authorized || status == .limited else {
                        throw NSError(domain: "Dropcut", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photo Library access denied. Please enable it in Settings."])
                    }
                    
                    try await PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
                    }
                    
                    // Copy video to permanent directory
                    let permanentFileName = try Project.saveVideoToPermanentDirectory(from: tempURL)
                    
                    // Copy individual clips to permanent directory
                    var finalClipPaths: [String] = []
                    var finalClipTitles: [String] = []
                    
                    for clip in selectedVideos {
                        let relativePath = try Project.saveClipToPermanentDirectory(from: clip.url)
                        finalClipPaths.append(relativePath)
                        finalClipTitles.append(clip.title)
                    }
                    
                    await MainActor.run {
                        let fileManager = FileManager.default
                        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        
                        if let existingProject = editingProject {
                            // Update existing project
                            // 1. Delete old combined video from disk
                            if let oldVideoPath = existingProject.videoPath {
                                let oldVideoURL = documentsURL.appendingPathComponent(oldVideoPath)
                                try? fileManager.removeItem(at: oldVideoURL)
                            }
                            
                            // 2. Identify clip files that are no longer used and delete them
                            let oldClipPaths = existingProject.safeClipPaths
                            for oldPath in oldClipPaths {
                                if !finalClipPaths.contains(oldPath) {
                                    let oldClipURL = documentsURL.appendingPathComponent(oldPath)
                                    try? fileManager.removeItem(at: oldClipURL)
                                }
                            }
                            
                            // 3. Update project details
                            existingProject.videoPath = permanentFileName
                            existingProject.clipPaths = finalClipPaths
                            existingProject.clipTitles = finalClipTitles
                            existingProject.timestamp = Date()
                            
                            editingProject = nil // Reset editing project binding
                        } else {
                            // Create new project
                            let allProjects = (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
                            let newName = Project.nextProjectName(existingProjects: allProjects)
                            let newProject = Project(
                                name: newName,
                                videoPath: permanentFileName,
                                clipPaths: finalClipPaths,
                                clipTitles: finalClipTitles,
                                instructions: customInstructions.isEmpty ? nil : customInstructions
                            )
                            modelContext.insert(newProject)
                        }
                        
                        try? modelContext.save()
                        
                        isExporting = false
                        alertTitle = "Success!"
                        alertMessage = "Your video has been combined and saved to your Photo Library."
                        showAlert = true
                    }
                } else {
                    let errorDesc = exportSession.error?.localizedDescription ?? "Export failed with an unknown error."
                    throw NSError(domain: "Dropcut", code: -1, userInfo: [NSLocalizedDescriptionKey: errorDesc])
                }
                
            } catch {
                await MainActor.run {
                    isExporting = false
                    alertTitle = "Upload Failed"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Timeline Clip View
struct TimelineClipView: View {
    let video: VideoClip
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(gradient: Gradient(colors: [.accentColor, .purple]), startPoint: .leading, endPoint: .trailing))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.secondarySystemBackground))
                }
                
                HStack {
                    Image(systemName: "video.fill")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(video.title)
                        .font(.caption)
                        .bold()
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
            }
            .frame(width: 140, height: 40)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    NavigationStack {
        VideoEditorView(
            navigationPath: .constant(NavigationPath()),
            selectedVideos: .constant([
                VideoClip(url: URL(string: "https://developer.apple.com/videos/mp4/subtitles_sample.mp4")!, title: "Intro")
            ]),
            editingProject: .constant(nil),
            customInstructions: .constant("Sample instructions")
        )
    }
}

// MARK: - Drag and Drop Delegate
struct ClipDropDelegate: DropDelegate {
    let item: VideoClip
    @Binding var items: [VideoClip]
    @Binding var draggedItem: VideoClip?
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        if draggedItem != item {
            let from = items.firstIndex(of: draggedItem)
            let to = items.firstIndex(of: item)
            if let from = from, let to = to {
                withAnimation {
                    items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                }
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}


