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


/// A parsed edit block from AI response.
struct EditBlock: Identifiable {
    
    let id = UUID()
    let searchText: String
    let replaceText: String
    var isApplied = false
}


/// The view model for the AI chat panel.
@MainActor @Observable
final class AIChatViewModel {
    
    var messages: [AIChatMessage] = []
    var inputText: String = ""
    var isProcessing = false
    
    /// Font size synced from the text editor.
    var fontSize: CGFloat = NSFont.systemFontSize
    
    /// Lazy provider that returns current document text and syntax name.
    var documentTextProvider: (() -> (text: String, syntax: String?))?
    
    /// Callback to preview an edit in the editor (highlight + popover).
    /// Parameters: searchText, replaceText, blockID (to mark as applied on accept).
    var onPreviewEdit: ((_ search: String, _ replace: String, _ blockID: UUID) -> Void)?
    
    /// Callback to replace all document text (fallback).
    var onReplaceAll: ((String) -> Void)?
    
    /// Track applied states for edit blocks per message.
    var appliedEdits: Set<UUID> = []
    
    
    func sendMessage() {
        
        let userText = self.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }
        
        NSLog("[AI sendMessage] START")
        self.messages.append(AIChatMessage(role: .user, content: userText))
        self.inputText = ""
        self.isProcessing = true
        NSLog("[AI sendMessage] isProcessing=true, creating Task")
        
        Task {
            do {
                NSLog("[AI sendMessage] Task started, building system prompt")
                let systemPrompt = self.buildSystemPrompt()
                NSLog("[AI sendMessage] System prompt built (%d chars), calling provider.send", systemPrompt.count)
                
                // Copy the messages to capture the current state and avoid data races during await
                let currentMessages = self.messages
                
                let response = try await AIService.shared.provider.send(
                    messages: currentMessages,
                    systemPrompt: systemPrompt,
                    model: AIService.shared.model
                )
                NSLog("[AI sendMessage] Response received (%d chars)", response.content.count)
                
                self.messages.append(AIChatMessage(role: .assistant, content: response.content))
                self.isProcessing = false
                NSLog("[AI sendMessage] isProcessing=false")
                
                // Auto-trigger inline diff for the first edit block.
                // IMPORTANT: Schedule on a *separate* run-loop cycle via
                // DispatchQueue.main.async so that SwiftUI's NSHostingView
                // transaction triggered by `messages.append` above finishes
                // completely before we touch AppKit's textStorage / layoutManager.
                let editBlocks = Self.parseEditBlocks(response.content)
                if let first = editBlocks.first {
                    NSLog("[AI sendMessage] Scheduling onPreviewEdit for block")
                    let preview = self.onPreviewEdit
                    DispatchQueue.main.async {
                        NSLog("[AI sendMessage] Calling onPreviewEdit")
                        preview?(first.searchText, first.replaceText, first.id)
                        NSLog("[AI sendMessage] onPreviewEdit done")
                    }
                }
            } catch {
                NSLog("[AI sendMessage] ERROR: %@", error.localizedDescription)
                self.messages.append(AIChatMessage(role: .system, content: "Error: \(error.localizedDescription)"))
                self.isProcessing = false
            }
        }
        NSLog("[AI sendMessage] END (Task launched)")
    }
    
    
    func clearChat() {
        
        self.messages.removeAll()
        self.appliedEdits.removeAll()
    }
    
    
    /// Parses SEARCH/REPLACE blocks from AI response text.
    static func parseEditBlocks(_ text: String) -> [EditBlock] {
        
        var blocks: [EditBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Detect <<<SEARCH marker (case-insensitive)
            guard trimmed.lowercased().hasPrefix("<<<search") || trimmed == "<<<" else {
                i += 1
                continue
            }
            
            i += 1
            
            // --- Phase 1: Collect SEARCH lines ---
            var searchLines: [String] = []
            while i < lines.count {
                let l = lines[i].trimmingCharacters(in: .whitespaces)
                let ll = l.lowercased()
                // Stop at separator (===) or directly at >>>REPLACE
                if l.hasPrefix("===") || ll.hasPrefix(">>>replace") {
                    break
                }
                searchLines.append(lines[i])
                i += 1
            }
            
            // --- Phase 2: Skip separator(s) ---
            // Handle patterns: "===" alone, "===\n>>>REPLACE", or just ">>>REPLACE"
            if i < lines.count {
                let sep = lines[i].trimmingCharacters(in: .whitespaces)
                if sep.hasPrefix("===") {
                    i += 1
                }
            }
            if i < lines.count {
                let sep = lines[i].trimmingCharacters(in: .whitespaces).lowercased()
                if sep.hasPrefix(">>>replace") {
                    i += 1
                }
            }
            
            // --- Phase 3: Collect REPLACE lines ---
            var replaceLines: [String] = []
            while i < lines.count {
                let l = lines[i].trimmingCharacters(in: .whitespaces)
                let ll = l.lowercased()
                // Stop at closing >>> or start of next <<<SEARCH block
                if l == ">>>" || ll.hasPrefix("<<<search") || l == "<<<" {
                    break
                }
                replaceLines.append(lines[i])
                i += 1
            }
            
            // Skip closing >>>
            if i < lines.count && lines[i].trimmingCharacters(in: .whitespaces) == ">>>" {
                i += 1
            }
            
            let search = searchLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let replace = replaceLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !search.isEmpty {
                blocks.append(EditBlock(searchText: search, replaceText: replace))
            }
        }
        
        return blocks
    }
    
    
    /// Returns the text content with edit blocks removed (for display as prose).
    static func textWithoutEditBlocks(_ text: String) -> String {
        
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var i = 0
        var inBlock = false
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            if line.hasPrefix("<<<SEARCH") || line.hasPrefix("<<<search") || line == "<<<" {
                inBlock = true
            } else if inBlock && (line == ">>>" || (line.hasPrefix("<<<") && i > 0)) {
                if line == ">>>" {
                    inBlock = false
                }
            } else if !inBlock {
                result.append(lines[i])
            }
            i += 1
        }
        
        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    
    private func buildSystemPrompt() -> String {
        
        var prompt = """
            You are an AI assistant integrated into a text editor called AntiElectricity.
            You help users with writing, editing, and coding tasks.
            You can see the user's current document content.
            Respond in the same language the user uses.
            
            IMPORTANT: When you want to modify the document, use SEARCH/REPLACE blocks:
            
            <<<SEARCH
            exact text to find in the document
            ===
            >>>REPLACE
            replacement text
            >>>
            
            Rules for SEARCH/REPLACE blocks:
            - The SEARCH text must EXACTLY match text in the document (including whitespace).
            - You can use multiple blocks to make multiple changes.
            - Only include the minimal context needed to uniquely identify the location.
            - For non-edit responses (explanations, questions), just write normally without blocks.
            """
        
        if let provider = self.documentTextProvider {
            let doc = provider()
            if !doc.text.isEmpty {
                let preview = String(doc.text.prefix(6000))
                prompt += "\n\n--- CURRENT DOCUMENT ---\n\(preview)\n--- END DOCUMENT ---"
            }
            if let syntax = doc.syntax {
                prompt += "\n\nDocument syntax: \(syntax)"
            }
        }
        
        return prompt
    }
}


