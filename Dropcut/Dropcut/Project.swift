//
//  Project.swift
//  Dropcut
//
//  Created by Antigravity on 6/4/26.
//

import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var name: String
    var timestamp: Date
    var videoPath: String?
    var clipPaths: [String]?
    var clipTitles: [String]?
    var instructions: String?
    var geminiPrompt: String?
    
    init(id: UUID = UUID(), name: String, timestamp: Date = Date(), videoPath: String? = nil, clipPaths: [String]? = [], clipTitles: [String]? = [], instructions: String? = nil, geminiPrompt: String? = nil) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.videoPath = videoPath
        self.clipPaths = clipPaths
        self.clipTitles = clipTitles
        self.instructions = instructions
        self.geminiPrompt = geminiPrompt
    }
}

extension Project {
    var safeClipPaths: [String] {
        clipPaths ?? []
    }
    
    var safeClipTitles: [String] {
        clipTitles ?? []
    }
    
    // Dynamically resolves the absolute URL of the video file inside the Documents directory.
    // Absolute paths in iOS containers change between app launches, so relative path must be used.
    var videoURL: URL? {
        guard let videoPath = videoPath else { return nil }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(videoPath)
    }
    
    // Saves a video file from a temporary URL to a permanent location in the Documents directory.
    // Returns the relative filename.
    static func saveVideoToPermanentDirectory(from url: URL) throws -> String {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        if !fileManager.fileExists(atPath: documentsURL.path) {
            try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        }
        
        let fileName = "\(UUID().uuidString).mp4"
        let destinationURL = documentsURL.appendingPathComponent(fileName)
        
        try fileManager.copyItem(at: url, to: destinationURL)
        return fileName
    }
    
    // Saves a clip video file to a permanent location inside the Documents directory,
    // avoiding re-copying if it is already located there. Returns the relative filename.
    static func saveClipToPermanentDirectory(from url: URL) throws -> String {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // If the URL is already pointing to a file in the documents directory, just return the filename.
        if url.deletingLastPathComponent().standardized == documentsURL.standardized {
            return url.lastPathComponent
        }
        
        if !fileManager.fileExists(atPath: documentsURL.path) {
            try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        }
        
        let fileName = "clip_\(UUID().uuidString).mp4"
        let destinationURL = documentsURL.appendingPathComponent(fileName)
        
        try fileManager.copyItem(at: url, to: destinationURL)
        return fileName
    }
    
    // Deletes the project from database and its video file from disk, as well as all raw clips.
    static func delete(_ project: Project, from modelContext: ModelContext) {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        if let videoPath = project.videoPath {
            let fileURL = documentsURL.appendingPathComponent(videoPath)
            try? fileManager.removeItem(at: fileURL)
        }
        
        for clipPath in project.safeClipPaths {
            let fileURL = documentsURL.appendingPathComponent(clipPath)
            try? fileManager.removeItem(at: fileURL)
        }
        
        modelContext.delete(project)
    }
    
    // Generates the next project name in format "Project #" based on the highest existing number
    // to handle project deletions gracefully.
    static func nextProjectName(existingProjects: [Project]) -> String {
        var maxNumber = 0
        for project in existingProjects {
            let name = project.name
            if name.hasPrefix("Project ") {
                let numberString = name.dropFirst("Project ".count)
                if let number = Int(numberString) {
                    maxNumber = max(maxNumber, number)
                }
            }
        }
        return "Project \(maxNumber + 1)"
    }
}
