//
//  BuatKategori.swift
//  Data SDI
//
//  Created by Bismillah on 12/10/24.
//

import Cocoa

protocol KategoriBaruDelegate: AnyObject {
    func didAddNewSemester(_ semester: String)
    func didCloseWindow()
}

class KategoriBaruViewController: NSViewController {
    @IBOutlet var smstrBaruTextField: NSTextField!
    var appDelegate: Bool = false
    weak var delegate: KategoriBaruDelegate?
    @IBOutlet weak var tutupButton: NSButton!
    
    // Suggestion TextField
    var suggestionManager: SuggestionManager!
    override func viewDidLoad() {
        smstrBaruTextField.delegate = self
        suggestionManager = SuggestionManager(suggestions: [""])
    }
    override func viewDidAppear() {
        if appDelegate {
            tutupButton.isHidden = false
        } else {
            tutupButton.isHidden = true
        }
    }
    override func viewWillDisappear() {
        super.viewWillDisappear()
        if appDelegate {
            view.window?.close()
            NSApp.stopModal()
        }
    }
    @IBAction func simpanSemester(_ sender: Any) {
        guard !smstrBaruTextField.stringValue.isEmpty else {return}
        let newSemester = smstrBaruTextField.stringValue.capitalizedAndTrimmed()
        delegate?.didAddNewSemester(newSemester)
        tutup(sender)
    }
    @IBAction func tutup(_ sender: Any) {
        if let window = view.window {
            if let sheetParent = window.sheetParent {
                // Jika jendela adalah sheet, akhiri sheet
                sheetParent.endSheet(window, returnCode: .cancel)
            } else {
                // Jika jendela bukan sheet, lakukan aksi tutup
                window.performClose(sender)
            }
        }
        delegate?.didCloseWindow()
    }
}
extension KategoriBaruViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, UserDefaults.standard.bool(forKey: "showSuggestions") else {return}
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
    }
    func controlTextDidBeginEditing(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return}
        let suggestionsDict: [NSTextField: [String]] = [
            smstrBaruTextField: Array(ReusableFunc.semester)
        ]
        if let activeTextField = obj.object as? NSTextField {
            suggestionManager.suggestions = suggestionsDict[activeTextField] ?? []
        }
    }
    func controlTextDidChange(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return}
        if let activeTextField = obj.object as? NSTextField {
            // Get the current input text
            var currentText = activeTextField.stringValue
            if currentText.last == "," {
                // Cek apakah karakter sebelum koma adalah spasi
                if currentText.dropLast().last == " " {
                    // Hapus spasi sebelum koma
                    let indexBeforeComma = currentText.index(before: currentText.index(before: currentText.endIndex))
                    currentText.remove(at: indexBeforeComma)
                }
                // Update text field dengan teks yang sudah diubah (dengan koma tetap ada)
                activeTextField.stringValue = currentText
            }
            // Find the last word (after the last space)
            if let lastSpaceIndex = currentText.lastIndex(of: " ") {
                let startIndex = currentText.index(after: lastSpaceIndex)
                let lastWord = String(currentText[startIndex...])
                
                // Update the text field with only the last word
                suggestionManager.typing = lastWord
                
            } else {
                suggestionManager.typing = smstrBaruTextField.stringValue
            }
        }
        if smstrBaruTextField.stringValue.isEmpty == true {
            suggestionManager.hideSuggestions()
        } else {
            suggestionManager.controlTextDidChange(obj)
        }
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else {return false}
        if !suggestionManager.suggestionWindow.isVisible {
            return false
        }
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)):
            suggestionManager.moveUp()
            return true
        case #selector(NSResponder.moveDown(_:)):
            suggestionManager.moveDown()
            return true
        case #selector(NSResponder.insertNewline(_:)):
            suggestionManager.enterSuggestions()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            suggestionManager.hideSuggestions()
            return true
        case #selector(NSResponder.insertTab(_:)):
            suggestionManager.hideSuggestions()
            return false
        default:
            return false
        }
    }
}
