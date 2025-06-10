//
//  SuggestionWindow.swift
//  TextField Completion
//
//  Created by Bismillah on 01/10/24.
//

import Cocoa

/// Class untuk menampilkan jendela saran yang berisi daftar saran yang dapat dipilih oleh pengguna.
class SuggestionWindow: NSPanel {
    /// Properti untuk tampilan saran yang berisi daftar saran yang dapat dipilih.
    private var suggestionView: SuggestionView
    /// Closure yang dipanggil ketika pengguna memilih saran dari daftar.
    /// Parameter `Int` adalah indeks saran yang dipilih, dan `String` adalah teks saran yang dipilih.
    var onSuggestionSelected: ((Int, String) -> Void)?

    /// Inisialisasi jendela saran dengan ukuran dan tipe penyimpanan yang ditentukan.
    /// Jendela ini memiliki gaya borderless dan non-activating panel, sehingga tidak mengganggu interaksi dengan jendela utama.
    /// Jendela ini juga memiliki latar belakang transparan dan dapat menampilkan bayangan.
    /// - Parameters:
    ///   - contentRect: NSRect yang menentukan ukuran dan posisi jendela.
    ///   - backing: NSWindow.BackingStoreType yang menentukan tipe penyimpanan jendela.
    ///   - flag: Bool yang menentukan apakah jendela harus ditunda saat inisialisasi.
    /// - Returns: Instance dari `SuggestionWindow` yang telah diinisialisasi.
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        suggestionView = SuggestionView(frame: contentRect)
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: backing, defer: flag)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        contentView = NSView(frame: contentRect)
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = .clear
        contentView?.addSubview(suggestionView)

        suggestionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            suggestionView.topAnchor.constraint(equalTo: contentView!.topAnchor),
            suggestionView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            suggestionView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            suggestionView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),
        ])

        suggestionView.onSuggestionSelected = { [weak self] int, suggestion in
            self?.onSuggestionSelected?(int, suggestion)
        }
    }

    /// Fungsi untuk memperbarui daftar saran yang ditampilkan di jendela saran.
    /// - Parameter suggestions: Array<String> yang berisi daftar saran yang akan ditampilkan.
    func updateSuggestions(_ suggestions: [String]) {
        suggestionView.updateSuggestions(suggestions)
        setContentSize(suggestionView.frame.size)
    }

    /// Fungsi untuk menampilkan jendela saran pada posisi yang ditentukan.
    /// - Parameter index: Int yang menentukan indeks saran yang akan dipilih.
    /// Fungsi ini akan menampilkan jendela saran pada posisi yang sesuai dengan indeks saran yang dipilih.
    func selectSuggestion(at index: Int) {
        suggestionView.selectSuggestion(at: index)
    }
}
