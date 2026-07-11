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
    @Binding var geminiPrompt: String
    
    @State private var activePlayer: AVPlayer? = nil
    @State private var selectedClip: VideoClip? = nil
    @State private var draggingClip: VideoClip? = nil
    @State private var justDroppedClipID: UUID? = nil
    
    @State private var isExporting = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @State private var isPromptExpanded = false
    @State private var isCopied = false
    
    private let pointsPerSecond: CGFloat = 40.0
    
    private var totalDuration: Double {
        selectedVideos.reduce(0.0) { $0 + $1.timelineDuration }
    }
    
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
                    playClip(first)
                }
            }
            .onDisappear {
                activePlayer?.pause()
                activePlayer = nil
            }
            
            // Timeline Area
            VStack(alignment: .leading, spacing: 0) {

                // Reorder hint — only visible when there are 2+ clips
                if selectedVideos.count > 1 {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Drag clips to reorder")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Timeline Tracks
                HStack(spacing: 0) {
                    // Fixed track headers sidebar
                    VStack(alignment: .center, spacing: 8) {
                        // Space matching height of TimelineTicksView
                        Spacer()
                            .frame(height: 24)
                        
                        Image(systemName: "film")
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 44) // matches TimelineClipView height
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    
                    // Scrollable timeline
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            if selectedVideos.isEmpty {
                                Spacer()
                                    .frame(height: 24)
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 200, height: 44)
                                    .overlay(
                                        Text("No clips imported")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    )
                            } else {
                                // Tick marks timeline ruler
                                TimelineTicksView(totalDuration: totalDuration, pointsPerSecond: pointsPerSecond)
                                
                                // Video clips row
                                HStack(spacing: 0) {
                                    ForEach(selectedVideos) { video in
                                        TimelineClipView(
                                            video: video,
                                            isSelected: selectedClip?.id == video.id,
                                            isDragging: draggingClip?.id == video.id,
                                            justDropped: justDroppedClipID == video.id,
                                            showHandle: selectedVideos.count > 1,
                                            width: CGFloat(video.timelineDuration) * pointsPerSecond,
                                            action: {
                                                playClip(video)
                                            },
                                            onTrimChanged: { newStart, newEnd in
                                                if let index = selectedVideos.firstIndex(where: { $0.id == video.id }) {
                                                    selectedVideos[index].startTime = newStart
                                                    selectedVideos[index].endTime = newEnd
                                                    
                                                    // Update the selectedClip copy to match
                                                    if selectedClip?.id == video.id {
                                                        selectedClip = selectedVideos[index]
                                                    }
                                                }
                                            },
                                            onTrimEnded: {
                                                if let index = selectedVideos.firstIndex(where: { $0.id == video.id }) {
                                                    playClip(selectedVideos[index])
                                                }
                                            },
                                            onDragProvider: {
                                                self.draggingClip = video
                                                return NSItemProvider(object: video.id.uuidString as NSString)
                                            },
                                            dropDelegate: ClipDropDelegate(
                                                item: video,
                                                items: $selectedVideos,
                                                draggedItem: $draggingClip,
                                                onDropped: { droppedID in
                                                    withAnimation(.easeInOut(duration: 0.15)) {
                                                        justDroppedClipID = droppedID
                                                    }
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                                                        withAnimation(.easeOut(duration: 0.3)) {
                                                            justDroppedClipID = nil
                                                        }
                                                    }
                                                }
                                            )
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                        .padding(.horizontal, 24) // Prevent clipping of edge text
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .animation(.easeInOut(duration: 0.2), value: selectedVideos.count)
            
            if !geminiPrompt.isEmpty {
                DisclosureGroup(
                    isExpanded: $isPromptExpanded,
                    content: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Spacer()
                                Button(action: {
                                    UIPasteboard.general.string = geminiPrompt
                                    isCopied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        isCopied = false
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                        Text(isCopied ? "Copied!" : "Copy Prompt")
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(isCopied ? .green : .accentColor)
                                }
                                .padding(.top, 4)
                            }
                            
                            ScrollView {
                                Text(geminiPrompt)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 140)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                        }
                    },
                    label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.themeSecondary)
                            Text("Gemini Prompt Debug")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                )
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            
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
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                    }
                    
                    Text(isExporting ? "Combining & Saving..." : "Save to Camera Roll")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    selectedVideos.isEmpty || isExporting
                        ? AnyView(Color.gray.opacity(0.5))
                        : AnyView(LinearGradient.themeGradient)
                )
                .cornerRadius(16)
                .shadow(color: !selectedVideos.isEmpty && !isExporting ? .themePrimary.opacity(0.4) : .clear, radius: 10, x: 0, y: 5)
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
        .task {
            for index in selectedVideos.indices {
                if selectedVideos[index].duration == nil, let url = selectedVideos[index].url {
                    let asset = AVAsset(url: url)
                    if let duration = try? await asset.load(.duration).seconds {
                        await MainActor.run {
                            selectedVideos[index].duration = duration
                        }
                    }
                }
            }
        }
    }
    
    private func createPlayer(for clip: VideoClip) async -> AVPlayer? {
        guard let url = clip.url else { return nil }
        let asset = AVAsset(url: url)
        
        let start = clip.startTime ?? 0.0
        let end: Double
        if let e = clip.endTime {
            end = e
        } else {
            let duration = (try? await asset.load(.duration)) ?? .zero
            end = duration.seconds
        }
        
        let composition = AVMutableComposition()
        if let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            do {
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                if let firstVideo = videoTracks.first {
                    let transform = try? await firstVideo.load(.preferredTransform)
                    videoTrack.preferredTransform = transform ?? .identity
                    let startCM = CMTime(seconds: start, preferredTimescale: 600)
                    let durationCM = CMTime(seconds: max(0.1, end - start), preferredTimescale: 600)
                    try videoTrack.insertTimeRange(CMTimeRange(start: startCM, duration: durationCM), of: firstVideo, at: .zero)
                }
                
                // Add optional audio track if present
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                if let firstAudio = audioTracks.first,
                   let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    let startCM = CMTime(seconds: start, preferredTimescale: 600)
                    let durationCM = CMTime(seconds: max(0.1, end - start), preferredTimescale: 600)
                    try audioTrack.insertTimeRange(CMTimeRange(start: startCM, duration: durationCM), of: firstAudio, at: .zero)
                }
                
                let playerItem = AVPlayerItem(asset: composition)
                return AVPlayer(playerItem: playerItem)
            } catch {
                print("Failed to build preview composition: \(error)")
            }
        }
        
        // Fallback
        return AVPlayer(url: url)
    }
    
    private func playClip(_ clip: VideoClip) {
        activePlayer?.pause()
        activePlayer = nil
        
        if selectedClip?.id == clip.id {
            selectedClip = nil
            return
        }
        
        selectedClip = clip
        
        Task {
            guard let player = await createPlayer(for: clip) else { return }
            guard selectedClip?.id == clip.id else { return } // Avoid race if user tapped another clip quickly
            
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }
            
            await MainActor.run {
                self.activePlayer = player
                player.play()
            }
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
                    guard let url = clip.url else { continue }
                    let asset = AVAsset(url: url)
                    
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
                    
                    let startCM = CMTime(seconds: clip.startTime ?? 0.0, preferredTimescale: 600)
                    let endCM = CMTime(seconds: clip.endTime ?? duration.seconds, preferredTimescale: 600)
                    let clipDurationCM = CMTimeSubtract(endCM, startCM)
                    let timeRange = CMTimeRange(start: startCM, duration: clipDurationCM)
                    
                    try compositionVideoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
                    
                    if let assetAudioTrack = audioTracks.first {
                        try compositionAudioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                    }
                    
                    currentTime = CMTimeAdd(currentTime, clipDurationCM)
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
                    var finalClipStartTimes: [Double] = []
                    var finalClipEndTimes: [Double] = []
                    
                    var urlToPermanentPath = [URL: String]()
                    
                    for clip in selectedVideos {
                        guard let url = clip.url else { continue }
                        let relativePath: String
                        if let cachedPath = urlToPermanentPath[url] {
                            relativePath = cachedPath
                        } else {
                            relativePath = try Project.saveClipToPermanentDirectory(from: url)
                            urlToPermanentPath[url] = relativePath
                        }
                        
                        finalClipPaths.append(relativePath)
                        finalClipTitles.append(clip.title)
                        
                        // Save or generate clip thumbnail
                        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let thumbnailRelativePath = relativePath.replacingOccurrences(of: ".mp4", with: ".jpg")
                        let thumbnailURL = documentsURL.appendingPathComponent(thumbnailRelativePath)
                        
                        if let thumbnail = clip.thumbnailImage {
                            if let data = thumbnail.jpegData(compressionQuality: 0.8) {
                                try? data.write(to: thumbnailURL)
                            }
                        } else {
                            let asset = AVAsset(url: url)
                            let generator = AVAssetImageGenerator(asset: asset)
                            generator.appliesPreferredTrackTransform = true
                            do {
                                let time = CMTime(seconds: 0.1, preferredTimescale: 600)
                                let (cgImage, _) = try await generator.image(at: time)
                                let uiImage = UIImage(cgImage: cgImage)
                                if let data = uiImage.jpegData(compressionQuality: 0.8) {
                                    try? data.write(to: thumbnailURL)
                                }
                            } catch {
                                print("Failed to generate clip thumbnail on save: \(error)")
                            }
                        }
                        
                        let start = clip.startTime ?? 0.0
                        let end: Double
                        if let e = clip.endTime {
                            end = e
                        } else {
                            let asset = AVAsset(url: url)
                            let dur = try? await asset.load(.duration)
                            end = dur?.seconds ?? 0.0
                        }
                        finalClipStartTimes.append(start)
                        finalClipEndTimes.append(end)
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
                                    
                                    // Also delete old clip thumbnail
                                    let oldThumbnailPath = oldPath.replacingOccurrences(of: ".mp4", with: ".jpg")
                                    let oldThumbnailURL = documentsURL.appendingPathComponent(oldThumbnailPath)
                                    try? fileManager.removeItem(at: oldThumbnailURL)
                                }
                            }
                            
                            // 3. Update project details
                            existingProject.videoPath = permanentFileName
                            existingProject.clipPaths = finalClipPaths
                            existingProject.clipTitles = finalClipTitles
                            existingProject.clipStartTimes = finalClipStartTimes
                            existingProject.clipEndTimes = finalClipEndTimes
                            existingProject.timestamp = Date()
                            existingProject.instructions = customInstructions.isEmpty ? nil : customInstructions
                            existingProject.geminiPrompt = geminiPrompt.isEmpty ? nil : geminiPrompt
                            
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
                                clipStartTimes: finalClipStartTimes,
                                clipEndTimes: finalClipEndTimes,
                                instructions: customInstructions.isEmpty ? nil : customInstructions,
                                geminiPrompt: geminiPrompt.isEmpty ? nil : geminiPrompt
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

