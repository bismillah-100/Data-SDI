//
//  NaikKelasTextField.swift
//  Data SDI
//
//  Created by MacBook on 20/08/25.
//

import AppKit

extension NaikKelasVC: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        if textField === inputTahun1,
           let intValue = Int(textField.stringValue)
        {
            inputTahun2.stringValue = String(intValue + 1)
            return
        }
    }
}
