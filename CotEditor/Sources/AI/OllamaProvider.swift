//
//  OllamaProvider.swift
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

/// An LLM provider that connects to a local Ollama instance.
struct OllamaProvider: LLMProvider {
    
    let name = "Ollama"
    
    /// The base URL of the Ollama server.
    let baseURL: URL
    
    
    /// Creates a new Ollama provider.
    ///
    /// - Parameter baseURL: The URL of the Ollama server. Defaults to `http://localhost:11434`.
    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        
        self.baseURL = baseURL
    }
    
    
    func availableModels() async throws -> [String] {
        
        let url = self.baseURL.appendingPathComponent("/api/tags")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.connectionFailed("Invalid response type")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LLMError.requestFailed(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        
        let result = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        
        return result.models.map(\.name)
    }
    
    
    func send(prompt: String, systemPrompt: String, model: String) async throws -> LLMResponse {
        
        let url = self.baseURL.appendingPathComponent("/api/chat")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120  // LLM can take time
        
        let body = OllamaChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: prompt),
            ],
            stream: false
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.connectionFailed("Invalid response type")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.requestFailed(httpResponse.statusCode, errorBody)
        }
        
        let result = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        
        guard let content = result.message?.content, !content.isEmpty else {
            throw LLMError.invalidResponse("Empty response content")
        }
        
        return LLMResponse(
            content: content,
            model: result.model,
            totalTokens: result.evalCount
        )
    }
    
    
    func testConnection() async -> Bool {
        
        let url = self.baseURL.appendingPathComponent("/api/tags")
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}


// MARK: - Ollama API Types

private struct OllamaChatRequest: Encodable {
    
    let model: String
    let messages: [Message]
    let stream: Bool
    
    struct Message: Encodable {
        let role: String
        let content: String
    }
}


private struct OllamaChatResponse: Decodable {
    
    let model: String
    let message: Message?
    let evalCount: Int?
    
    struct Message: Decodable {
        let role: String
        let content: String
    }
    
    enum CodingKeys: String, CodingKey {
        case model
        case message
        case evalCount = "eval_count"
    }
}


private struct OllamaTagsResponse: Decodable {
    
    let models: [Model]
    
    struct Model: Decodable {
        let name: String
    }
}
