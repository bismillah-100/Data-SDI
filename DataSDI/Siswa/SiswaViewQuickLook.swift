//
//  SiswaViewQuickLook.swift
//  Data SDI
//
//  Created by Bismillah on 27/10/24.
//

import Cocoa
import Quartz

extension SiswaViewController: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    /// Merespons aksi pengguna untuk menampilkan foto-foto siswa menggunakan Quick Look.
    ///
    /// Fungsi ini menentukan baris mana yang diklik atau dipilih di `tableView`.
    /// Jika ada baris yang diklik atau dipilih, ia akan memanggil `showQuickLook`
    /// untuk menampilkan foto-foto siswa yang terkait dalam Quick Look.
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini.
    @IBAction func tampilkanFotos(_ sender: NSMenuItem) {
        let klikRow = tableView.clickedRow
        if klikRow != -1 {
            if tableView.selectedRowIndexes.contains(klikRow), klikRow >= 0 {
                showQuickLook(tableView.selectedRowIndexes)
            } else if !tableView.selectedRowIndexes.contains(klikRow), klikRow >= 0 {
                showQuickLook(IndexSet([klikRow]))
            }
        } else {
            showQuickLook(tableView.selectedRowIndexes)
        }
    }

    /// Menampilkan foto-foto siswa yang dipilih dalam panel Quick Look.
    ///
    /// Fungsi ini membersihkan item pratinjau sebelumnya dan membuat direktori sementara baru
    /// untuk menyimpan salinan foto-foto yang akan ditampilkan. Ia mengambil data foto
    /// dari model data (`viewModel` atau `dbController`) berdasarkan indeks baris yang dipilih,
    /// menulisnya ke file sementara, lalu menambahkan URL file tersebut ke `previewItems`.
    /// Setelah semua foto disiapkan, ia mengaktifkan dan memperbarui `QLPreviewPanel`
    /// untuk menampilkan foto-foto tersebut.
    ///
    /// - Parameter index: `IndexSet` yang berisi indeks baris dari siswa yang fotonya akan ditampilkan.
    func showQuickLook(_ index: IndexSet) {
        guard !index.isEmpty else { return }

        // Bersihkan preview items yang lama
        previewItems.removeAll()

        // Hapus temporary directory yang lama jika ada
        if let oldTempDir = tempDir {
            try? FileManager.default.removeItem(at: oldTempDir)
        }

        // Buat temporary directory baru
        let sessionID = UUID().uuidString
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(sessionID)

        guard let tempDir else { return }

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            for row in index.reversed() {
                // Ambil data gambar
                let id: Int64?
                let nama: String
                if currentTableViewMode == .plain {
                    nama = viewModel.filteredSiswaData[row].nama
                } else {
                    let id = viewModel.getSiswaIdInGroupedMode(row: row)
                    nama = dbController.getSiswa(idValue: id).nama
                }
                if currentTableViewMode == .plain {
                    id = viewModel.filteredSiswaData[row].id
                } else {
                    id = viewModel.getSiswaIdInGroupedMode(row: row)
                }
                guard id != nil else { continue }
                let fotoData = dbController.bacaFotoSiswa(idValue: id!).foto
                let fileName = "\(nama).png"
                let fileURL = tempDir.appendingPathComponent(fileName)

                try fotoData.write(to: fileURL)

                previewItems.append(fileURL)
            }

            isQuickLookActive = true
            if let panel = QLPreviewPanel.shared() {
                panel.updateController()
                DispatchQueue.main.async { [unowned self] in
                    // Jika panel sudah visible, reload data
                    if panel.isVisible {
                        panel.reloadData()
                    } else {
                        self.beginPreviewPanelControl(panel)
                        panel.isFloatingPanel = true
                    }
                }
            }

        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.orderFront(self)
        panel.updateController()
        panel.dataSource = self
        panel.delegate = self
        // panel.currentPreviewItemIndex = //your initial index
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
        DispatchQueue.global(qos: .background).async {
            self.cleanupQuickLook()
        }
    }

    // MARK: - QLPreviewPanelDelegate

    /// Mengimplementasikan delegasi `QLPreviewPanel` untuk menyediakan *frame* sumber di layar
    /// untuk item yang sedang dipratinjau.
    ///
    /// Fungsi ini bertanggung jawab untuk mengembalikan `NSRect` yang menunjukkan posisi dan ukuran
    /// dari "sumber" visual item yang saat ini dilihat di Quick Look. Ini menciptakan efek animasi
    /// yang mulus saat panel Quick Look muncul atau menghilang, membuatnya terlihat seolah-olah
    /// panel meluas atau menyusut dari lokasi item di `tableView`.
    ///
    /// - Parameters:
    ///   - panel: Instance `QLPreviewPanel` yang meminta *frame* sumber.
    ///   - item: Objek `QLPreviewItem` yang saat ini sedang dipratinjau.
    /// - Returns: `NSRect` yang merepresentasikan *frame* sumber di koordinat layar.
    ///            Jika item tidak dapat ditemukan atau tidak terlihat, `NSZeroRect` akan dikembalikan.
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        var returnIconRect = NSZeroRect
        let index = tableView.selectedRowIndexes.last!
        if index != NSNotFound {
            var iconRect = tableView.frameOfCell(atColumn: 0, row: index)

            // fix icon width
            iconRect.size.width = iconRect.size.height
            let visibleRect = tableView.visibleRect

            if NSIntersectsRect(visibleRect, iconRect) {
                var convertedRect = tableView.convert(iconRect, to: nil)
                convertedRect.origin = (tableView.window?.convertPoint(toScreen: convertedRect.origin))!
                returnIconRect = convertedRect
            }
        }
        return returnIconRect
    }

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // Handle key events
        if event.type == .keyDown {
            switch event.keyCode {
            case 125: // Down arrow
                guard isQuickLookActive else { return false }
                let nextIndex = tableView.selectedRowIndexes.first.map { $0 + 1 }
                if let next = nextIndex, next < tableView.numberOfRows {
                    tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
                    tableView.scrollRowToVisible(next)
                    showQuickLook(tableView.selectedRowIndexes)
                }
                return true
            case 126: // Up arrow
                guard isQuickLookActive else { return false }
                let prevIndex = tableView.selectedRowIndexes.first.map { $0 - 1 }
                if let prev = prevIndex, prev >= 0 {
                    tableView.selectRowIndexes(IndexSet(integer: prev), byExtendingSelection: false)
                    tableView.scrollRowToVisible(prev)
                    showQuickLook(tableView.selectedRowIndexes)
                }
                return true
            case 49: // Space
                QLPreviewPanel.shared()?.close()
                isQuickLookActive = false
                if let panel = QLPreviewPanel.shared() {
                    endPreviewPanelControl(panel)
                }
                return true
//            case 53: // Esc
//                QLPreviewPanel.shared()?.close()
//                isQuickLookActive = false
//                return true
            default:
                return false
            }
        }
        return false
    }

    private func cleanupQuickLook() {
        isQuickLookActive = false

        // Cleanup temporary files
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
            self.tempDir = nil
        }
        previewItems.removeAll()
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewItems.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewItems[index] as QLPreviewItem
    }

    // MARK: - Keyboard Handler

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // Space key
            if QLPreviewPanel.shared().isVisible {
                if let panel = QLPreviewPanel.shared() {
                    endPreviewPanelControl(panel)
                }
            } else {
                showQuickLook(tableView.selectedRowIndexes)
            }
        } else if event.keyCode == 53 { // Key code 53 adalah tombol Esc
            if QLPreviewPanel.shared().isVisible {
                QLPreviewPanel.shared()?.close()
            }
        } else {
            super.keyDown(with: event)
        }
    }

    /// Pemeriksaan quick look apakah ada yang ditampilkan.
    ///
    /// Ini berguna untuk menutup QuickLook ketika view induk tidak lagi direpresentasikan di layar.
    func cekQuickLook() {
        if isQuickLookActive {
            QLPreviewPanel.shared()?.close()
            isQuickLookActive = false
        }
    }
}
