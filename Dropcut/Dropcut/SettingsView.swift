//
//  SettingsView.swift
//  Dropcut
//
//  Created by Antigravity on 6/9/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var isSecure: Bool = true
    @State private var showSaveConfirmation: Bool = false
    @State private var isValidating: Bool = false
    @State private var validationErrorMessage: String? = nil
    @State private var showValidationError: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Harmonious background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 28) {
                    // Title section
                    VStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient.themeGradient(startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .shadow(color: .themePrimary.opacity(0.2), radius: 10, x: 0, y: 5)
                            .padding(.top, 20)

                        Text("Gemini API Configuration")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("Configure your personal Gemini API key. It is saved locally on your device and never shared elsewhere.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Input Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        HStack {
                            if isSecure {
                                SecureField("AIzaSy...", text: $apiKey)
                                    .font(.body)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            } else {
                                TextField("AIzaSy...", text: $apiKey)
                                    .font(.body)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }

                            Button(action: {
                                isSecure.toggle()
                            }) {
                                Image(systemName: isSecure ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)

                    // Instructions to get key
                    Link(destination: URL(string: "https://aistudio.google.com/")!) {
                        HStack(spacing: 6) {
                            Text("Get a Gemini API Key from Google AI Studio")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                    }

                    Spacer()

                    // Save Button
                    Button(action: {
                        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        isValidating = true
                        Task {
                            do {
                                try await GeminiService.validateAPIKey(trimmedKey)
                                UserDefaults.standard.set(trimmedKey, forKey: "GeminiAPIKey")
                                await MainActor.run {
                                    isValidating = false
                                    withAnimation {
                                        showSaveConfirmation = true
                                    }
                                }
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                await MainActor.run {
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    isValidating = false
                                    validationErrorMessage = error.localizedDescription
                                    showValidationError = true
                                }
                            }
                        }
                    }) {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                                Text("Validating…")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            } else if showSaveConfirmation {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.headline)
                                Text("Saved Successfully!")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            } else {
                                Text("Save Key")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            showSaveConfirmation
                                ? AnyView(Color.green)
                                : AnyView(LinearGradient.themeGradient)
                        )
                        .cornerRadius(16)
                        .shadow(color: showSaveConfirmation ? .green.opacity(0.3) : .themePrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating || showSaveConfirmation)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isValidating)
                }
            }
            .onAppear {
                apiKey = UserDefaults.standard.string(forKey: "GeminiAPIKey") ?? ""
            }
            .alert("Invalid API Key", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationErrorMessage ?? "The API key could not be verified. Please check it and try again.")
            }
        }
    }
}

#Preview {
    SettingsView()
}
