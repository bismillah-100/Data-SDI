//
//  AddTugasGuruDelegate.swift
//  Data SDI
//
//  Created by MacBook on 15/07/25.
//

import Cocoa

extension AddTugasGuruVC: NSTextFieldDelegate {
    func controlTextDidBeginEditing(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        activeText = obj.object as? NSTextField
        if let activeTextField = obj.object as? NSTextField {
            if options == .tambahGuru || options == .editGuru {
                let suggestionsDict: [NSTextField: [String]] = [
                    nameTextField: Array(ReusableFunc.namaguru),
                    addressTextField: Array(ReusableFunc.alamat),
                ]
                suggestionManager.suggestions = suggestionsDict[activeTextField] ?? []
            } else {
                suggestionManager.suggestions = Array(ReusableFunc.mapel)
            }
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
        if textField === tahunAjaran1TextField,
           let intValue = Int(textField.stringValue)
        {
            tahunAjaran2TextField.stringValue = String(intValue + 1)
            return
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        if let activeTextField = obj.object as? NSTextField {
            // Find the last word (after the last space)
            if let lastSpaceIndex = ReusableFunc.getLastLetterBeforeSpace(activeTextField.stringValue) {
                // Update the text field with only the last letter
                suggestionManager.typing = lastSpaceIndex
            } else {
                suggestionManager.typing = activeText.stringValue
            }
        }

        if activeText?.stringValue.isEmpty == true {
            suggestionManager.hideSuggestions()
        } else {
            suggestionManager.controlTextDidChange(obj)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        suggestionManager.controlTextField(control, textView: textView, doCommandBy: commandSelector)
    }
}

extension AddTugasGuruVC: KategoriBaruDelegate {
    /// Menampilkan atau membuat jendela popup kategori.
    /// - Parameter sender: NSMenuItem yang memicu aksi ini. Objek ini harus memiliki `representedObject` bertipe `CategoryType`.
    /// - Catatan: Jika jendela kategori (`kategoriWindow`) sudah ada, maka jendela tersebut akan dibawa ke depan.
    /// Jika belum ada, maka akan dibuat jendela kategori baru menggunakan fungsi ``ReusableFunc/openNewCategoryWindow(_:viewController:type:menuBar:suggestions:)``.
    @objc func buatMenuPopUp(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? CategoryType else { return }
        guard kategoriWindow == nil else {
            kategoriWindow?.window?.makeKeyAndOrderFront(sender)
            if let vc = kategoriWindow?.contentViewController as? KategoriBaruViewController {
                vc.categoryType = context
            }
            return
        }

        kategoriWindow = ReusableFunc.openNewCategoryWindow(view, viewController: self, type: context, suggestions: CategoryType.suggestions(context))
    }

    /// Fungsi dari ``DataSDI/KategoriBaruDelegate`` saat jendela pembuatan kategori ditutup.
    func didCloseWindow() {
        kategoriWindow = nil
    }

    /// Menangani penambahan kategori baru berdasarkan tipe kategori yang dipilih.
    /// - Parameters:
    ///   - category: Nama kategori baru yang akan ditambahkan.
    ///   - categoryType: Tipe kategori yang akan ditambahkan (guru, semester, jabatan, dll).
    ///
    /// Untuk tipe `.guru`, fungsi akan menambah guru baru ke database, memasukkan nama guru ke dalam `namaPopUpButton`, dan memilih item tersebut.
    /// Untuk tipe `.semester`, fungsi akan menambah semester baru ke dalam `semesterPopUpButton` dan memilihnya.
    /// Untuk tipe `.jabatan`, fungsi akan menambah jabatan baru ke database, memasukkan nama jabatan ke dalam `jabatanPopUpButton`, dan memilih item tersebut.
    /// Jika terjadi kesalahan saat menambah guru, akan ditampilkan alert.
    /// Tipe kategori lain tidak dilakukan aksi apapun.
    func didAddNewCategory(_ category: String, ofType categoryType: CategoryType) {
        switch categoryType {
        case .guru:
            guard let guruID = dbController.tambahGuru(category) else {
                ReusableFunc.showAlert(title: "Error", message: "Tidak dapat menambahkan guru baru.")
                return
            }
            let itemIndex = namaPopUpButton.numberOfItems - 2
            namaPopUpButton.insertItem(withTitle: category, at: itemIndex)
            namaPopUpButton.item(at: itemIndex)?.tag = Int(guruID)
            namaPopUpButton.selectItem(at: itemIndex)
        case .semester:
            semesterPopUpButton.insertItem(withTitle: category, at: semesterPopUpButton.numberOfItems - 2)
            semesterPopUpButton.selectItem(at: semesterPopUpButton.numberOfItems - 3)
        case .jabatan:
            Task {
                guard let jabatanID = await IdsCacheManager.shared.jabatanID(for: category) else { return }
                let itemIndex = jabatanPopUpButton.numberOfItems - 2
                jabatanPopUpButton.insertItem(withTitle: category, at: itemIndex)
                jabatanPopUpButton.item(at: itemIndex)?.tag = Int(jabatanID)
                jabatanPopUpButton.selectItem(at: itemIndex)
            }
        default: break
        }
    }
}
