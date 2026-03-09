//
//  ClaudeOAuthProvider.swift
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

import AppKit
import CryptoKit
import Foundation
import Security


/// An LLM provider that uses Claude Pro/Max subscription via OAuth PKCE flow.
///
/// This provider replicates the authentication flow used by Claude Code CLI,
/// allowing users to access the Anthropic Messages API using their existing
/// Claude Pro or Max subscription instead of a separate API key.
///
/// - Important: This is an experimental feature. Anthropic's terms of service
///   prohibit using OAuth tokens outside of Claude Code. Use at your own risk.
struct ClaudeOAuthProvider: LLMProvider {
    
    let name = "Claude (OAuth)"
    
    // MARK: OAuth Constants
    
    /// The OAuth client ID (same as Claude Code CLI).
    static let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    
    /// The authorization endpoint on claude.ai.
    static let authorizationURL = "https://claude.ai/oauth/authorize"
    
    /// The token exchange endpoint on Anthropic's API.
    static let tokenURL = "https://api.anthropic.com/oauth/token"
    
    /// The Messages API base URL.
    static let apiBaseURL = URL(string: "https://api.anthropic.com")!
    
    /// The OAuth scope for API access (matches Claude Code CLI).
    static let scope = "org:create_api_key user:profile user:inference"
    
    /// The local redirect URI for catching the OAuth callback.
    /// Uses port 0 to let the OS assign a random available port.
    private static func makeRedirectURI(port: UInt16) -> String {
        "http://localhost:\(port)/callback"
    }
    
    /// The Keychain service identifier.
    private static let keychainService = "com.antielectricity.claude-oauth"
    
    /// The anthropic-beta header required for OAuth token authentication.
    private static let oauthBetaHeader = "oauth-2025-04-20"
    
    /// The API version header.
    private static let apiVersion = "2023-06-01"
    
    /// Stored PKCE code verifier for manual code exchange.
    private static var pendingCodeVerifier: String?
    private static var pendingRedirectURI: String?
    
    
    // MARK: - LLMProvider
    
