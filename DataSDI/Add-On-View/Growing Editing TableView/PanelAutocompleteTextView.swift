//
//  PanelAutocompleteTextView.swift
//  Data SDI
//
//  Created by Ays on 16/05/25.
//

import Cocoa

/// Sebuah NSTextView yang digunakan untuk menampilkan saran otomatis dalam bentuk panel.
class PanelAutocompleteTextView: NSTextView {
    // MARK: – Panel & TableView

    /// Membuat NSTableView untuk menampilkan saran otomatis.
    /// TableView ini akan menampilkan daftar saran berdasarkan teks yang sedang diketik.
    private lazy var suggestionTable: NSTableView = {
        let tv = NSTableView(frame: .zero)
        let col = NSTableColumn(identifier: .init("suggestion"))
        col.width = 200
        tv.addTableColumn(col)
        tv.headerView = nil
        tv.delegate = self
        tv.dataSource = self
        tv.rowHeight = 20
        tv.selectionHighlightStyle = .regular
        tv.gridStyleMask = .solidHorizontalGridLineMask
        tv.style = .fullWidth
        tv.doubleAction = #selector(commitSelection)
        return tv
    }()

    /// ScrollView yang membungkus suggestionTable.
    /// ScrollView ini akan menampilkan daftar saran dengan scrollbar vertikal.
    private lazy var suggestionScroll: NSScrollView = {
        let sv = NSScrollView(frame: .zero)
        sv.documentView = suggestionTable
        sv.hasVerticalScroller = true
        sv.borderType = .lineBorder
        sv.automaticallyAdjustsContentInsets = false
        sv.wantsLayer = true
        sv.layer?.masksToBounds = true
        sv.layer?.cornerRadius = 8.0
        return sv
    }()

    /// Parent window yang akan menampung panel.
    var parentWindow: NSWindow!
    /// Nama kolom yang sedang diedit.
    /// Ini digunakan untuk menentukan saran yang relevan berdasarkan kolom yang sedang diedit.
    /// Misalnya, jika kolom adalah "nilai", maka saran yang ditampilkan akan relevan dengan nilai tersebut.
    var columnName = ""

    /// Panel yang menampilkan saran otomatis.
    /// Panel ini akan muncul di bawah caret teks saat pengguna mengetik.
    /// Panel ini akan berisi suggestionScroll yang menampilkan daftar saran.
    /// Panel ini akan muncul sebagai child window dari parentWindow.
    /// Panel ini akan memiliki style non-activating dan full size content view.
    /// Panel ini akan memiliki background transparan dan shadow.
    /// Panel ini akan memiliki level pop-up menu sehingga selalu di atas jendela lainnya.
    lazy var panel: NSPanel = {
        let p = NSPanel(contentRect: .zero,
                        styleMask: [.nonactivatingPanel, .fullSizeContentView],
                        backing: .buffered,
                        defer: false)
        p.titleVisibility = .hidden
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.level = .popUpMenu
        p.isOpaque = false
        p.backgroundColor = .clear
        p.contentView = suggestionScroll
        p.hasShadow = true
        return p
    }()

    /// Semua saran yang tersedia untuk kolom ini.
    /// Saran ini akan diambil dari sumber data yang relevan, misalnya dari database atau file.
    /// Saran ini akan digunakan untuk menampilkan daftar saran yang relevan saat pengguna mengetik.
    /// Saran ini harus diisi sebelum panel ditampilkan.
    /// Saran ini akan di-cache untuk meningkatkan performa.
    var allSuggestions: [String]!

    /// Saran yang sedang ditampilkan di panel.
    private var displayedSuggestions: [String] = []

    // TableView SuperView
    var tableView: NSTableView?

    /// Inisialisasi PanelAutocompleteTextView dengan frame dan kolom yang relevan.
    /// - Parameter charRange: NSRange yang menunjukkan posisi caret teks.
    func showPanel(at charRange: NSRange) {
        // 1. Dapatkan rect caret di koordinat layar
        var actual = NSRange()
        let screenRect = firstRect(forCharacterRange: charRange, actualRange: &actual)
        // screenRect.origin adalah pojok kiri bawah karakter

        // 2. Hitung origin panel di layar:
        //    x = sama dengan caret.x
        //    y = caret.y – tinggi panel
        let panelSize = panel.frame.size
        let panelOriginScreen = CGPoint(
            x: screenRect.minX,
            y: screenRect.minY - panelSize.height
        )

        // 3. Set frame panel:
        panel.setFrameOrigin(panelOriginScreen)

        // 4. Tambahkan sebagai child window jika belum
        if panel.parent == nil {
            parentWindow = window
            parentWindow.addChildWindow(panel, ordered: .above)
        }
        panel.orderFront(nil)
    }

