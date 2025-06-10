//
//  OverlayEditorManager.swift
//  tableViewCellOverlay
//
//  Created by Ays on 15/05/25.
//

import Cocoa

/// `OverlayEditorManager` mengelola overlay editor yang muncul saat pengguna mengedit sel di `NSTableView`.
/// Overlay ini memungkinkan pengguna untuk mengedit teks sel dengan lebih nyaman, termasuk dukungan untuk saran teks.
class OverlayEditorManager: NSObject {
    /// TableView yang akan dikelola oleh OverlayEditorManager.
    private weak var tableView: NSTableView?
    /// Window utama yang berisi tableView
    private weak var window: NSWindow?

    /// DataSource yang menyediakan data untuk OverlayEditorManager.
    weak var dataSource: OverlayEditorManagerDataSource?
    /// Delegate yang menangani peristiwa terkait overlay editor.
    weak var delegate: OverlayEditorManagerDelegate?

    /// `NSViewController` yang akan digunakan untuk mengelola tampilan editor.
    private var activeEditingViewController: EditingViewController?
    /// View yang aktif saat ini, yang merupakan overlay editor.
    /// Ini akan menjadi `nil` jika tidak ada editor yang aktif.
    /// Ini adalah view yang ditambahkan ke superview dari tableView saat mengedit.
    /// View ini akan dihapus saat editor ditutup.
    private var activeOverlayView: NSView?
    /// Monitor untuk mendeteksi klik di luar overlay editor.
    private var clickOutsideMonitor: Any?

    /// Baris yang sedang diedit saat ini.
    private var currentlyEditingRow: Int?
    /// Kolom yang sedang diedit saat ini.
    private var currentlyEditingColumn: Int?
    /// Arah pertumbuhan editor, apakah ke atas atau ke bawah.
    private var editorGrowthDirection: GrowthDirection = .downwards
    /// Teks asli sel sebelum diedit, digunakan untuk mengembalikan teks saat pembatalan.
    /// Ini akan diisi saat mulai mengedit.
    private var originalCellTextBeforeEditing: String? // Untuk restore saat cancel jika cell dikosongkan

    /// Kordinat y untuk untuk menetapkan tinggi yang benar ketika ``editorGrowthDirection`` berubah.
    private var overlayAnchorYRelativeToCell: CGFloat = 0.0 // Ini adalah y-koordinat (di targetSuperview) dari tepi atas atau bawah sel asli

    init(tableView: NSTableView, containingWindow: NSWindow) {
        self.tableView = tableView
        window = containingWindow
        super.init()
        setupTableScrollObserver()
    }

