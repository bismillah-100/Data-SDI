//
//  SuggetionsTextField.swift
//  Data SDI
//
//  Created by Bismillah on 04/10/24.
//

import Cocoa

class SuggestionItemView: NSView {
    let textField: NSTextField
    var index: Int = 0
    var isHighlighted: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    init(frame: NSRect, text: String, index: Int) {
        textField = NSTextField(frame: NSRect(x: 8, y: 0, width: frame.width - 16, height: frame.height))
        self.index = index
        super.init(frame: frame)

        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.textColor = .labelColor
        textField.stringValue = text
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingTail
        textField.toolTip = textField.stringValue
        addSubview(textField)

        wantsLayer = true
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            NSColor.controlAccentColor.setFill()
            dirtyRect.fill(using: .sourceOver)
        } else {
            NSColor.clear.setFill()
            dirtyRect.fill(using: .sourceOver)
        }
        super.draw(dirtyRect)
    }

    private func updateAppearance() {
        textField.textColor = isHighlighted ? .white : .labelColor
        needsDisplay = true
    }
}
