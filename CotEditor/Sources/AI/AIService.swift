//
//  AIService.swift
//
//  AntiElectricity
//  https://github.com/aumosita/AntiElectricity
//
//  Created by AntiElectricity on 2026-03-08.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

/// The result of an AI command execution.
struct AIResult: Sendable {
    
    /// The command that was executed.
    let command: AICommand
    
    /// The original input text.
    let originalText: String
    
    /// The AI-generated result text.
    let resultText: String
    
    /// The model used.
    let model: String
}


/// Supported AI provider types.
enum AIProviderType: String, CaseIterable, Sendable {
    
    case ollama = "Ollama"
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case copilot = "GitHub Copilot"
}


/// Coordinates AI command execution between the editor and LLM providers.
@MainActor @Observable
final class AIService {
    
    static let shared = AIService()
    
    var isProcessing = false
    var lastError: String?
    
    /// The current LLM provider.
    private(set) var provider: any LLMProvider
    
    /// The active provider type.
    private(set) var providerType: AIProviderType
    
    /// The model to use.
    var model: String {
        get {
            let key = "\(self.providerType.rawValue)_model"
            return UserDefaults.standard.string(forKey: key) ?? ""
        }
        set {
            let key = "\(self.providerType.rawValue)_model"
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
    
    
    private init() {
        
        let savedType = UserDefaults.standard.string(forKey: "aiProviderType")
            .flatMap(AIProviderType.init(rawValue:)) ?? .ollama
        
        self.providerType = savedType
        self.provider = Self.createProvider(type: savedType)
    }
    
    
    // MARK: Provider Management
    
    /// Switches to the specified provider type.
    func switchProvider(to type: AIProviderType) {
        
        self.providerType = type
        UserDefaults.standard.set(type.rawValue, forKey: "aiProviderType")
        self.provider = Self.createProvider(type: type)
    }
    
    
    /// Updates the Ollama server URL.
    func updateOllamaURL(_ urlString: String) {
        
        guard let url = URL(string: urlString) else { return }
        
        UserDefaults.standard.set(urlString, forKey: "ollamaURL")
        
        if self.providerType == .ollama {
            self.provider = OllamaProvider(baseURL: url)
        }
    }
    
    
    /// Updates the Anthropic API key.
    func updateAnthropicAPIKey(_ key: String) {
        
        UserDefaults.standard.set(key, forKey: "anthropicAPIKey")
        
        if self.providerType == .anthropic {
            self.provider = AnthropicProvider(apiKey: key)
        }
    }
    
    
    /// Updates the OpenAI API key.
    func updateOpenAIAPIKey(_ key: String) {
        
        UserDefaults.standard.set(key, forKey: "openaiAPIKey")
        
        if self.providerType == .openai {
            self.provider = OpenAIProvider(apiKey: key)
        }
    }
    
    
    /// Updates the GitHub Copilot token.
    func updateCopilotToken(_ token: String) {
        
        UserDefaults.standard.set(token, forKey: "copilotGitHubToken")
        
        if self.providerType == .copilot {
            self.provider = CopilotProvider(githubToken: token)
        }
    }
    
    
    // MARK: Execution
    
    /// Executes an AI command on the given text.
    func execute(command: AICommand, text: String, syntaxName: String? = nil) async throws -> AIResult {
        
        self.isProcessing = true
        self.lastError = nil
        
        defer { self.isProcessing = false }
        
        var prompt = text
        if let syntaxName, command.id.hasPrefix("example.code") {
            prompt = "Language: \(syntaxName)\n\n\(text)"
        }
        
        do {
            let response = try await self.provider.send(
                prompt: prompt,
                systemPrompt: command.systemPrompt,
                model: self.model
            )
            
            return AIResult(
                command: command,
                originalText: text,
                resultText: response.content,
                model: response.model
            )
        } catch {
            self.lastError = error.localizedDescription
            throw error
        }
    }
    
    
    /// Executes a free-form prompt on the given text.
    func executeFreePrompt(_ userPrompt: String, text: String) async throws -> AIResult {
        
        let command = AICommand(
            id: "freeform",
            label: String(localized: "Free Prompt", table: "AI"),
            systemPrompt: userPrompt
        )
        
        return try await self.execute(command: command, text: text)
    }
    
    
    /// Fetches available models from the provider.
    func fetchModels() async throws -> [String] {
        
        try await self.provider.availableModels()
    }
    
    
    /// Tests the connection to the current provider.
    func testConnection() async -> Bool {
        
        await self.provider.testConnection()
    }
    
    
    // MARK: Private
    
    private static func createProvider(type: AIProviderType) -> any LLMProvider {
        
        switch type {
            case .ollama:
                let urlString = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
                let url = URL(string: urlString) ?? URL(string: "http://localhost:11434")!
                return OllamaProvider(baseURL: url)
                
            case .anthropic:
                let apiKey = UserDefaults.standard.string(forKey: "anthropicAPIKey") ?? ""
                return AnthropicProvider(apiKey: apiKey)
                
            case .openai:
                let apiKey = UserDefaults.standard.string(forKey: "openaiAPIKey") ?? ""
                return OpenAIProvider(apiKey: apiKey)
                
            case .copilot:
                let token = UserDefaults.standard.string(forKey: "copilotGitHubToken") ?? ""
                return CopilotProvider(githubToken: token)
        }
    }
}