    /// Menyesuaikan ukuran panel berdasarkan jumlah saran yang ditampilkan.
    /// Panel akan menyesuaikan tinggi berdasarkan jumlah saran yang ditampilkan.
    func adjustPanelSize() {
        let rowCount = min(displayedSuggestions.count, 6)
        let height = CGFloat(rowCount) * suggestionTable.rowHeight
        suggestionScroll.frame = NSRect(x: 0, y: 0, width: 200, height: height)
        panel.contentView?.frame = suggestionScroll.frame
        panel.setContentSize(suggestionScroll.frame.size)
    }

    // MARK: – Update suggestion tiap teks berubah

    override func didChangeText() {
        super.didChangeText()
        Task { [weak self] in
            guard let self, columnName != "nilai", !self.allSuggestions.isEmpty else { return }
            await updateSuggestions()
        }
        guard columnName == "nilai" else { return }
        if let value = Int(string) {
            // string valid angka
            textStorage?.foregroundColor =
                (value <= 59)
                    ? NSColor.red
                    : NSColor.controlTextColor
        } else {
            // string bukan angka, pakai warna normal
            textStorage?.foregroundColor = NSColor.controlTextColor
        }
    }

    /// Memperbarui saran berdasarkan teks yang sedang diketik.
    /// Fungsi ini akan dipanggil setiap kali teks berubah.
    /// Ini akan mengambil teks yang sedang diketik, memisahkan menjadi token, dan mencari saran yang relevan.
    /// Jika saran ditemukan, panel akan ditampilkan dengan daftar saran.
    /// Jika tidak ada saran yang ditemukan, panel akan disembunyikan.
    func updateSuggestions() async {
        // Ambil range token yang sedang diketik.
        guard let currentTokenRange = currentWordRange() else {
            displayedSuggestions = []
            hideSuggestionPanel()
            return
        }

        let fullText = string as NSString
        let prefix = fullText.substring(with: currentTokenRange)
        let currentTypedToken = fullText.substring(with: currentTokenRange)
        let lowerPref = currentTypedToken.lowercased()

        // Ambil teks sebelum token terakhir dan pisahkan menjadi token-token yang sudah diketik.
        let prefixText = fullText.substring(to: currentTokenRange.location)
        let alreadyTypedTokens = prefixText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Buat cache key dengan menggabungkan token yang sudah diketik dan token saat ini.
        let cacheKey = (alreadyTypedTokens.joined(separator: " ") + "|\(lowerPref)")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Cek apakah hasil saran untuk key tersebut sudah ada di cache.
        if let cached = await SuggestionCacheManager.shared.getCache(for: columnName, filter: cacheKey) {
            // Jika ada, langsung update UI pada main thread.
            // Karena ini dipanggil dari main thread, DispatchQueeu.main.async tidak mutlak diperlukan
            // tetapi bisa membantu konsistensi jika method ini dipanggil dari background task.
            await MainActor.run { // Tetap gunakan main.async untuk safety UI
                self.displayedSuggestions = cached.map { $0 }
                self.updateUIForSuggestions()
            }
            return
        }

        // Ambil batas maksimal saran dari UserDefaults.
        let userDefaults = UserDefaults.standard
        let maxSuggestions = userDefaults.integer(forKey: "maksimalSaran")
        let maxLimit = maxSuggestions > 0 ? maxSuggestions : 5

        // Jalankan pekerjaan pencarian saran di background Task
        // `Task` secara default menggunakan pool thread background
        // Gunakan TaskGroup untuk memparalelkan iterasi `allSuggestions`
        var concurrentValidCandidates: [String] = []
        let numSuggestions = allSuggestions.count

        // Tentukan berapa banyak task yang akan dibuat
        // Misalnya, bagi menjadi 8 chunk, atau berdasarkan jumlah inti CPU
        let numberOfTasks = min(numSuggestions, ProcessInfo.processInfo.activeProcessorCount * 2) // Contoh
        let chunkSize = numSuggestions / numberOfTasks

        await withTaskGroup(of: [String].self) { [weak self] group in
            guard let self else { return }
            for i in 0 ..< numberOfTasks {
                let startIndex = i * chunkSize
                let endIndex = (i == numberOfTasks - 1) ? numSuggestions : min(startIndex + chunkSize, numSuggestions)

                // Pastikan range valid
                guard startIndex < endIndex else { continue }

                let chunk = Array(allSuggestions[startIndex ..< endIndex])

                group.addTask {
                    var localCandidates: [String] = []
                    for suggestion in chunk {
                        // Optimisasi awal: jika saran tidak mengandung prefix secara kasar, lewati.
                        if !suggestion.lowercased().contains(lowerPref) {
                            continue
                        }

                        // Skor kecocokan antar saran dan prefix.
                        let score = await self.scoreMatch(suggestion, for: prefix)
                        if score < 25 || suggestion.count <= prefix.count {
                            continue
                        }

                        let suggestionTokens = suggestion
                            .components(separatedBy: .whitespacesAndNewlines)
                            .filter { !$0.isEmpty }
                        if suggestionTokens.count < alreadyTypedTokens.count + 1 { continue }

                        // Cek apakah saran sudah mulai dengan token-token yang sudah diketik.
                        var startsWithTokens = true
                        for (index, typedToken) in alreadyTypedTokens.enumerated() {
                            if index >= suggestionTokens.count ||
                                suggestionTokens[index].lowercased() != typedToken.lowercased()
                            {
                                startsWithTokens = false
                                break
                            }
                        }

                        let candidateIndex: Int
                        if startsWithTokens {
                            candidateIndex = alreadyTypedTokens.count
                            // Pastikan token kandidat memiliki prefix yang sesuai.
                            guard candidateIndex < suggestionTokens.count,
                                  suggestionTokens[candidateIndex].lowercased().hasPrefix(lowerPref)
                            else {
                                continue
                            }
                        } else {
                            // Fallback: cari token terakhir yang memenuhi prefix.
                            guard let fallbackIndex = suggestionTokens.lastIndex(where: { $0.lowercased().hasPrefix(lowerPref) }) else {
                                continue
                            }
                            candidateIndex = fallbackIndex
                        }

                        // Ambil token saran dari candidateIndex sampai akhir.
                        let displayTokens = Array(suggestionTokens[candidateIndex...])
                        let displayString = displayTokens
                            .joined(separator: " ")
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        if displayString.isEmpty || displayString.lowercased() == lowerPref {
                            continue
                        }

                        // Perhatikan: Duplikasi dan batas maksimal akan ditangani setelah semua hasil dikumpulkan
                        // karena kita sedang memproses secara paralel.
                        localCandidates.append(displayString)
                    }
                    return localCandidates
                }
            }

            // Kumpulkan hasil dari semua sub-task
            for await candidatesChunk in group {
                concurrentValidCandidates.append(contentsOf: candidatesChunk)
            }
        }

        // Setelah semua hasil terkumpul, lakukan deduplikasi dan ambil batas maksimal
        let uniqueCandidates = Array(Set(concurrentValidCandidates)).sorted() // Sort untuk konsistensi
        let finalValidCandidates = uniqueCandidates.prefix(maxLimit).map { $0 }

        // Simpan hasil perhitungan ke cache. SuggestionCacheManager harus thread-safe.
        await SuggestionCacheManager.shared.storeCache(for: columnName, filter: cacheKey, suggestions: finalValidCandidates)

        // Update UI pada main thread.
        await MainActor.run { // Pastikan pembaruan UI di main thread
            self.displayedSuggestions = finalValidCandidates
            self.updateUIForSuggestions()
        }
    }

