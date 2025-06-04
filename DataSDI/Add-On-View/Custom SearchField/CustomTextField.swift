//
//  CustomTextField.swift
//  Data SDI
//
//  Created by Bismillah on 18/12/24.
//

import Cocoa

class CustomTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        ReusableFunc.resetMenuItems()
        return super.becomeFirstResponder()
    }
    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: nil)
    }
}
