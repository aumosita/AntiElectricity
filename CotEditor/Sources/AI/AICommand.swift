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

/// Defines an AI command that can be executed on text.
struct AICommand: Identifiable, Codable, Sendable {
    
    let id: String
    var label: String
    var systemPrompt: String
    var isBuiltIn: Bool
    
    
    init(id: String = UUID().uuidString, label: String, systemPrompt: String, isBuiltIn: Bool = false) {
        
        self.id = id
        self.label = label
        self.systemPrompt = systemPrompt
        self.isBuiltIn = isBuiltIn
    }
}


// MARK: - Built-in Commands

extension AICommand {
    
    static let spellCheck = AICommand(
        id: "builtin.spellcheck",
        label: String(localized: "Spell Check", table: "AI"),
        systemPrompt: """
            주어진 한국어 텍스트의 맞춤법과 문법을 교정하세요.
            원문의 의미와 문체는 유지하고, 변경된 부분만 수정하세요.
            수정된 전체 텍스트만 출력하세요. 설명은 하지 마세요.
            영어가 포함된 경우 영어 맞춤법도 교정하세요.
            """,
        isBuiltIn: true
    )
    
    static let rewrite = AICommand(
        id: "builtin.rewrite",
        label: String(localized: "Rewrite", table: "AI"),
        systemPrompt: """
            주어진 텍스트를 더 자연스럽고 간결하게 고쳐 쓰세요.
            원문의 핵심 의미는 유지하되, 문체를 개선하세요.
            고쳐 쓴 전체 텍스트만 출력하세요. 설명은 하지 마세요.
            """,
        isBuiltIn: true
    )
    
    static let translateOldKorean = AICommand(
        id: "builtin.translate.old-korean",
        label: String(localized: "Translate to Old Korean", table: "AI"),
        systemPrompt: """
            주어진 현대 한국어 텍스트를 조선시대 옛 한글로 번역하세요.
            아래아(ㆍ), 옛 이응(ㆁ), 반시옷(ㅸ) 등 옛 한글 자모를 적극 사용하세요.
            훈민정음 창제 당시의 표기법을 따르세요.
            번역된 텍스트만 출력하세요. 설명은 하지 마세요.
            """,
        isBuiltIn: true
    )
    
    static let codeGenerate = AICommand(
        id: "builtin.code.generate",
        label: String(localized: "Generate Code", table: "AI"),
        systemPrompt: """
            주어진 설명이나 주석을 바탕으로 코드를 생성하세요.
            코드만 출력하세요. 설명이나 마크다운 코드 블록 기호(```)는 포함하지 마세요.
            """,
        isBuiltIn: true
    )
    
    static let codeFix = AICommand(
        id: "builtin.code.fix",
        label: String(localized: "Fix Code", table: "AI"),
        systemPrompt: """
            주어진 코드의 버그를 수정하고 개선하세요.
            수정된 전체 코드만 출력하세요. 설명이나 마크다운 코드 블록 기호(```)는 포함하지 마세요.
            """,
        isBuiltIn: true
    )
    
    static let codeExplain = AICommand(
        id: "builtin.code.explain",
        label: String(localized: "Explain Code", table: "AI"),
        systemPrompt: """
            주어진 코드를 한국어로 상세히 설명하세요.
            각 부분이 무엇을 하는지, 전체적인 구조와 동작 원리를 설명하세요.
            """,
        isBuiltIn: true
    )
    
    /// All built-in commands.
    static let builtInCommands: [AICommand] = [
        .spellCheck,
        .rewrite,
        .translateOldKorean,
        .codeGenerate,
        .codeFix,
        .codeExplain,
    ]
}


// MARK: - Command Manager

/// Manages built-in and custom AI commands.
@MainActor @Observable
final class AICommandManager {
    
    static let shared = AICommandManager()
    
    private(set) var commands: [AICommand]
    
    
    private init() {
        
        let customCommands = Self.loadCustomCommands()
        self.commands = AICommand.builtInCommands + customCommands
    }
    
    
    /// All user-created custom commands.
    var customCommands: [AICommand] {
        
        self.commands.filter { !$0.isBuiltIn }
    }
    
    
    /// Adds a new custom command.
    func addCommand(_ command: AICommand) {
        
        var cmd = command
        cmd.isBuiltIn = false
        self.commands.append(cmd)
        self.saveCustomCommands()
    }
    
    
    /// Updates an existing command (custom only).
    func updateCommand(_ command: AICommand) {
        
        guard let index = self.commands.firstIndex(where: { $0.id == command.id }) else { return }
        guard !self.commands[index].isBuiltIn else { return }
        
        self.commands[index] = command
        self.saveCustomCommands()
    }
    
    
    /// Removes a custom command.
    func removeCommand(id: String) {
        
        self.commands.removeAll { $0.id == id && !$0.isBuiltIn }
        self.saveCustomCommands()
    }
    
    
    // MARK: Private
    
    private func saveCustomCommands() {
        
        let data = try? JSONEncoder().encode(self.customCommands)
        UserDefaults.standard.set(data, forKey: "customAICommands")
    }
    
    
    private static func loadCustomCommands() -> [AICommand] {
        
        guard
            let data = UserDefaults.standard.data(forKey: "customAICommands"),
            let commands = try? JSONDecoder().decode([AICommand].self, from: data)
        else { return [] }
        
        return commands
    }
}
