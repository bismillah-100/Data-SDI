//
//  CustomTextField.swift
//  Data SDI
//
//  Created by MacBook on 11/08/25.
//

import Cocoa

/// Custom textField untuk scroll ke tempat textField ketika menerima input
/// sebagai firstResponder di window.
class CustomTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { scrollToFirstResponderIfNeeded(visualize: true) }
        return ok
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        scrollToFirstResponderIfNeeded(visualize: false)
    }

    private func scrollToFirstResponderIfNeeded(visualize: Bool) {
        guard let scrollView = enclosingScrollView,
              let documentView = scrollView.documentView else { return }

        let targetRect = convert(bounds, to: documentView)
        // let visibleRect = documentView.visibleRect

        // Cek posisi relatif
        // let isNearTop = targetRect.minY - visibleRect.minY < 50
        // let isNearBottom = visibleRect.maxY - targetRect.maxY < 50

        // Adjust padding based on position
        // let padding: CGFloat = 30
        // var scrollRect = targetRect

        // if isNearTop {
        // Jika dekat top, tambah padding di atas
        // scrollRect.origin.y -= padding
        // scrollRect.size.height += padding
        // } else if isNearBottom {
        // Jika dekat bottom, tambah padding di bawah
        // scrollRect.size.height += padding
        // } else {
        // Default: padding di kedua sisi
        // scrollRect = targetRect.insetBy(dx: 0, dy: -padding)
        // }

        if visualize {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.25
            NSAnimationContext.current.allowsImplicitAnimation = true
            documentView.animator().scrollToVisible(targetRect.insetBy(dx: 0, dy: -6))
            NSAnimationContext.endGrouping()
        } else {
            documentView.scrollToVisible(targetRect.insetBy(dx: 0, dy: -6))
        }
    }
}
