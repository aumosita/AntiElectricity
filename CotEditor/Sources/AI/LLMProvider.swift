//
//  LLMProvider.swift
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

/// A response from an LLM provider.
struct LLMResponse: Sendable {
    
    /// The generated text content.
    let content: String
    
    /// The model used for generation.
    let model: String
    
    /// Total tokens used (if available).
    let totalTokens: Int?
}


/// An error that can occur during LLM operations.
enum LLMError: LocalizedError {
    
    case connectionFailed(String)
    case invalidResponse(String)
    case modelNotFound(String)
    case requestFailed(Int, String)
    
    var errorDescription: String? {
        switch self {
            case .connectionFailed(let detail):
                String(localized: "LLM connection failed: \(detail)", table: "AI")
            case .invalidResponse(let detail):
                String(localized: "Invalid LLM response: \(detail)", table: "AI")
            case .modelNotFound(let model):
                String(localized: "Model not found: \(model)", table: "AI")
            case .requestFailed(let status, let detail):
                String(localized: "LLM request failed (\(status)): \(detail)", table: "AI")
        }
    }
}


/// A protocol that abstracts LLM providers (Ollama, OpenAI, Claude, etc.).
protocol LLMProvider: Sendable {
    
    /// The display name of this provider.
    var name: String { get }
    
    /// Fetches the list of available models.
    func availableModels() async throws -> [String]
    
    /// Sends a prompt and returns the completed response.
    ///
    /// - Parameters:
    ///   - prompt: The user's input text.
    ///   - systemPrompt: The system instruction for the LLM.
    ///   - model: The model identifier to use.
    /// - Returns: The LLM response.
    func send(prompt: String, systemPrompt: String, model: String) async throws -> LLMResponse
    
    /// Tests the connection to the provider.
    ///
    /// - Returns: `true` if the connection is successful.
    func testConnection() async -> Bool
}