    /// Memperbarui UI berdasarkan saran yang ditampilkan.
    /// Jika tidak ada saran yang ditampilkan, panel akan disembunyikan.
    /// Jika ada saran, panel akan ditampilkan dengan daftar saran yang relevan.
    /// Ini juga akan menyesuaikan ukuran panel berdasarkan jumlah saran yang ditampilkan.
    /// Jika panel sudah ditampilkan, akan menyesuaikan ukuran kolom untuk menampung konten.
    /// Jika panel belum ditampilkan, akan menampilkan panel di bawah caret teks.
    func updateUIForSuggestions() {
        if displayedSuggestions.isEmpty {
            hideSuggestionPanel()
        } else {
            suggestionTable.reloadData()
            adjustPanelSize()
            // currentWordRange() mungkin perlu dipanggil lagi atau disimpan jika method ini dipanggil dari background
            // Namun, untuk kasus ini, kita asumsikan currentTokenRange masih relevan
            // Jika tidak, Anda perlu cara untuk mendapatkan lokasi yang tepat lagi
            guard let currentTokenRange = currentWordRange() else { return }
            showPanel(at: currentTokenRange)
            sizeColumnToFitContents(
                font: typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            )
        }
    }

    /// Mengganti teks yang sedang diketik dengan saran yang dipilih.
    /// Fungsi ini akan mengganti teks yang sedang diketik dengan saran yang dipilih dari daftar saran.
    /// Ini akan mencari prefix terpanjang yang cocok dengan teks sebelum caret, dan mengganti teks tersebut dengan saran yang dipilih.
    /// Jika tidak ada prefix yang cocok, akan mengganti teks dengan saran secara langsung.
    /// Ini akan dipanggil ketika pengguna memilih saran dari daftar saran, misalnya dengan menekan Enter atau Tab.
    /// - Note: Fungsi ini harus dipanggil dari main thread karena berinteraksi dengan UI.
    @objc func commitSelection() {
        let fullText = string as NSString
        let caret = selectedRange().location
        let pick = displayedSuggestions[suggestionTable.selectedRow]

        // 1️⃣ Cari panjang minimal (yang sudah diketik)
        guard let wordRange = currentWordRange() else { return }
        let typedLen = wordRange.length

        // 2️⃣ Maximum prefix length adalah min(pick.count, caret)
        let maxPrefix = min(pick.count, caret)

        // 3️⃣ Temukan prefix terpanjang dari `pick` yang match teks sebelum caret
        var matchedLen = 0
        for prefixLen in stride(from: maxPrefix, through: typedLen, by: -1) {
            let start = caret - prefixLen
            let substr = fullText.substring(with: NSRange(location: start, length: prefixLen)).lowercased()
            let prefix = String(pick.prefix(prefixLen)).lowercased()
            if substr == prefix {
                matchedLen = prefixLen
                break
            }
        }

        // 4️⃣ Jika tidak ketemu (malah aneh), fallback ke kata tunggal
        guard matchedLen > 0 else {
            replace(range: wordRange, with: pick)
            return
        }

        // 5️⃣ Bangun range yang akan diganti
        let replaceRange = NSRange(location: caret - matchedLen, length: matchedLen)
        replace(range: replaceRange, with: pick)
    }

