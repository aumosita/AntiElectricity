//
//  DiffPreviewPopover.swift
//
//  AntiElectricity (forked from CotEditor)
//

import AppKit

/// A popover that shows a before/after diff preview with Accept/Reject buttons.
final class DiffPreviewPopover: NSPopover {
    
    private let searchText: String
    private let replaceText: String
    private let onAccept: () -> Void
    private let onReject: () -> Void
    
    
    init(searchText: String, replaceText: String, onAccept: @escaping () -> Void, onReject: @escaping () -> Void) {
        
        self.searchText = searchText
        self.replaceText = replaceText
        self.onAccept = onAccept
        self.onReject = onReject
        
        super.init()
        
        self.behavior = .semitransient
        self.contentViewController = self.makeContentViewController()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private func makeContentViewController() -> NSViewController {
        
        let vc = NSViewController()
        let container = NSView()
        
        // --- Title ---
        let titleLabel = NSTextField(labelWithString: "Proposed Change")
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        
        // --- "Before" section ---
        let beforeLabel = NSTextField(labelWithString: "Before:")
        beforeLabel.font = .systemFont(ofSize: 10, weight: .medium)
        beforeLabel.textColor = .systemRed
        
        let beforeText = NSTextField(wrappingLabelWithString: self.searchText)
        beforeText.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        beforeText.textColor = .labelColor
        beforeText.backgroundColor = NSColor.systemRed.withAlphaComponent(0.08)
        beforeText.drawsBackground = true
        beforeText.isBordered = false
        beforeText.isEditable = false
        beforeText.maximumNumberOfLines = 20
        
        // --- "After" section ---
        let afterLabel = NSTextField(labelWithString: "After:")
        afterLabel.font = .systemFont(ofSize: 10, weight: .medium)
        afterLabel.textColor = .systemGreen
        
        let afterText = NSTextField(wrappingLabelWithString: self.replaceText)
        afterText.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        afterText.textColor = .labelColor
        afterText.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.08)
        afterText.drawsBackground = true
        afterText.isBordered = false
        afterText.isEditable = false
        afterText.maximumNumberOfLines = 20
        
        // --- Buttons ---
        let acceptButton = NSButton(title: "Accept", target: self, action: #selector(acceptClicked))
        acceptButton.bezelStyle = .rounded
        acceptButton.contentTintColor = .systemGreen
        acceptButton.keyEquivalent = "\r"
        
        let rejectButton = NSButton(title: "Reject", target: self, action: #selector(rejectClicked))
        rejectButton.bezelStyle = .rounded
        rejectButton.contentTintColor = .systemRed
        rejectButton.keyEquivalent = "\u{1b}"  // Escape
        
        let buttonStack = NSStackView(views: [rejectButton, acceptButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.distribution = .fillEqually
        
        // --- Layout ---
        let stack = NSStackView(views: [titleLabel, beforeLabel, beforeText, afterLabel, afterText, buttonStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        
        // Make button stack fill width
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            buttonStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
        ])
        
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
        ])
        
        vc.view = container
        return vc
    }
    
    
    @objc private func acceptClicked() {
        
        self.onAccept()
        self.close()
    }
    
    
    @objc private func rejectClicked() {
        
        self.onReject()
        self.close()
    }
}
