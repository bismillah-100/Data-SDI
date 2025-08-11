//
//  BuatKategori.swift
//  Data SDI
//
//  Created by Bismillah on 12/10/24.
//

import Cocoa

/// Definisi Enum untuk Tipe Kategori yang digunakan ``KategoriBaruDelegate``.
enum CategoryType: String {
    case guru
    case jabatan
    case semester
    case kelas

    static func suggestions(_ type: CategoryType) -> Set<String> {
        return switch type {
        case .guru:
            ReusableFunc.namaguru
        case .jabatan:
            ReusableFunc.jabatan
        case .semester:
            ReusableFunc.semester
        case .kelas:
            [""]
        }
    }
}

/// Protokol untuk delegasi untuk menambahkan kategori / semester baru
/// saat akan menambahkan nilai di ``AddTugasGuruVC``, ``NaikKelasVC`` dan``AddDetaildiKelas``.
protocol KategoriBaruDelegate: AnyObject {
    /// Meneruskan nama kategori baru ke objek yang menjalankan delegasi.
    func didAddNewCategory(_ category: String, ofType categoryType: CategoryType)
    /// Membersihkan referensi jendela `NSWindowController` yang memuat
    /// tampilan ``KategoriBaruViewController``.
    func didCloseWindow()
}

/// Class yang menangani penambahan data kategori baru ketika
/// akan menambahkan data baru menggunakan `NSPopUpButton`.
class KategoriBaruViewController: NSViewController {
    /// Outlet untuk pengetikan nama kategori baru.
    @IBOutlet weak var smstrBaruTextField: NSTextField!
    /// Outlet tombol untuk menutup.
    @IBOutlet weak var tutupButton: NSButton!

    /// Referensi jika objek pemicu adalah `ViewController` yang dibuka
    /// melalui class AppDelegate. Ketika membuka ``AddDetaildiKelas`` dari Menu Bar.
    var appDelegate: Bool = false

    /// Delegate yang menangani peristiwa terkait penambahan semester baru.
    weak var delegate: KategoriBaruDelegate?

    // Suggestion TextField
    /// Instans ``SuggestionManager``.
    var suggestionManager: SuggestionManager!

    // Ini akan menampung tipe kategori yang akan ditambahkan.
    var categoryType: CategoryType!
    
    /// Prediksi ketik untuk ``smstrBaruTextField``.
    var suggestions = Set<String>()

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

    /// Fungsi ketika tombol "simpan" diklik.
    /// Menjalankan delegate?.didAddNewSemester untuk meneruskan nama semester baru ke
    /// objek yang menangani delegasi.
    /// - Parameter sender: Objek pemicu dapat berupa apapun
    @IBAction func simpanSemester(_ sender: Any) {
        /// Pastikan input pengetikan semester baru tidak kosong.
        guard !smstrBaruTextField.stringValue.isEmpty else { return }
        let newSemester = smstrBaruTextField.stringValue.capitalizedAndTrimmed()
        delegate?.didAddNewCategory(newSemester, ofType: categoryType)
        tutup(sender)
    }

    /// Fungsi ketika ``tutupButton`` diklik.
    /// Menutup window yang memuat tampilan ``KategoriBaruViewController``
    /// dan menjalankan delegate?.didCloseWindow untuk meneruskan
    /// penanganan ke objek yang menangani delegasi.
    /// - Parameter sender:
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
        guard let textField = obj.object as? NSTextField, UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        let suggestionsDict: [NSTextField: [String]] = [
            smstrBaruTextField: Array(suggestions),
        ]
        if let activeTextField = obj.object as? NSTextField {
            suggestionManager.suggestions = suggestionsDict[activeTextField] ?? []
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
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
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return false }
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
