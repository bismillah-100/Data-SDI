//
//  EditingViewController.swift
//  tableViewCellOverlay
//
//  Created by Ays on 15/05/25.
//

import Cocoa

/// `EditingViewController` adalah kelas yang mengelola tampilan editor teks yang dapat tumbuh secara dinamis.
/// Class ini merupakan subclass dari `NSViewController` dan mengimplementasikan `NSTextViewDelegate` untuk menangani perubahan teks.
class EditingViewController: NSViewController, NSTextViewDelegate {
    // --- Outlets ---
    /// Outlet untuk NSScrollView yang membungkus NSTextView.
    @IBOutlet weak var scrollView: NSScrollView!
    /// Outlet untuk NSTextView yang digunakan untuk mengedit teks.
    @IBOutlet var textView: PanelAutocompleteTextView! /// NSTextView sering dideklarasikan sebagai 'var' karena textStorage-nya bisa berubah

    // --- Properti yang Diterima dari Manager ---
    /// Teks awal yang akan ditampilkan di editor. Ini bisa kosong jika tidak ada teks awal.
    var initialText: String = ""
    /// Lebar maksimum untuk ``EditingViewController``. Ini diatur oleh manager yang mengelola tampilan ini.
    var originalColumnWidth: CGFloat!

    // --- Properti Internal untuk Konfigurasi & Callback ---
    /// Sebuah closure opsional yang akan dipanggil ketika proses commit dan penutupan selesai.
    /// Gunakan properti ini untuk menentukan aksi yang dilakukan setelah perubahan disimpan dan tampilan ditutup.
    var commitAndCloseAction: (() -> Void)?
    /// Aksi yang dipanggil ketika pengguna membatalkan dan menutup tampilan.
    /// Digunakan untuk menangani logika pembatalan dan penutupan secara eksternal.
    var cancelAndCloseAction: (() -> Void)?
    /// Callback untuk memberitahu manager ukuran berubah.
    var textDidChangeSizeAction: (() -> Void)?
    /// Callback untuk mengedit kolom selanjutnya jika kolom masih berada
    /// di rentang yang valid di tableView.
    var commitAndEditNextColumn: (() -> Void)?

    /// Jumlah baris teks yang diinginkan untuk ditampilkan secara maksimal.
    private var preferredMaxTextLines: Int = 3

    // --- Parameter untuk Perhitungan Ukuran Dinamis ---
    /// Tinggi minimum untuk konten teks dalam satu baris. Ini akan dihitung ulang berdasarkan font yang digunakan.
    private var minTextViewContentHeightOneLine: CGFloat = 17 // Akan dihitung ulang berdasarkan font
    /// Batas absolut tinggi untuk tampilan view controller. Ini adalah batas maksimum yang akan digunakan untuk mengatur ukuran preferensi.
    private var maxViewHeightOverall: CGFloat = 150 // Batas absolut tinggi VC view
    /// Maksimal batas tinggi ``EditingViewController``.
    private var maxViewHeight: CGFloat = 53

