//
//  ContentViewController.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2024-05-04.
//
//  ---------------------------------------------------------------------------
//
//  © 2024-2025 1024jp
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import AppKit
import SwiftUI

final class ContentViewController: NSSplitViewController {
    
    // MARK: Public Properties
    
    var document: DataDocument?  { didSet { self.updateDocument(from: oldValue) } }
    
    var documentViewController: DocumentViewController? {
        
        self.splitViewItems.first?.viewController as? DocumentViewController
    }
    
    
    // MARK: AI Properties
    
    private var aiPanelItem: NSSplitViewItem?
    private var currentAIResult: AIResult?
    
    
    // MARK: Lifecycle
    
    init(document: DataDocument?) {
        
        self.document = document
        
        super.init(nibName: nil, bundle: nil)
        
        self.splitViewItems = [
            NSSplitViewItem(viewController: .viewController(document: document)),
        ]
    }
    
    
    required init?(coder: NSCoder) {
        
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.splitView.isVertical = false
    }
    
    
    // MARK: Split View Controller Methods
    
    override func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        
        // avoid showing draggable cursor for the status bar boundary
        // but allow AI panel divider to be draggable
        if self.aiPanelItem != nil && dividerIndex == self.splitViewItems.count - 2 {
            return proposedEffectiveRect
        }
        return .zero
    }
    
    
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        
        super.splitViewDidResizeSubviews(notification)
        
        // Save AI panel split ratio when user drags the divider
        guard let aiItem = self.aiPanelItem,
              let aiView = aiItem.viewController.viewIfLoaded
        else { return }
        
        let totalHeight = self.splitView.frame.height
        guard totalHeight > 0 else { return }
        
        let ratio = aiView.frame.height / totalHeight
        if ratio > 0.05 {
            UserDefaults.standard.set(ratio, forKey: "aiPanelSplitRatio")
        }
    }
    
    
    // MARK: AI Methods
    
    /// Executes an AI command on the current editor selection or full text.
    func executeAICommand(_ command: AICommand) {
        
        guard let docVC = self.documentViewController,
              let textView = docVC.focusedTextView
        else { return }
        
        let selectedRange = textView.selectedRange()
        let text: String
        if selectedRange.length > 0,
           let selectedText = (textView.string as NSString?)?.substring(with: selectedRange) {
            text = selectedText
        } else {
            text = textView.string
        }
        
        guard !text.isEmpty else { return }
        
        // Show the AI panel with loading state
        let syntaxName = (self.document as? Document)?.syntaxName
        self.showAIPanel(processing: true)
        
        Task {
            do {
                let result = try await AIService.shared.execute(
                    command: command,
                    text: text,
                    syntaxName: syntaxName
                )
                self.currentAIResult = result
                self.showAIPanel(result: result)
            } catch {
                self.showAIPanel(error: error.localizedDescription)
            }
        }
    }
    
    
    /// Executes a free-form AI prompt.
    func executeFreePrompt(_ prompt: String) {
        
        guard let docVC = self.documentViewController,
              let textView = docVC.focusedTextView
        else { return }
        
        let selectedRange = textView.selectedRange()
        let text: String
        if selectedRange.length > 0,
           let selectedText = (textView.string as NSString?)?.substring(with: selectedRange) {
            text = selectedText
        } else {
            text = textView.string
        }
        
        guard !text.isEmpty else { return }
        
        self.showAIPanel(processing: true)
        
        Task {
            do {
                let result = try await AIService.shared.executeFreePrompt(prompt, text: text)
                self.currentAIResult = result
                self.showAIPanel(result: result)
                
                // Ask user to save as preset
                self.offerSaveAsPreset(prompt: prompt)
            } catch {
                self.showAIPanel(error: error.localizedDescription)
            }
        }
    }
    
    
    /// Accepts the AI result and replaces the original text.
    func acceptAIResult() {
        
        guard let result = self.currentAIResult,
              let docVC = self.documentViewController,
              let textView = docVC.focusedTextView
        else { return }
        
        let selectedRange = textView.selectedRange()
        
        if selectedRange.length > 0 {
            // Replace the selection
            textView.insertText(result.resultText, replacementRange: selectedRange)
        } else {
            // Replace the entire document
            textView.selectAll(nil)
            textView.insertText(result.resultText, replacementRange: textView.selectedRange())
        }
        
        self.hideAIPanel()
    }
    
    
    /// Rejects the AI result and closes the panel.
    func rejectAIResult() {
        
        self.hideAIPanel()
    }
    
    
    // MARK: Private AI Methods
    
    private func showAIPanel(processing: Bool = false, result: AIResult? = nil, error: String? = nil) {
        
        // Remove existing panel if any
        if let existingItem = self.aiPanelItem {
            self.removeSplitViewItem(existingItem)
        }
        
        let editorFontSize = self.documentViewController?.focusedTextView?.font?.pointSize ?? NSFont.systemFontSize
        
        var resultView = AIResultView(
            result: result,
            isProcessing: processing,
            errorMessage: error,
            fontSize: editorFontSize
        )
        resultView.onAccept = { [weak self] in self?.acceptAIResult() }
        resultView.onReject = { [weak self] in self?.rejectAIResult() }
        resultView.onCopy = { [weak self] in
            guard let text = self?.currentAIResult?.resultText else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        
        let hostingController = NSHostingController(rootView: resultView)
        let item = NSSplitViewItem(viewController: hostingController)
        item.minimumThickness = 120
        item.canCollapse = false
        
        // Insert before the last item (status bar) if it exists, otherwise append
        let insertIndex = max(self.splitViewItems.count - 1, 1)
        self.insertSplitViewItem(item, at: insertIndex)
        self.aiPanelItem = item
        
        // Set the AI panel height: use saved ratio or default 50%
        DispatchQueue.main.async {
            let totalHeight = self.splitView.frame.height
            guard totalHeight > 0 else { return }
            
            let savedRatio = UserDefaults.standard.double(forKey: "aiPanelSplitRatio")
            let ratio = (savedRatio > 0.1 && savedRatio < 0.9) ? savedRatio : 0.5
            let dividerPosition = totalHeight * (1.0 - ratio)
            
            self.splitView.setPosition(dividerPosition, ofDividerAt: insertIndex - 1)
        }
    }
    
    
    /// Offers to save a free prompt as a reusable preset.
    private func offerSaveAsPreset(prompt: String) {
        
        let alert = NSAlert()
        alert.messageText = String(localized: "Save as Preset?", table: "AI")
        alert.informativeText = String(localized: "Would you like to save this prompt as a reusable preset?", table: "AI")
        alert.addButton(withTitle: String(localized: "Save", table: "AI"))
        alert.addButton(withTitle: String(localized: "Don't Save", table: "AI"))
        alert.alertStyle = .informational
        
        // Add a text field for the preset name
        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        nameField.placeholderString = String(localized: "Preset Name", table: "AI")
        nameField.stringValue = String(prompt.prefix(40))
        alert.accessoryView = nameField
        
        guard let window = self.view.window else { return }
        
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            
            let name = nameField.stringValue.isEmpty ? String(prompt.prefix(40)) : nameField.stringValue
            let command = AICommand(label: name, systemPrompt: prompt)
            AICommandManager.shared.addCommand(command)
        }
    }
    
    
    private func hideAIPanel() {
        
        if let item = self.aiPanelItem {
            self.removeSplitViewItem(item)
            self.aiPanelItem = nil
        }
        self.currentAIResult = nil
    }
    
    
    // MARK: Private Methods
    
    /// Updates the document in children.
    private func updateDocument(from oldDocument: DataDocument?) {
        
        guard oldDocument != self.document else { return }
        
        self.splitViewItems[0] = NSSplitViewItem(viewController: .viewController(document: self.document))
    }
}


private extension NSViewController {
    
    /// Creates a new view controller with the passed-in document.
    ///
    /// - Parameter document: The represented document.
    /// - Returns: A view controller.
    static func viewController(document: DataDocument?) -> sending NSViewController {
        
        switch document {
            case let document as Document:
                DocumentViewController(document: document)
            case let document as PreviewDocument:
                NSHostingController(rootView: FilePreviewView(item: document))
            case .none:
                NSHostingController(rootView: NoDocumentView())
            default:
                preconditionFailure()
        }
    }
}
