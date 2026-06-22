import SwiftUI
import SwiftData
import PhotosUI
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
                                    return VideoClip(url: url, title: title)
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
                        selectedVideos.isEmpty || isProcessing
                            ? AnyView(Color.gray.opacity(0.5))
                            : AnyView(LinearGradient(gradient: Gradient(colors: [.accentColor, .purple]), startPoint: .leading, endPoint: .trailing))
                    )
                    .cornerRadius(16)
                    .shadow(color: !selectedVideos.isEmpty && !isProcessing ? .accentColor.opacity(0.4) : .clear, radius: 10, x: 0, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(selectedVideos.isEmpty || isProcessing)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: pickerItems) { _, newItems in
                if newItems.isEmpty { return }
                isLoading = true
                Task {
                    let importedClips = await withTaskGroup(of: (Int, VideoTransferable?).self) { group in
                        for (index, item) in newItems.enumerated() {
                            group.addTask {
                                do {
                                    let transferable = try await item.loadTransferable(type: VideoTransferable.self)
                                    return (index, transferable)
                                } catch {
                                    print("Failed to load video: \(error)")
                                    return (index, nil)
                                }
                            }
                        }
                        
                        var results = [Int: VideoTransferable]()
                        for await (index, transferable) in group {
                            if let transferable = transferable {
                                results[index] = transferable
                            }
                        }
                        
                        // Sort by original index to preserve selection order
                        return newItems.indices.compactMap { results[$0] }
                    }
                    
                    await MainActor.run {
                        for transferable in importedClips {
                            let clipNum = selectedVideos.count + 1
                            selectedVideos.append(VideoClip(url: transferable.url, title: "Clip \(clipNum)"))
                        }
                        isLoading = false
                        pickerItems = []
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
    }
    
    private func runDropcutPipeline() {
        var resolvedApiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        if resolvedApiKey.isEmpty {
            resolvedApiKey = UserDefaults.standard.string(forKey: "GeminiAPIKey") ?? ""
        }
        
        guard !resolvedApiKey.isEmpty else {
            showNoKeyAlert = true
            return
        }
        
        isProcessing = true
        processingStep = "Preparing clips..."
        
        Task {
            do {
                // A. Query duration of each clip to construct a clear prompt
                var originalClipsWithDurations: [(clip: VideoClip, duration: Double)] = []
                for clip in selectedVideos {
                    let asset = AVURLAsset(url: clip.url)
                    let duration = try await asset.load(.duration)
                    originalClipsWithDurations.append((clip: clip, duration: duration.seconds))
                }
                
                // B. Upload files concurrently to Gemini File API
                let totalCount = originalClipsWithDurations.count
                await MainActor.run {
                    processingStep = "Uploading and processing clips (0/\(totalCount))..."
                }
                
                let uploadedFileURIs: [String] = try await withThrowingTaskGroup(of: (Int, String).self) { group in
                    for (index, item) in originalClipsWithDurations.enumerated() {
                        group.addTask {
                            let uploadRes = try await GeminiService.uploadFile(fileURL: item.clip.url, apiKey: resolvedApiKey)
                            let activeURI = try await GeminiService.pollFileStatus(fileName: uploadRes.name, apiKey: resolvedApiKey)
                            return (index, activeURI)
                        }
                    }
                    
                    var results = [Int: String]()
                    for try await (index, uri) in group {
                        results[index] = uri
                        let completedCount = results.count
                        await MainActor.run {
                            processingStep = "Uploading and processing clips (\(completedCount)/\(totalCount))..."
                        }
                    }
                    
                    // Sort to maintain original selection order
                    return originalClipsWithDurations.indices.map { results[$0]! }
                }
                
                // C. Construct the prompt
                await MainActor.run {
                    processingStep = "Analyzing clips with Gemini..."
                }
                
                let contentEditingType = selectedContent ?? "General"
                let videoLength = "\(durationSeconds)"
                
                var promptText = "You are a content creator who creates short-form videos to highlight [insert selected content editing type]. You have taken these videos. Choose the best moments among these videos to create a final video that is [insert selected video length] seconds long and ready to be posted as a Reel or TikTok. "
                
                if !customInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    promptText += "Here is some more specific information about the editing style I want to have the final video in: [insert editing instructions]. "
                }
                
                promptText += "In JSON format, return to me the specific timestamps of each original video that I should use as well as the order of the clips to combine into a final video.\n\n"
                
                // Perform replacements
                promptText = promptText.replacingOccurrences(of: "[insert selected content editing type]", with: contentEditingType)
                promptText = promptText.replacingOccurrences(of: "[insert selected video length]", with: videoLength)
                if !customInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    promptText = promptText.replacingOccurrences(of: "[insert editing instructions]", with: customInstructions)
                }
                
                promptText += "Your response must be a JSON object containing an array of video cuts. The JSON must follow this exact schema:\n"
                promptText += "{\n  \"clips\": [\n    {\n      \"video_index\": <int, 0-indexed position of the original video clip in the list provided below>,\n      \"start_time\": <float, start time in seconds within the original video clip>,\n      \"end_time\": <float, end time in seconds within the original video clip>,\n      \"placement_order\": <int, 1-indexed order/placement position in which this cut segment should appear in the final video timeline>\n    }\n  ]\n}\n\n"
                
                promptText += "Here are the video clips you have access to, in order:\n"
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
                promptText += "4. Return only valid, raw JSON. Do not wrap the JSON output in markdown backticks (e.g. do not use ```json)."
                
                // D. Call Gemini GenerateContent REST API
                let jsonResponseText = try await GeminiService.generateContent(apiKey: resolvedApiKey, fileURIs: uploadedFileURIs, promptText: promptText)
                
                // E. Parse JSON Response
                guard let jsonData = jsonResponseText.data(using: .utf8) else {
                    throw GeminiError.invalidResponse
                }
                
                let parsedPlan = try JSONDecoder().decode(GeminiVideoPlan.self, from: jsonData)
                let sortedClips = parsedPlan.clips.sorted(by: { ($0.placement_order ?? 0) < ($1.placement_order ?? 0) })
                
                // F. Trimming clips based on timestamps and order
                await MainActor.run {
                    processingStep = "Trimming and organizing clips..."
                }
                
                var cutClips: [VideoClip] = []
                for (index, cut) in sortedClips.enumerated() {
                    guard cut.video_index >= 0 && cut.video_index < selectedVideos.count else {
                        continue
                    }
                    let originalClip = selectedVideos[cut.video_index]
                    
                    let cutURL = try await trimVideo(
                        url: originalClip.url,
                        startTime: cut.start_time,
                        endTime: cut.end_time
                    )
                    
                    let newClip = VideoClip(
                        url: cutURL,
                        title: "\(originalClip.title) (Cut \(index + 1))"
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
        .frame(maxWidth: .infinity)
        .frame(height: 120)
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
            try FileManager.default.copyItem(at: received.file, to: destinationURL)
            return VideoTransferable(url: destinationURL)
        }
    }
}