    override func viewDidLoad() {
        super.viewDidLoad()

        // --- Konfigurasi View Utama (untuk Bug 2: Rounded Window/ContentView) ---
        view.wantsLayer = true
        // self.view.layer?.masksToBounds = true
        // self.view.layer?.cornerRadius = 4
        // self.view.layer?.borderWidth = 2
        // self.view.layer?.borderColor = NSColor.controlAccentColor.cgColor

        // Cek warna ini: Apakah "EditorBackgroundColor" ada di Assets?
        // Apakah NSColor.textBackgroundColor.cgColor transparan atau sama dengan background window?
        let editorBGColor = NSColor(named: "EditorBackgroundColor")?.cgColor ?? NSColor.clear.cgColor
        view.layer?.backgroundColor = editorBGColor

        configureTextView()
        configureScrollView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        calculateAndUpdatePreferredViewSize()
        view.window?.makeFirstResponder(textView)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: view.window
        )
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        // Dismiss editor saat window kehilangan fokus
        commitAndCloseAction?()
        if let panelParent = textView.parentWindow {
            panelParent.removeChildWindow(textView.panel)
        }
        textView.panel.orderOut(notification)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        // Ini penting agar OverlayEditorManager bisa mendapatkan ukuran awal yang benar
        textView.selectAll(nil)
    }

    /// Mengkonfigurasi tampilan teks (NSTextView) pada tampilan pengeditan.
    /// Fungsi ini digunakan untuk mengatur properti dan perilaku dari NSTextView
    /// sesuai kebutuhan aplikasi, seperti font, warna, delegasi, dan lain-lain.
    func configureTextView() {
        textView.string = initialText
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize) // Sesuaikan
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor // Atau .clear jika ingin background scrollView/viewController tembus

        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.delegate = self // Untuk textDidChange

        // Perilaku standar untuk NSTextView dalam NSScrollView
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.minSize = NSSize(width: 0, height: minTextViewContentHeightOneLine) // Minimal setinggi kontennya
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false // Agar teks wrap
        textView.textContainer?.widthTracksTextView = true // Lebar container teks mengikuti lebar textview
    }

    /// Mengkonfigurasi NSScrollView yang membungkus NSTextView.
    func configureScrollView() {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false // Biasanya false untuk editor teks yang wrap
        scrollView.borderType = .noBorder // Atau .bezelBorder sesuai selera
        scrollView.focusRingType = .exterior
    }

    // MARK: - NSTextView Lebar-Tinggi Dinamis

    /// Fungsi untuk mendapatkan tinggi satu baris aktual dari layoutManager
    func getAccurateSingleLineHeight() -> CGFloat {
        guard let layoutManager = textView.layoutManager, let font = textView.font else {
            return 16.0 // Fallback kasar
        }
        // defaultLineHeight(for:) adalah metode yang baik dan sudah ada di NSLayoutManager
        return ceil(layoutManager.defaultLineHeight(for: font))
    }

    /// Mengonfigurasi parameter tinggi untuk tampilan editor.
    /// Fungsi ini mengatur tinggi maksimum tampilan berdasarkan jumlah baris yang diinginkan dan tinggi satu baris aktual.
    /// Ini juga memastikan bahwa tinggi maksimum tidak kurang dari tinggi minimum untuk satu baris teks.
    /// Fungsi ini harus dipanggil sebelum menghitung ukuran preferensi tampilan.
    /// - Parameters:
    ///   - maxOverallHeight: Tinggi maksimum keseluruhan yang diizinkan untuk tampilan editor.
    ///   - preferredVisibleLines: Jumlah baris yang diinginkan untuk ditampilkan secara maksimal. Default adalah 3.
    func configureHeightParameters(maxOverallHeight: CGFloat, preferredVisibleLines: Int = 3) {
        let oneLineHeight = getAccurateSingleLineHeight()
        minTextViewContentHeightOneLine = oneLineHeight // Minimal adalah 1 baris

        let heightForPreferredLines = (CGFloat(preferredVisibleLines) * oneLineHeight)

        maxViewHeight = min(heightForPreferredLines, maxOverallHeight)
        // Pastikan maxViewHeight tidak lebih kecil dari tinggi minimal 1 baris + padding
        maxViewHeight = max(maxViewHeight, minTextViewContentHeightOneLine)
    }

    /// Dipanggil oleh manager saat inisialisasi dan oleh textDidChange.
    /// Menghitung dan memperbarui ukuran preferensi tampilan berdasarkan teks yang ada di NSTextView.
    /// Fungsi ini akan menghitung ukuran yang diperlukan untuk menampilkan teks dengan baik,
    /// termasuk lebar dan tinggi yang sesuai, serta mengatur ukuran preferensi tampilan.
    /// Fungsi ini juga akan memperbarui ukuran konten teks di dalam scrollView.
    /// Jika teks kosong atau tidak ada font/layoutManager, akan mengatur ukuran preferensi ke nilai default.
    /// Jika ada perubahan ukuran, akan memanggil `textDidChangeSizeAction` untuk memberi tahu manager.
    func calculateAndUpdatePreferredViewSize() {
        guard let font = textView.font,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              originalColumnWidth > 0
        else {
            let fallbackHeight = min(minTextViewContentHeightOneLine, maxViewHeightOverall)
            preferredContentSize = NSSize(width: originalColumnWidth > 0 ? originalColumnWidth : 100, height: fallbackHeight)
            textDidChangeSizeAction?()
            return
        }

        // --- 1. Tentukan Lebar Aktual untuk Konten Teks (actualTextContentWidth) ---
        // Lebar maksimum yang tersedia untuk area teks di dalam NSTextView
        let textContainerMaxWidth = originalColumnWidth - (scrollView.verticalScroller?.frame.width ?? 0) // Kurangi lebar scrollbar jika terlihat

        let textNSString = textView.string as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: font]

        // Lebar teks jika tidak di-wrap
        let unboundedTextWidth = ceil(textNSString.boundingRect(
            with: CGSize(width: .greatestFiniteMagnitude, height: getAccurateSingleLineHeight()),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        ).size.width)

        // Lebar konten teks aktual: minimum antara unbounded dan max, tapi tidak kurang dari min.
        let minTextContentWidth: CGFloat = 4 // Lebar minimal untuk area teks itu sendiri
        let actualTextContentWidth = min(max(unboundedTextWidth, minTextContentWidth), textContainerMaxWidth)

        // --- 2. Hitung Tinggi Teks Penuh (actualRenderedTextHeight) ---
        // PENTING: Atur lebar textContainer SEBELUM mengukur tinggi.
        if abs(textContainer.containerSize.width - actualTextContentWidth) > 0.1 {
            textContainer.containerSize = NSSize(width: actualTextContentWidth, height: .greatestFiniteMagnitude)
        }
        layoutManager.ensureLayout(for: textContainer)
        let actualRenderedTextHeight = ceil(layoutManager.usedRect(for: textContainer).height)

        // --- 3. Tentukan Tinggi Konten Maksimum untuk N Baris (maxContentHeightForNLines) ---
        let accurateSingleLineHeight = getAccurateSingleLineHeight()
        if minTextViewContentHeightOneLine != accurateSingleLineHeight { // Update jika font berubah/baru terdeteksi
            minTextViewContentHeightOneLine = accurateSingleLineHeight
        }
        let maxContentHeightForNLines = accurateSingleLineHeight * CGFloat(preferredMaxTextLines)

        // --- 4. Tentukan Tinggi Internal Teks (internalTextHeight) ---
        // Ini adalah tinggi yang akan ditempati konten teks di dalam scrollview, mungkin dibatasi N baris.
        let internalTextHeight: CGFloat = if actualRenderedTextHeight <= maxContentHeightForNLines {
            max(actualRenderedTextHeight, minTextViewContentHeightOneLine)
        } else {
            maxContentHeightForNLines
        }

        // --- 5. Tentukan Tinggi Akhir untuk View Controller (finalViewHeight) ---
        // Tinggi internal teks + padding di sekeliling scrollview, semua dibatasi oleh maxViewHeightOverall.
        let finalViewHeight = min(internalTextHeight, maxViewHeightOverall)

        // --- 6. Atur Frame NSTextView (documentView dari NSScrollView) ---
        // Lebarnya adalah actualTextContentWidth. Tingginya adalah actualRenderedTextHeight (tinggi penuh teks).
        let newTextViewFrame = NSRect(x: 0, y: 0, width: actualTextContentWidth, height: actualRenderedTextHeight)
        if !NSEqualRects(textView.frame, newTextViewFrame) {
            textView.frame = newTextViewFrame
        }

        // --- 7. Konfigurasi Scroller Vertikal ---
        // Tinggi yang terlihat untuk teks di dalam scrollview
        let epsilon: CGFloat = 0.5 // Toleransi kecil untuk perbandingan float
        let needsScroller = actualRenderedTextHeight > (finalViewHeight + epsilon)

        if scrollView.hasVerticalScroller != needsScroller {
            scrollView.hasVerticalScroller = needsScroller
            // Perlu update layout jika scroller muncul/hilang karena bisa mengubah textContainerMaxWidth
            // Ini bisa menyebabkan rekursi jika tidak hati-hati. Cukup panggil sekali lagi di akhir.
        }

        let lineCount = Int(ceil(actualRenderedTextHeight / accurateSingleLineHeight))
        let extraRightPadding: CGFloat = (lineCount > 1) ? 30 : 0

        // --- 8. Tentukan Lebar Akhir untuk View Controller (finalViewWidth) ---
        let desiredViewWidthWithPadding = actualTextContentWidth - extraRightPadding + (needsScroller ? (scrollView.verticalScroller?.frame.width ?? 0) : 0)
        var finalViewWidth = min(max(desiredViewWidthWithPadding, 0), originalColumnWidth)
        if finalViewWidth < 6, !textView.string.isEmpty {
            finalViewWidth = 10
        }
        // --- 9. Atur Preferred Content Size ---
        let newPreferredSize = NSSize(width: finalViewWidth, height: finalViewHeight)
        if preferredContentSize != newPreferredSize {
            preferredContentSize = newPreferredSize
        }

        // Panggil action setelah semua kalkulasi selesai
        // textDidChangeSizeAction akan memicu OverlayEditorManager untuk menyesuaikan frame overlay
        textDidChangeSizeAction?()

        // Jika scroller baru muncul/hilang, lebar textContainerMaxWidth berubah, perlu hitung ulang sekali.
        // Ini untuk mengatasi kasus di mana penambahan/penghilangan scroller mengubah wrapping.
        // Tambahkan flag untuk mencegah rekursi tak terbatas.
        // Untuk kesederhanaan, kita bisa mengabaikan perhitungan ulang ini jika tidak terlalu signifikan.
        // Jika lebar textContainerMaxWidth berubah signifikan karena scroller, panggil lagi:
        // if needsScroller != wasScrollerVisiblePreviously { self.calculateAndUpdatePreferredViewSize() } // Perlu state `wasScrollerVisiblePreviously`
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        // Dipanggil setiap kali teks di NSTextView berubah
        if notification.object as? NSTextView == textView {
            calculateAndUpdatePreferredViewSize() // Hitung ulang ukuran preferensi view controller
        }
    }

    /// Menangani Enter dan Escape. Untuk NSTextView, kita bisa override keyDown atau implementasi delegate.
    /// Metode delegate lebih bersih.
    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(insertNewline(_:)) { // User menekan Enter
            // Jika Anda ingin Enter membuat baris baru di NSTextView:
            // textView.insertNewlineIgnoringFieldEditor(nil)
            // return true
            // Jika Anda ingin Enter meng-commit dan menutup (perilaku saat ini):
            commitAndCloseAction?()
            return true
        } else if selector == #selector(cancelOperation(_:)) { // User menekan Escape
            cancelAndCloseAction?()
            return true
        } else if selector == #selector(insertTab(_:)) {
            commitAndEditNextColumn?()
        }
        return false // Perintah tidak ditangani, biarkan default behavior
    }
}
