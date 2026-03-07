//
//  AICommand.swift
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

/// Defines an AI command preset that can be executed on text.
struct AICommand: Identifiable, Codable, Sendable {
    
    let id: String
    var label: String
    var systemPrompt: String
    
    
    init(id: String = UUID().uuidString, label: String, systemPrompt: String) {
        
        self.id = id
        self.label = label
        self.systemPrompt = systemPrompt
    }
}


// MARK: - Example Presets

extension AICommand {
    
    /// Example presets that users can import into their command list.
    static let examples: [AICommand] = [
        AICommand(
            id: "example.spellcheck",
            label: String(localized: "Spell Check", table: "AI"),
            systemPrompt: """
                주어진 한국어 텍스트의 맞춤법과 문법을 교정하세요.
                원문의 의미와 문체는 유지하고, 변경된 부분만 수정하세요.
                수정된 전체 텍스트만 출력하세요. 설명은 하지 마세요.
                영어가 포함된 경우 영어 맞춤법도 교정하세요.
                """
        ),
        AICommand(
            id: "example.rewrite",
            label: String(localized: "Rewrite", table: "AI"),
            systemPrompt: """
                주어진 텍스트를 더 자연스럽고 간결하게 고쳐 쓰세요.
                원문의 핵심 의미는 유지하되, 문체를 개선하세요.
                고쳐 쓴 전체 텍스트만 출력하세요. 설명은 하지 마세요.
                """
        ),
        AICommand(
            id: "example.translate.old-korean",
            label: String(localized: "Translate to Old Korean", table: "AI"),
            systemPrompt: """
                주어진 현대 한국어 텍스트를 조선시대 옛 한글로 번역하세요.
                아래아(ㆍ), 옛 이응(ㆁ), 반시옷(ㅸ) 등 옛 한글 자모를 적극 사용하세요.
                훈민정음 창제 당시의 표기법을 따르세요.
                번역된 텍스트만 출력하세요. 설명은 하지 마세요.
                """
        ),
        AICommand(
            id: "example.code.generate",
            label: String(localized: "Generate Code", table: "AI"),
            systemPrompt: """
                주어진 설명이나 주석을 바탕으로 코드를 생성하세요.
                코드만 출력하세요. 설명이나 마크다운 코드 블록 기호(```)는 포함하지 마세요.
                """
        ),
        AICommand(
            id: "example.code.fix",
            label: String(localized: "Fix Code", table: "AI"),
            systemPrompt: """
                주어진 코드의 버그를 수정하고 개선하세요.
                수정된 전체 코드만 출력하세요. 설명이나 마크다운 코드 블록 기호(```)는 포함하지 마세요.
                """
        ),
        AICommand(
            id: "example.code.explain",
            label: String(localized: "Explain Code", table: "AI"),
            systemPrompt: """
                주어진 코드를 한국어로 상세히 설명하세요.
                각 부분이 무엇을 하는지, 전체적인 구조와 동작 원리를 설명하세요.
                """
        ),
    ]
}


// MARK: - Command Manager

/// Manages user AI command presets.
@MainActor @Observable
final class AICommandManager {
    
    static let shared = AICommandManager()
    
    private(set) var commands: [AICommand]
    
    
    private init() {
        
        self.commands = Self.loadCommands()
    }
    
    
    /// Adds a new command preset.
    func addCommand(_ command: AICommand) {
        
        self.commands.append(command)
        self.saveCommands()
    }
    
    
    /// Updates an existing command.
    func updateCommand(_ command: AICommand) {
        
        guard let index = self.commands.firstIndex(where: { $0.id == command.id }) else { return }
        
        self.commands[index] = command
        self.saveCommands()
    }
    
    
    /// Removes a command by ID.
    func removeCommand(id: String) {
        
        self.commands.removeAll { $0.id == id }
        self.saveCommands()
    }
    
    
    /// Imports example presets (skips already-existing IDs).
    func importExamples() {
        
        let existingIDs = Set(self.commands.map(\.id))
        let newExamples = AICommand.examples.filter { !existingIDs.contains($0.id) }
        
        guard !newExamples.isEmpty else { return }
        
        self.commands.append(contentsOf: newExamples)
        self.saveCommands()
    }
    
    
    // MARK: Private
    
    private func saveCommands() {
        
        let data = try? JSONEncoder().encode(self.commands)
        UserDefaults.standard.set(data, forKey: "aiCommandPresets")
    }
    
    
    private static func loadCommands() -> [AICommand] {
        
        guard
            let data = UserDefaults.standard.data(forKey: "aiCommandPresets"),
            let commands = try? JSONDecoder().decode([AICommand].self, from: data)
        else { return [] }
        
        return commands
    }
}
