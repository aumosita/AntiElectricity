//
//  AIMenuActions.swift
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

import AppKit

/// Sets up the AI menu in the main menu bar.
enum AIMenuBuilder {
    
    /// Creates and inserts the AI menu into the main menu bar.
    @MainActor
    static func installAIMenu() {
        
        guard let mainMenu = NSApp.mainMenu else { return }
        
        let aiMenu = NSMenu(title: String(localized: "AI", table: "AI"))
        
        // Text commands
        aiMenu.addItem(makeItem(.spellCheck, shortcut: "k", modifiers: [.command, .shift]))
        aiMenu.addItem(makeItem(.rewrite, shortcut: "r", modifiers: [.command, .shift]))
        aiMenu.addItem(makeItem(.translateOldKorean, shortcut: "t", modifiers: [.command, .shift]))
        
        aiMenu.addItem(.separator())
        
        // Code commands
        aiMenu.addItem(makeItem(.codeGenerate, shortcut: "g", modifiers: [.command, .shift]))
        aiMenu.addItem(makeItem(.codeFix, shortcut: "", modifiers: []))
        aiMenu.addItem(makeItem(.codeExplain, shortcut: "e", modifiers: [.command, .shift]))
        
        aiMenu.addItem(.separator())
        
        // Free prompt
        let freePromptItem = NSMenuItem(
            title: String(localized: "Free Prompt…", table: "AI"),
            action: #selector(ContentViewController.showAIFreePromptDialog(_:)),
            keyEquivalent: "p"
        )
        freePromptItem.keyEquivalentModifierMask = [.command, .shift]
        aiMenu.addItem(freePromptItem)
        
        // AI menu item for main menu bar
        let aiMenuItem = NSMenuItem()
        aiMenuItem.title = String(localized: "AI", table: "AI")
        aiMenuItem.submenu = aiMenu
        
        // Insert before the last menu item (Help) or at the end
        let insertIndex = max(mainMenu.items.count - 1, 0)
        mainMenu.insertItem(aiMenuItem, at: insertIndex)
    }
    
    
    private static func makeItem(_ command: AICommand, shortcut: String, modifiers: NSEvent.ModifierFlags) -> NSMenuItem {
        
        let item = NSMenuItem(
            title: command.label,
            action: #selector(ContentViewController.handleAICommand(_:)),
            keyEquivalent: shortcut
        )
        item.keyEquivalentModifierMask = modifiers
        item.representedObject = command
        return item
    }
}


// MARK: - Action Handlers on ContentViewController

extension ContentViewController {
    
    /// Handles an AI command from the menu.
    @objc func handleAICommand(_ sender: NSMenuItem) {
        
        guard let command = sender.representedObject as? AICommand else { return }
        
        self.executeAICommand(command)
    }
    
    
    /// Shows the free prompt dialog.
    @objc func showAIFreePromptDialog(_ sender: Any?) {
        
        let alert = NSAlert()
        alert.messageText = String(localized: "Free Prompt", table: "AI")
        alert.informativeText = String(localized: "Enter your instruction for the AI:", table: "AI")
        alert.addButton(withTitle: String(localized: "Execute", table: "AI"))
        alert.addButton(withTitle: String(localized: "Cancel", table: "AI"))
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
        textField.placeholderString = String(localized: "e.g., Translate to English", table: "AI")
        alert.accessoryView = textField
        
        guard let window = self.view.window else { return }
        
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn,
                  !textField.stringValue.isEmpty
            else { return }
            
            self?.executeFreePrompt(textField.stringValue)
        }
    }
}
