//
//  AIResultView.swift
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
import AppKit

/// A SwiftUI view that displays the AI result with accept/reject controls.
struct AIResultView: View {
    
    let result: AIResult?
    let isProcessing: Bool
    let errorMessage: String?
    
    var onAccept: (() -> Void)?
    var onReject: (() -> Void)?
    var onCopy: (() -> Void)?
    
    
    var body: some View {
        
        VStack(spacing: 0) {
            // Header toolbar
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                
                if let result {
                    Text(result.command.label)
                        .font(.headline)
                    
                    Text("(\(result.model))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isProcessing {
                    Text(String(localized: "Processing…", table: "AI"))
                        .font(.headline)
                } else {
                    Text(String(localized: "AI Result", table: "AI"))
                        .font(.headline)
                }
                
                Spacer()
                
                if let _ = result {
                    Button {
                        self.onCopy?()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .help(String(localized: "Copy result", table: "AI"))
                    .buttonStyle(.borderless)
                    
                    Button(String(localized: "Reject", table: "AI")) {
                        self.onReject?()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    Button(String(localized: "Accept", table: "AI")) {
                        self.onAccept?()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                }
                
                if !isProcessing && result == nil {
                    Button {
                        self.onReject?()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            
            Divider()
            
            // Content area
            Group {
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text(String(localized: "Waiting for AI response…", table: "AI"))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if let result {
                    AIResultTextView(text: result.resultText)
                } else {
                    Text(String(localized: "No result yet.", table: "AI"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}


// MARK: - NSTextView Wrapper

/// A wrapped NSTextView for displaying AI result text with proper font rendering.
struct AIResultTextView: NSViewRepresentable {
    
    let text: String
    
    
    func makeNSView(context: Context) -> NSScrollView {
        
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.backgroundColor = .textBackgroundColor
        textView.string = self.text
        
        return scrollView
    }
    
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.string != self.text {
            textView.string = self.text
        }
    }
}
