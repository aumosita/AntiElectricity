//
//  AISettingsView.swift
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

import SwiftUI

struct AISettingsView: View {
    
    @State private var providerType: AIProviderType = AIService.shared.providerType
    
    // Ollama
    @State private var ollamaURL: String = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
    
    // Anthropic
    @State private var anthropicAPIKey: String = UserDefaults.standard.string(forKey: "anthropicAPIKey") ?? ""
    
    // OpenAI
    @State private var openaiAPIKey: String = UserDefaults.standard.string(forKey: "openaiAPIKey") ?? ""
    
    // Copilot
    @State private var copilotToken: String = UserDefaults.standard.string(forKey: "copilotGitHubToken") ?? ""
    @State private var copilotUserCode: String = ""
    @State private var copilotVerificationURL: String = ""
    @State private var isCopilotAuthenticating = false
    @State private var copilotAuthStatus: String = ""
    
    // Shared
    @State private var selectedModel: String = AIService.shared.model
    @State private var availableModels: [String] = []
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isLoadingModels = false
    
    @State private var commands: [AICommand] = AICommandManager.shared.commands
    @State private var isAddingCommand = false
    @State private var editingCommand: AICommand?
    
    
    enum ConnectionStatus {
        case unknown, connected, failed
    }
    
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 20) {
            // Provider Selection
            Section {
                Picker(String(localized: "Provider:", table: "AI"), selection: $providerType) {
                    ForEach(AIProviderType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 380)
                .onChange(of: providerType) {
                    AIService.shared.switchProvider(to: providerType)
                    self.selectedModel = AIService.shared.model
                    self.connectionStatus = .unknown
                    self.availableModels = []
                    self.loadModels()
                }
            } header: {
                Text(String(localized: "AI Provider", table: "AI"))
                    .font(.headline)
            }
            
            // Provider-specific settings
            Section {
                Grid(alignment: .leadingFirstTextBaseline, verticalSpacing: 8) {
                    if providerType == .ollama {
                        self.ollamaSettings
                    } else if providerType == .anthropic {
                        self.anthropicSettings
                    } else if providerType == .openai {
                        self.openaiSettings
                    } else if providerType == .copilot {
                        self.copilotSettings
                    }
                    
                    // Model picker (shared)
                    GridRow {
                        Text("Model:")
                            .gridColumnAlignment(.trailing)
                        
                        HStack {
                            if isLoadingModels {
                                ProgressView()
                                    .controlSize(.small)
                            } else if availableModels.isEmpty {
                                Text("No models")
                                    .foregroundStyle(.secondary)
                            } else {
                                Picker("", selection: $selectedModel) {
                                    ForEach(availableModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 250)
                                .onChange(of: selectedModel) {
                                    AIService.shared.model = selectedModel
                                }
                            }
                            
                            Button(String(localized: "Refresh", table: "AI")) {
                                self.loadModels()
                            }
                        }
                    }
                }
            } header: {
                Text(providerType.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Command Presets
            Section {
                if commands.isEmpty {
                    Text("No presets. Add your own or import examples.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    List {
                        ForEach(commands) { command in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(command.label)
                                        .font(.body)
                                    Text(command.systemPrompt)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                Button {
                                    self.editingCommand = command
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                AICommandManager.shared.removeCommand(id: commands[index].id)
                            }
                            self.commands = AICommandManager.shared.commands
                        }
                    }
                    .frame(height: 150)
                }
                
                HStack {
                    Button(String(localized: "Import Examples", table: "AI")) {
                        AICommandManager.shared.importExamples()
                        self.commands = AICommandManager.shared.commands
                    }
                    
                    Spacer()
                    
                    Button {
                        self.isAddingCommand = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            } header: {
                Text(String(localized: "Command Presets", table: "AI"))
                    .font(.headline)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 480)
        .onAppear {
            self.commands = AICommandManager.shared.commands
            self.loadModels()
        }
        .sheet(isPresented: $isAddingCommand) {
            AICommandEditView { command in
                AICommandManager.shared.addCommand(command)
                self.commands = AICommandManager.shared.commands
            }
        }
        .sheet(item: $editingCommand) { command in
            AICommandEditView(command: command) { updated in
                AICommandManager.shared.updateCommand(updated)
                self.commands = AICommandManager.shared.commands
            }
        }
    }
    
    
    // MARK: - Provider-specific Settings
    
    @ViewBuilder
    private var ollamaSettings: some View {
        
        GridRow {
            Text("Server URL:")
                .gridColumnAlignment(.trailing)
            
            HStack {
                TextField("http://localhost:11434", text: $ollamaURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                    .onSubmit {
                        AIService.shared.updateOllamaURL(self.ollamaURL)
                    }
                
                self.connectionIndicator
                
                Button(String(localized: "Test", table: "AI")) {
                    AIService.shared.updateOllamaURL(self.ollamaURL)
                    self.testConnection()
                }
            }
        }
    }
    
    
    @ViewBuilder
    private var anthropicSettings: some View {
        
        GridRow {
            Text("API Key:")
                .gridColumnAlignment(.trailing)
            
            HStack {
                SecureField("sk-ant-...", text: $anthropicAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                    .onSubmit {
                        AIService.shared.updateAnthropicAPIKey(self.anthropicAPIKey)
                    }
                
                self.connectionIndicator
                
                Button(String(localized: "Test", table: "AI")) {
                    AIService.shared.updateAnthropicAPIKey(self.anthropicAPIKey)
                    self.testConnection()
                }
            }
        }
    }
    
    
    @ViewBuilder
    private var openaiSettings: some View {
        
        GridRow {
            Text("API Key:")
                .gridColumnAlignment(.trailing)
            
            HStack {
                SecureField("sk-...", text: $openaiAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                    .onSubmit {
                        AIService.shared.updateOpenAIAPIKey(self.openaiAPIKey)
                    }
                
                self.connectionIndicator
                
                Button(String(localized: "Test", table: "AI")) {
                    AIService.shared.updateOpenAIAPIKey(self.openaiAPIKey)
                    self.testConnection()
                }
            }
        }
    }
    
    
    @ViewBuilder
    private var connectionIndicator: some View {
        
        switch connectionStatus {
            case .unknown:
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            case .connected:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
        }
    }
    
    
    // MARK: - Actions
    
    private func testConnection() {
        
        Task {
            let result = await AIService.shared.testConnection()
            self.connectionStatus = result ? .connected : .failed
        }
    }
    
    
    private func loadModels() {
        
        self.isLoadingModels = true
        
        Task {
            do {
                let models = try await AIService.shared.fetchModels()
                self.availableModels = models
                self.connectionStatus = (providerType == .ollama) ? .connected : .unknown
                
                if !models.isEmpty && (self.selectedModel.isEmpty || !models.contains(self.selectedModel)) {
                    self.selectedModel = models[0]
                    AIService.shared.model = models[0]
                }
            } catch {
                if providerType == .ollama {
                    self.connectionStatus = .failed
                }
                self.availableModels = []
            }
            self.isLoadingModels = false
        }
    }
    
    
    @ViewBuilder
    private var copilotSettings: some View {
        
        GridRow {
            Text("GitHub:")
                .gridColumnAlignment(.trailing)
            
            HStack {
                if copilotToken.isEmpty {
                    if isCopilotAuthenticating {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("Code:")
                                    .font(.caption)
                                Text(copilotUserCode)
                                    .font(.system(.title3, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.purple)
                                    .textSelection(.enabled)
                                
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(copilotUserCode, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                            }
                            
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(copilotAuthStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button("Sign in with GitHub") {
                            self.startCopilotAuth()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Connected")
                        .foregroundStyle(.secondary)
                    
                    Button("Sign Out") {
                        self.copilotToken = ""
                        UserDefaults.standard.removeObject(forKey: "copilotGitHubToken")
                        AIService.shared.updateCopilotToken("")
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }
    
    
    private func startCopilotAuth() {
        
        self.isCopilotAuthenticating = true
        self.copilotAuthStatus = "Starting…"
        
        Task {
            do {
                let flow = try await CopilotProvider.startDeviceFlow()
                self.copilotUserCode = flow.userCode
                self.copilotVerificationURL = flow.verificationUri
                self.copilotAuthStatus = "Open browser and enter the code"
                
                // Open verification URL in browser
                if let url = URL(string: flow.verificationUri) {
                    NSWorkspace.shared.open(url)
                }
                
                // Poll for token
                let token = try await CopilotProvider.pollForToken(
                    deviceCode: flow.deviceCode,
                    interval: flow.interval
                )
                
                self.copilotToken = token
                AIService.shared.updateCopilotToken(token)
                self.connectionStatus = .connected
                self.copilotAuthStatus = ""
                self.loadModels()
            } catch {
                self.copilotAuthStatus = "Auth failed: \(error.localizedDescription)"
            }
            self.isCopilotAuthenticating = false
        }
    }
    
    
}


// MARK: - Command Edit Sheet

private struct AICommandEditView: View {
    
    @State private var label: String
    @State private var systemPrompt: String
    @Environment(\.dismiss) private var dismiss
    
    private let existingCommand: AICommand?
    private let onSave: (AICommand) -> Void
    
    
    init(command: AICommand? = nil, onSave: @escaping (AICommand) -> Void) {
        
        self.existingCommand = command
        self._label = State(initialValue: command?.label ?? "")
        self._systemPrompt = State(initialValue: command?.systemPrompt ?? "")
        self.onSave = onSave
    }
    
    
    var body: some View {
        
        VStack(spacing: 16) {
            Text(existingCommand == nil
                 ? String(localized: "New Preset", table: "AI")
                 : String(localized: "Edit Preset", table: "AI"))
                .font(.headline)
            
            TextField(String(localized: "Preset Name", table: "AI"), text: $label)
                .textFieldStyle(.roundedBorder)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "System Prompt:", table: "AI"))
                    .font(.caption)
                
                TextEditor(text: $systemPrompt)
                    .font(.body)
                    .frame(height: 120)
                    .border(.separator)
            }
            
            HStack {
                Button(String(localized: "Cancel", table: "AI")) {
                    self.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(String(localized: "Save", table: "AI")) {
                    var command = existingCommand ?? AICommand(label: label, systemPrompt: systemPrompt)
                    command.label = self.label
                    command.systemPrompt = self.systemPrompt
                    self.onSave(command)
                    self.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(label.isEmpty || systemPrompt.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
