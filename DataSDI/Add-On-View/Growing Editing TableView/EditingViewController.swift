//
//  EditingViewController.swift
//  tableViewCellOverlay
//
//  Created by Ays on 15/05/25.
//

import Cocoa

class EditingViewController: NSViewController, NSTextViewDelegate {
    // --- Outlets ---
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet var textView: PanelAutocompleteTextView! /// NSTextView sering dideklarasikan sebagai 'var' karena textStorage-nya bisa berubah

    /// --- Properti yang Diterima dari Manager ---
    var initialText: String = ""
    var originalColumnWidth: CGFloat! /// Lebar maksimum untuk view controller ini
    
    /// --- Properti Internal untuk Konfigurasi & Callback ---
    var commitAndCloseAction: (() -> Void)?
    var cancelAndCloseAction: (() -> Void)?
    var textDidChangeSizeAction: (() -> Void)? /// Callback baru untuk memberitahu manager ukuran berubah
    
    /// Ini akan menggantikan updateTextFieldHeight dan updatePreferredContentSize sebelumnya
    //var textFieldPadding: CGFloat = 0 /// Padding di sekeliling scrollView dalam view utama VC ini
    private var preferredMaxTextLines: Int = 3 /// Jumlah baris teks sebelum scroll
    //private let horizontalPadding: CGFloat = 0  /// misalnya 6pt kiri + 6pt kanan
    private var minTextViewContentHeightOneLine: CGFloat = 17 /// Akan dihitung ulang berdasarkan font
    private var maxViewHeightOverall: CGFloat = 150 /// Batas absolut tinggi VC view
    private var maxViewHeight: CGFloat = 53
    //private var minViewWidth: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        // --- Konfigurasi View Utama (untuk Bug 2: Rounded Window/ContentView) ---
        self.view.wantsLayer = true
        //self.view.layer?.masksToBounds = true
        //self.view.layer?.cornerRadius = 4
        //self.view.layer?.borderWidth = 2
        //self.view.layer?.borderColor = NSColor.controlAccentColor.cgColor
        
        // Cek warna ini: Apakah "EditorBackgroundColor" ada di Assets?
        // Apakah NSColor.textBackgroundColor.cgColor transparan atau sama dengan background window?
        let editorBGColor = NSColor(named: "EditorBackgroundColor")?.cgColor ?? NSColor.clear.cgColor
        self.view.layer?.backgroundColor = editorBGColor

        configureTextView()
        configureScrollView()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        textView.scrollToBeginningOfDocument(nil)
        view.window?.makeFirstResponder(textView)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: self.view.window
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
    
    private func configureTextView() {
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
        
        // Jika menggunakan Auto Layout untuk NSTextView di dalam NSScrollView (direkomendasikan di XIB):
        //textView.translatesAutoresizingMaskIntoConstraints = false
        // NSLayoutConstraint.activate([
        //     textView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
        //     textView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
        //     textView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor)
        //     // Bottom constraint tidak diperlukan, biarkan tingginya tumbuh
        // ])
        // Jika tidak, pastikan autoresizingMask di XIB sudah benar: textView.autoresizingMask = [.width]
    }

    private func configureScrollView() {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false // Biasanya false untuk editor teks yang wrap
        scrollView.borderType = .noBorder // Atau .bezelBorder sesuai selera
        scrollView.focusRingType = .exterior
        // scrollView.backgroundColor = .clear // Biarkan background view controller yang terlihat
    }
    
    
    //MARK: - NSTextView Lebar-Tinggi Dinamis
    
    /// Helper untuk mendapatkan tinggi satu baris aktual dari layoutManager
    private func getAccurateSingleLineHeight() -> CGFloat {
        guard let layoutManager = textView.layoutManager, let font = textView.font else {
            return 17.0 // Fallback kasar
        }
        // defaultLineHeight(for:) adalah metode yang baik dan sudah ada di NSLayoutManager
        return ceil(layoutManager.defaultLineHeight(for: font))
    }
    
    func configureHeightParameters(maxOverallHeight: CGFloat, preferredVisibleLines: Int = 3) {
        let oneLineHeight = getAccurateSingleLineHeight()
        minTextViewContentHeightOneLine = oneLineHeight // Minimal adalah 1 baris
        
        let heightForPreferredLines = (CGFloat(preferredVisibleLines) * oneLineHeight)
        
        self.maxViewHeight = min(heightForPreferredLines, maxOverallHeight)
        // Pastikan maxViewHeight tidak lebih kecil dari tinggi minimal 1 baris + padding
        self.maxViewHeight = max(self.maxViewHeight, minTextViewContentHeightOneLine)
    }

    /// Dipanggil oleh manager saat inisialisasi dan oleh textDidChange
    func calculateAndUpdatePreferredViewSize() {
        guard let font = textView.font,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              originalColumnWidth > 0
        else {
            let fallbackHeight = min(minTextViewContentHeightOneLine, maxViewHeightOverall)
            self.preferredContentSize = NSSize(width: originalColumnWidth > 0 ? originalColumnWidth : 100, height: fallbackHeight)
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
        let internalTextHeight: CGFloat
        if actualRenderedTextHeight <= maxContentHeightForNLines {
            internalTextHeight = max(actualRenderedTextHeight, minTextViewContentHeightOneLine)
        } else {
            internalTextHeight = maxContentHeightForNLines
        }
        
        // --- 5. Tentukan Tinggi Akhir untuk View Controller (finalViewHeight) ---
        // Tinggi internal teks + padding di sekeliling scrollview, semua dibatasi oleh maxViewHeightOverall.
        let finalViewHeight = min(internalTextHeight, self.maxViewHeightOverall)
        
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
        var finalViewWidth = min(max(desiredViewWidthWithPadding, 0), self.originalColumnWidth)
        if finalViewWidth < 6 && !textView.string.isEmpty {
           finalViewWidth = 10
        }
        // --- 9. Atur Preferred Content Size ---
        let newPreferredSize = NSSize(width: finalViewWidth, height: finalViewHeight)
        if self.preferredContentSize != newPreferredSize {
            self.preferredContentSize = newPreferredSize
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
        }
        return false // Perintah tidak ditangani, biarkan default behavior
    }
    
    /// Metode untuk mendapatkan teks saat ini dari NSTextView
    ///func getCurrentText() -> String {
        ///return textView.string
    ///}
}
