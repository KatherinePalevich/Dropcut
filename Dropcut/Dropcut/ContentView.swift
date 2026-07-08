import SwiftUI
import SwiftData
import PhotosUI
import Photos
import AVKit
import AVFoundation
import UniformTypeIdentifiers

// Enum representing the navigation routes
enum AppScreen: Hashable {
    case welcome
    case preferences
    case instructions
    case importClips
    case videoEditor
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    
    @Query(sort: \Project.timestamp, order: .reverse) private var projects: [Project]
    
    // Preferences screen state
    @State private var selectedContent: String? = nil
    @State private var durationSeconds: Int = 15
    @State private var customInstructions: String = ""
    @State private var geminiPrompt: String = ""

    
    // Import clips screen state
    @State private var selectedVideos: [VideoClip] = []
    @State private var editingProject: Project? = nil

    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if projects.isEmpty {
                    WelcomeView(navigationPath: $navigationPath)
                } else {
                    ProjectsHomeView(
                        navigationPath: $navigationPath,
                        startNewProject: startNewProject,
                        editProject: { project in
                            self.editingProject = project
                            self.geminiPrompt = project.geminiPrompt ?? ""
                            self.customInstructions = project.instructions ?? ""
                            if project.safeClipPaths.isEmpty, let videoPath = project.videoPath {
                                // Fallback for legacy projects (use combined video as single clip)
                                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                let url = documentsURL.appendingPathComponent(videoPath)
                                self.selectedVideos = [VideoClip(url: url, title: project.name)]
                            } else {
                                // Map saved clips
                                self.selectedVideos = project.safeClipPaths.indices.map { index in
                                    let relativePath = project.safeClipPaths[index]
                                    let title = project.safeClipTitles[index]
                                    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                    let url = documentsURL.appendingPathComponent(relativePath)
                                    let start = project.safeClipStartTimes.indices.contains(index) ? project.safeClipStartTimes[index] : nil
                                    let end = project.safeClipEndTimes.indices.contains(index) ? project.safeClipEndTimes[index] : nil
                                    return VideoClip(url: url, title: title, startTime: start, endTime: end)
                                }
                            }
                            navigationPath.append(AppScreen.videoEditor)
                        }
                    )
                }
            }
            .navigationDestination(for: AppScreen.self) { screen in
                switch screen {
                case .welcome:
                    WelcomeView(navigationPath: $navigationPath)
                case .preferences:
                    PreferencesView(
                        navigationPath: $navigationPath,
                        selectedContent: $selectedContent,
                        durationSeconds: $durationSeconds,
                        isFirstProject: projects.isEmpty
                    )
                case .instructions:
                    InstructionsView(
                        navigationPath: $navigationPath,
                        selectedContent: $selectedContent,
                        instructionsText: $customInstructions
                    )
                case .importClips:
                    ImportClipsView(
                        navigationPath: $navigationPath,
                        selectedVideos: $selectedVideos,
                        selectedContent: $selectedContent,
                        durationSeconds: $durationSeconds,
                        customInstructions: $customInstructions,
                        geminiPrompt: $geminiPrompt
                    )
                case .videoEditor:
                    VideoEditorView(
                        navigationPath: $navigationPath,
                        selectedVideos: $selectedVideos,
                        editingProject: $editingProject,
                        customInstructions: $customInstructions,
                        geminiPrompt: $geminiPrompt
                    )
                }
            }
        }
    }
    
    private func startNewProject() {
        selectedContent = nil
        durationSeconds = 15
        customInstructions = ""
        geminiPrompt = ""
        selectedVideos = []
        editingProject = nil
        navigationPath = NavigationPath()
        navigationPath.append(AppScreen.preferences)
    }
}

