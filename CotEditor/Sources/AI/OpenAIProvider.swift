//
//  OpenAIProvider.swift
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

/// An LLM provider that connects to the OpenAI Chat Completions API.
struct OpenAIProvider: LLMProvider {
    
    let name = "OpenAI"
    
    /// The API key for authentication.
    let apiKey: String
    
    /// The base URL of the OpenAI API.
    let baseURL: URL
    
    
    /// Creates a new OpenAI provider.
    ///
    /// - Parameters:
    ///   - apiKey: The OpenAI API key.
    ///   - baseURL: The API base URL. Defaults to `https://api.openai.com`.
    init(apiKey: String, baseURL: URL = URL(string: "https://api.openai.com")!) {
        
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    
    func availableModels() async throws -> [String] {
        
        // Fetch models from the API
        let url = self.baseURL.appendingPathComponent("v1/models")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200
            else {
                // Fallback to hardcoded list
                return Self.defaultModels
            }
            
            let result = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
            
            // Filter to chat-capable models and sort
            let chatModels = result.data
                .map(\.id)
                .filter { id in
                    id.hasPrefix("gpt-") || id.hasPrefix("o") || id.contains("codex")
                }
                .sorted()
            
            return chatModels.isEmpty ? Self.defaultModels : chatModels
        } catch {
            return Self.defaultModels
        }
    }
    
    
    func send(messages: [AIChatMessage], systemPrompt: String, model: String) async throws -> LLMResponse {
        
        let url = self.baseURL.appendingPathComponent("v1/chat/completions")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120
        
        var requestMessages: [OpenAIChatRequest.Message] = [
            .init(role: "system", content: systemPrompt)
        ]
        
        for msg in messages {
            let roleStr: String = {
                switch msg.role {
                    case .user: return "user"
                    case .assistant: return "assistant"
                    case .system: return "system"
                }
            }()
            requestMessages.append(.init(role: roleStr, content: msg.content))
        }
        
        let body = OpenAIChatRequest(
            model: model,
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
        
        let result = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        
        guard let choice = result.choices.first else {
            throw LLMError.invalidResponse("No choices in response")
        }
        
        return LLMResponse(
            content: choice.message.content,
            model: result.model,
            totalTokens: result.usage.map { $0.totalTokens }
        )
    }
    
    
    func testConnection() async -> Bool {
        
        guard !self.apiKey.isEmpty else { return false }
        
        do {
            _ = try await self.send(
                messages: [.init(role: .user, content: "Hi")],
                systemPrompt: "Reply with just 'ok'",
                model: "gpt-4o-mini"
            )
            return true
        } catch {
            return false
        }
    }
    
    
    // MARK: Private
    
    private static let defaultModels = [
        "gpt-5.4",
        "gpt-5.1",
        "gpt-5.1-codex",
        "gpt-5.1-codex-mini",
        "gpt-4.1",
        "gpt-4.1-mini",
        "gpt-4o",
        "gpt-4o-mini",
        "o4-mini",
        "o3-pro",
        "o3",
    ]
}


// MARK: - OpenAI API Types

private struct OpenAIModelsResponse: Decodable {
    
    let data: [Model]
    
    struct Model: Decodable {
        let id: String
    }
}


private struct OpenAIChatRequest: Encodable {
    
    let model: String
    let messages: [Message]
    
    struct Message: Encodable {
        let role: String
        let content: String
    }
}


private struct OpenAIChatResponse: Decodable {
    
    let model: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Decodable {
        let message: Message
        
        struct Message: Decodable {
            let content: String
        }
    }
    
    struct Usage: Decodable {
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case totalTokens = "total_tokens"
        }
    }
}
