//
//  InlineDiffController.swift
//
//  AntiElectricity (forked from CotEditor)
//

import AppKit

/// Manages VS Code–style inline diff visualization within an NSTextView.
///
/// When activated:
/// 1. Highlights the original (SEARCH) text with red background + strikethrough
/// 2. Inserts the replacement (REPLACE) text with green background right after (ghost text)
/// 3. Shows floating Accept/Reject controls near the diff
///
/// Ghost text insertion uses disabled undo registration.
/// Accept: replaces original+ghost with replacement text (undoable).
/// Reject: removes ghost text, restores original styling.
final class InlineDiffController: NSObject {
    
    // MARK: Properties
    
    private weak var textView: NSTextView?
    private let searchText: String
    private let replaceText: String
    private var originalRange: NSRange
    private var ghostTextLength: Int = 0
    private(set) var isActive = false
    
    private var controlsView: NSView?
    
    var onAccept: (() -> Void)?
    var onReject: (() -> Void)?
    
    
    // MARK: Lifecycle
    
    init(textView: NSTextView, searchRange: NSRange, searchText: String, replaceText: String) {
        
        self.textView = textView
        self.originalRange = searchRange
        self.searchText = searchText
        self.replaceText = replaceText
        super.init()
    }
    
    
    // MARK: Public Methods
    
    /// Activates the inline diff display.
    func activate() {
        
        guard let textView, let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage
        else { return }
        guard !isActive else { return }
        isActive = true
        
        // 1. Style SEARCH text: red background + strikethrough
        layoutManager.addTemporaryAttribute(
            .backgroundColor,
            value: NSColor.systemRed.withAlphaComponent(0.18),
            forCharacterRange: originalRange
        )
        layoutManager.addTemporaryAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            forCharacterRange: originalRange
        )
        layoutManager.addTemporaryAttribute(
            .strikethroughColor,
            value: NSColor.systemRed.withAlphaComponent(0.7),
            forCharacterRange: originalRange
        )
        
        // 2. Insert ghost text (replacement) right after search range
        let insertPoint = originalRange.location + originalRange.length
        let ghostString = "\n" + replaceText
        ghostTextLength = (ghostString as NSString).length
        
        let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let ghostAttrs: [NSAttributedString.Key: Any] = [
            .backgroundColor: NSColor.systemGreen.withAlphaComponent(0.12),
            .foregroundColor: NSColor.labelColor,
            .font: font,
        ]
        
        // Disable undo for ghost text insertion (it's temporary)
        textView.undoManager?.disableUndoRegistration()
        textStorage.beginEditing()
        textStorage.insert(
            NSAttributedString(string: ghostString, attributes: ghostAttrs),
            at: insertPoint
        )
        textStorage.endEditing()
        textView.undoManager?.enableUndoRegistration()
        
        // 3. Scroll to show the full diff area
        let fullRange = NSRange(
            location: originalRange.location,
            length: originalRange.length + ghostTextLength
        )
        textView.scrollRangeToVisible(fullRange)
        