    /// Mengatur observer untuk mendeteksi perubahan scroll pada tabel.
    /// Fungsi ini digunakan untuk memantau pergerakan scroll pada tabel dan menjalankan aksi tertentu ketika terjadi perubahan posisi scroll.
    private func setupTableScrollObserver() {
        guard let scrollView = tableView?.enclosingScrollView else { return }

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleTableViewScroll(_:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
    }

    /// Menangani notifikasi scroll pada TableView.
    /// - Parameter notification: Notifikasi yang diterima ketika TableView discroll.
    @objc func handleTableViewScroll(_ notification: Notification) {
        if activeOverlayView != nil {
            // Saat scroll, anggap cancel dan kembalikan teks asli jika sel dikosongkan
            dismissEditor(commit: true, newTextFromEditor: activeEditingViewController?.textView.string)
        }
    }

    /// Memulai proses pengeditan pada baris dan kolom tertentu di tabel.
    /// - Parameter row: Indeks baris yang akan diedit.
    /// - Parameter column: Indeks kolom yang akan diedit.
    func startEditing(row: Int, column: Int) {
        guard delegate?.overlayEditorManager(self, perbolehkanEdit: column, row: row) == true else {
            print("kolom tidak diperbolehkan diedit.")
            return
        }

        guard let tableView, let window, let targetSuperview = window.contentView else {
            print("OverlayEditorManager tidak dikonfigurasi dengan benar atau window tidak tersedia.")
            return
        }

        if activeOverlayView != nil {
            if currentlyEditingRow == row, currentlyEditingColumn == column {
                activeOverlayView?.window?.makeFirstResponder(activeEditingViewController?.textView)
                return
            } else {
                // Tutup editor lama, jangan commit, kembalikan teks asli selnya jika perlu
                dismissEditor(commit: false, textToRestoreToCell: originalCellTextBeforeEditing)
            }
        }

        currentlyEditingRow = row
        currentlyEditingColumn = column

        guard let currentText = dataSource?.overlayEditorManager(self, textForCellAtRow: row, column: column, in: tableView),
              let originalColumnWidth = dataSource?.overlayEditorManager(self, originalColumnWidthForCellAtRow: row, column: column, in: tableView)
        else {
            print("DataSource tidak menyediakan data yang diperlukan.")
            clearEditingState()
            return
        }

        guard let cellView = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView else {
            print("Tidak bisa mendapatkan cell view pada baris \(row), kolom \(column).")
            clearEditingState()
            return
        }

        // Minta saran:
        var suggestions = [String]()
        if !UserDefaults.standard.bool(forKey: "showSuggestionsDiTabel") {
            suggestions = []
        } else {
            suggestions = dataSource?.overlayEditorManager?(self, suggestionsForCellAtColumn: column, in: tableView) ?? []
        }

        // delegate?.overlayEditorManager(self, willShowEditorForCellAtRow: row, column: column, cellView: cellView, in: tableView)

        // --- Konversi Koordinat ---
        // let cellBounds = cellView.bounds
        // let cellFrameInWindowCoordinates = cellView.convert(cellBounds, to: nil)

        guard let textField = cellView.textField else {
            print("Tidak ada textField dalam cellView.")
            clearEditingState()
            return
        }
        let textFieldBounds = textField.bounds
        let textFieldFrameInWindowCoordinates = textField.convert(textFieldBounds, to: nil)

        guard let sourceWindowForCell = cellView.window else {
            print("CellView tidak memiliki window.")
            clearEditingState()
            return
        }
        // Asumsi targetSuperview adalah contentView dari window yang sama dengan sourceWindowForCell
        let cellFrameInTargetSuperview = targetSuperview.convert(textFieldFrameInWindowCoordinates, from: sourceWindowForCell.contentView)

        // --- Expanded Width & Origin X ---
        let leftPaddingForOverlay: CGFloat = 2
        let rightPaddingForOverlay: CGFloat = 6

        let editorViewExpandedWidth = originalColumnWidth + rightPaddingForOverlay
        let overlayOriginX = cellFrameInTargetSuperview.origin.x + leftPaddingForOverlay

        // --- Buat EditingViewController ---
        let editorVC = EditingViewController(nibName: "EditingViewController", bundle: nil)
        editorVC.initialText = currentText
        editorVC.originalColumnWidth = editorViewExpandedWidth - leftPaddingForOverlay

        _ = editorVC.view // Muat view
        if let mainContentViewHeight = window.contentView?.bounds.height {
            editorVC.configureHeightParameters(maxOverallHeight: mainContentViewHeight * 0.8, preferredVisibleLines: 3) // Misal maks 80% tinggi window
        } else {
            editorVC.configureHeightParameters(maxOverallHeight: 200, preferredVisibleLines: 3) // Fallback
        }
        editorVC.calculateAndUpdatePreferredViewSize()
        let initialEditorContentSize = editorVC.preferredContentSize

        // --- Hitung Frame Awal & Arah Pertumbuhan ---
        editorGrowthDirection = .downwards
        var finalOverlayOriginY = cellFrameInTargetSuperview.origin.y + cellFrameInTargetSuperview.size.height - initialEditorContentSize.height
        let finalOverlayHeight = initialEditorContentSize.height
        let finalOverlayWidth = initialEditorContentSize.width // Seharusnya sama dengan editorViewExpandedWidth atau dari preferredSize VC

        if finalOverlayOriginY < 0 {
            finalOverlayOriginY = cellFrameInTargetSuperview.origin.y
            editorGrowthDirection = .upwards
            overlayAnchorYRelativeToCell = cellFrameInTargetSuperview.minY

            if (finalOverlayOriginY + finalOverlayHeight) > targetSuperview.bounds.height {
                finalOverlayOriginY = targetSuperview.bounds.height - finalOverlayHeight
            }
        } else {
            overlayAnchorYRelativeToCell = cellFrameInTargetSuperview.maxY
            if (finalOverlayOriginY + finalOverlayHeight) > targetSuperview.bounds.height {
                finalOverlayOriginY = targetSuperview.bounds.height - finalOverlayHeight
            }
        }
        finalOverlayOriginY = max(0, finalOverlayOriginY)
        let finalOverlayOriginXAdjusted = max(0, overlayOriginX)
        let editorViewFrame = NSRect(x: finalOverlayOriginXAdjusted, y: finalOverlayOriginY, width: finalOverlayWidth, height: finalOverlayHeight)
        editorVC.view.frame = editorViewFrame

        targetSuperview.addSubview(editorVC.view, positioned: .above, relativeTo: nil)

        // Simpan teks asli sel sebelum dikosongkan
        originalCellTextBeforeEditing = cellView.textField?.stringValue

        activeOverlayView = editorVC.view
        activeEditingViewController = editorVC

        // --- Setup Callbacks ---
        editorVC.commitAndCloseAction = { [weak self, weak editorVC] in
            guard let self, let vc = editorVC, let committedText = vc.textView?.textStorage?.string else { return }
            self.dismissEditor(commit: true, newTextFromEditor: committedText)
            if let splitVC = window.contentViewController as? SplitVC {
                AppDelegate.shared.updateUndoRedoMenu(for: splitVC)
            } else if let rincianSiswa = window.contentViewController as? DetailSiswaController {
                AppDelegate.shared.updateUndoRedoMenu(for: rincianSiswa)
            }
        }
        editorVC.cancelAndCloseAction = { [weak self] in
            self?.dismissEditor(commit: false, textToRestoreToCell: self?.originalCellTextBeforeEditing)
            if let splitVC = window.contentViewController as? SplitVC {
                AppDelegate.shared.updateUndoRedoMenu(for: splitVC)
            } else if let rincianSiswa = window.contentViewController as? DetailSiswaController {
                AppDelegate.shared.updateUndoRedoMenu(for: rincianSiswa)
            }
        }
        // Ganti nama callback jika Anda mengubahnya di EditingViewController
        editorVC.textDidChangeSizeAction = { [weak self] in
            self?.handleEditorViewResize() // Metode ini tetap sama, akan mengambil preferredContentSize
        }

        // --- First Responder & Row Emphasis ---
        DispatchQueue.main.async {
            textField.stringValue = "" // Kosongkan teks di sel (pilihan UI Anda)
            cellView.textField?.allowsExpansionToolTips = false
            if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) {
                rowView.isEmphasized = true // Jaga highlight tetap biru
            }
        }
        // Suggestions Panel
        editorVC.textView.columnName = tableView.tableColumns[column].identifier.rawValue
        editorVC.textView.allSuggestions = suggestions
        editorVC.textView.tableView = tableView

        // Setup behavior
        ReusableFunc.resetMenuItems()
        setupClickOutsideMonitor()
        tooltipsDisable(editorVC.view)
    }

