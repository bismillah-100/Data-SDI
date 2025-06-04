//
//  SuggestionManager.swift
//  TextField Completion
//
//  Created by Bismillah on 02/10/24.
//

import Cocoa

class SuggestionManager: NSObject, NSTextFieldDelegate {
    let suggestionWindow: SuggestionWindow
    private let suggestionView: SuggestionView
    private weak var activeTextField: NSTextField?
    var suggestions = [""]
    var typing: String = ""
    private var currentSuggestions: [String] = []
    private var selectedSuggestionIndex: Int = -1
    public var isHidden: Bool = true
    
    init(suggestions: [String]) {
        self.suggestionWindow = SuggestionWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),backing: .buffered, defer: false)
        self.suggestionView = SuggestionView()
        super.init()
        self.suggestions = suggestions
        suggestionWindow.onSuggestionSelected = { [weak self] index, suggestion in
            guard let self = self else { return }

            if self.selectedSuggestionIndex == index {
                // Jika item yang diklik sudah terpilih, langsung terapkan saran
                self.applySuggestion(suggestion)
            } else {
                // Jika item yang diklik berbeda, perbarui pilihan dan highlight
                self.selectedSuggestionIndex = index
            }
        }
    }
    
    private func updateSelectedSuggestion() {
        suggestionWindow.selectSuggestion(at: selectedSuggestionIndex)
    }
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        activeTextField = textField
        
        generateSuggestions(for: typing) { [weak self] suggestions in
            guard let self = self else { return }
            self.currentSuggestions = suggestions
            self.suggestionWindow.updateSuggestions(suggestions)
            
            if !suggestions.isEmpty {
                if self.selectedSuggestionIndex == -1 {
                    self.selectedSuggestionIndex = 0
                    self.updateSelectedSuggestion()
                }
                self.showSuggestions(for: textField)
                self.isHidden = false
            } else {
                self.hideSuggestions()
                self.isHidden = true
            }
        }
    }

    func showSuggestions(for textField: NSTextField) {
        guard let window = textField.window,
              !(window.childWindows?.contains(suggestionWindow) ?? false) else {
            #if DEBUG
            print("window sudah ada")
            #endif
            return
        }
        
        // Convert the text field's frame to window coordinates
        let textFieldFrameInWindow = textField.convert(textField.bounds, to: nil)
        
        // Convert the window coordinates to screen coordinates
        let textFieldFrameOnScreen = window.convertToScreen(textFieldFrameInWindow)
        
        // Calculate the suggestion window position
        let suggestionWindowOrigin = NSPoint(
            x: textFieldFrameOnScreen.minX,
            y: textFieldFrameOnScreen.minY - suggestionWindow.frame.height - 5 // Tambahkan offset 5 px
        )
        
        let suggestionWindowSize = NSSize(
            width: textFieldFrameOnScreen.width,
            height: suggestionWindow.frame.height
        )
        
        let windowFrame = NSRect(origin: suggestionWindowOrigin, size: suggestionWindowSize)
        
        suggestionWindow.setFrame(windowFrame, display: true)
        
        // If the text field is in a popover, we need to make the suggestion window a child of the main window
        if let _ = findPopover(for: textField), let mainWindow = NSApp.mainWindow {
            mainWindow.addChildWindow(suggestionWindow, ordered: .above)
        } else {
            window.addChildWindow(suggestionWindow, ordered: .above)
        }
    }
    private func findPopover(for view: NSView) -> NSPopover? {
        var currentView: NSView? = view
        while currentView != nil {
            let siswa = SiswaViewController()
            if (currentView?.enclosingMenuItem?.view) != nil {
                let popover =  siswa.popover
                return popover
            }
            currentView = currentView?.superview
        }
        return nil
    }
    func hideSuggestions() {
        isHidden = true
        selectedSuggestionIndex = -1
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Hapus window dari parent untuk membebaskan resource
            if let parentWindow = self.suggestionWindow.parent {
                parentWindow.removeChildWindow(self.suggestionWindow)
                #if DEBUG
                print("removeSuggestionsWindow:", self.suggestionWindow, "fromWindow:", parentWindow)
                #endif
            }
            self.suggestionWindow.close()
        }
    }
    
    func generateSuggestions(for input: String, completion: @escaping ([String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            // Lakukan filtering dan sorting di background
            let filteredSuggestions = self.suggestions
                .filter { $0.lowercased().hasPrefix(input.lowercased()) }
                .sorted {
                    if $0.count == $1.count {
                        return $0.lowercased() < $1.lowercased()
                    }
                    return $0.count < $1.count
                }
            let userDefaults = UserDefaults.standard
            let maxSuggestions = userDefaults.integer(forKey: "maksimalSaran")
            let maxLimit = maxSuggestions > 0 ? maxSuggestions : 5
            let limitedSuggestions = Array(filteredSuggestions.prefix(maxLimit))
            
            // Pindahkan hasil kembali ke main thread
            DispatchQueue.main.async {
                completion(limitedSuggestions)
            }
        }
    }

    
    func moveUp() {
        guard !isHidden else {return}
        
        if selectedSuggestionIndex > 0 {
            selectedSuggestionIndex -= 1
        } else {
            selectedSuggestionIndex = currentSuggestions.count - 1
        }
        suggestionView.selectSuggestion(at: selectedSuggestionIndex)
        
        updateSelectedSuggestion()
    }
    func moveDown() {
        guard !isHidden else {return}
        
        if selectedSuggestionIndex < currentSuggestions.count - 1 {
            selectedSuggestionIndex += 1
        } else {
            selectedSuggestionIndex = 0
        }
        suggestionView.selectSuggestion(at: selectedSuggestionIndex)
        
        updateSelectedSuggestion()
    }
    func enterSuggestions() {
        guard selectedSuggestionIndex != -1 else {return}
        applySuggestion(currentSuggestions[selectedSuggestionIndex])
        
        isHidden = true
    }
    private func applySuggestion(_ suggestion: String) {
        guard let textField = activeTextField else { return }
        
        let currentText = textField.stringValue
        if let lastSpaceIndex = currentText.lastIndex(of: " ") {
            let prefix = String(currentText[..<lastSpaceIndex])
            textField.stringValue = prefix + " " + suggestion + " "
        } else {
            textField.stringValue = suggestion + " "
        }
        
        // Move the cursor to the end of the text field
        textField.currentEditor()?.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
        hideSuggestions()
    }
    
    deinit {
        suggestionWindow.orderOut(nil)
        suggestionWindow.parent?.removeChildWindow(suggestionWindow)
    }
}

