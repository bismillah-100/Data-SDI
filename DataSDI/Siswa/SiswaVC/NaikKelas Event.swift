//
//  NaikKelas Event.swift
//  Data SDI
//
//  Created by MacBook on 05/08/25.
//

import AppKit
import Combine

/// Event yang digunakan untuk mengelola perubahan kelas siswa
/// dan mengaktifkan siswa.
/// Event ini digunakan dalam `SiswaViewController` untuk menangani aksi terkait kelas siswa,
/// seperti mengubah kelas, mengaktifkan siswa, dan mengelola undo/redo perubahan kelas.
enum NaikKelasEvent {
    /// Event untuk mengubah kelas siswa.
    /// - Parameters:
    ///   - id: ID siswa yang kelasnya akan diubah.
    ///   - fromKelas: Kelas asal siswa sebelum perubahan.
    case kelasBerubah(_ id: Int64, fromKelas: String)

    /// Event untuk mengubah kelas siswa dengan undo/redo.
    /// - Parameters:
    ///   - id: ID siswa yang kelasnya akan diubah.
    ///   - toKelas: Kelas baru yang akan diterapkan pada siswa.
    ///   - status: Status siswa setelah perubahan kelas.
    case undoUbahKelas(_ id: Int64, toKelas: String, status: StatusSiswa)

    /// Event untuk mengaktifkan siswa.
    /// - Parameters:
    ///   - id: ID siswa yang akan diaktifkan.
    ///  - kelas: Kelas yang akan diterapkan pada siswa yang diaktifkan.
    case aktifkanSiswa(_ id: Int64, kelas: String)

    /// Event untuk mengaktifkan siswa dengan undo/redo.
    /// - Parameters:
    ///   - id: ID siswa yang akan diaktifkan.
    ///   - kelas: Kelas yang akan diterapkan pada siswa yang diaktifkan.
    case undoAktifkanSiswa(_ id: Int64, kelas: String)
}

extension SiswaViewController {
    /**
     * Fungsi ini dijalankan ketika mengubah status siswa dari menu klik kanan atau dari menu di toolbar.
     * Fungsi ini menangani logika untuk mengubah status siswa, baik ketika baris tertentu diklik atau ketika tidak ada baris yang diklik tetapi ada baris yang dipilih.
     *
     * - Parameter sender: Objek NSMenuItem yang memicu aksi ini.
     */
    @IBAction func ubahStatus(_ sender: NSMenuItem) {
        pilihubahStatus(sender)
    }

