//
//  SuggestionView.swift
//  TextField Completion
//
//  Created by Bismillah on 02/10/24.
//

import Cocoa

/// Class untuk menampilkan daftar saran yang dapat dipilih oleh pengguna.
class SuggestionView: NSView {
    /// Outlet untuk NSView yang berisi tampilan utama dari SuggestionView.
    @IBOutlet var view: NSView!
    /// Outlet untuk NSView yang berfungsi sebagai kontainer untuk item saran.
    @IBOutlet weak var containerView: NSView!
    /// Properti untuk menyimpan daftar saran yang akan ditampilkan.
    var selectedIndex: Int = -1
    /// Closure yang dipanggil ketika pengguna memilih saran dari daftar.
    var onSuggestionSelected: ((Int, String) -> Void)?
    /// Array untuk menyimpan item saran yang ditampilkan.
    private var suggestionItemViews: [SuggestionItemView] = []
    /// Properti untuk mengatur radius sudut dari tampilan.
    /// Digunakan untuk memberikan efek visual pada tampilan dengan sudut yang melengkung.
    /// Nilai default adalah 7.0, yang dapat diubah sesuai kebutuhan.
    var cornerRadius: CGFloat = 7.0 {
        didSet {
            layer?.cornerRadius = cornerRadius
            layer?.masksToBounds = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupFromNib()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupFromNib()
    }

    /// Fungsi untuk menginisialisasi tampilan dari NIB file.
    /// Fungsi ini memuat tampilan dari file NIB dan mengatur properti tampilan seperti corner radius.
    /// Juga mengatur layer untuk memberikan efek visual pada tampilan.
    /// Digunakan untuk memastikan bahwa tampilan diinisialisasi dengan benar sebelum digunakan.
    /// Fungsi ini dipanggil pada saat inisialisasi dari kode atau dari storyboard.
    private func setupFromNib() {
        Bundle.main.loadNibNamed("SuggestionView", owner: self, topLevelObjects: nil)
        addSubview(view)
        view.frame = bounds
        view.autoresizingMask = [.width, .height]

        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true

        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = cornerRadius
        containerView.layer?.masksToBounds = true

        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true

        view.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
    }

    /// Fungsi untuk memperbarui daftar saran yang ditampilkan pada tampilan.
    /// Fungsi ini akan menghapus semua subview dan item saran sebelumnya, kemudian menambahkan item saran baru berdasarkan daftar yang diberikan.
    /// Setiap item saran akan dibuat sebagai instance dari `SuggestionItemView`, yang merupakan tampilan khusus untuk menampilkan saran
    /// Fungsi ini juga mengatur gesture recognizer untuk menangani klik pada item saran, dan memperbarui tinggi dari `containerView` dan tampilan utama sesuai dengan jumlah saran yang diberikan.
    /// Digunakan untuk memperbarui tampilan saran ketika daftar saran berubah, misalnya ketika pengguna mengetik di text field.
    /// - Parameter suggestions: Daftar saran yang akan ditampilkan pada tampilan.
    func updateSuggestions(_ suggestions: [String]) {
        // Hapus semua subview dan suggestionTextFields sebelumnya
        suggestionItemViews.forEach { $0.removeFromSuperview() }
        suggestionItemViews.removeAll()

        // Tambahkan view baru untuk setiap saran
        for (index, suggestion) in suggestions.enumerated() {
            // Buat instance CenteredTextFieldView
            let centeredView = SuggestionItemView(frame: NSRect(x: 0, y: CGFloat((suggestions.count - 1 - index) * 18), width: containerView.frame.width, height: 18), text: suggestion, index: index)
            centeredView.translatesAutoresizingMaskIntoConstraints = false
            let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(suggestionClicked(_:)))
            centeredView.textField.addGestureRecognizer(clickGesture)
            centeredView.textField.tag = index

            // Tambahkan CenteredTextFieldView ke containerView
            containerView.addSubview(centeredView)
            suggestionItemViews.append(centeredView)
            // Buat dan tambahkan LineView
            let lineView = LineView()
            lineView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(lineView)

            // Set constraints untuk CenteredTextFieldView
            NSLayoutConstraint.activate([
                centeredView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                centeredView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                centeredView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: CGFloat(index * 21)), // 20 untuk tinggi + 1 untuk jarak
                centeredView.heightAnchor.constraint(equalToConstant: 20),

                // Set constraints untuk LineView
                lineView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                lineView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                lineView.bottomAnchor.constraint(equalTo: centeredView.topAnchor), // Garis di atas textField
                lineView.heightAnchor.constraint(equalToConstant: 1), // Tinggi garis
            ])
        }

        // Update tinggi containerView dan view utama sesuai dengan jumlah suggestions
        let height = CGFloat(suggestions.count * 21) // Tinggi 20 untuk textField + 1 untuk jarak
        containerView.frame.size.height = height
        frame.size.height = height
        view.frame = bounds
        updateHighlight()
    }

    /// Fungsi yang menangani klik pada item saran.
    /// Fungsi ini akan memperbarui indeks yang dipilih, memanggil closure `onSuggestionSelected` dengan indeks dan teks yang dipilih,
    /// - Parameter gesture: Gesture recognizer yang menangani klik pada item saran.
    @objc private func suggestionClicked(_ gesture: NSClickGestureRecognizer) {
        guard let textField = gesture.view as? NSTextField else { return }
        selectedIndex = textField.tag
        updateHighlight()
        onSuggestionSelected?(textField.tag, textField.stringValue)
        selectSuggestion(at: textField.tag)
    }

    /// Fungsi untuk memilih saran berdasarkan indeks yang diberikan.
    /// - Parameter index: Indeks dari saran yang akan dipilih.
    func selectSuggestion(at index: Int) {
        selectedIndex = index
        updateHighlight()
    }

    /// Fungsi untuk memperbarui highlight pada item saran yang dipilih.
    /// Fungsi ini akan mengiterasi semua item saran dan mengatur status highlight berdasarkan indeks yang dipilih.
    /// Digunakan untuk memberikan efek visual pada item saran yang sedang dipilih oleh pengguna.
    /// Fungsi ini dipanggil setiap kali pengguna memilih item saran atau ketika indeks yang dipilih berubah.
    /// Jika indeks yang dipilih sama dengan indeks item saran, maka item tersebut akan di-highlight.
    /// Jika tidak, maka item tersebut tidak akan di-highlight.å
    func updateHighlight() {
        for itemView in suggestionItemViews {
            itemView.isHighlighted = (itemView.index == selectedIndex)
        }
    }
}
