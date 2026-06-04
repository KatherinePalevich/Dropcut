import SwiftUI
import SwiftData
import PhotosUI
import AVKit
import UniformTypeIdentifiers

// Enum representing the navigation routes
enum AppScreen: Hashable {
    case welcome
    case preferences
    case importClips
    case videoEditor
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    
    // Preferences screen state
    @State private var selectedContent: String? = nil
    @State private var durationSeconds: Int = 15

    
    // Import clips screen state
    @State private var selectedVideos: [VideoClip] = []

    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            WelcomeView(navigationPath: $navigationPath)
                .navigationDestination(for: AppScreen.self) { screen in
                    switch screen {
                    case .welcome:
                        WelcomeView(navigationPath: $navigationPath)
                    case .preferences:
                        PreferencesView(
                            navigationPath: $navigationPath,
                            selectedContent: $selectedContent,
                            durationSeconds: $durationSeconds
                        )
                    case .importClips:
                        ImportClipsView(
                            navigationPath: $navigationPath,
                            selectedVideos: $selectedVideos
                        )
                    case .videoEditor:
                        VideoEditorView(
                            navigationPath: $navigationPath,
                            selectedVideos: $selectedVideos
                        )
                    }
                }
        }
    }
}

// MARK: - Welcome View (Screen 1)
struct WelcomeView: View {
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        ZStack {
            // Elegant background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Animated decorative icon
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.accentColor, .purple, .pink]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .accentColor.opacity(0.3), radius: 15, x: 0, y: 10)
                
                VStack(spacing: 10) {
                    Text("Dropcut")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.accentColor, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("AI-Powered Smart Video Editor")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Button(action: {
                    navigationPath.append(AppScreen.preferences)
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.accentColor, .accentColor.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .accentColor.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Preferences View (Screen 2)
struct PreferencesView: View {
    @Binding var navigationPath: NavigationPath
    @Binding var selectedContent: String?
    @Binding var durationSeconds: Int
    
    let categories = [
        ("Food", "fork.knife"),
        ("Fashion", "tshirt"),
        ("Lifestyle", "sparkles")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    
                    // Question 1
                    VStack(alignment: .leading, spacing: 16) {
                        Text("1. What content are you editing?")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.0) { name, icon in
                                CategoryCard(
                                    title: name,
                                    icon: icon,
                                    isSelected: selectedContent == name
                                ) {
                                    selectedContent = name
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    Divider()
                    
                    // Question 2
                    VStack(alignment: .leading, spacing: 16) {
                        Text("2. How long do you want your final video to be?")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 16) {
                            Spacer()
                            
                            Picker("Duration", selection: $durationSeconds) {
                                ForEach(5...120, id: \.self) { seconds in
                                    Text("\(seconds)").tag(seconds)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: 120)
                            .clipped()
                            
                            Text("seconds")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Next Button
            Button(action: {
                navigationPath.append(AppScreen.importClips)
            }) {
                Text("Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedContent != nil
                            ? AnyView(LinearGradient(gradient: Gradient(colors: [.accentColor, .accentColor.opacity(0.8)]), startPoint: .leading, endPoint: .trailing))
                            : AnyView(Color.gray.opacity(0.5))
                    )
                    .cornerRadius(16)
                    .shadow(color: selectedContent != nil ? .accentColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(selectedContent == nil)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Import Clips View (Screen 3)
struct ImportClipsView: View {
    @Binding var navigationPath: NavigationPath
    @Binding var selectedVideos: [VideoClip]
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3. Import your video clips")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Add the raw footages that you'd like Dropcut to edit into a story.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // 2-row horizontal grid
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your Clips")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            
                            if isLoading {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            
                            // Mock loader helper for testing
                            Button(action: loadSampleClips) {
                                Label("Load Samples", systemImage: "arrow.down.circle")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: true) {
                            LazyHGrid(rows: [
                                GridItem(.fixed(120), spacing: 12),
                                GridItem(.fixed(120), spacing: 12)
                            ], spacing: 12) {
                                // Add button inside grid
                                PhotosPicker(
                                    selection: $pickerItems,
                                    maxSelectionCount: 10,
                                    matching: .videos
                                ) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "video.badge.plus")
                                            .font(.system(size: 28))
                                            .foregroundColor(.accentColor)
                                        Text("Import Video")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.accentColor)
                                    }
                                    .frame(width: 140, height: 120)
                                    .background(Color.accentColor.opacity(0.08))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                    )
                                }
                                
                                ForEach(selectedVideos) { video in
                                    VideoPlayerThumbnail(video: video)
                                }
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 252) // 2 rows of 120 + 12 spacing
                        }
                    }
                }
            }
            
            // "Dropcut it!" Action Button
            Button(action: {
                navigationPath.append(AppScreen.videoEditor)
            }) {
                Text("Dropcut it!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedVideos.isEmpty
                            ? AnyView(Color.gray.opacity(0.5))
                            : AnyView(LinearGradient(gradient: Gradient(colors: [.accentColor, .purple]), startPoint: .leading, endPoint: .trailing))
                    )
                    .cornerRadius(16)
                    .shadow(color: !selectedVideos.isEmpty ? .accentColor.opacity(0.4) : .clear, radius: 10, x: 0, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(selectedVideos.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("Import")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItems) { _, newItems in
            if newItems.isEmpty { return }
            isLoading = true
            Task {
                for item in newItems {
                    do {
                        if let transferable = try await item.loadTransferable(type: VideoTransferable.self) {
                            await MainActor.run {
                                let clipNum = selectedVideos.count + 1
                                selectedVideos.append(VideoClip(url: transferable.url, title: "Clip \(clipNum)"))
                            }
                        }
                    } catch {
                        print("Failed to load video: \(error)")
                    }
                }
                await MainActor.run {
                    isLoading = false
                    pickerItems = []
                }
            }
        }
    }
    
    // Help load public test clips in Simulator
    private func loadSampleClips() {
        let samples = [
            VideoClip(url: URL(string: "https://developer.apple.com/videos/mp4/subtitles_sample.mp4")!, title: "Intro"),
            VideoClip(url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4")!, title: "Action"),
            VideoClip(url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4")!, title: "Outro"),
            VideoClip(url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4")!, title: "B-Roll"),
            VideoClip(url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4")!, title: "Teaser")
        ]
        selectedVideos.append(contentsOf: samples)
    }
}

// MARK: - UI Helper Components
struct VideoClip: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let title: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: VideoClip, rhs: VideoClip) -> Bool {
        lhs.id == rhs.id
    }
}

struct VideoPlayerThumbnail: View {
    let video: VideoClip
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true) // Disable standard media controls
            } else {
                Color.black
                ProgressView()
            }
            
            VStack {
                Spacer()
                HStack {
                    Text(video.title)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "video.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(6)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(width: 140, height: 120)
        .cornerRadius(16)
        .clipped()
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            let player = AVPlayer(url: video.url)
            player.isMuted = true
            self.player = player
            
            // Loop video play
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }
            player.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

struct CategoryCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? .white : .primary)
                Text(title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .aspectRatio(1.0, contentMode: .fit) // Square
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Copy URL from Photos picker into a local temp file to bypass sandbox read errors in AVPlayer
func copyVideoToTemporaryDirectory(from url: URL) -> URL? {
    let tempDir = FileManager.default.temporaryDirectory
    let destinationURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
    do {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: url, to: destinationURL)
        return destinationURL
    } catch {
        print("Failed to copy video: \(error)")
        return nil
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

// Custom Transferable representation for Video files from PhotosPicker
struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let tempDir = FileManager.default.temporaryDirectory
            let destinationURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(received.file.pathExtension)
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: received.file, to: destinationURL)
            return VideoTransferable(url: destinationURL)
        }
    }
}