    /**
     Mengubah status siswa yang dipilih berdasarkan item menu yang dipilih.

     Fungsi ini menampilkan dialog konfirmasi untuk mengubah status siswa yang dipilih.
     Jika pengguna mengkonfirmasi, status siswa akan diperbarui di database dan tampilan tabel.
     Fungsi ini juga menangani logika khusus untuk status "Lulus", termasuk menghapus siswa dari kelas aktif
     dan menampilkan peringatan konfirmasi tambahan.

     - Parameter sender: Item menu yang memicu aksi ini. `representedObject` dari pengirim harus berupa `String`
        yang merepresentasikan status yang akan diubah.

     - Precondition: `tableView.selectedRowIndexes` harus berisi indeks baris yang valid.
     `viewModel.filteredSiswaData` harus berisi data siswa yang sesuai dengan indeks yang dipilih.
     */
    @IBAction func pilihubahStatus(_ sender: NSMenuItem) {
        guard let statusString = sender.representedObject as? String else {
            return
        }

        let tanggalSekarang = ReusableFunc.buatFormatTanggal(Date())!
        let selectedRows: IndexSet
        let namaSiswa: String

        var selectedSiswa: [ModelSiswa] = [] // Deklarasikan di scope yang bisa diakses
        if tableView.clickedRow >= 0, tableView.clickedRow < viewModel.filteredSiswaData.count {
            let clickedSiswa = viewModel.filteredSiswaData[tableView.clickedRow]

            if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                selectedSiswa = tableView.selectedRowIndexes.compactMap { row in
                    let originalSiswa = viewModel.filteredSiswaData[row]
                    return originalSiswa.copy() as? ModelSiswa
                }
                selectedRows = tableView.selectedRowIndexes
                namaSiswa = "\(tableView.selectedRowIndexes.count) siswa"
            } else {
                selectedSiswa.append(clickedSiswa.copy() as! ModelSiswa)
                selectedRows = IndexSet(integer: tableView.clickedRow)
                namaSiswa = clickedSiswa.nama
            }
        } else if tableView.clickedRow == -1 {
            selectedSiswa = tableView.selectedRowIndexes.compactMap { row in
                let originalSiswa = viewModel.filteredSiswaData[row]
                return originalSiswa.copy() as? ModelSiswa
            }
            selectedRows = tableView.selectedRowIndexes
            namaSiswa = "\(tableView.selectedRowIndexes.count) siswa"

        } else {
            selectedRows = tableView.selectedRowIndexes
            namaSiswa = "\(tableView.selectedRowIndexes.count) siswa"
        }

        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "rectangle.and.pencil.and.ellipsis", accessibilityDescription: .none)
        alert.messageText = "Konfirmasi Pengubahan Status"
        alert.informativeText = "Apakah Anda yakin mengubah status dari \(namaSiswa) menjadi〝\(statusString)〞?"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Batalkan")

        // Menampilkan peringatan dan menunggu respons
        let response = alert.runModal()

        guard response == .alertFirstButtonReturn,
              statusString != StatusSiswa.aktif.description
        else {
            let popover = NSPopover()
            // 2. Instantiate your popover content view controller
            guard let (naikKelas, leadingEdgeRect) = makeNaikKelasComponents(
                tableView: tableView,
                columnIndex: columnIndexOfKelasAktif,
                row: selectedRows.first!
            )
            else { return }

            naikKelas.onSimpanKelas = { [unowned self] _, tahunAjaran, semester in
                self.prosesSiswaNaik(
                    "",
                    selectedRowIndexes: selectedRows,
                    tahunAjaran: tahunAjaran,
                    semester: semester,
                    statusSiswa: .aktif
                )
                for siswa in selectedSiswa {
                    self.dbController.updateTglBerhenti(kunci: siswa.id, editTglBerhenti: "")
                    self.dbController.updateStatusSiswa(idSiswa: siswa.id, newStatus: .aktif)
                    siswa.status = .aktif
                    siswa.tanggalberhenti = ""
                    if let index = viewModel.filteredSiswaData.firstIndex(of: siswa) {
                        viewModel.updateSiswa(siswa, at: index)
                    }
                }

                let cols = IndexSet([self.columnIndexOfStatus, self.columnIndexOfKelasAktif, self.columnIndexOfTglBerhenti])
                self.tableView.reloadData(forRowIndexes: selectedRows, columnIndexes: cols)

                popover.performClose(nil) // Close the popover after saving
            }
            naikKelas.onClose = {
                popover.performClose(nil) // Close the popover if cancelled
            }

            // 3. Configure the popover
            popover.contentViewController = naikKelas
            popover.behavior = .semitransient

            // 4. Show the popover
            // Present the popover from the calculated rectangle in the table view's superview
            tableView.scrollColumnToVisible(columnIndexOfKelasAktif)
            popover.show(relativeTo: leadingEdgeRect, of: tableView.superview!, preferredEdge: .maxY)
            return
        }

        let showLulus = UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus")
        let showBerhenti = !isBerhentiHidden

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self,
                  let newStatus = StatusSiswa.from(description: statusString)
            else { return }

            // Kumpulkan semua context undo/redo
            let undoRedoContexts: [UndoNaikKelasContext] = await withTaskGroup(of: UndoNaikKelasContext?.self, returning: [UndoNaikKelasContext].self) { group in
                for rowIndex in selectedRows.reversed() {
                    group.addTask { [weak self] in
                        guard let self = self else { return nil }
                        let siswa = self.viewModel.filteredSiswaData[rowIndex]
                        let idSiswa = siswa.id

                        // Update model langsung
                        siswa.status = newStatus
                        siswa.tanggalberhenti = tanggalSekarang
                        siswa.tingkatKelasAktif = (newStatus == .lulus ? .lulus : siswa.tingkatKelasAktif)
                        dbController.updateTglBerhenti(kunci: idSiswa, editTglBerhenti: tanggalSekarang)
                        dbController.updateStatusSiswa(idSiswa: idSiswa, newStatus: newStatus)

                        return await self.dbController.naikkanSiswa(
                            idSiswa,
                            namaKelasBaru: "",
                            tingkatBaru: nil,
                            tahunAjaran: nil,
                            semester: nil,
                            tanggalNaik: tanggalSekarang,
                            statusEnrollment: newStatus
                        )
                    }
                }

                // kumpulkan non-nil hasilnya
                var results: [UndoNaikKelasContext] = []
                for await ctx in group {
                    if let ctx = ctx {
                        results.append(ctx)
                    }
                }
                return results
            }

            // Terakhir, update UI di MainActor
            await MainActor.run {
                let mgr = SiswaViewModel.siswaUndoManager
                if undoRedoContexts.isEmpty {
                    mgr.registerUndo(withTarget: self) { [weak self] _ in
                        guard let self = self else { return }
                        viewModel.undoEditSiswa(selectedSiswa)
                    }
                } else {
                    mgr.registerUndo(withTarget: self) { [weak self] _ in
                        guard let self = self else { return }
                        self.handleUndoNaikKelas(contexts: undoRedoContexts, siswa: selectedSiswa)
                    }
                }
                for rowIndex in selectedRows.reversed() {
                    // Jika siswa seharusnya disembunyikan
                    if (newStatus == .lulus && !showLulus) ||
                        (newStatus == .berhenti && !showBerhenti)
                    {
                        self.tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .slideUp)
                        self.viewModel.removeSiswa(at: rowIndex)
                    } else {
                        let cols = IndexSet([self.columnIndexOfStatus, self.columnIndexOfKelasAktif, self.columnIndexOfTglBerhenti])
                        self.tableView.reloadData(forRowIndexes: IndexSet([rowIndex]), columnIndexes: cols)
                    }
                }

                self.deleteAllRedoArray(self)
                self.updateUndoRedo(self)

                if newStatus == .aktif {
                    for a in selectedSiswa {
                        self.viewModel.kelasEvent.send(.aktifkanSiswa(a.id, kelas: a.tingkatKelasAktif.rawValue))
                    }
                } else {
                    for a in selectedSiswa {
                        self.viewModel.kelasEvent.send(.undoAktifkanSiswa(a.id, kelas: a.tingkatKelasAktif.rawValue))
                    }
                }
            }
        }
    }

    // MARK: - Pembaruan Kelas

    /// Mengembalikan instance NaikKelasVC dan rect jangkar untuk NSPopover.
    /// - Parameters:
    ///   - tableView: NSTableView tempat cell berada.
    ///   - columnIndex: Indeks kolom target.
    ///   - row: Indeks baris target.
    /// - Returns: Tuple (NaikKelasVC, NSRect) atau nil jika input tidak valid.
    private func makeNaikKelasComponents(
        tableView: NSTableView,
        columnIndex: Int, row: Int
    ) -> (viewController: NaikKelasVC, anchorRect: NSRect)? {
        // Pastikan kolom/baris valid dan superview tersedia
        guard columnIndex >= 0,
              row >= 0,
              let superview = tableView.superview
        else {
            return nil
        }

        // Instantiate NaikKelasVC dari storyboard
        let naikVC = NaikKelasVC(nibName: "NaikKelasVC", bundle: nil)

        // Hitung frame cell di coordinate superview
        let cellRect = tableView.frameOfCell(atColumn: columnIndex, row: row)
        let targetRect = tableView.convert(cellRect, to: superview)

        // Buat leading edge rect untuk anchor popover
        let anchorRect = NSRect(
            x: targetRect.minX,
            y: targetRect.minY,
            width: 14,
            height: targetRect.height
        )

        return (viewController: naikVC, anchorRect: anchorRect)
    }

    /**
     * Memperbarui kelas yang dipilih untuk siswa yang dipilih dalam tampilan tabel.
     *
     * Fungsi ini melakukan beberapa tindakan:
     * 1. Memastikan ada baris yang dipilih. Jika tidak ada, fungsi akan keluar.
     * 2. Menyimpan data siswa yang dipilih sebelum perubahan untuk keperluan undo.
     * 3. Mengiterasi setiap siswa yang dipilih:
     *    - Memeriksa apakah kelas siswa saat ini berbeda dengan kelas yang baru dipilih. Jika sama, iterasi dilanjutkan ke siswa berikutnya.
     *    - Memperbarui kelas siswa saat ini dengan kelas yang baru dipilih.
     *    - Memperbarui data siswa di view model dan database.
     *    - Menampilkan dialog konfirmasi untuk menghapus data siswa dari kelas sebelumnya.
     *    - Menangani opsi "Terapkan ke semua" dan "Batalkan semua" pada dialog konfirmasi.
     * 4. Setelah semua siswa diproses, fungsi memperbarui tampilan tabel untuk mencerminkan perubahan kelas.
     * 5. Mendaftarkan aksi undo untuk mengembalikan perubahan jika diperlukan.
     *
     * - Parameter kelasAktifString: String yang merepresentasikan kelas yang baru dipilih.
     */
    @objc func updateKelasDipilih(_ kelasAktifString: String, selectedRowIndexes: IndexSet) {
        // Ensure there's a selected row to present the popover from
        guard let selectedRow = selectedRowIndexes.first else { return }
        
        let popover = NSPopover()

        // 1. Get the target cell's frame
        // Make sure the column exists and is visible
        guard columnIndexOfKelasAktif != -1 else { return }

        // 2. Instantiate your popover content view controller
        guard let (naikKelas, leadingEdgeRect) = makeNaikKelasComponents(
            tableView: tableView,
            columnIndex: columnIndexOfKelasAktif,
            row: selectedRow
        )
        else { return }

        naikKelas.onSimpanKelas = { [unowned self] _, tahunAjaran, semester in
            self.prosesSiswaNaik(
                kelasAktifString,
                selectedRowIndexes: selectedRowIndexes,
                tahunAjaran: tahunAjaran,
                semester: semester
            )
            popover.performClose(nil) // Close the popover after saving
        }

        naikKelas.onClose = {
            popover.performClose(nil) // Close the popover if cancelled
        }

        // 3. Configure the popover
        popover.contentViewController = naikKelas
        popover.behavior = .semitransient

        // 4. Show the popover
        // Present the popover from the calculated rectangle in the table view's superview
        tableView.scrollColumnToVisible(columnIndexOfKelasAktif)
        popover.show(relativeTo: leadingEdgeRect, of: tableView.superview!, preferredEdge: .maxY)
    }

    // MARK: - Langkah 2: Perbaiki `prosesSiswaNaik` dengan TaskGroup (Anti Race Condition)

    private func prosesSiswaNaik(_ kelasAktifString: String, selectedRowIndexes: IndexSet, tahunAjaran: String, semester: String, statusSiswa: StatusSiswa = .naik) {
        guard !selectedRowIndexes.isEmpty else { print("return"); return }

        // Buat snapshot dari model asli untuk pemulihan UI
        let originalSiswaModels: [ModelSiswa] = selectedRowIndexes.compactMap {
            viewModel.filteredSiswaData[$0].copy() as? ModelSiswa
        }

        // Lakukan semua pekerjaan database di background
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            // Kembali ke MainActor dan siapkan kelas aktif terlebih dahulu.
            await MainActor.run {
                for data in originalSiswaModels {
                    let kelasSekarang = data.tingkatKelasAktif.rawValue
                    if statusSiswa != .aktif {
                        TableType.fromString(kelasSekarang) { type in
                            guard !(KelasViewModel.shared.isDataLoaded[type] ?? false) else {
                                self.viewModel.kelasEvent.send(.kelasBerubah(data.id, fromKelas: kelasSekarang))
                                return
                            }
                            Task {
                                await KelasViewModel.shared.loadKelasData(forTableType: type)
                                if let splitVC = AppDelegate.shared.mainWindow.contentViewController as? SplitVC,
                                   let contentContainerView = splitVC.contentContainerView?.viewController as? ContainerSplitView {
                                    #if DEBUG
                                        print("loadView + send event")
                                    #endif
                                    _ = contentContainerView.kelasVC.view
                                }
                            }
                        }
                    }
                }
            }

            // --- FIX RACE CONDITION DENGAN TASKGROUP ---
            // `await` di sini akan menunggu SEMUA tugas di dalam grup selesai.
            let undoRedoContexts: [UndoNaikKelasContext] = await withTaskGroup(
                of: UndoNaikKelasContext?.self,
                returning: [UndoNaikKelasContext].self
            ) { group in
                for siswa in originalSiswaModels {
                    group.addTask {
                        let tingkatKelas = !kelasAktifString.isEmpty
                            ? kelasAktifString.replacingOccurrences(of: "Kelas ", with: "")
                            : siswa.tingkatKelasAktif.rawValue.replacingOccurrences(of: "Kelas ", with: "")

                        let context = await self.dbController.naikkanSiswa(
                            siswa.id,
                            namaKelasBaru: "A",
                            tingkatBaru: tingkatKelas,
                            tahunAjaran: tahunAjaran,
                            semester: semester,
                            tanggalNaik: ReusableFunc.buatFormatTanggal(Date())!,
                            statusEnrollment: statusSiswa
                        )

                        return context
                    }
                }

                var contexts: [UndoNaikKelasContext] = []

                for await context in group {
                    if let ctx = context {
                        contexts.append(ctx)
                    }
                }

                return contexts
            }

            // Sekarang `undoRedoContexts` dijamin sudah terisi penuh.
            guard !undoRedoContexts.isEmpty else {
                await MainActor.run {
                    ReusableFunc.showAlert(title: "Error ketika membuat context untuk undo/redo.", message: "Perubahan mungkin tidak dapat diurungkan.")
                }
                return
            }

            // Kembali ke Main Thread untuk memperbarui UI dan mendaftarkan Undo
            await MainActor.run {
                // Perbarui ViewModel dengan data baru
                for context in undoRedoContexts {
                    if let row = self.viewModel.filteredSiswaData.firstIndex(where: { $0.id == context.siswaId }) {
                        let siswa = self.viewModel.filteredSiswaData[row]
                        if statusSiswa != .aktif {
                            siswa.tingkatKelasAktif = KelasAktif(rawValue: kelasAktifString) ?? .belumDitentukan
                        }
                        self.viewModel.updateSiswa(siswa, at: row)
                    }
                }
                if statusSiswa != .aktif {
                    self.refreshTableViewCells(for: selectedRowIndexes, newKelasAktifString: kelasAktifString)
                }

                // Daftarkan aksi UNDO yang bersih
                let mgr = SiswaViewModel.siswaUndoManager
                mgr.registerUndo(withTarget: self) { [weak self] _ in
                    guard let self = self else { return }
                    self.handleUndoNaikKelas(
                        contexts: undoRedoContexts,
                        siswa: originalSiswaModels,
                        aktifkanSiswa: statusSiswa == .aktif
                    )
                }

                self.deleteAllRedoArray(self)
                self.updateUndoRedo(self)
                
                for data in originalSiswaModels {
                    let kelasSekarang = data.tingkatKelasAktif.rawValue
                    if statusSiswa != .aktif {
                        self.viewModel.kelasEvent.send(.kelasBerubah(data.id, fromKelas: kelasSekarang))
                    } else {
                        self.viewModel.kelasEvent.send(.aktifkanSiswa(data.id, kelas: kelasSekarang))
                    }
                }
                
            }
        }
    }

    // MARK: - Langkah 3: Buat Handler Terpisah untuk Undo dan Redo

    /// Menangani proses UNDO kenaikan kelas pada data siswa,
    /// mengembalikan state database dan UI sesuai konteks yang diberikan.
    ///
    /// Langkah-langkah yang dijalankan:
    /// 1. Memanggil `undoNaikKelas` pada database controller untuk rollback data.
    /// 2. Memperbarui model siswa pada ViewModel sesuai daftar `siswa` lama.
    /// 3. Mendaftarkan aksi REDO pada `UndoManager` untuk memungkinkan redo kenaikan kelas.
    ///
    /// - Parameters:
    ///   - contexts: Array ``UndoNaikKelasContext`` yang berisi detail operasi undo untuk tiap siswa.
    ///   - siswa: Array ``ModelSiswa`` sebelum kenaikan kelas (state lama) untuk referensi pengembalian UI.
    func handleUndoNaikKelas(contexts: [UndoNaikKelasContext], siswa: [ModelSiswa], aktifkanSiswa: Bool = false) {
        delegate?.didUpdateTable(.siswa)
        #if DEBUG
            print("--- 🔄 Melakukan UNDO Naik Kelas ---")
        #endif
        // 1. Kembalikan state database
        dbController.undoNaikKelas(using: contexts)
        #if DEBUG
            print("🔧 Database dikembalikan dengan \(contexts.count) context")
        #endif

        // Data yang sedang ditampilkan.
        var updatedModels = [ModelSiswa]()
        if currentTableViewMode == .plain {
            for data in viewModel.filteredSiswaData {
                for oldModels in siswa where data.id == oldModels.id {
                    updatedModels.append(data)
                    #if DEBUG
                        print("data.tingkatKelasAktif", data.tingkatKelasAktif)
                        print("data.status", data.status.description)
                    #endif
                }
            }
        } else {
            for group in viewModel.groupedSiswa {
                for siswaLama in group {
                    for oldModel in siswa where siswaLama.id == oldModel.id {
                        updatedModels.append(siswaLama)
                        #if DEBUG
                            print("siswa.tingkatKelasAktif", siswaLama.tingkatKelasAktif)
                            print("siswa.status", siswaLama.status.description)
                        #endif
                    }
                }
            }
        }

        // 2. Kembalikan state UI (ViewModel)
        viewModel.undoEditSiswa(siswa, registerUndo: false)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            guard let self = self else { return }
            // 3. SEGERA daftarkan aksi REDO
            self.handleRedoNaikKelas(contexts: contexts, siswa: updatedModels, oldData: siswa, aktifkanSiswa: aktifkanSiswa)
        }

        for data in siswa {
            if aktifkanSiswa {
                viewModel.kelasEvent.send(.undoAktifkanSiswa(data.id, kelas: data.tingkatKelasAktif.rawValue))
            } else {
                viewModel.kelasEvent.send(.undoUbahKelas(data.id, toKelas: data.tingkatKelasAktif.rawValue, status: data.status))
            }
        }
    }

    /// Menangani proses REDO kenaikan kelas pada data siswa,
    /// menerapkan kembali perubahan pada database dan memperbarui UI.
    ///
    /// Langkah-langkah:
    /// 1. Jalankan Task detached dengan TaskGroup untuk paralel semua operasi DB.
    /// 2. Lakukan kenaikan kelas per context menggunakan
    /// ``DatabaseController/nainaikkanSiswa(_:namaKelasBaru:tingkatBaru:tahunAjaran:semester:tanggalNaik:statusEnrollment:)
    /// 3. Kumpulkan dan kembalikan daftar ModelSiswa yang diupdate.
    /// 4. Jalankan update UI di MainActor dengan undoEditSiswa jika diperlukan.
    /// 5. Daftarkan aksi UNDO untuk kembali ke state sebelumnya.
    ///
    /// - Parameters:
    ///   - contexts: Array ``UndoNaikKelasContext`` yang berisi detail redo untuk tiap siswa.
    ///   - siswa: Array ``ModelSiswa`` hasil state sebelum redo, untuk lookup dan update.
    ///   - oldData: Array ``ModelSiswa`` state lama sebelum undo, digunakan untuk mendaftar UNDO.
    func handleRedoNaikKelas(contexts: [UndoNaikKelasContext], siswa: [ModelSiswa], oldData: [ModelSiswa], aktifkanSiswa: Bool = false) {
        delegate?.didUpdateTable(.siswa)
        #if DEBUG
            print("--- 🔁 Melakukan REDO Naik Kelas ---")
        #endif
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            // Gunakan TaskGroup untuk redo semua perubahan DB
            let updatedModels: [ModelSiswa] = await withTaskGroup(of: ModelSiswa?.self) { group -> [ModelSiswa] in
                for context in contexts {
                    group.addTask {
                        guard let row = siswa.firstIndex(where: { $0.id == context.siswaId }) else {
                            #if DEBUG
                                print("⚠️ ID \(context.siswaId) ga ketemu, skip.")
                            #endif
                            return nil
                        }
                        let s = siswa[row]
                        let tingkat = s.tingkatKelasAktif.rawValue.replacingOccurrences(of: "Kelas ", with: "")
                        let kelasAktifString = s.tingkatKelasAktif.rawValue
                        #if DEBUG
                            print("⏩ REDO: \(s.nama) [id: \(s.id)] → \(tingkat), [status: \(s.status.description)")
                        #endif
                        await self.dbController.naikkanSiswa(
                            context.siswaId,
                            namaKelasBaru: "A",
                            tingkatBaru: tingkat,
                            tahunAjaran: context.tahunAjaran,
                            semester: context.semester,
                            tanggalNaik: context.newEntryTanggal,
                            statusEnrollment: s.status
                        )
                        s.tingkatKelasAktif = KelasAktif(rawValue: kelasAktifString) ?? .belumDitentukan
                        return s
                    }
                }

                // 2. Kumpulkan hasilnya
                var results = [ModelSiswa]()
                for await maybeSiswa in group {
                    if let s = maybeSiswa {
                        results.append(s)
                    }
                }

                // 3. HARUS return array nya
                return results
            }

            await MainActor.run { [unowned self] in
                self.viewModel.undoEditSiswa(updatedModels, registerUndo: false)
                for data in oldData {
                    if aktifkanSiswa {
                        self.viewModel.kelasEvent.send(.undoAktifkanSiswa(data.id, kelas: data.tingkatKelasAktif.rawValue))
                    } else {
                        self.viewModel.kelasEvent.send(.kelasBerubah(data.id, fromKelas: data.tingkatKelasAktif.rawValue))
                    }
                }
            }
        }
        let mgr = SiswaViewModel.siswaUndoManager
        mgr.registerUndo(withTarget: self) { [weak self] _ in
            guard let self = self else { return }
            self.handleUndoNaikKelas(contexts: contexts, siswa: oldData, aktifkanSiswa: aktifkanSiswa)
        }
    }
}
