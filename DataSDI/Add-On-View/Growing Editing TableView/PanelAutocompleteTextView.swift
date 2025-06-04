//
//  PanelTextView.swift
//  Data SDI
//
//  Created by Ays on 16/05/25.
//

import Cocoa


class PanelAutocompleteTextView: NSTextView {
    // MARK: – Panel & TableView
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
    
    var parentWindow: NSWindow!
    var columnName = ""
    
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

    // Data suggestion
    var allSuggestions: [String]!
    private var displayedSuggestions: [String] = []
    private let cacheQueue = DispatchQueue(label: "cacheQueue", attributes: .concurrent)

    // TableView SuperView
    var tableView: NSTableView?
    
    private func showPanel(at charRange: NSRange) {
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
    
    private func adjustPanelSize() {
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
            guard let self = self, self.columnName != "nilai", !self.allSuggestions.isEmpty else { return }
            await self.updateSuggestions()
        }
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
    private func updateSuggestions() async {
        // Ambil range token yang sedang diketik.
        guard let currentTokenRange = currentWordRange() else {
            displayedSuggestions = []
            hideSuggestionPanel()
            return
        }
        
        let fullText = self.string as NSString
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
        let numSuggestions = self.allSuggestions.count
        
        // Tentukan berapa banyak task yang akan dibuat
        // Misalnya, bagi menjadi 8 chunk, atau berdasarkan jumlah inti CPU
        let numberOfTasks = min(numSuggestions, ProcessInfo.processInfo.activeProcessorCount * 2) // Contoh
        let chunkSize = numSuggestions / numberOfTasks
        
        await withTaskGroup(of: [String].self) { [weak self] group in
            guard let self = self else { return }
            for i in 0..<numberOfTasks {
                    let startIndex = i * chunkSize
                let endIndex = (i == numberOfTasks - 1) ? numSuggestions : min(startIndex + chunkSize, numSuggestions)
                
                // Pastikan range valid
                guard startIndex < endIndex else { continue }
                
                let chunk = Array(self.allSuggestions[startIndex..<endIndex])
                
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
                                suggestionTokens[index].lowercased() != typedToken.lowercased() {
                                startsWithTokens = false
                                break
                            }
                        }
                        
                        let candidateIndex: Int
                        if startsWithTokens {
                            candidateIndex = alreadyTypedTokens.count
                            // Pastikan token kandidat memiliki prefix yang sesuai.
                            guard candidateIndex < suggestionTokens.count,
                                  suggestionTokens[candidateIndex].lowercased().hasPrefix(lowerPref) else {
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
        await SuggestionCacheManager.shared.storeCache(for: self.columnName, filter: cacheKey, suggestions: finalValidCandidates)
        
        // Update UI pada main thread.
        await MainActor.run { // Pastikan pembaruan UI di main thread
            self.displayedSuggestions = finalValidCandidates
            self.updateUIForSuggestions()
        }
    }
    
    // Helper method untuk memperbarui UI, agar kode lebih bersih
    private func updateUIForSuggestions() {
        if self.displayedSuggestions.isEmpty {
            self.hideSuggestionPanel()
        } else {
            self.suggestionTable.reloadData()
            self.adjustPanelSize()
            // currentWordRange() mungkin perlu dipanggil lagi atau disimpan jika method ini dipanggil dari background
            // Namun, untuk kasus ini, kita asumsikan currentTokenRange masih relevan
            // Jika tidak, Anda perlu cara untuk mendapatkan lokasi yang tepat lagi
            guard let currentTokenRange = self.currentWordRange() else { return }
            self.showPanel(at: currentTokenRange)
            self.sizeColumnToFitContents(
                font: self.typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            )
        }
    }
    
    @objc private func commitSelection() {
        let fullText = self.string as NSString
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

    private func replace(range: NSRange, with text: String) {
        if shouldChangeText(in: range, replacementString: text) {
            replaceCharacters(in: range, with: text)
            didChangeText()
        }
        hideSuggestionPanel()
    }

    // MARK: – Cari current word range
    private func currentWordRange() -> NSRange? {
        let idx = selectedRange().location
        guard idx > 0 else { return nil }
        let txt = string as NSString
        var start = idx
        while start > 0,
              CharacterSet.alphanumerics.contains(Unicode.Scalar(txt.character(at: start-1))!) {
            start -= 1
        }
        let length = idx - start
        return length > 0 ? NSRange(location: start, length: length) : nil
    }
    
    //MARK: - Skor saran
    // Opsional: Tambahkan fungsi untuk scoring matches
    private func scoreMatch(_ suggestion: String, for searchText: String) async -> Int {
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
            .contains(searchLower) {
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

    private func moveSelection(down: Bool) {
        let row = suggestionTable.selectedRow
        let next = down ? min(row + 1, displayedSuggestions.count - 1) : max(row - 1, 0)
        suggestionTable.selectRowIndexes([next], byExtendingSelection: false)
        suggestionTable.scrollRowToVisible(next)
    }
    
    func hideSuggestionPanel() {
        if let parentWindow = parentWindow { parentWindow.removeChildWindow(panel) };  panel.orderOut(nil)
    }
    
    deinit {
        allSuggestions.removeAll()
        displayedSuggestions.removeAll()
    }
}
// MARK: – NSTableView DataSource & Delegate
extension PanelAutocompleteTextView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { displayedSuggestions.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
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
            label.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])

        return cellView
    }

    func tableViewSelectionDidChange(_ notif: Notification) {
        // Atur row tableview supaya warna seleksi tidak berubah.
        tableView?.rowView(atRow: tableView?.selectedRow ?? 0, makeIfNecessary: false)?.isEmphasized = true
    }
    
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
