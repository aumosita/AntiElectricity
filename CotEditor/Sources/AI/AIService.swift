//
//  AIService.swift
//
//  AntiElectricity
//  https://github.com/lyon/AntiElectricity
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


/// Coordinates AI command execution between the editor and LLM providers.
@MainActor @Observable
final class AIService {
    
    static let shared = AIService()
    
    var isProcessing = false
    var lastError: String?
    
    /// The current LLM provider.
    private(set) var provider: any LLMProvider
    
    /// The model to use.
    var model: String {
        get { UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3.2" }
        set { UserDefaults.standard.set(newValue, forKey: "ollamaModel") }
    }
    
    
    private init() {
        
        let urlString = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        let url = URL(string: urlString) ?? URL(string: "http://localhost:11434")!
        self.provider = OllamaProvider(baseURL: url)
    }
    
    
    /// Updates the Ollama server URL.
    func updateOllamaURL(_ urlString: String) {
        
        guard let url = URL(string: urlString) else { return }
        
        UserDefaults.standard.set(urlString, forKey: "ollamaURL")
        self.provider = OllamaProvider(baseURL: url)
    }
    
    
    /// Executes an AI command on the given text.
    ///
    /// - Parameters:
    ///   - command: The AI command to execute.
    ///   - text: The input text.
    ///   - syntaxName: The current syntax name (for code-related commands).
    /// - Returns: The AI result.
    func execute(command: AICommand, text: String, syntaxName: String? = nil) async throws -> AIResult {
        
        self.isProcessing = true
        self.lastError = nil
        
        defer { self.isProcessing = false }
        
        // Build the prompt with optional syntax context
        var prompt = text
        if let syntaxName, command.id.hasPrefix("builtin.code") {
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
    ///
    /// - Parameters:
    ///   - userPrompt: The user's custom instruction.
    ///   - text: The input text.
    /// - Returns: The AI result.
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
}