    /// Mengganti teks dalam range tertentu dengan teks baru.
    /// Fungsi ini akan mengganti teks dalam range yang diberikan dengan teks baru.
    /// Ini akan memanggil `shouldChangeText(in:replacementString:)` untuk memastikan perubahan diperbolehkan.
    /// Jika perubahan diperbolehkan, akan memanggil `replaceCharacters(in:with:)` untuk mengganti teks.
    /// Setelah mengganti teks, akan memanggil `didChangeText()` untuk memperbarui UI.
    /// Ini juga akan menyembunyikan panel saran setelah mengganti teks.
    /// - Parameters:
    ///   - range: NSRange yang menunjukkan posisi teks yang akan diganti.
    ///   - text: String baru yang akan menggantikan teks dalam range tersebut.
    func replace(range: NSRange, with text: String) {
        if shouldChangeText(in: range, replacementString: text) {
            replaceCharacters(in: range, with: text)
            didChangeText()
        }
        hideSuggestionPanel()
    }

    // MARK: – Cari current word range

    /// Mendapatkan range dari kata yang sedang diketik.
    /// Fungsi ini akan mencari kata yang sedang diketik berdasarkan posisi caret teks.
    /// Ini akan mencari karakter sebelum caret, dan menentukan range dari kata tersebut.
    /// Jika caret berada di awal teks, akan mengembalikan nil.
    /// - Returns: NSRange yang menunjukkan posisi kata yang sedang diketik, atau nil jika caret berada di awal teks.
    func currentWordRange() -> NSRange? {
        let idx = selectedRange().location
        guard idx > 0 else { return nil }
        let txt = string as NSString
        var start = idx
        while start > 0,
              CharacterSet.alphanumerics.contains(Unicode.Scalar(txt.character(at: start - 1))!)
        {
            start -= 1
        }
        let length = idx - start
        return length > 0 ? NSRange(location: start, length: length) : nil
    }

    // MARK: - Skor saran

    /// Menghitung skor kecocokan antara saran dan teks pencarian.
    /// Fungsi ini akan memberikan skor berdasarkan seberapa baik saran cocok dengan teks pencarian.
    /// Skor tertinggi diberikan untuk kecocokan yang tepat, diikuti oleh kecocokan yang dimulai dengan teks pencarian,
    /// kecocokan yang mengandung teks pencarian sebagai kata utuh, dan kecocokan yang mengandung teks pencarian di mana saja.
    /// - Parameters:
    ///   - suggestion: String yang merupakan saran yang akan dinilai.
    ///   - searchText: String yang merupakan teks pencarian yang sedang diketik.
    /// - Returns: Skor kecocokan sebagai Integer.
    func scoreMatch(_ suggestion: String, for searchText: String) async -> Int {
        var score = 0
        let suggestionLower = suggestion.lowercased()
        let searchLower = searchText.lowercased()

        // Exact match gets highest score
        if suggestionLower == searchLower {
            score += 100
        }
        // Starts with search text
        else if suggestionLower.hasPrefix(searchLower) {
            score += 75
        }
        // Contains search text as a whole word
        else if suggestionLower.components(separatedBy: .whitespacesAndNewlines)
            .contains(searchLower)
        {
            score += 50
        }
        // Contains search text anywhere
        else if suggestionLower.contains(searchLower) {
            score += 25
        }

        return score
    }

