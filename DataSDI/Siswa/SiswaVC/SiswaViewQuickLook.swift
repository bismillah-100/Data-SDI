//
//  SiswaViewQuickLook.swift
//  Data SDI
//
//  Created by Bismillah on 27/10/24.
//

import Cocoa
import Quartz

extension SiswaViewController {
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
        SharedQuickLook.shared.sourceTableView = tableView
        SharedQuickLook.shared.columnIndex = ReusableFunc.columnIndex(of: namaColumn, in: tableView)
        // Bersihkan preview items yang lama
        SharedQuickLook.shared.cleanTempDir()
        SharedQuickLook.shared.cleanPreviewItems()

        // Buat temporary directory baru
        let sessionID = UUID().uuidString
        SharedQuickLook.shared.setTempDir(FileManager.default.temporaryDirectory.appendingPathComponent(sessionID))

        guard let tempDir = SharedQuickLook.shared.getTempDir() else { return }

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            for row in index.reversed() {
                // Ambil data gambar
                let id: Int64?
                let nama: String
                if currentTableViewMode == .plain {
                    nama = viewModel.filteredSiswaData[row].nama.replacingOccurrences(of: "/", with: "-")
                } else {
                    let id = viewModel.getSiswaIdInGroupedMode(row: row)
                    nama = dbController.getSiswa(idValue: id).nama.replacingOccurrences(of: "/", with: "-")
                }
                if currentTableViewMode == .plain {
                    id = viewModel.filteredSiswaData[row].id
                } else {
                    id = viewModel.getSiswaIdInGroupedMode(row: row)
                }
                
                guard let id else { continue }
                
                let fotoData = dbController.bacaFotoSiswa(idValue: id)
                let trimmedNama = nama.replacingOccurrences(of: "/", with: "-")
                let fileName = "\(trimmedNama).png"
                let fileURL = tempDir.appendingPathComponent(fileName)

                try fotoData.write(to: fileURL)

                SharedQuickLook.shared.setPreviewItems(fileURL)
            }
            
            SharedQuickLook.shared.showQuickLook()

        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    // MARK: - Keyboard Handler
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // Space key
            if QLPreviewPanel.shared().isVisible {
                SharedQuickLook.shared.endPreviewPanelControl(QLPreviewPanel.shared()!)
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
        if SharedQuickLook.shared.isQuickLookVisible() {
            SharedQuickLook.shared.closeQuickLook()
        }
    }
}
