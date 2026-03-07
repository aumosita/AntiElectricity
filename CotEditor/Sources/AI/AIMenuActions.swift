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

// MARK: - AI Menu Builder

/// Builds the AI menu for the main menu bar and other integration points.
enum AIMenuBuilder {
    
    /// Creates and inserts the AI menu into the main menu bar.
    @MainActor
    static func installAIMenu() {
        
        guard let mainMenu = NSApp.mainMenu else { return }
        
        let aiMenu = NSMenu(title: String(localized: "AI", table: "AI"))
        aiMenu.delegate = AIMenuDelegate.shared
        
        // placeholder — items are built dynamically by the delegate
        
        let aiMenuItem = NSMenuItem()
        aiMenuItem.title = String(localized: "AI", table: "AI")
        aiMenuItem.submenu = aiMenu
        
        // Insert before Help
        let insertIndex = max(mainMenu.items.count - 1, 0)
        mainMenu.insertItem(aiMenuItem, at: insertIndex)
    }
    
    
    /// Builds an AI submenu with current user presets (for context menu / toolbar).
    @MainActor
    static func buildAISubmenu() -> NSMenu {
        
        let menu = NSMenu(title: String(localized: "AI", table: "AI"))
        populateMenu(menu)
        return menu
    }
    
    
    /// Populates an AI menu with preset commands and free prompt.
    @MainActor
    static func populateMenu(_ menu: NSMenu) {
        
        menu.removeAllItems()
        
        let commands = AICommandManager.shared.commands
        
        if commands.isEmpty {
            let emptyItem = NSMenuItem(title: String(localized: "No Presets", table: "AI"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for command in commands {
                let item = NSMenuItem(
                    title: command.label,
                    action: #selector(ContentViewController.handleAICommand(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = command
                menu.addItem(item)
            }
        }
        
        menu.addItem(.separator())
        
        // Free prompt
        let freeItem = NSMenuItem(
            title: String(localized: "Free Prompt…", table: "AI"),
            action: #selector(ContentViewController.showAIFreePromptDialog(_:)),
            keyEquivalent: "p"
        )
        freeItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(freeItem)
    }
}


// MARK: - Menu Delegate (Dynamic Rebuild)

/// Rebuilds the AI menu each time it opens to reflect current presets.
final class AIMenuDelegate: NSObject, NSMenuDelegate {
    
    @MainActor static let shared = AIMenuDelegate()
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        
        AIMenuBuilder.populateMenu(menu)
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