/// The main AI chat panel view.
struct AIChatView: View {
    
    @Bindable var viewModel: AIChatViewModel
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
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    viewModel: viewModel
                                )
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
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask AI anything…", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: viewModel.fontSize))
                    .focused($isInputFocused)
                    .lineLimit(1...8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onSubmit {
                        // In macOS 14+, onSubmit on a vertical TextField maps to the Return key.
                        // However, to support Shift+Return for newlines, we still need
                        // key press handling, but iOS/macOS differ. For simple native behavior,
                        // macOS handles newlines automatically with Option+Return.
                        // If we want Shift+Return, keep onKeyPress:
                    }
                    .onKeyPress(.return, phases: .down) { keyPress in
                        if keyPress.modifiers.contains(.shift) {
                            viewModel.inputText += "\n"
                            return .handled
                        } else {
                            viewModel.sendMessage()
                            return .handled
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


/// A single chat message bubble with edit block detection.
private struct MessageBubble: View {
    
    let message: AIChatMessage
    let viewModel: AIChatViewModel
    
    var body: some View {
        
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                
                if message.role == .assistant {
                    let editBlocks = AIChatViewModel.parseEditBlocks(message.content)
                    let proseText = AIChatViewModel.textWithoutEditBlocks(message.content)
                    
                    // Show prose text
                    if !proseText.isEmpty {
                        Text(proseText)
                            .font(.system(size: viewModel.fontSize))
                            .padding(10)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Show simple notification for edit blocks
                    if !editBlocks.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.line")
                                .foregroundStyle(.purple)
                            Text("Changes applied to editor — check the inline diff.")
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: max(viewModel.fontSize - 2, 10)))
                        .padding(8)
                        .background(Color.purple.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    // User / system message
                    Text(message.content)
                        .font(.system(size: viewModel.fontSize))
                        .padding(10)
                        .background(self.bubbleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .contextMenu {
                Button("Copy Message") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.content, forType: .string)
                }
            }
            
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


/// Displays a single SEARCH/REPLACE edit block with diff preview and apply button.
private struct EditBlockView: View {
    
    let block: EditBlock
    let isApplied: Bool
    let onApply: () -> Void
    
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pencil.line")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text("Edit")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.purple)
                
                Spacer()
                
                if isApplied {
                    Label("Applied", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button {
                        self.onApply()
                    } label: {
                        Label("Apply", systemImage: "arrow.right.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.08))
            
            Divider()
            
            // Diff view
            VStack(alignment: .leading, spacing: 2) {
                // Removed text
                HStack(alignment: .top, spacing: 4) {
                    Text("−")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.red)
                        .frame(width: 14)
                    Text(block.searchText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.8))
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.06))
                
                // Added text
                HStack(alignment: .top, spacing: 4) {
                    Text("+")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.green)
                        .frame(width: 14)
                    Text(block.replaceText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.8))
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.06))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}
