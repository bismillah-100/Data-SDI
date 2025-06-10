//
//  SuggestionManager.swift
//  TextField Completion
//
//  Created by Bismillah on 02/10/24.
//

import Cocoa

///  Class untuk mengelola prediksi otomatis pada NSTextField.
/// Digunakan untuk menampilkan prediksi berdasarkan input pengguna pada field teks.
class SuggestionManager: NSObject, NSTextFieldDelegate {
    /// Window yang melayang untuk menampilkan prediksi.
    let suggestionWindow: SuggestionWindow

    /// View yang menampilkan daftar prediksi.
    /// Digunakan untuk menampilkan daftar prediksi yang dihasilkan berdasarkan input pengguna.
    private let suggestionView: SuggestionView

    /// TextField yang sedang aktif dan menerima input.
    private weak var activeTextField: NSTextField?
    /// Daftar saran yang tersedia untuk prediksi.
    var suggestions = [""]
    /// String yang sedang diketik oleh pengguna.
    var typing: String = ""
    /// Daftar saran yang saat ini ditampilkan.
    private var currentSuggestions: [String] = []
    /// Indeks saran yang dipilih saat ini.
    private var selectedSuggestionIndex: Int = -1
    /// Menyimpan status visibilitas dari jendela saran.
    public var isHidden: Bool = true

    /// Inisialisasi `SuggestionManager` dengan daftar saran yang diberikan.
    /// Digunakan untuk menginisialisasi jendela saran dan view saran.
    /// - Parameter suggestions: Daftar saran yang akan digunakan untuk prediksi.
    /// - Returns: Instance dari `SuggestionManager`.
    /// - Note: Pastikan untuk mengaktifkan `NSTextFieldDelegate` memanggil `controlTextDidChange` pada `NSTextField` yang sesuai untuk memperbarui saran.
    init(suggestions: [String]) {
        suggestionWindow = SuggestionWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), backing: .buffered, defer: false)
        suggestionView = SuggestionView()
        super.init()
        self.suggestions = suggestions
        suggestionWindow.onSuggestionSelected = { [weak self] index, suggestion in
            guard let self else { return }

            if self.selectedSuggestionIndex == index {
                // Jika item yang diklik sudah terpilih, langsung terapkan saran
                self.applySuggestion(suggestion)
            } else {
                // Jika item yang diklik berbeda, perbarui pilihan dan highlight
                self.selectedSuggestionIndex = index
            }
        }
    }

    /// Memperbarui indeks saran yang dipilih dan menyorot saran yang sesuai.
    /// Digunakan untuk memperbarui tampilan saran yang dipilih berdasarkan indeks yang diberikan.
    /// - Note: Pastikan untuk memanggil metode ini setelah mengubah `selectedSuggestionIndex` untuk memperbarui tampilan saran yang dipilih.
    private func updateSelectedSuggestion() {
        suggestionWindow.selectSuggestion(at: selectedSuggestionIndex)
    }

    /// Menangani perubahan teks pada `NSTextField`.
    /// Metode ini dipanggil setiap kali teks pada `NSTextField` berubah.
    /// Ini akan memperbarui daftar saran berdasarkan teks yang sedang diketik oleh pengguna.
    /// - Parameter obj: Notification yang berisi objek `NSTextField` yang berubah.
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        activeTextField = textField

        generateSuggestions(for: typing) { [weak self] suggestions in
            guard let self else { return }
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

    /// Menampilkan jendela saran di atas `NSTextField` yang diberikan.
    /// - Parameter textField: `NSTextField` yang akan digunakan sebagai referensi untuk menampilkan jendela saran.
    func showSuggestions(for textField: NSTextField) {
        guard let window = textField.window,
              !(window.childWindows?.contains(suggestionWindow) ?? false)
        else {
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

    /// Mencari popover yang berisi `NSView` tertentu.
    /// Metode ini akan mencari melalui hierarki tampilan untuk menemukan popover yang berisi `NSView` yang diberikan.
    /// - Parameter view: `NSView` yang akan dicari popover-nya.
    /// - Returns: `NSPopover` jika ditemukan, atau `nil` jika tidak ada popover yang berisi `NSView` tersebut.
    private func findPopover(for view: NSView) -> NSPopover? {
        var currentView: NSView? = view
        while currentView != nil {
            let siswa = SiswaViewController()
            if (currentView?.enclosingMenuItem?.view) != nil {
                let popover = siswa.popover
                return popover
            }
            currentView = currentView?.superview
        }
        return nil
    }

    /// Menyembunyikan jendela saran dan menghapusnya dari parent window.
    func hideSuggestions() {
        isHidden = true
        selectedSuggestionIndex = -1
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
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

    /// Menghasilkan saran berdasarkan input yang diberikan.
    /// Metode ini akan melakukan filtering dan sorting pada daftar saran yang ada,
    /// kemudian mengembalikan saran yang sesuai dengan input pengguna melalui callback `completion`.
    /// - Parameters:
    ///   - input: String yang dimasukkan oleh pengguna untuk mencari saran.
    ///   - completion: Callback yang akan dipanggil dengan daftar saran yang dihasilkan.
    /// - Note: Pastikan untuk memanggil metode ini di thread yang sesuai, karena akan melakukan operasi filtering dan sorting yang mungkin memakan waktu.
    func generateSuggestions(for input: String, completion: @escaping ([String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
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

    /// Memindahkan indeks saran yang dipilih ke bawah.
    func moveUp() {
        guard !isHidden else { return }

        if selectedSuggestionIndex > 0 {
            selectedSuggestionIndex -= 1
        } else {
            selectedSuggestionIndex = currentSuggestions.count - 1
        }
        suggestionView.selectSuggestion(at: selectedSuggestionIndex)

        updateSelectedSuggestion()
    }

    /// Memindahkan indeks saran yang dipilih ke atas.
    func moveDown() {
        guard !isHidden else { return }

        if selectedSuggestionIndex < currentSuggestions.count - 1 {
            selectedSuggestionIndex += 1
        } else {
            selectedSuggestionIndex = 0
        }
        suggestionView.selectSuggestion(at: selectedSuggestionIndex)

        updateSelectedSuggestion()
    }

    /// Memasukkan saran yang dipilih ke dalam `NSTextField` yang aktif.
    func enterSuggestions() {
        guard selectedSuggestionIndex != -1 else { return }
        applySuggestion(currentSuggestions[selectedSuggestionIndex])

        isHidden = true
    }

    /// Menerapkan saran yang dipilih ke dalam `NSTextField` yang aktif.
    /// Metode ini akan mengambil teks yang sedang diketik, menambahkan saran yang dipilih, dan mengatur posisi kursor ke akhir teks.
    /// - Parameter suggestion: String yang akan diterapkan sebagai saran pada `NSTextField`.
    /// - Note: Pastikan `activeTextField` telah diatur sebelum memanggil metode ini, jika tidak, saran tidak akan diterapkan.
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
