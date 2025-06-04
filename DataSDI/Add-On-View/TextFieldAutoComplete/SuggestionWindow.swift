//
//  WindowController.swift
//  TextField Completion
//
//  Created by Bismillah on 01/10/24.
//

import Cocoa
class SuggestionWindow: NSPanel {
    private var suggestionView: SuggestionView
    var onSuggestionSelected: ((Int, String) -> Void)?
    
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        suggestionView = SuggestionView(frame: contentRect)
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: backing, defer: flag)
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.contentView = NSView(frame: contentRect)
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.backgroundColor = .clear
        self.contentView?.addSubview(suggestionView)
        
        suggestionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            suggestionView.topAnchor.constraint(equalTo: contentView!.topAnchor),
            suggestionView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            suggestionView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            suggestionView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor)
        ])
        
        suggestionView.onSuggestionSelected = { [weak self] int, suggestion in
            self?.onSuggestionSelected?(int, suggestion)
        }
    }
    
    func updateSuggestions(_ suggestions: [String]) {
        suggestionView.updateSuggestions(suggestions)
        setContentSize(suggestionView.frame.size)
    }
    
    func selectSuggestion(at index: Int) {
        suggestionView.selectSuggestion(at: index)
    }
}