        // 4. Show floating controls (after layout settles)
        DispatchQueue.main.async { [weak self] in
            self?.showControls()
        }
    }
    
    
    // MARK: Actions
    
    /// Accepts: removes original text, keeps replacement.
    @objc func acceptClicked() {
        
        guard isActive, let textView, let textStorage = textView.textStorage,
              let layoutManager = textView.layoutManager
        else { return }
        
        controlsView?.removeFromSuperview()
        controlsView = nil
        
        // Current document state: [...][SEARCH (red)][GHOST (green)][...]
        // Goal: [...][REPLACE (normal)][...]
        
        let combinedLength = originalRange.length + ghostTextLength
        let combinedRange = NSRange(location: originalRange.location, length: combinedLength)
        
        // Clear temporary attributes
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: combinedRange)
        layoutManager.removeTemporaryAttribute(.strikethroughStyle, forCharacterRange: originalRange)
        layoutManager.removeTemporaryAttribute(.strikethroughColor, forCharacterRange: originalRange)
        
        // Replace combined region with replacement text (undoable via shouldChangeText)
        if textView.shouldChangeText(in: combinedRange, replacementString: replaceText) {
            textStorage.beginEditing()
            textStorage.replaceCharacters(in: combinedRange, with: replaceText)
            
            // Restore normal styling on the replacement text
            let newRange = NSRange(location: originalRange.location, length: (replaceText as NSString).length)
            if newRange.length > 0 {
                textStorage.setAttributes(textView.typingAttributes, range: newRange)
            }
            textStorage.endEditing()
            textView.didChangeText()
        }
        
        isActive = false
        onAccept?()
    }
    
    
    /// Rejects: removes ghost text, restores original.
    @objc func rejectClicked() {
        
        guard isActive, let textView, let textStorage = textView.textStorage,
              let layoutManager = textView.layoutManager
        else { return }
        
        controlsView?.removeFromSuperview()
        controlsView = nil
        
        // Remove ghost text
        let ghostRange = NSRange(
            location: originalRange.location + originalRange.length,
            length: ghostTextLength
        )
        
        textView.undoManager?.disableUndoRegistration()
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: ghostRange, with: "")
        textStorage.endEditing()
        textView.undoManager?.enableUndoRegistration()
        
        // Remove styling from original text
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: originalRange)
        layoutManager.removeTemporaryAttribute(.strikethroughStyle, forCharacterRange: originalRange)
        layoutManager.removeTemporaryAttribute(.strikethroughColor, forCharacterRange: originalRange)
        
        isActive = false
        onReject?()
    }
    
    
    // MARK: Private Methods
    
    private func showControls() {
        
        guard let textView, let layoutManager = textView.layoutManager else { return }
        
        let searchGlyphRange = layoutManager.glyphRange(
            forCharacterRange: originalRange, actualCharacterRange: nil
        )
        let boundingRect = layoutManager.boundingRect(
            forGlyphRange: searchGlyphRange, in: textView.textContainer!
        )
        
        let ctrlWidth: CGFloat = 150
        let ctrlHeight: CGFloat = 28
        
        // Position at the right of the first line of the diff
        let visibleMaxX = textView.enclosingScrollView?.documentVisibleRect.maxX
            ?? textView.bounds.maxX
        let x = min(
            boundingRect.maxX + textView.textContainerOrigin.x + 12,
            visibleMaxX - ctrlWidth - 12
        )
        let y = boundingRect.origin.y + textView.textContainerOrigin.y - 2
        
        // Container view
        let container = NSView(frame: NSRect(x: x, y: y, width: ctrlWidth, height: ctrlHeight))
        container.wantsLayer = true
        container.layer?.cornerRadius = 6
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        container.layer?.borderColor = NSColor.separatorColor.cgColor
        container.layer?.borderWidth = 0.5
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.15
        container.layer?.shadowRadius = 4
        container.layer?.shadowOffset = NSSize(width: 0, height: -2)
        
        // Accept button
        let acceptBtn = NSButton(frame: NSRect(x: 4, y: 3, width: 68, height: 22))
        acceptBtn.title = "✓ Accept"
        acceptBtn.bezelStyle = .recessed
        acceptBtn.isBordered = true
        acceptBtn.font = .systemFont(ofSize: 11, weight: .medium)
        acceptBtn.contentTintColor = .systemGreen
        acceptBtn.target = self
        acceptBtn.action = #selector(acceptClicked)
        acceptBtn.keyEquivalent = "\r"
        
        // Reject button
        let rejectBtn = NSButton(frame: NSRect(x: 76, y: 3, width: 68, height: 22))
        rejectBtn.title = "✗ Reject"
        rejectBtn.bezelStyle = .recessed
        rejectBtn.isBordered = true
        rejectBtn.font = .systemFont(ofSize: 11, weight: .medium)
        rejectBtn.contentTintColor = .systemRed
        rejectBtn.target = self
        rejectBtn.action = #selector(rejectClicked)
        rejectBtn.keyEquivalent = "\u{1b}"
        
        container.addSubview(acceptBtn)
        container.addSubview(rejectBtn)
        
        textView.addSubview(container)
        self.controlsView = container
    }
}