    /// Menonaktifkan tooltip pada tampilan overlay yang diberikan.
    ///
    /// - Parameter overlay: NSView yang akan dinonaktifkan tooltips-nya.
    func tooltipsDisable(_ overlay: NSView) {
        guard let tableView, let row = currentlyEditingRow, row + 1 < tableView.numberOfRows, let column = currentlyEditingColumn, let cell = tableView.view(atColumn: column, row: row + 1, makeIfNecessary: false) as? NSTableCellView else { return }
        if overlay.frame.height > 16, overlay.frame.height <= 32 {
            if row + 1 < tableView.numberOfRows {
                cell.textField?.allowsExpansionToolTips = false
            }
        } else if overlay.frame.height > 32 {
            if row + 2 < tableView.numberOfRows, let cell = tableView.view(atColumn: column, row: row + 2, makeIfNecessary: false) as? NSTableCellView {
                cell.textField?.allowsExpansionToolTips = false
            }
        }
    }

    /// Menangani logika ketika tampilan editor diubah ukurannya.
    /// Fungsi ini akan dipanggil setiap kali ukuran editor view berubah,
    /// dan bertanggung jawab untuk memperbarui tata letak atau melakukan penyesuaian lain yang diperlukan.
    private func handleEditorViewResize() {
        guard let vc = activeEditingViewController, let overlay = activeOverlayView, let superview = overlay.superview else { return }

        let newPreferredSize = vc.preferredContentSize // Ukuran baru dari EditingViewController
        let currentFrame = overlay.frame // Frame overlay saat ini

        var newCalculatedY: CGFloat
        let newCalculatedHeight = newPreferredSize.height
        // Lebar bisa diambil dari preferred size, atau tetap seperti currentFrame jika tidak ingin lebar berubah saat resize tinggi
        let newCalculatedWidth = newPreferredSize.width // Atau currentFrame.width jika lebar tidak dinamis

        if editorGrowthDirection == .downwards {
            // Jangkar di ATAS (overlayAnchorYRelativeToCell adalah koordinat Y dari tepi atas).
            // y_baru = jangkar_atas - tinggi_baru
            newCalculatedY = overlayAnchorYRelativeToCell - newCalculatedHeight
        } else { // .upwards
            // Jangkar di BAWAH (overlayAnchorYRelativeToCell adalah koordinat Y dari tepi bawah).
            // y_baru = jangkar_bawah (tetap)
            newCalculatedY = overlayAnchorYRelativeToCell
        }

        var finalNewFrame = NSRect(
            x: currentFrame.origin.x, // Untuk sementara, asumsikan X tidak berubah. Atau hitung ulang X jika lebar dinamis.
            y: newCalculatedY,
            width: newCalculatedWidth,
            height: newCalculatedHeight
        )

        // --- Penyesuaian Batas Superview ---
        // Pastikan frame baru tetap dalam batas superview sebisa mungkin,
        // sambil mencoba mempertahankan anchor jika memungkinkan.

        // Batas bawah
        if finalNewFrame.minY < superview.bounds.minY {
            finalNewFrame.origin.y = superview.bounds.minY
            if editorGrowthDirection == .downwards {
                // Jika tumbuh ke bawah dan mentok bawah, tinggi maksimal adalah jarak dari anchor atasnya ke 0
                finalNewFrame.size.height = min(newCalculatedHeight, overlayAnchorYRelativeToCell - superview.bounds.minY)
            }
        }

        // Batas atas
        if finalNewFrame.maxY > superview.bounds.maxY {
            if editorGrowthDirection == .upwards {
                // Jika tumbuh ke atas dan mentok atas, tinggi maksimal adalah jarak dari anchor bawahnya ke atas superview
                finalNewFrame.size.height = min(newCalculatedHeight, superview.bounds.maxY - overlayAnchorYRelativeToCell)
                // Y (anchor bawah) tetap, tinggi yang disesuaikan
                finalNewFrame.origin.y = overlayAnchorYRelativeToCell
            } else { // Tumbuh ke bawah dan mentok atas
                finalNewFrame.origin.y = superview.bounds.maxY - newCalculatedHeight
            }
            // Jika setelah penyesuaian Y, minY jadi negatif (karena tinggi terlalu besar), set minY ke 0 dan sesuaikan tinggi
            if finalNewFrame.minY < superview.bounds.minY {
                finalNewFrame.size.height = min(newCalculatedHeight, superview.bounds.maxY - superview.bounds.minY) // Ketinggian maksimal adalah tinggi superview
                finalNewFrame.origin.y = superview.bounds.minY
            }
        }

        // Penyesuaian untuk X dan Width jika lebar juga dinamis dan perlu dibatasi (mirip dengan Y dan Height)
        // ...
        if finalNewFrame.minX < superview.bounds.minX {
            finalNewFrame.origin.x = superview.bounds.minX
            // Sesuaikan width jika perlu
        }
        if finalNewFrame.maxX > superview.bounds.maxX {
            finalNewFrame.origin.x = superview.bounds.maxX - finalNewFrame.width
            // Sesuaikan width jika perlu dan origin.x jadi negatif
            if finalNewFrame.minX < superview.bounds.minX {
                finalNewFrame.size.width = min(newCalculatedWidth, superview.bounds.maxX - superview.bounds.minX)
                finalNewFrame.origin.x = superview.bounds.minX
            }
        }

        if !NSEqualRects(currentFrame, finalNewFrame) {
            overlay.frame = finalNewFrame
        }
        tooltipsDisable(overlay)
    }