// MARK: - VideoClip Timeline Helpers
extension VideoClip {
    var timelineDuration: Double {
        if let start = startTime, let end = endTime {
            return max(0.1, end - start)
        }
        if let duration = duration {
            return max(0.1, duration)
        }
        return 3.75 // Default fallback duration (equivalent to 150 points at 40 points/sec)
    }
}

// MARK: - Timeline Ticks View
struct TimelineTicksView: View {
    let totalDuration: Double
    let pointsPerSecond: CGFloat
    
    var body: some View {
        let totalWidth = CGFloat(totalDuration) * pointsPerSecond
        let maxSecond = Int(totalDuration)
        
        ZStack(alignment: .leading) {
            // A bottom divider line for the timeline ruler
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .bottom)
            
            // Loop through all seconds up to totalDuration
            ForEach(Array(0...maxSecond), id: \.self) { second in
                let xPosition = CGFloat(second) * pointsPerSecond
                
                if second % 2 == 0 {
                    // Even second: timestamp
                    VStack(spacing: 2) {
                        Text(formatTimestamp(second))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        // Tiny tick mark under timestamp
                        Rectangle()
                            .fill(Color.secondary.opacity(0.7))
                            .frame(width: 1, height: 6)
                    }
                    .position(x: xPosition, y: 12)
                } else {
                    // Odd second: tick mark
                    Rectangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 1, height: 8)
                        .position(x: xPosition, y: 18)
                }
            }
        }
        .frame(width: totalWidth, height: 24)
    }
    
    private func formatTimestamp(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Timeline Clip View
struct TimelineClipView: View {
    let video: VideoClip
    let isSelected: Bool
    let isDragging: Bool
    let justDropped: Bool
    let showHandle: Bool
    let width: CGFloat
    let action: () -> Void
    let onTrimChanged: (Double, Double) -> Void
    let onTrimEnded: () -> Void
    let onDragProvider: () -> NSItemProvider
    let dropDelegate: ClipDropDelegate
    
    @State private var dragStartLeftTime: Double? = nil
    @State private var dragStartRightTime: Double? = nil
    
    private let pointsPerSecond: CGFloat = 40.0

    var body: some View {
        ZStack {
            Button(action: action) {
                ZStack {
                    // Background
                    if let img = video.thumbnailImage {
                        let aspect = img.size.height > 0 ? (img.size.width / img.size.height) : 1.6
                        let scaledWidth = max(10, 44.0 * aspect)
                        let repeatCount = max(1, Int(ceil(width / scaledWidth)))
                        
                        HStack(spacing: 0) {
                            ForEach(0..<repeatCount, id: \.self) { _ in
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: scaledWidth, height: 44)
                                    .clipped()
                            }
                        }
                        .frame(width: width, alignment: .leading)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(isSelected ? 0.25 : 0.0))
                        )
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                    }

                    if isSelected {
                        HStack(spacing: 5) {
                            // Drag handle grip — universal iOS drag affordance
                            if showHandle && width > 60 {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Image(systemName: "video.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, min(10, width / 10))
                    }
                }
                .frame(width: width, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            justDropped ? Color.green : (isSelected ? Color.accentColor : Color.gray.opacity(0.4)),
                            lineWidth: justDropped ? 2.5 : 1.5
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            // Drag-state visual lift: fades and shrinks the dragged card
            .scaleEffect(isDragging ? 0.91 : 1.0)
            .opacity(isDragging ? 0.55 : 1.0)
            .shadow(
                color: isDragging ? Color.black.opacity(0.28) : .clear,
                radius: 10, x: 0, y: 6
            )
            .onDrag(onDragProvider)
            .onDrop(of: [.text], delegate: dropDelegate)
            
            if isSelected {
                ZStack {
                    // Left Arrow Handle
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                                .frame(width: 20, height: 44)
                                .shadow(radius: 2)
                            
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if dragStartLeftTime == nil {
                                        dragStartLeftTime = video.startTime ?? 0.0
                                    }
                                    guard let startVal = dragStartLeftTime else { return }
                                    
                                    let dx = value.translation.width
                                    let dt = Double(dx / pointsPerSecond)
                                    let maxDuration = video.duration ?? 3.75
                                    let currentEndTime = video.endTime ?? maxDuration
                                    
                                    var newStartTime = startVal + dt
                                    newStartTime = max(0.0, min(newStartTime, currentEndTime - 0.1))
                                    
                                    onTrimChanged(newStartTime, currentEndTime)
                                }
                                .onEnded { _ in
                                    dragStartLeftTime = nil
                                    onTrimEnded()
                                }
                        )
                        Spacer()
                    }
                    .offset(x: -20)
                    
                    // Right Arrow Handle
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                                .frame(width: 20, height: 44)
                                .shadow(radius: 2)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let maxDuration = video.duration ?? 3.75
                                    if dragStartRightTime == nil {
                                        dragStartRightTime = video.endTime ?? maxDuration
                                    }
                                    guard let endVal = dragStartRightTime else { return }
                                    
                                    let dx = value.translation.width
                                    let dt = Double(dx / pointsPerSecond)
                                    let currentStartTime = video.startTime ?? 0.0
                                    
                                    var newEndTime = endVal + dt
                                    newEndTime = max(currentStartTime + 0.1, min(newEndTime, maxDuration))
                                    
                                    onTrimChanged(currentStartTime, newEndTime)
                                }
                                .onEnded { _ in
                                    dragStartRightTime = nil
                                    onTrimEnded()
                                }
                        )
                    }
                    .offset(x: 20)
                    
                    // Timestamp pills
                    VStack {
                        HStack {
                            Text(formatSeconds(video.startTime ?? 0.0))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                            
                            Spacer()
                            
                            let maxDuration = video.duration ?? 3.75
                            Text(formatSeconds(video.endTime ?? maxDuration))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                        Spacer()
                    }
                }
                .frame(width: width)
                .allowsHitTesting(true)
            }
        }
        .frame(width: width, height: 44)
        .zIndex(isSelected ? 1.0 : 0.0)
    }
    
    private func formatSeconds(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        if mins > 0 {
            return String(format: "%d:%04.1f", mins, secs)
        } else {
            return String(format: "%.1fs", secs)
        }
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
            customInstructions: .constant("Sample instructions"),
            geminiPrompt: .constant("Mock Gemini Prompt Details\nLines of debug info...")
        )
    }
}

// MARK: - Drag and Drop Delegate
struct ClipDropDelegate: DropDelegate {
    let item: VideoClip
    @Binding var items: [VideoClip]
    @Binding var draggedItem: VideoClip?
    var onDropped: ((UUID) -> Void)? = nil

    func performDrop(info: DropInfo) -> Bool {
        // Capture the dropped clip's ID before clearing state so the
        // parent can trigger a confirmation flash on the reordered card.
        let droppedID = draggedItem?.id
        draggedItem = nil
        if let id = droppedID {
            onDropped?(id)
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        if draggedItem != item {
            let from = items.firstIndex(of: draggedItem)
            let to = items.firstIndex(of: item)
            if let from = from, let to = to {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                }
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}


