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
        if ok, let scrollView = enclosingScrollView, let superview = superview {
            ReusableFunc.scrollToFirstResponderIfNeeded(superview, scrollView: scrollView)
        }
        return ok
    }
}
