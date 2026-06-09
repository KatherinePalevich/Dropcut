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
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .apiError(let message):
            return message
        case .invalidResponse:
            return "Received an invalid response from the Gemini API."
        case .fileProcessingFailed:
            return "Gemini failed to process the video files."
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
        
        // Build multipart/related body
        var body = Data()
        
        // Part 1: Metadata
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        
        let fileMetadata: [String: Any] = [
            "file": [
                "displayName": fileURL.lastPathComponent,
                "mimeType": "video/mp4"
            ]
        ]
        
        let metadataData = try JSONSerialization.data(withJSONObject: fileMetadata)
        body.append(metadataData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Part 2: Binary File Data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        
        let fileData = try Data(contentsOf: fileURL)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End Boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
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
        
        // Poll every 1.5 seconds up to 40 times (60 seconds max)
        for _ in 0..<40 {
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
            
            // Wait 1.5 seconds before polling again
            try await Task.sleep(nanoseconds: 1_500_000_000)
        }
        
        throw GeminiError.apiError("Timeout waiting for file to process.")
    }
    
    // Sends the prompt text along with the file URIs to Gemini content generation API
    static func generateContent(apiKey: String, fileURIs: [String], promptText: String) async throws -> String {
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
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": parts
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]
        
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
