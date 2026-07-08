//
//  GeminiService.swift
//  Dropcut
//
//  Created by Antigravity on 6/9/26.
//

import Foundation

enum GeminiError: Error, LocalizedError {
    case invalidURL
    case apiError(String)
    case invalidResponse
    case fileProcessingFailed
    case invalidAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Something went wrong internally. Please restart the app and try again."
        case .apiError(let message):
            return message
        case .invalidResponse:
            return "We received an unexpected response. Please try again."
        case .fileProcessingFailed:
            return "We weren't able to process one of your video files. Try re-importing the clip."
        case .invalidAPIKey:
            return "That API key wasn't accepted. Please check that you copied it correctly from Google AI Studio."
        }
    }
}

struct GeminiService {
    
    // Uploads a local file to the Gemini File API
    // Returns the resource 'name' of the file (e.g. "files/some-id") and the 'uri'
    static func uploadFile(fileURL: URL, apiKey: String, onProgress: ((Double) -> Void)? = nil) async throws -> (name: String, uri: String) {
        let uploadURLString = "https://generativelanguage.googleapis.com/upload/v1beta/files?key=\(apiKey)"
        guard let url = URL(string: uploadURLString) else {
            throw GeminiError.invalidURL
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("multipart", forHTTPHeaderField: "X-Goog-Upload-Protocol")
        
        // Build multipart/related body on disk in a temporary file to avoid loading file bytes into RAM
        let tempMultipartURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gemini_upload_\(UUID().uuidString)")
            .appendingPathExtension("tmp")
        
        FileManager.default.createFile(atPath: tempMultipartURL.path, contents: nil, attributes: nil)
        
        let fileHandle = try FileHandle(forWritingTo: tempMultipartURL)
        defer {
            try? fileHandle.close()
            try? FileManager.default.removeItem(at: tempMultipartURL)
        }
        
        // Part 1: Metadata
        try fileHandle.write(contentsOf: "--\(boundary)\r\n".data(using: .utf8)!)
        try fileHandle.write(contentsOf: "Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        
        let fileMetadata: [String: Any] = [
            "file": [
                "displayName": fileURL.lastPathComponent,
                "mimeType": "video/mp4"
            ]
        ]
        
        let metadataData = try JSONSerialization.data(withJSONObject: fileMetadata)
        try fileHandle.write(contentsOf: metadataData)
        try fileHandle.write(contentsOf: "\r\n".data(using: .utf8)!)
        
        // Part 2: Binary File Data
        try fileHandle.write(contentsOf: "--\(boundary)\r\n".data(using: .utf8)!)
        try fileHandle.write(contentsOf: "Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        
        let sourceHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? sourceHandle.close()
        }
        
        let bufferSize = 1024 * 1024 // 1MB buffer
        while let chunk = try sourceHandle.read(upToCount: bufferSize), !chunk.isEmpty {
            try fileHandle.write(contentsOf: chunk)
        }
        
        try fileHandle.write(contentsOf: "\r\n".data(using: .utf8)!)
        
        // End Boundary
        try fileHandle.write(contentsOf: "--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Close the handle before uploading so all contents are written
        try fileHandle.close()
        
        // Stream the upload from the temp file
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: tempMultipartURL)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorDict = errorJson["error"] as? [String: Any],
               let errorMessage = errorDict["message"] as? String {
                throw GeminiError.apiError(errorMessage)
            }
            throw GeminiError.apiError("Upload failed with status code: \(httpResponse.statusCode)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fileInfo = json["file"] as? [String: Any],
              let name = fileInfo["name"] as? String,
              let uri = fileInfo["uri"] as? String else {
            throw GeminiError.invalidResponse
        }
        
        return (name: name, uri: uri)
    }
    
    // Polls file status until the file status is "ACTIVE" or fails
    static func pollFileStatus(fileName: String, apiKey: String) async throws -> String {
        let statusURLString = "https://generativelanguage.googleapis.com/v1beta/\(fileName)?key=\(apiKey)"
        guard let url = URL(string: statusURLString) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        var sleepInterval: UInt64 = 500_000_000 // Start with 0.5 seconds
        
        // Poll up to 120 times (3 minutes maximum with backoff)
        for _ in 0..<120 {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw GeminiError.apiError("Failed to check file status: \(httpResponse.statusCode)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw GeminiError.invalidResponse
            }
            
            if let state = json["state"] as? String {
                if state == "ACTIVE" {
                    if let uri = json["uri"] as? String {
                        return uri
                    }
                    throw GeminiError.invalidResponse
                } else if state == "FAILED" {
                    throw GeminiError.fileProcessingFailed
                }
            }
            
            try await Task.sleep(nanoseconds: sleepInterval)
            // Linear backoff up to 1.5 seconds
            if sleepInterval < 1_500_000_000 {
                sleepInterval += 500_000_000
            }
        }
        
        throw GeminiError.apiError("Timeout waiting for file to process.")
    }
    
    // Sends the prompt text along with the file URIs to Gemini content generation API
    static func generateContent(apiKey: String, fileURIs: [String], promptText: String, systemInstruction: String? = nil) async throws -> String {
        let generateURLString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: generateURLString) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Construct standard request JSON body
        var parts: [[String: Any]] = []
        
        // Add file parts
        for fileUri in fileURIs {
            parts.append([
                "fileData": [
                    "mimeType": "video/mp4",
                    "fileUri": fileUri
                ]
            ])
        }
        
        // Add text prompt part
        parts.append([
            "text": promptText
        ])
        
        var requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": parts
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.1,
                "responseSchema": [
                    "type": "OBJECT",
                    "properties": [
                        "clips": [
                            "type": "ARRAY",
                            "items": [
                                "type": "OBJECT",
                                "properties": [
                                    "video_index": ["type": "INTEGER"],
                                    "start_time": ["type": "NUMBER"],
                                    "end_time": ["type": "NUMBER"],
                                    "placement_order": ["type": "INTEGER"]
                                ],
                                "required": ["video_index", "start_time", "end_time", "placement_order"]
                            ]
                        ]
                    ],
                    "required": ["clips"]
                ]
            ]
        ]
        
        if let systemInstruction = systemInstruction {
            requestBody["systemInstruction"] = [
                "parts": [
                    ["text": systemInstruction]
                ]
            ]
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = bodyData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorDict = errorJson["error"] as? [String: Any],
               let errorMessage = errorDict["message"] as? String {
                throw GeminiError.apiError(errorMessage)
            }
            throw GeminiError.apiError("Content generation failed with status code: \(httpResponse.statusCode)")
        }
        
        // Decode candidate text response
        let apiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = apiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }
        
        return text
    }
    
    // Validates an API key using the lightweight GET /v1beta/models endpoint.
    // This is the correct way to check key validity: no tokens consumed, no model-availability
    // edge cases, and a clean 200 vs 400/403 response for valid vs invalid keys.
    static func validateAPIKey(_ apiKey: String) async throws {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)&pageSize=1"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            return // Key is valid
        case 400, 401, 403:
            // Extract the API error message if present for a clearer user-facing error
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorDict = errorJson["error"] as? [String: Any],
               let message = errorDict["message"] as? String {
                throw GeminiError.apiError(message)
            }
            throw GeminiError.invalidAPIKey
        default:
            // Surface the actual HTTP status to help with debugging unexpected failures
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorDict = errorJson["error"] as? [String: Any],
               let message = errorDict["message"] as? String {
                throw GeminiError.apiError(message)
            }
            throw GeminiError.apiError("Could not reach Gemini API (HTTP \(httpResponse.statusCode)). Check your connection and try again.")
        }
    }
}

// Swift models for decoding the generateContent response
struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String?
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}
