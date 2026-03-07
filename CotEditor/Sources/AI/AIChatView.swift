//
//  AIChatView.swift
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

import SwiftUI

/// A message in the AI chat conversation.
struct AIChatMessage: Identifiable {
    
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date
    
    enum Role {
        case user
        case assistant
        case system
    }
    
    init(role: Role, content: String) {
        
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}


/// The view model for the AI chat panel.
@MainActor @Observable
final class AIChatViewModel {
    
    var messages: [AIChatMessage] = []
    var inputText: String = ""
    var isProcessing = false
    
    /// Reference to the document text (updated externally).
    var documentText: String = ""
    var syntaxName: String?
    
    /// Callback to apply text to the document.
    var onApplyToDocument: ((String) -> Void)?
    
    
    func sendMessage() {
        
        let userText = self.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }
        
        self.messages.append(AIChatMessage(role: .user, content: userText))
        self.inputText = ""
        self.isProcessing = true
        
        Task {
            do {
                // Build system prompt with document context
                let systemPrompt = self.buildSystemPrompt()
                
                let response = try await AIService.shared.provider.send(
                    prompt: userText,
                    systemPrompt: systemPrompt,
                    model: AIService.shared.model
                )
                
                self.messages.append(AIChatMessage(role: .assistant, content: response.content))
            } catch {
                self.messages.append(AIChatMessage(role: .system, content: "Error: \(error.localizedDescription)"))
            }
            self.isProcessing = false
        }
    }
    
    
    func clearChat() {
        
        self.messages.removeAll()
    }
    
    
    private func buildSystemPrompt() -> String {
        
        var prompt = """
            You are an AI assistant integrated into a text editor called AntiElectricity.
            You help users with writing, editing, and coding tasks.
            You can see the user's current document content.
            
            When the user asks you to modify text, provide the modified text in a code block.
            The user can then apply your changes directly to their document.
            
            Respond in the same language the user uses.
            """
        
        if !self.documentText.isEmpty {
            let preview = self.documentText.prefix(4000)
            prompt += "\n\nCurrent document content:\n```\n\(preview)\n```"
        }
        
        if let syntax = self.syntaxName {
            prompt += "\n\nDocument syntax: \(syntax)"
        }
        
        return prompt
    }
}


/// The main AI chat panel view.
struct AIChatView: View {
    
    @State var viewModel = AIChatViewModel()
    @FocusState private var isInputFocused: Bool
    
    
    var body: some View {
        
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("AI Chat")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    self.viewModel.clearChat()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Clear conversation")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Messages
            if viewModel.messages.isEmpty {
                self.emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message, onApply: viewModel.onApplyToDocument)
                                    .id(message.id)
                            }
                            
                            if viewModel.isProcessing {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Thinking…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .id("loading")
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: viewModel.messages.count) {
                        withAnimation {
                            if viewModel.isProcessing {
                                proxy.scrollTo("loading", anchor: .bottom)
                            } else if let last = viewModel.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Input
            HStack(spacing: 8) {
                TextField("Ask AI anything…", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onSubmit {
                        if !NSEvent.modifierFlags.contains(.shift) {
                            self.viewModel.sendMessage()
                        }
                    }
                
                Button {
                    self.viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.inputText.isEmpty ? .gray : .purple)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.inputText.isEmpty || viewModel.isProcessing)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(10)
        }
        .frame(minWidth: 280, idealWidth: 320)
        .onAppear {
            self.isInputFocused = true
        }
    }
    
    
    private var emptyState: some View {
        
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(.purple.opacity(0.5))
            
            Text("AI Chat")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Text("Ask questions, request edits,\nor explore ideas about your document.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}


/// A single chat message bubble.
private struct MessageBubble: View {
    
    let message: AIChatMessage
    let onApply: ((String) -> Void)?
    
    @State private var isHovering = false
    
    
    var body: some View {
        
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(self.bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if message.role == .assistant && isHovering {
                    HStack(spacing: 8) {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        
                        if let onApply {
                            Button("Apply to Document") {
                                onApply(message.content)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .foregroundStyle(.purple)
                        }
                    }
                }
            }
            .onHover { self.isHovering = $0 }
            
            if message.role != .user {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 12)
    }
    
    
    private var bubbleBackground: some ShapeStyle {
        
        switch message.role {
            case .user:
                Color.purple.opacity(0.15)
            case .assistant:
                Color.primary.opacity(0.06)
            case .system:
                Color.red.opacity(0.1)
        }
    }
}
