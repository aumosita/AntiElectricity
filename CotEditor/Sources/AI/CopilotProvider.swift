//
//  CopilotProvider.swift
//
//  AntiElectricity
//  https://github.com/aumosita/AntiElectricity
//
//  Created by Yong Lee on 2026-03-08.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

/// An LLM provider that connects to GitHub Copilot via OAuth Device Flow.
struct CopilotProvider: LLMProvider {
    
    let name = "GitHub Copilot"
    
    /// The GitHub access token obtained via OAuth.
    let githubToken: String
    
    /// Copilot's OAuth client_id (public, same for all users).
    static let clientId = "Iv1.b507a08c87ecfe98"
    
    
    // MARK: - LLMProvider
    
    func availableModels() async throws -> [String] {
        
        // Copilot models available through the API
        [
            "gpt-4o",
            "gpt-4o-mini",
            "claude-3.5-sonnet",
            "o3-mini",
        ]
    }
    
    
    func send(prompt: String, systemPrompt: String, model: String) async throws -> LLMResponse {
        
        // Step 1: Exchange GitHub token for Copilot token
        let copilotToken = try await self.getCopilotToken()
        
        // Step 2: Send chat completion request
        let url = URL(string: "https://api.githubcopilot.com/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(copilotToken)", forHTTPHeaderField: "Authorization")
        request.setValue("vscode/1.96.0", forHTTPHeaderField: "Editor-Version")
        request.setValue("vscode", forHTTPHeaderField: "Editor-Plugin-Version")
        request.setValue("copilot-chat", forHTTPHeaderField: "Copilot-Integration-Id")
        request.setValue("AntiElectricity", forHTTPHeaderField: "X-Request-Id")
        request.timeoutInterval = 120
        
        let body = CopilotChatRequest(
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
        
        let result = try JSONDecoder().decode(CopilotChatResponse.self, from: data)
        
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
        
        guard !self.githubToken.isEmpty else { return false }
        
        do {
            _ = try await self.getCopilotToken()
            return true
        } catch {
            return false
        }
    }
    
    
    // MARK: - Token Exchange
    
    /// Exchanges the GitHub OAuth token for a Copilot API token.
    private func getCopilotToken() async throws -> String {
        
        let url = URL(string: "https://api.github.com/copilot_internal/v2/token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.githubToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AntiElectricity/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw LLMError.connectionFailed("Failed to get Copilot token. Is your GitHub Copilot subscription active?")
        }
        
        let tokenResponse = try JSONDecoder().decode(CopilotTokenResponse.self, from: data)
        return tokenResponse.token
    }
    
    
    // MARK: - OAuth Device Flow
    
    /// Initiates the GitHub OAuth Device Flow.
    ///
    /// - Returns: A tuple of (deviceCode, userCode, verificationURI, interval).
    static func startDeviceFlow() async throws -> DeviceFlowResponse {
        
        let url = URL(string: "https://github.com/login/device/code")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let body = ["client_id": clientId, "scope": "copilot"]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(DeviceFlowResponse.self, from: data)
    }
    
    
    /// Polls for the OAuth access token after user authorization.
    ///
    /// - Parameters:
    ///   - deviceCode: The device code from the device flow.
    ///   - interval: The polling interval in seconds.
    /// - Returns: The GitHub access token.
    static func pollForToken(deviceCode: String, interval: Int) async throws -> String {
        
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        
        while true {
            try await Task.sleep(for: .seconds(interval))
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let body: [String: String] = [
                "client_id": clientId,
                "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            ]
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
            
            if let token = response.accessToken {
                return token
            }
            
            if response.error == "expired_token" || response.error == "access_denied" {
                throw LLMError.connectionFailed("Authorization \(response.error ?? "failed")")
            }
            
            // "authorization_pending" or "slow_down" — keep polling
            if response.error == "slow_down" {
                try await Task.sleep(for: .seconds(5))
            }
        }
    }
}


// MARK: - API Types

struct DeviceFlowResponse: Decodable {
    
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int
    
    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}


private struct OAuthTokenResponse: Decodable {
    
    let accessToken: String?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case error
    }
}


private struct CopilotTokenResponse: Decodable {
    
    let token: String
}


private struct CopilotChatRequest: Encodable {
    
    let model: String
    let messages: [Message]
    let stream: Bool
    
    struct Message: Encodable {
        let role: String
        let content: String
    }
}


private struct CopilotChatResponse: Decodable {
    
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
