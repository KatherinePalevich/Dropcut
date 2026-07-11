//
//  ProjectsHomeView.swift
//  Dropcut
//
//  Created by Antigravity on 6/4/26.
//

import SwiftUI
import SwiftData
import AVKit

struct ProjectsHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    var startNewProject: () -> Void
    var editProject: (Project) -> Void
    
    @Query(sort: \Project.timestamp, order: .reverse) private var projects: [Project]
    @State private var projectToPlay: Project? = nil
    @State private var showSettings = false
    
    // State variables for renaming and deletion
    @State private var projectToRename: Project? = nil
    @State private var showRenameAlert = false
    @State private var renameText = ""
    
    @State private var projectToDelete: Project? = nil
    @State private var showDeleteAlert1 = false
    @State private var showDeleteAlert2 = false
    
    // Grid configuration: 2 columns
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if projects.isEmpty {
                // Fallback empty state in case all projects are deleted
                VStack(spacing: 24) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient.themeGradient(startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .themePrimary.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    VStack(spacing: 8) {
                        Text("No Projects Yet")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Tap the button below to start creating your first smart video.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Button(action: startNewProject) {
                        Text("Create New Video")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 32)
                            .background(
                                LinearGradient.themeGradient
                            )
                            .cornerRadius(16)
                            .shadow(color: .themePrimary.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Creations")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(projects) { project in
                                ProjectGridCard(
                                    project: project,
                                    onEdit: {
                                        editProject(project)
                                    },
                                    onPlay: {
                                        projectToPlay = project
                                    },
                                    onRename: {
                                        projectToRename = project
                                        renameText = project.name
                                        showRenameAlert = true
                                    },
                                    onDelete: {
                                        projectToDelete = project
                                        showDeleteAlert1 = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 8)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 12) {
                        ZStack {
                            Text("Dropcut")
                                .font(.themeSerif(size: 34, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient.themeGradient
                                )
                            
                            HStack {
                                Spacer()
                                Button(action: {
                                    showSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.trailing, 20)
                            }
                        }
                        
                        Button(action: startNewProject) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                Text("New Video")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .background(
                                LinearGradient.themeGradient
                            )
                            .cornerRadius(12)
                            .shadow(color: .themePrimary.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .overlay(
                        VStack {
                            Spacer()
                            Divider()
                        }
                    )
                }
            }
        }
        .navigationBarHidden(true) // We use our own header for home screen for a more custom, premium feel
        .fullScreenCover(item: $projectToPlay) { project in
            FullScreenPlayerView(project: project)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .alert("Rename Project", isPresented: $showRenameAlert) {
            TextField("Project Name", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let project = projectToRename, !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    project.name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    try? modelContext.save()
                }
            }
        } message: {
            Text("Enter a new name for your project.")
        }
        .alert("Delete Project", isPresented: $showDeleteAlert1) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                showDeleteAlert2 = true
            }
        } message: {
            if let project = projectToDelete {
                Text("Are you sure you want to delete \"\(project.name)\"?")
            } else {
                Text("Are you sure you want to delete this project?")
            }
        }
        .alert("Confirm Deletion", isPresented: $showDeleteAlert2) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Permanently", role: .destructive) {
                if let project = projectToDelete {
                    withAnimation {
                        Project.delete(project, from: modelContext)
                    }
                }
            }
        } message: {
            Text("This action cannot be undone. Are you absolutely sure?")
        }
    }
}

// MARK: - Project Grid Card
struct ProjectGridCard: View {
    let project: Project
    let onEdit: () -> Void
    let onPlay: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 0) {
                    // Card Media Area
                    ZStack {
                        if let url = project.videoURL {
                            VideoThumbnailView(videoURL: url)
                        } else {
                            Color.black.opacity(0.1)
                            Image(systemName: "video.slash")
                                .foregroundColor(.secondary)
                        }
                        
                        // Semi-transparent play button overlay
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipped()
                    
                    // Details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .padding(.trailing, 24) // Make room for three-dot menu
                        
                        Text(project.timestamp, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Three-dot menu button overlay
            Menu {
                Button(action: onRename) {
                    Label("Rename Project", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Project", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
            }
        }
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
        .contextMenu {
            Button(action: onPlay) {
                Label("Play Video", systemImage: "play.fill")
            }
            
            if let videoURL = project.videoURL {
                ShareLink(item: videoURL) {
                    Label("Share Video", systemImage: "square.and.arrow.up")
                }
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Project", systemImage: "trash")
            }
        }
    }
}

// MARK: - Video Thumbnail View
struct VideoThumbnailView: View {
    let videoURL: URL
    @State private var thumbnailImage: UIImage? = nil
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black.opacity(0.08)
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "video.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        guard thumbnailImage == nil && !isLoading else { return }
        isLoading = true
        
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Use a time slightly offset from start (e.g. 0.1s)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        Task {
            do {
                let cgImage = try await imageGenerator.image(at: time).image
                let uiImage = UIImage(cgImage: cgImage)
                await MainActor.run {
                    self.thumbnailImage = uiImage
                    self.isLoading = false
                }
            } catch {
                print("Failed to generate thumbnail: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Full Screen Player View
struct FullScreenPlayerView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer? = nil
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }
            
            // Top Controls
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Spacer()
                    
                    Text(project.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if let url = project.videoURL {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    } else {
                        Spacer().frame(width: 30)
                    }
                }
                .padding()
                Spacer()
            }
        }
        .onAppear {
            if let url = project.videoURL {
                let player = AVPlayer(url: url)
                self.player = player
                player.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
