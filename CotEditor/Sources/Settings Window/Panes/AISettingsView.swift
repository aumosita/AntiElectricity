//
//  AISettingsView.swift
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

import SwiftUI

struct AISettingsView: View {
    
    @State private var ollamaURL: String = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
    @State private var selectedModel: String = UserDefaults.standard.string(forKey: "ollamaModel") ?? ""
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
            // Ollama Connection
            Section {
                Grid(alignment: .leadingFirstTextBaseline, verticalSpacing: 8) {
                    GridRow {
                        Text("Server URL:")
                            .gridColumnAlignment(.trailing)
                        
                        HStack {
                            TextField("http://localhost:11434", text: $ollamaURL)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 250)
                                .onSubmit { self.saveURL() }
                            
                            self.connectionIndicator
                            
                            Button(String(localized: "Test", table: "AI")) {
                                self.testConnection()
                            }
                        }
                    }
                    
                    GridRow {
                        Text("Model:")
                            .gridColumnAlignment(.trailing)
                        
                        HStack {
                            if isLoadingModels {
                                ProgressView()
                                    .controlSize(.small)
                            } else if availableModels.isEmpty {
                                Text("No models found")
                                    .foregroundStyle(.secondary)
                            } else {
                                Picker("", selection: $selectedModel) {
                                    ForEach(availableModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 200)
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
                Text("Ollama")
                    .font(.headline)
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
    
    
    private func saveURL() {
        
        AIService.shared.updateOllamaURL(self.ollamaURL)
    }
    
    
    private func testConnection() {
        
        self.saveURL()
        
        Task {
            let result = await AIService.shared.testConnection()
            self.connectionStatus = result ? .connected : .failed
        }
    }
    
    
    private func loadModels() {
        
        self.saveURL()
        self.isLoadingModels = true
        
        Task {
            do {
                let models = try await AIService.shared.fetchModels()
                self.availableModels = models
                self.connectionStatus = .connected
                
                if !models.isEmpty && (self.selectedModel.isEmpty || !models.contains(self.selectedModel)) {
                    self.selectedModel = models[0]
                    AIService.shared.model = models[0]
                }
            } catch {
                self.connectionStatus = .failed
                self.availableModels = []
            }
            self.isLoadingModels = false
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