    func availableModels() async throws -> [String] {
        
        // Models available on Claude Pro/Max subscription
        [
            "claude-sonnet-4-6",
            "claude-opus-4-6",
            "claude-sonnet-4",
            "claude-haiku-3-5",
        ]
    }
    
    
    func send(messages: [AIChatMessage], systemPrompt: String, model: String) async throws -> LLMResponse {
        
        // Get a valid access token (refresh if needed)
        let accessToken = try await Self.getValidAccessToken()
        
        NSLog("[ClaudeOAuth] Token prefix: %@", String(accessToken.prefix(20)))
        
        // Claude Code CLI uses ?beta=true query parameter
        var urlComponents = URLComponents(url: Self.apiBaseURL.appendingPathComponent("v1/messages"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "beta", value: "true")]
        let url = urlComponents.url!
        
        NSLog("[ClaudeOAuth] Request URL: %@", url.absoluteString)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Try both auth methods: x-api-key AND Authorization Bearer
        request.setValue(accessToken, forHTTPHeaderField: "x-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 120
        
        var requestMessages: [ClaudeOAuthRequest.Message] = []
        
        for msg in messages {
            let roleStr = msg.role == .assistant ? "assistant" : "user" // Map system messages to user
            requestMessages.append(.init(role: roleStr, content: msg.content))
        }
        
        let body = ClaudeOAuthRequest(
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
        
        // If unauthorized, try refreshing the token once
        if httpResponse.statusCode == 401 {
            let refreshedToken = try await Self.refreshAccessToken()
            
            var retryRequest = request
            retryRequest.setValue(refreshedToken, forHTTPHeaderField: "x-api-key")
            
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            
            guard let retryHttp = retryResponse as? HTTPURLResponse else {
                throw LLMError.connectionFailed("Invalid response type on retry")
            }
            
            guard retryHttp.statusCode == 200 else {
                let errorBody = String(data: retryData, encoding: .utf8) ?? "Unknown error"
                throw LLMError.requestFailed(retryHttp.statusCode, errorBody)
            }
            
            return try Self.parseResponse(retryData)
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.requestFailed(httpResponse.statusCode, errorBody)
        }
        
        return try Self.parseResponse(data)
    }
    
    
    func testConnection() async -> Bool {
        
        guard Self.loadTokens() != nil else { return false }
        
        do {
            _ = try await self.send(
                messages: [.init(role: .user, content: "Hi")],
                systemPrompt: "Reply with just 'ok'",
                model: "claude-haiku-3-5"
            )
            return true
        } catch {
            return false
        }
    }
    
    
    // MARK: - OAuth Flow
    
    /// OAuth flow result containing everything needed for the flow.
    struct OAuthFlowParams {
        let authURL: URL
        let codeVerifier: String
        let redirectURI: String
        let state: String
    }
    
    
    /// Prepares the OAuth PKCE parameters and returns the authorization URL.
    ///
    /// This does NOT open the browser or start any servers.
    /// The caller is responsible for opening the URL.
    static func prepareOAuthFlow() -> OAuthFlowParams {
        
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let state = UUID().uuidString
        
        // Use a fixed well-known port that's more likely to work
        let port: UInt16 = 18923
        let redirectURI = makeRedirectURI(port: port)
        
        // Store for manual code exchange
        Self.pendingCodeVerifier = codeVerifier
        Self.pendingRedirectURI = redirectURI
        
        // Build authorization URL
        var components = URLComponents(string: authorizationURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        
        return OAuthFlowParams(
            authURL: components.url!,
            codeVerifier: codeVerifier,
            redirectURI: redirectURI,
            state: state
        )
    }
    
    
    /// Starts a local server and waits for the OAuth redirect callback.
    ///
    /// - Returns: The authorization code, or nil if the server couldn't start.
    static func waitForCallback(params: OAuthFlowParams) async -> String? {
        
        let serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { return nil }
        
        var yes: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(18923).bigEndian
        addr.sin_addr.s_addr = UInt32(INADDR_LOOPBACK).bigEndian
        
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult == 0 else {
            close(serverSocket)
            return nil
        }
        
        guard listen(serverSocket, 1) == 0 else {
            close(serverSocket)
            return nil
        }
        
        // Set a timeout (180 seconds)
        var timeout = timeval(tv_sec: 180, tv_usec: 0)
        setsockopt(serverSocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        
        return await withCheckedContinuation { continuation in
            Task.detached {
                defer { close(serverSocket) }
                
                var clientAddr = sockaddr_in()
                var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                
                let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        accept(serverSocket, $0, &clientAddrLen)
                    }
                }
                
                guard clientSocket >= 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                
                defer { close(clientSocket) }
                
                var buffer = [UInt8](repeating: 0, count: 4096)
                let bytesRead = recv(clientSocket, &buffer, buffer.count, 0)
                
                guard bytesRead > 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let requestString = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""
                
                guard let requestLine = requestString.components(separatedBy: "\r\n").first,
                      let urlPath = requestLine.components(separatedBy: " ").dropFirst().first,
                      let fullURL = URL(string: "http://localhost\(urlPath)"),
                      let queryItems = URLComponents(url: fullURL, resolvingAgainstBaseURL: false)?.queryItems
                else {
                    Self.sendHTTPResponse(to: clientSocket, success: false)
                    continuation.resume(returning: nil)
                    return
                }
                
                // Validate state
                let receivedState = queryItems.first(where: { $0.name == "state" })?.value
                guard receivedState == params.state else {
                    Self.sendHTTPResponse(to: clientSocket, success: false)
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
                    Self.sendHTTPResponse(to: clientSocket, success: false)
                    continuation.resume(returning: nil)
                    return
                }
                
                Self.sendHTTPResponse(to: clientSocket, success: true)
                continuation.resume(returning: code)
            }
        }
    }
    
    
    /// Completes the OAuth flow by exchanging the authorization code for tokens.
    static func completeOAuthFlow(code: String, params: OAuthFlowParams) async throws {
        
        let tokens = try await exchangeCodeForTokens(
            code: code,
            codeVerifier: params.codeVerifier,
            redirectURI: params.redirectURI
        )
        
        try Self.saveTokens(tokens)
        Self.pendingCodeVerifier = nil
        Self.pendingRedirectURI = nil
    }
    
    
    /// Exchanges a manually-pasted authorization code for tokens.
    ///
    /// Use this when the automatic redirect doesn't work and the user
    /// copies the code from the browser.
    static func exchangeManualCode(_ code: String) async throws -> Bool {
        
        guard let codeVerifier = pendingCodeVerifier,
              let redirectURI = pendingRedirectURI
        else {
            throw LLMError.connectionFailed("No pending OAuth flow. Please start sign-in first.")
        }
        
        let tokens = try await exchangeCodeForTokens(
            code: code,
            codeVerifier: codeVerifier,
            redirectURI: redirectURI
        )
        
        try Self.saveTokens(tokens)
        Self.pendingCodeVerifier = nil
        Self.pendingRedirectURI = nil
        
        return true
    }
    
    
    /// Sends a simple HTTP response to the OAuth redirect browser tab.
    private static func sendHTTPResponse(to socket: Int32, success: Bool) {
        
        let body: String
        if success {
            body = """
                <html><body style="font-family:system-ui;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:#1a1a2e;color:#e0e0e0">
                <div style="text-align:center">
                <h1 style="color:#a855f7">✓ Authenticated</h1>
                <p>You can close this tab and return to AntiElectricity.</p>
                </div></body></html>
                """
        } else {
            body = """
                <html><body style="font-family:system-ui;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:#1a1a2e;color:#e0e0e0">
                <div style="text-align:center">
                <h1 style="color:#ef4444">✗ Authentication Failed</h1>
                <p>Please try again in AntiElectricity.</p>
                </div></body></html>
                """
        }
        
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n\(body)"
        _ = response.withCString { Darwin.send(socket, $0, strlen($0), 0) }
    }
    
    
    // MARK: - Token Exchange & Refresh
    
    /// Exchanges an authorization code for access and refresh tokens.
    /// Exchanges an authorization code for access and refresh tokens.
    private static func exchangeCodeForTokens(code: String, codeVerifier: String, redirectURI: String) async throws -> OAuthTokens {
        
        let url = URL(string: tokenURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let bodyString = [
            "grant_type=authorization_code",
            "client_id=\(clientId)",
            "code=\(code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code)",
            "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI)",
            "code_verifier=\(codeVerifier)",
        ].joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.connectionFailed("Token exchange failed: \(errorBody)")
        }
        
        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        
        return OAuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn ?? 3600))
        )
    }
    
    
    /// Gets a valid access token, refreshing if expired.
    private static func getValidAccessToken() async throws -> String {
        
        guard let tokens = loadTokens() else {
            throw LLMError.connectionFailed("Not authenticated. Please log in with Claude OAuth first.")
        }
        
        // If token is still valid (with 60s buffer), use it
        if tokens.expiresAt > Date().addingTimeInterval(60) {
            return tokens.accessToken
        }
        
        // Token expired, refresh it
        return try await refreshAccessToken()
    }
    
    
    /// Refreshes the access token using the stored refresh token.
    @discardableResult
    private static func refreshAccessToken() async throws -> String {
        
        guard let tokens = loadTokens(),
              let refreshToken = tokens.refreshToken
        else {
            throw LLMError.connectionFailed("No refresh token available. Please re-authenticate.")
        }
        
        let url = URL(string: tokenURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let bodyString = [
            "grant_type=refresh_token",
            "client_id=\(clientId)",
            "refresh_token=\(refreshToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? refreshToken)",
        ].joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            // Clear stored tokens if refresh fails
            Self.deleteTokens()
            throw LLMError.connectionFailed("Token refresh failed: \(errorBody). Please re-authenticate.")
        }
        
        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        
        let newTokens = OAuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn ?? 3600))
        )
        
        try Self.saveTokens(newTokens)
        
        return newTokens.accessToken
    }
    
    
    // MARK: - PKCE Helpers
    
    /// Generates a random code verifier for PKCE.
    private static func generateCodeVerifier() -> String {
        
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    
    /// Generates a code challenge from the code verifier using SHA-256.
    private static func generateCodeChallenge(from verifier: String) -> String {
        
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    
    // MARK: - Keychain Storage
    
    /// Saves OAuth tokens to the macOS Keychain.
    static func saveTokens(_ tokens: OAuthTokens) throws {
        
        let data = try JSONEncoder().encode(tokens)
        
        // Delete existing entry first
        Self.deleteTokens()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "oauth_tokens",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw LLMError.connectionFailed("Failed to save tokens to Keychain (status: \(status))")
        }
    }
    
    
    /// Loads OAuth tokens from the macOS Keychain.
    static func loadTokens() -> OAuthTokens? {
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "oauth_tokens",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        NSLog("[ClaudeOAuth] loadTokens keychain status: %d", status)
        
        guard status == errSecSuccess,
              let data = result as? Data
        else {
            NSLog("[ClaudeOAuth] loadTokens: no data in keychain")
            return nil
        }
        
        let tokens = try? JSONDecoder().decode(OAuthTokens.self, from: data)
        NSLog("[ClaudeOAuth] loadTokens: decoded=%@, tokenPrefix=%@",
              tokens != nil ? "YES" : "NO",
              tokens.map { String($0.accessToken.prefix(25)) } ?? "nil")
        return tokens
    }
    
    
    /// Deletes stored OAuth tokens from the Keychain.
    static func deleteTokens() {
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "oauth_tokens",
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    
    /// Returns whether the user is currently authenticated.
    static var isAuthenticated: Bool {
        let result = loadTokens() != nil
        NSLog("[ClaudeOAuth] isAuthenticated: %@", result ? "YES" : "NO")
        return result
    }
    
    
    /// Logs out by deleting stored tokens.
    static func logout() {
        
        deleteTokens()
    }
    
    
    // MARK: - Response Parsing
    
    private static func parseResponse(_ data: Data) throws -> LLMResponse {
        
        let result = try JSONDecoder().decode(ClaudeOAuthResponse.self, from: data)
        
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
}


// MARK: - Data Types

/// Stored OAuth tokens.
struct OAuthTokens: Codable {
    
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}


private struct OAuthTokenResponse: Decodable {
    
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}


private struct ClaudeOAuthRequest: Encodable {
    
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


private struct ClaudeOAuthResponse: Decodable {
    
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