// MARK: - Welcome View (Screen 1)
struct WelcomeView: View {
    @Binding var navigationPath: NavigationPath
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            // Elegant background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Settings button top-right
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .padding(.top, 10)
                    .padding(.trailing, 10)
                }
                Spacer()
            }
            
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - Preferences View (Screen 2)
struct PreferencesView: View {
    @Binding var navigationPath: NavigationPath
    @Binding var selectedContent: String?
    @Binding var durationSeconds: Int
    let isFirstProject: Bool
    
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
                if isFirstProject {
                    navigationPath.append(AppScreen.importClips)
                } else {
                    navigationPath.append(AppScreen.instructions)
                }
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

// MARK: - Instructions View (Screen 2.5)
struct InstructionsView: View {
    @Binding var navigationPath: NavigationPath
    @Binding var selectedContent: String?
    @Binding var instructionsText: String
    @FocusState private var isInputActive: Bool
    
    var suggestions: [String] {
        switch selectedContent {
        case "Food":
            return ["Steady movements", "Focus on food items", "Overhead shot of all items", "Show the cooking process", "Close-up of textures"]
        case "Fashion":
            return ["Highlight outfits", "Cinematic transitions", "Focus on details", "Fast-paced cut", "Smooth walk sequence"]
        case "Lifestyle":
            return ["Steady camera movements", "Natural lighting focus", "Focus on people", "Slow motion highlights", "Cozy transition style"]
        default:
            return ["Steady movements", "Fast transitions", "Upbeat mood", "Cinematic feel", "Focus on details"]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add editing instructions")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Describe how you want Dropcut to edit your video (optional).")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    
                    // Input Text Editor Card
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            if instructionsText.isEmpty {
                                Text("e.g. Focus on steady movements, start the video with an overhead shot...")
                                    .font(.body)
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                            
                            TextEditor(text: $instructionsText)
                                .font(.body)
                                .padding(12)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .focused($isInputActive)
                                .onChange(of: instructionsText) { _, newValue in
                                    if newValue.count > 500 {
                                        instructionsText = String(newValue.prefix(500))
                                    }
                                }
                        }
                        .frame(height: 180)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                        
                        HStack {
                            Spacer()
                            Text("\(instructionsText.count)/500")
                                .font(.caption2)
                                .foregroundColor(instructionsText.count >= 500 ? .red : .secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    // Suggestion Chips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Suggestions")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button(action: {
                                        if instructionsText.isEmpty {
                                            instructionsText = suggestion + "."
                                        } else {
                                            let trimmed = instructionsText.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if trimmed.isEmpty {
                                                instructionsText = suggestion + "."
                                            } else if trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?") {
                                                instructionsText = trimmed + " " + suggestion + "."
                                            } else {
                                                instructionsText = trimmed + ", " + suggestion.lowercased() + "."
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 10, weight: .bold))
                                            Text(suggestion)
                                        }
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(Color.accentColor.opacity(0.08))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1.2)
                                        )
                                        .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .onTapGesture {
                isInputActive = false
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
                        LinearGradient(
                            gradient: Gradient(colors: [.accentColor, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("Instructions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Import Clips View (Screen 3)
struct ImportClipsView: View {
    @Binding var navigationPath: NavigationPath
    @Binding var selectedVideos: [VideoClip]
    
    @Binding var selectedContent: String?
    @Binding var durationSeconds: Int
    @Binding var customInstructions: String
    @Binding var geminiPrompt: String
    
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoading = false
    
    // Gemini Processing states
    @State private var isProcessing = false
    @State private var processingStep = ""
    @State private var showNoKeyAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var uploadTask: Task<Void, Never>? = nil
    
    var body: some View {
        ZStack {
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
                            }
                            .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                // Add button inside grid
                                PhotosPicker(
                                    selection: $pickerItems,
                                    maxSelectionCount: 10,
                                    matching: .videos,
                                    photoLibrary: .shared()
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
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .background(Color.accentColor.opacity(0.08))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                    )
                                }
                                .disabled(isProcessing)
                                
                                ForEach(selectedVideos) { video in
                                    VideoPlayerThumbnail(video: video)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                // "Dropcut it!" Action Button
                Button(action: {
                    runDropcutPipeline()
                }) {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isProcessing ? "Dropcutting..." : "Dropcut it!")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedVideos.isEmpty || isProcessing || selectedVideos.contains(where: { $0.isImporting })
                            ? AnyView(Color.gray.opacity(0.5))
                            : AnyView(LinearGradient(gradient: Gradient(colors: [.accentColor, .purple]), startPoint: .leading, endPoint: .trailing))
                    )
                    .cornerRadius(16)
                    .shadow(color: !selectedVideos.isEmpty && !isProcessing && !selectedVideos.contains(where: { $0.isImporting }) ? .accentColor.opacity(0.4) : .clear, radius: 10, x: 0, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(selectedVideos.isEmpty || isProcessing || selectedVideos.contains(where: { $0.isImporting }))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: pickerItems) { _, newItems in
                if newItems.isEmpty { return }
                isLoading = true
                let currentCount = selectedVideos.count
                Task {
                    // 1. Check and request readWrite authorization
                    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    let hasPermission = (status == .authorized || status == .limited)
                    
                    // 2. Immediately create placeholder clips on the main thread (without blocking on thumbnails)
                    var tempClips: [VideoClip] = []
                    for index in 0..<newItems.count {
                        let clipNum = currentCount + index + 1
                        let clip = VideoClip(
                            url: nil,
                            title: "Clip \(clipNum)",
                            isImporting: true,
                            thumbnailImage: nil
                        )
                        tempClips.append(clip)
                    }
                    
                    await MainActor.run {
                        selectedVideos.append(contentsOf: tempClips)
                    }
                    
                    // 3. Import each video concurrently and update elements individually
                    await withTaskGroup(of: Void.self) { group in
                        for (index, item) in newItems.enumerated() {
                            let targetClipId = tempClips[index].id
                            let localID = item.itemIdentifier
                            
                            group.addTask {
                                // Fetch thumbnail asynchronously in the background first so the placeholder updates quickly
                                var fetchedThumbnail: UIImage? = nil
                                if hasPermission, let localID = localID {
                                    fetchedThumbnail = await fetchThumbnail(for: localID)
                                    if let thumbnail = fetchedThumbnail {
                                        await MainActor.run {
                                            if let idx = selectedVideos.firstIndex(where: { $0.id == targetClipId }) {
                                                selectedVideos[idx].thumbnailImage = thumbnail
                                            }
                                        }
                                    }
                                }
                                
                                do {
                                    let transferable = try await item.loadTransferable(type: VideoTransferable.self)
                                    guard let url = transferable?.url else {
                                        throw NSError(domain: "Dropcut", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to obtain local URL"])
                                    }
                                    
                                    // Generate thumbnail from local URL if we don't already have one from PHPhotoLibrary
                                    var finalThumbnail = fetchedThumbnail
                                    if finalThumbnail == nil {
                                        finalThumbnail = await generateThumbnail(for: url)
                                    }
                                    
                                    let resultThumbnail = finalThumbnail
                                    await MainActor.run {
                                        if let idx = selectedVideos.firstIndex(where: { $0.id == targetClipId }) {
                                            selectedVideos[idx].url = url
                                            selectedVideos[idx].isImporting = false
                                            selectedVideos[idx].thumbnailImage = resultThumbnail
                                        }
                                    }
                                } catch {
                                    print("Failed to import video: \(error)")
                                    await MainActor.run {
                                        // Remove the failed clip from selectedVideos
                                        selectedVideos.removeAll(where: { $0.id == targetClipId })
                                    }
                                }
                            }
                        }
                    }
                    
                    await MainActor.run {
                        pickerItems = []
                        startBackgroundUploads()
                        isLoading = false
                    }
                }
            }
            .alert("API Key Missing", isPresented: $showNoKeyAlert) {
                Button("OK") { }
            } message: {
                Text("Please configure your Gemini API Key first by tapping the gear icon on the home screen.")
            }
            .alert("Gemini Failed", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            
            // Modern Glassmorphic Progress Overlay
            if isProcessing {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.8)
                        .padding(.bottom, 10)
                    
                    Text(processingStep)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            }
        }
        .onAppear {
            startBackgroundUploads()
        }
    }
    
    private func resolvedApiKey() -> String {
        var apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        if apiKey.isEmpty {
            apiKey = UserDefaults.standard.string(forKey: "GeminiAPIKey") ?? ""
        }
        return apiKey
    }
    
    private func startBackgroundUploads() {
        let key = resolvedApiKey()
        guard !key.isEmpty else { return }
        
        uploadTask?.cancel()
        
        uploadTask = Task {
            while !Task.isCancelled {
                // Find first video that is not uploaded, not currently uploading, has no error, and has finished importing (has a non-nil url)
                guard let index = selectedVideos.firstIndex(where: {
                    $0.url != nil && $0.geminiFileURI == nil && !$0.isUploading && $0.uploadError == nil
                }) else {
                    break
                }
                
                await MainActor.run {
                    selectedVideos[index].isUploading = true
                    selectedVideos[index].uploadError = nil
                }
                
                let clip = selectedVideos[index]
                guard let url = clip.url else { break }
                
                do {
                    let compressedURL = try await Self.compressVideoForUpload(url: url)
                    defer {
                        try? FileManager.default.removeItem(at: compressedURL)
                    }
                    
                    let uploadRes = try await GeminiService.uploadFile(fileURL: compressedURL, apiKey: key)
                    let activeURI = try await GeminiService.pollFileStatus(fileName: uploadRes.name, apiKey: key)
                    
                    if Task.isCancelled { break }
                    
                    await MainActor.run {
                        if let idx = selectedVideos.firstIndex(where: { $0.id == clip.id }) {
                            selectedVideos[idx].geminiFileURI = activeURI
                            selectedVideos[idx].isUploading = false
                        }
                    }
                } catch {
                    if Task.isCancelled { break }
                    print("Background upload failed for clip \(clip.title): \(error.localizedDescription)")
                    
                    await MainActor.run {
                        if let idx = selectedVideos.firstIndex(where: { $0.id == clip.id }) {
                            selectedVideos[idx].isUploading = false
                            selectedVideos[idx].uploadError = error.localizedDescription
                        }
                    }
                }
            }
        }
    }
    
    private func runDropcutPipeline() {
        let resolvedApiKey = resolvedApiKey()
        
        guard !resolvedApiKey.isEmpty else {
            showNoKeyAlert = true
            return
        }
        
        isProcessing = true
        processingStep = "Preparing clips..."
        
        // Cancel background upload task to prevent race conditions and CPU/GPU contention
        uploadTask?.cancel()
        uploadTask = nil
        
        // Reset uploading states
        for index in selectedVideos.indices {
            selectedVideos[index].isUploading = false
        }
        
        Task {
            do {
                // A. Query duration of each clip concurrently to construct a clear prompt
                let originalClipsWithDurations: [(clip: VideoClip, duration: Double)] = try await withThrowingTaskGroup(of: (Int, VideoClip, Double).self) { group in
                    for (index, clip) in selectedVideos.enumerated() {
                        if let url = clip.url {
                            group.addTask {
                                let asset = AVURLAsset(url: url)
                                let duration = try await asset.load(.duration)
                                return (index, clip, duration.seconds)
                            }
                        }
                    }
                    var results = [(Int, VideoClip, Double)]()
                    for try await result in group {
                        results.append(result)
                    }
                    return results.sorted(by: { $0.0 < $1.0 }).map { ($0.1, $0.2) }
                }
                
                // B. Upload files sequentially to Gemini File API (using cache)
                let totalCount = originalClipsWithDurations.count
                await MainActor.run {
                    processingStep = "Uploading and processing clips (0/\(totalCount))..."
                }
                
                var uploadedFileURIs = [String]()
                for (index, item) in originalClipsWithDurations.enumerated() {
                    try Task.checkCancellation()
                    
                    let activeURI: String
                    if let cachedURI = item.clip.geminiFileURI {
                        activeURI = cachedURI
                    } else {
                        guard let url = item.clip.url else {
                            throw GeminiError.apiError("Missing file URL for clip.")
                        }
                        let compressedURL = try await Self.compressVideoForUpload(url: url)
                        defer {
                            try? FileManager.default.removeItem(at: compressedURL)
                        }
                        
                        let uploadRes = try await GeminiService.uploadFile(fileURL: compressedURL, apiKey: resolvedApiKey)
                        activeURI = try await GeminiService.pollFileStatus(fileName: uploadRes.name, apiKey: resolvedApiKey)
                        
                        // Update cache
                        await MainActor.run {
                            if let idx = selectedVideos.firstIndex(where: { $0.id == item.clip.id }) {
                                selectedVideos[idx].geminiFileURI = activeURI
                            }
                        }
                    }
                    
                    uploadedFileURIs.append(activeURI)
                    let completedCount = index + 1
                    await MainActor.run {
                        processingStep = "Uploading and processing clips (\(completedCount)/\(totalCount))..."
                    }
                }
                
                // C. Construct the prompt and system instructions
                await MainActor.run {
                    processingStep = "Analyzing clips with Gemini..."
                }
                
                let contentEditingType = selectedContent ?? "General"
                let videoLength = "\(durationSeconds)"
                
                let systemInstruction = "You are a content creator who creates short-form videos to highlight \(contentEditingType). Choose the best moments among the provided videos to create a final video edit plan."
                
                var promptText = "Create a final video edit plan that is \(videoLength) seconds long and ready to be posted as a Reel or TikTok. "
                
                if !customInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    promptText += "Here is some more specific information about the editing style I want to have the final video in: \(customInstructions). "
                }
                
                promptText += "\nHere are the video clips you have access to, in order:\n"
                for (index, item) in originalClipsWithDurations.enumerated() {
                    promptText += "- Clip \(index): title: \"\(item.clip.title)\", duration: \(String(format: "%.2f", item.duration)) seconds\n"
                }
                
                let totalUploadedDuration = originalClipsWithDurations.map { $0.duration }.reduce(0, +)
                let targetLength = min(Double(durationSeconds), totalUploadedDuration)
                let formattedTargetLength = String(format: "%.2f", targetLength)
                
                promptText += "\nGuidelines:\n"
                promptText += "1. Every start_time must be >= 0 and end_time <= the original video duration. Keep each cut's duration (end_time - start_time) at least 1.0 second.\n"
                promptText += "2. The total sum of the cut durations must equal \(formattedTargetLength) seconds as closely as possible. The total length of the video must be the smaller of either the specified video length (\(durationSeconds) seconds) or the total length of uploaded video content (\(String(format: "%.2f", totalUploadedDuration)) seconds).\n"
                promptText += "3. Don't repeat clips in the final video. Each original clip (identified by video_index) must be used at most once.\n"
                
                // D. Call Gemini GenerateContent REST API with system instructions
                let jsonResponseText = try await GeminiService.generateContent(apiKey: resolvedApiKey, fileURIs: uploadedFileURIs, promptText: promptText, systemInstruction: systemInstruction)
                
                // E. Parse JSON Response
                guard let jsonData = jsonResponseText.data(using: .utf8) else {
                    throw GeminiError.invalidResponse
                }
                
                let parsedPlan = try JSONDecoder().decode(GeminiVideoPlan.self, from: jsonData)
                let sortedClips = parsedPlan.clips.sorted(by: { ($0.placement_order ?? 0) < ($1.placement_order ?? 0) })
                
                // F. Organizing clips based on timestamps and order (no physical trimming)
                await MainActor.run {
                    processingStep = "Organizing clips..."
                }
                
                var cutClips: [VideoClip] = []
                for (index, cut) in sortedClips.enumerated() {
                    guard cut.video_index >= 0 && cut.video_index < selectedVideos.count else {
                        continue
                    }
                    let originalClip = selectedVideos[cut.video_index]
                    
                    let newClip = VideoClip(
                        url: originalClip.url,
                        title: "\(originalClip.title) (Cut \(index + 1))",
                        geminiFileURI: originalClip.geminiFileURI,
                        startTime: cut.start_time,
                        endTime: cut.end_time,
                        thumbnailImage: originalClip.thumbnailImage
                    )
                    cutClips.append(newClip)
                }
                
                if cutClips.isEmpty {
                    throw GeminiError.apiError("Gemini did not return any valid clip segments.")
                }
                
                // G. Complete processing and navigate
                await MainActor.run {
                    self.geminiPrompt = promptText
                    self.selectedVideos = cutClips
                    self.isProcessing = false
                    navigationPath.append(AppScreen.videoEditor)
                }
                
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    static func compressVideoForUpload(url: URL) async throws -> URL {
        let fileManager = FileManager.default
        if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? UInt64,
           fileSize < 15 * 1024 * 1024 {
            // Already small, copy directly to a temporary file
            let tempURL = fileManager.temporaryDirectory
                .appendingPathComponent("upload_direct_\(UUID().uuidString)")
                .appendingPathExtension("mp4")
            try fileManager.copyItem(at: url, to: tempURL)
            return tempURL
        }
        
        let asset = AVURLAsset(url: url)
        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent("upload_\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        
        let preset = AVAssetExportPreset640x480
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: preset
        ) else {
            throw NSError(domain: "Dropcut", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create AVAssetExportSession for compression."])
        }
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            return tempURL
        } else {
            // Fallback to low quality if 640x480 fails
            if let fallbackSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetLowQuality) {
                fallbackSession.outputURL = tempURL
                fallbackSession.outputFileType = .mp4
                fallbackSession.shouldOptimizeForNetworkUse = true
                await fallbackSession.export()
                if fallbackSession.status == .completed {
                    return tempURL
                }
            }
            let errorDesc = exportSession.error?.localizedDescription ?? "Compression failed with an unknown error."
            throw NSError(domain: "Dropcut", code: -1, userInfo: [NSLocalizedDescriptionKey: errorDesc])
        }
    }
    
    private func trimVideo(url: URL, startTime: Double, endTime: Double) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let maxDuration = duration.seconds
        
        let clampedStart = max(0.0, min(startTime, maxDuration))
        let clampedEnd = max(clampedStart, min(endTime, maxDuration))
        
        let start = CMTime(seconds: clampedStart, preferredTimescale: 600)
        let dur = CMTime(seconds: max(0.5, clampedEnd - clampedStart), preferredTimescale: 600)
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cut_\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "Dropcut", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create AVAssetExportSession for trimming."])
        }
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = CMTimeRange(start: start, duration: dur)
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            return tempURL
        } else {
            let errorDesc = exportSession.error?.localizedDescription ?? "Trim failed with an unknown error."
            throw NSError(domain: "Dropcut", code: -1, userInfo: [NSLocalizedDescriptionKey: errorDesc])
        }
    }
}

// JSON mapping models
struct GeminiVideoCut: Codable {
    let video_index: Int
    let start_time: Double
    let end_time: Double
    let placement_order: Int?
}

struct GeminiVideoPlan: Codable {
    let clips: [GeminiVideoCut]
}

// MARK: - UI Helper Components
struct VideoClip: Identifiable, Hashable {
    let id: UUID
    var url: URL?
    var title: String
    var geminiFileURI: String?
    var isUploading: Bool
    var uploadError: String?
    var startTime: Double?
    var endTime: Double?
    var isImporting: Bool
    var thumbnailImage: UIImage?
    
    init(id: UUID = UUID(), url: URL? = nil, title: String, geminiFileURI: String? = nil, isUploading: Bool = false, uploadError: String? = nil, startTime: Double? = nil, endTime: Double? = nil, isImporting: Bool = false, thumbnailImage: UIImage? = nil) {
        self.id = id
        self.url = url
        self.title = title
        self.geminiFileURI = geminiFileURI
        self.isUploading = isUploading
        self.uploadError = uploadError
        self.startTime = startTime
        self.endTime = endTime
        self.isImporting = isImporting
        self.thumbnailImage = thumbnailImage
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(url)
        hasher.combine(title)
        hasher.combine(geminiFileURI)
        hasher.combine(isUploading)
        hasher.combine(uploadError)
        hasher.combine(startTime)
        hasher.combine(endTime)
        hasher.combine(isImporting)
    }
    
    static func == (lhs: VideoClip, rhs: VideoClip) -> Bool {
        lhs.id == rhs.id &&
        lhs.url == rhs.url &&
        lhs.title == rhs.title &&
        lhs.geminiFileURI == rhs.geminiFileURI &&
        lhs.isUploading == rhs.isUploading &&
        lhs.uploadError == rhs.uploadError &&
        lhs.startTime == rhs.startTime &&
        lhs.endTime == rhs.endTime &&
        lhs.isImporting == rhs.isImporting &&
        lhs.thumbnailImage == rhs.thumbnailImage
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
            } else if let thumbnail = video.thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                
                if video.isImporting {
                    Color.black.opacity(0.3)
                    ProgressView()
                        .tint(.white)
                }
            } else {
                Color(.secondarySystemBackground)
                if video.isImporting {
                    ProgressView()
                } else {
                    Image(systemName: "video.slash")
                        .foregroundColor(.secondary)
                }
            }
            
            // Glassmorphic checkmark badge in top-left when completed
            if !video.isImporting {
                VStack {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 28, height: 28)
                                .shadow(color: .black.opacity(0.15), radius: 4)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(8)
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            // Upload Status Overlay in top right corner
            VStack {
                HStack {
                    Spacer()
                    if video.isUploading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.7)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(6)
                    } else if video.geminiFileURI != nil {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(LinearGradient(gradient: Gradient(colors: [.purple, .accentColor]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(Circle())
                            .padding(6)
                    } else if video.uploadError != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .padding(6)
                    }
                }
                Spacer()
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
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .cornerRadius(16)
        .clipped()
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            setupPlayer()
        }
        .onChange(of: video.url) { _, _ in
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func setupPlayer() {
        guard let url = video.url else { return }
        if player != nil { return }
        
        let player = AVPlayer(url: url)
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

func fetchThumbnail(for localIdentifier: String) async -> UIImage? {
    let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
    guard let asset = result.firstObject else { return nil }
    
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = true
    options.deliveryMode = .fastFormat
    options.isSynchronous = true
    
    var fetchedImage: UIImage? = nil
    PHImageManager.default().requestImage(
        for: asset,
        targetSize: CGSize(width: 300, height: 300),
        contentMode: .aspectFill,
        options: options
    ) { image, _ in
        fetchedImage = image
    }
    return fetchedImage
}

func generateThumbnail(for url: URL) async -> UIImage? {
    let asset = AVAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    
    do {
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        let (cgImage, _) = try await generator.image(at: time)
        return UIImage(cgImage: cgImage)
    } catch {
        print("Thumbnail generation failed: \(error)")
        return nil
    }
}


#Preview {
    ContentView()
        .modelContainer(for: Project.self, inMemory: true)
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
            do {
                try FileManager.default.moveItem(at: received.file, to: destinationURL)
            } catch {
                try FileManager.default.copyItem(at: received.file, to: destinationURL)
            }
            return VideoTransferable(url: destinationURL)
        }
    }
}