    /// Menutup editor overlay pada tampilan tabel.
    /// - Parameters:
    ///   - commit: Menentukan apakah perubahan yang dilakukan pada editor harus disimpan (commit) atau tidak.
    ///   - newTextFromEditor: (Opsional) Teks baru yang dihasilkan dari editor, jika ada perubahan yang ingin disimpan.
    ///   - textToRestoreToCell: (Opsional) Teks yang akan dikembalikan ke sel tabel jika perubahan tidak disimpan.
    ///
    /// Fungsi ini digunakan untuk menutup editor yang sedang aktif pada tampilan tabel.
    /// Jika `commit` bernilai true, maka perubahan yang dilakukan pada editor akan disimpan.
    /// Jika `commit` bernilai false, maka editor akan ditutup tanpa menyimpan perubahan, dan teks pada sel dapat dikembalikan ke nilai sebelumnya jika `textToRestoreToCell` disediakan.
    func dismissEditor(commit: Bool, newTextFromEditor: String? = nil, textToRestoreToCell: String? = nil) {
        guard let row = currentlyEditingRow, let col = currentlyEditingColumn, let tableView, let cell = self.tableView?.view(atColumn: currentlyEditingColumn ?? 0, row: currentlyEditingRow ?? 0, makeIfNecessary: false) as? NSTableCellView else {
            activeOverlayView?.removeFromSuperview() // Pastikan view bersih jika state tidak konsisten
            activeEditingViewController?.textView?.undoManager?.removeAllActions()
            activeOverlayView?.removeFromSuperview()
            clearEditorStateAndReferences()
            if let cell = self.tableView?.view(atColumn: currentlyEditingColumn ?? 0, row: currentlyEditingRow ?? 0, makeIfNecessary: false) as? NSTableCellView {
                cell.textField?.allowsExpansionToolTips = true
            }
            return
        }
        activeEditingViewController?.textView.hideSuggestionPanel()
        activeEditingViewController?.textView?.undoManager?.removeAllActions()
        activeOverlayView?.removeFromSuperview()

        if commit, let textToCommit = newTextFromEditor {
            delegate?.overlayEditorManager(self, didUpdateText: textToCommit, forCellAtRow: row, column: col, in: tableView)
            tableView.reloadData(forRowIndexes: IndexSet([row]), columnIndexes: IndexSet([col]))
            if !textToCommit.isEmpty {
                let newSuggestion = textToCommit.capitalizedAndTrimmed()
                let columnName = tableView.tableColumns[col].identifier.rawValue
                Task {
                    await SuggestionCacheManager.shared.appendToCache(for: columnName, filter: newSuggestion, newSuggestions: [newSuggestion])
                }
            }
        } else { // Cancel atau dismiss karena scroll, dll.
            // Kembalikan teks asli ke sel jika sebelumnya dikosongkan
            if let cellView = tableView.view(atColumn: col, row: row, makeIfNecessary: false) as? NSTableCellView {
                cellView.textField?.allowsExpansionToolTips = true
            }
            delegate?.overlayEditorManagerDidCancelEditing?(self, forCellAtRow: row, column: col, in: tableView)
            tableView.reloadData(forRowIndexes: IndexSet([row]), columnIndexes: IndexSet([col]))
        }

        clearEditorStateAndReferences()
        // Opsional: Kembalikan fokus ke table view
        window?.makeFirstResponder(self.tableView)
        cell.textField?.allowsExpansionToolTips = true
        if row + 1 < tableView.numberOfRows, let cell = tableView.view(atColumn: col, row: row + 1, makeIfNecessary: false) as? NSTableCellView {
            cell.textField?.allowsExpansionToolTips = true
        }
        if row + 2 < tableView.numberOfRows, let cell = tableView.view(atColumn: col, row: row + 2, makeIfNecessary: false) as? NSTableCellView {
            cell.textField?.allowsExpansionToolTips = true
        }
    }

