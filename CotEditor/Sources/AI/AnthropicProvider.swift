//
//  AnthropicProvider.swift
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

/// An LLM provider that connects to the Anthropic Messages API.
struct AnthropicProvider: LLMProvider {
    
    let name = "Anthropic"
    
    /// The API key for authentication.
    let apiKey: String
    
    /// The base URL of the Anthropic API.
    let baseURL: URL
    
    /// The API version header.
    private let apiVersion = "2023-06-01"
    
    
    /// Creates a new Anthropic provider.
    ///
    /// - Parameters:
    ///   - apiKey: The Anthropic API key.
    ///   - baseURL: The API base URL. Defaults to `https://api.anthropic.com`.
    init(apiKey: String, baseURL: URL = URL(string: "https://api.anthropic.com")!) {
        
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    
    func availableModels() async throws -> [String] {
        
        // Anthropic doesn't provide a models list API; return latest models
        [
            "claude-sonnet-4-6-20250627",
            "claude-opus-4-6-20250627",
            "claude-haiku-4-5-20250627",
        ]
    }
    
    
    func send(messages: [AIChatMessage], systemPrompt: String, model: String) async throws -> LLMResponse {
        
        let url = self.baseURL.appendingPathComponent("v1/messages")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 120
        
        var requestMessages: [AnthropicRequest.Message] = []
        
        for msg in messages {
            let roleStr = msg.role == .assistant ? "assistant" : "user" // Map system messages to user
            requestMessages.append(.init(role: roleStr, content: msg.content))
        }
        
        let body = AnthropicRequest(
            model: model,
            maxTokens: 4096,
            system: systemPrompt,
            messages: requestMessages
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
        
        let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        
        guard let textBlock = result.content.first(where: { $0.type == "text" }),
              !textBlock.text.isEmpty
        else {
            throw LLMError.invalidResponse("Empty response content")
        }
        
        return LLMResponse(
            content: textBlock.text,
            model: result.model,
            totalTokens: result.usage.map { $0.inputTokens + $0.outputTokens }
        )
    }
    
    
    func testConnection() async -> Bool {
        
        guard !self.apiKey.isEmpty else { return false }
        
        do {
            _ = try await self.send(
                messages: [.init(role: .user, content: "Hi")],
                systemPrompt: "Reply with just 'ok'",
                model: "claude-3-5-haiku-20241022"
            )
            return true
        } catch {
            return false
        }
    }
}


// MARK: - Anthropic API Types

private struct AnthropicRequest: Encodable {
    
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]
    
    struct Message: Encodable {
        let role: String
        let content: String
    }
    
    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}


private struct AnthropicResponse: Decodable {
    
    let model: String
    let content: [ContentBlock]
    let usage: Usage?
    
    struct ContentBlock: Decodable {
        let type: String
        let text: String
    }
    
    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
}