    // MARK: – Navigasi key-down

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: // Down
            if panel.isVisible {
                moveSelection(down: true); return
            }
        case 126: // Up
            if panel.isVisible {
                moveSelection(down: false); return
            }
        case 36, 48: // Return or Tab
            if panel.isVisible, suggestionTable.selectedRow >= 0 {
                commitSelection(); return
            }
        case 53: // Esc
            if panel.isVisible {
                hideSuggestionPanel()
                return
            }
        default: break
        }
        super.keyDown(with: event)
    }

    /// Memindahkan seleksi pada suggestionTable ke atas atau bawah.
    /// - Parameter down: Bool yang menentukan arah pergerakan seleksi.
    func moveSelection(down: Bool) {
        let row = suggestionTable.selectedRow
        let next = down ? min(row + 1, displayedSuggestions.count - 1) : max(row - 1, 0)
        suggestionTable.selectRowIndexes([next], byExtendingSelection: false)
        suggestionTable.scrollRowToVisible(next)
    }

    /// Menyembunyikan panel saran.
    /// Fungsi ini akan menghapus panel dari parent window jika ada, dan menyembunyikan panel.
    func hideSuggestionPanel() {
        if let parentWindow { parentWindow.removeChildWindow(panel) }; panel.orderOut(nil)
    }

    deinit {
        allSuggestions.removeAll()
        displayedSuggestions.removeAll()
    }
}

// MARK: – NSTableView DataSource & Delegate

extension PanelAutocompleteTextView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in _: NSTableView) -> Int { displayedSuggestions.count }
    func tableView(_: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < displayedSuggestions.count else {
            return NSView()
        }
        // 1. Buat cellView sebagai container
        let cellView = NSTableCellView()
        cellView.identifier = tableColumn?.identifier

        // 2. Buat textField
        let label = NSTextField(labelWithString: displayedSuggestions[row])
        label.font = typingAttributes[.font] as? NSFont
        label.translatesAutoresizingMaskIntoConstraints = false

        // 3. Tambahkan ke container
        cellView.addSubview(label)

        // 4. Constraint: leading/trailing ke cellView
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 0),
            label.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: 0),
            label.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
        ])

        return cellView
    }

    func tableViewSelectionDidChange(_: Notification) {
        // Atur row tableview supaya warna seleksi tidak berubah.
        tableView?.rowView(atRow: tableView?.selectedRow ?? 0, makeIfNecessary: false)?.isEmphasized = true
    }

    /// Menyesuaikan lebar kolom untuk menyesuaikan konten.
    /// Fungsi ini akan menghitung lebar maksimum dari header dan setiap saran yang ditampilkan,
    /// dan mengatur lebar kolom sesuai dengan lebar maksimum tersebut.
    /// Jika kolom tidak diberikan, akan menggunakan kolom pertama dari suggestionTable.
    /// Ini akan memastikan bahwa kolom cukup lebar untuk menampilkan semua konten tanpa terpotong.
    /// - Parameters:
    ///   - column: NSTableColumn? yang akan disesuaikan, jika nil akan menggunakan kolom pertama.
    ///   - font: NSFont yang digunakan untuk menghitung lebar teks.
    ///   - Note: Pastikan font yang digunakan sama dengan font yang digunakan di suggestionTable.
    func sizeColumnToFitContents(
        _ column: NSTableColumn? = nil,
        font: NSFont
    ) {
        let col = column ?? suggestionTable.tableColumns.first!

        // 1. Lebar header
        let headerString = col.headerCell.stringValue as NSString
        var maxWidth = headerString.size(withAttributes: [.font: font]).width

        // 2. Lebar masing‑masing string di matches
        //    Asumsikan dataSource Anda punya array `matches: [String]`
        if let vc = suggestionTable.dataSource as? PanelAutocompleteTextView {
            for text in vc.displayedSuggestions {
                let w = (text as NSString).size(withAttributes: [.font: font]).width
                maxWidth = max(maxWidth, w)
            }
        }
        // 3. Apply + padding
        col.width = maxWidth
    }
}