    /// Menghapus status editor dan referensi yang terkait.
    ///
    /// Fungsi ini digunakan untuk mereset atau membersihkan semua data dan referensi yang digunakan oleh editor.
    /// Biasanya dipanggil saat editor perlu diinisialisasi ulang atau saat keluar dari mode pengeditan.
    /// Pastikan untuk memanggil fungsi ini agar tidak ada data atau referensi yang tertinggal yang dapat menyebabkan kebocoran memori.
    private func clearEditorStateAndReferences() {
        activeOverlayView = nil
        activeEditingViewController = nil
        currentlyEditingRow = nil
        currentlyEditingColumn = nil
        originalCellTextBeforeEditing = nil
        removeClickOutsideMonitor()
    }

    /// Mengatur monitor untuk mendeteksi klik di luar area tertentu.
    /// Fungsi ini digunakan untuk memantau interaksi pengguna di luar komponen yang sedang aktif,
    /// sehingga dapat menutup atau membatalkan aksi ketika pengguna mengklik di luar area tersebut.
    private func setupClickOutsideMonitor() {
        removeClickOutsideMonitor()
        clickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event -> NSEvent? in
            guard let self, let overlay = self.activeOverlayView, overlay.window == event.window else { return event }
            let locationInOverlay = overlay.convert(event.locationInWindow, from: nil)
            if overlay.bounds.contains(locationInOverlay) {
                return event
            } else {
                #if DEBUG
                    print("Klik di luar overlay, menutup editor (commit).")
                #endif
                // Panggil commit action dari VC jika ada, atau dismiss langsung
                if let editorVC = self.activeEditingViewController {
                    editorVC.commitAndCloseAction?()
                } else {
                    self.dismissEditor(commit: true, newTextFromEditor: self.activeEditingViewController?.textView.string)
                }
                self.tableView?.mouseDown(with: event)
                return nil // Konsumsi event
            }
        }
    }

    /// Membersihkan monitoring klik di luar overlay.
    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    /// Mungkin bisa ditambahkan logika pembersihan editing?
    /// Contoh penggunaan:
    ///
    ///     func clearEditingState() {
    ///         // reset semua nilai terkait editing
    ///     }
    ///
    /// Pastikan dipanggil setelah editing selesai atau dibatalkan.
    func clearEditingState() {}

    deinit {
        NotificationCenter.default.removeObserver(self)
        removeClickOutsideMonitor()
    }
}
