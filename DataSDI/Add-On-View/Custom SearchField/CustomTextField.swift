//
//  CustomTextField.swift
//  Data SDI
//
//  Created by Bismillah on 18/12/24.
//

import Cocoa
/// Class NSTextField kustom dengan tujuan mereset menu item di Menu Bar ketika menjadi `firstResponder` (View pertama yang menerima input keyboard)
/// dan mengirim notifikasi `NSWindow.didBecomeKeyNotification` ketika tidak menjadi `firstResponder`.
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
