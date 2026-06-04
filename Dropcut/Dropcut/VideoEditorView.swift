//
//  VideoEditorView.swift
//  Dropcut
//

import SwiftUI
import AVKit


struct VideoEditorView: View {
    @Binding var navigationPath: NavigationPath
    @Binding var selectedVideos: [VideoClip]
    
    @State private var activePlayer: AVPlayer? = nil
    @State private var selectedClip: VideoClip? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Main workspace/editor title
            HStack {
                Text("Video Editor")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
                
                Button(action: {
                    // Go back to the welcome screen / pop all
                    navigationPath = NavigationPath()
                }) {
                    Text("Done")
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
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
            
            // Timeline Controls
            HStack(spacing: 24) {
                Button(action: {}) {
                    VStack {
                        Image(systemName: "scissors")
                        Text("Split").font(.caption)
                    }
                }
                Button(action: {}) {
                    VStack {
                        Image(systemName: "plus.circle")
                        Text("Add Clip").font(.caption)
                    }
                }
                Button(action: {}) {
                    VStack {
                        Image(systemName: "textformat")
                        Text("Text").font(.caption)
                    }
                }
                Button(action: {}) {
                    VStack {
                        Image(systemName: "music.note")
                        Text("Audio").font(.caption)
                    }
                }
                Button(action: {}) {
                    VStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Adjust").font(.caption)
                    }
                }
            }
            .foregroundColor(.primary)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            
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
                            }
                        }
                    }
                    
                    // Audio Track
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .foregroundColor(.green)
                            .padding(.leading, 8)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 358, height: 24)
                            .overlay(
                                HStack {
                                    Text("bg_music.mp3")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                        .padding(.leading, 8)
                                    Spacer()
                                }
                            )
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            
            Spacer()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false) // Let native back button show
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
            ])
        )
    }
}


