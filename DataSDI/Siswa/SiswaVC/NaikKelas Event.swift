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
    case nonaktifkanSiswa(_ id: Int64, kelas: String)
}

extension SiswaViewController {
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
    @IBAction func ubahStatus(_ sender: NSMenuItem) {
        // 1. Dapatkan status baru dari menu item
        guard let statusString = sender.representedObject as? String,
              let newStatus = StatusSiswa.from(description: statusString)
        else {
            print("Error: Status tidak valid atau tidak ditemukan.")
            return
        }

        // 2. Dapatkan data siswa yang relevan dari table view
        guard let selection = getSelectedSiswaAndRows() else { return }

        // 3. Arahkan ke handler yang sesuai berdasarkan status
        if newStatus == .aktif {
            // Menampilkan popover untuk proses aktivasi/kenaikan kelas
            showAktivasiPopover(at: selection.rows)
        } else {
            // Menjalankan proses perubahan status di background
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                await processStatusChangeInBackground(
                    for: selection.siswa,
                    at: selection.rows,
                    to: newStatus
                )
            }
        }
    }

    // MARK: - Fungsi Pembantu (Hasil Refactor)

    /**
     Mengambil siswa dan indeks baris yang dipilih dari table view.
     Menangani logika kompleks dari baris yang diklik kanan vs. baris yang sudah dipilih.
     - Returns: Sebuah tuple (siswa: [ModelSiswa], rows: IndexSet)? atau nil jika tidak ada yang dipilih.
     */
    private func getSelectedSiswaAndRows() -> (siswa: [ModelSiswa], rows: IndexSet)? {
        let selectedRows = ReusableFunc.resolveRowsToProcess(selectedRows: tableView.selectedRowIndexes, clickedRow: tableView.clickedRow)

        // Jika tidak ada baris yang dipilih sama sekali, kembalikan nil
        guard !selectedRows.isEmpty else { return nil }

        // Ambil model siswa berdasarkan indeks baris yang valid
        let originalSiswa = viewModel.siswa(in: selectedRows)
        let selectedSiswa = originalSiswa.compactMap { siswa in
            siswa.copy() as? ModelSiswa
        }

        return (selectedSiswa, selectedRows)
    }

    /**
     Memproses perubahan status siswa (non-aktif) di background thread untuk menjaga UI tetap responsif.
     */
    private func processStatusChangeInBackground(for siswa: [ModelSiswa], at rows: IndexSet, to newStatus: StatusSiswa) async {
        await viewModel.updateStatus(siswa: siswa, to: newStatus)

        // Kembali ke MainActor untuk memperbarui UI dan mendaftarkan Undo
        await MainActor.run { [weak self] in
            guard let self else { return }
            // Update UI
            for rowIndex in rows.reversed() {
                // Jika siswa seharusnya disembunyikan setelah perubahan status
                if (newStatus == .lulus && !tampilkanSiswaLulus) || (newStatus == .berhenti && isBerhentiHidden) {
                    viewModel.removeSiswa(at: rowIndex)
                    UpdateData.applyUpdates([.remove(index: rowIndex)], tableView: tableView, deselectAll: false)
                } else {
                    let cols = IndexSet([columnIndexOfStatus, columnIndexOfTglBerhenti])
                    tableView.reloadData(forRowIndexes: IndexSet(integer: rowIndex), columnIndexes: cols)
                }
            }
            deleteAllRedoArray(self)
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
        guard let selectedRow = getFirstVisibleRow(selectedRowIndexes) else { return }

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
            prosesSiswaNaik(
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
        guard !selectedRowIndexes.isEmpty else { return }

        // Buat snapshot dari model asli untuk pemulihan UI
        let originalSiswaModels: [ModelSiswa] = viewModel.siswa(in: selectedRowIndexes)

        // Lakukan semua pekerjaan database di background
        var updates = [UpdateData]()
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            // Kembali ke MainActor dan siapkan kelas aktif terlebih dahulu.
            await prepareKelasVC(originalSiswaModels, statusSiswa: statusSiswa)

            let undoRedoContexts = await viewModel.naikkanSiswaBatch(
                siswa: originalSiswaModels,
                ke: kelasAktifString,
                tahunAjaran: tahunAjaran,
                semester: semester,
                status: statusSiswa
            )

            if statusSiswa != .aktif {
                await MainActor.run { [comparator, viewModel] in
                    updates = viewModel.performBatchUpdates {
                        var updates = [UpdateData]()
                        for siswa in originalSiswaModels {
                            if let update = viewModel.relocateSiswa(siswa, comparator: comparator) {
                                updates.append(update)
                            }
                        }
                        return updates
                    }
                }
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
                updates.isEmpty
                    ? self.refreshTableViewCells(for: selectedRowIndexes)
                    : UpdateData.applyUpdates(updates, tableView: self.tableView, deselectAll: true)

                self.deleteAllRedoArray(self)
            }
        }
    }

    @MainActor
    private func prepareKelasVC(_ siswa: [ModelSiswa], statusSiswa: StatusSiswa) async {
        for data in siswa {
            let kelasSekarang = data.tingkatKelasAktif.rawValue

            guard statusSiswa != .aktif,
                  let type = await TableType.fromString(kelasSekarang),
                  !(KelasViewModel.shared.isDataLoaded[type] ?? false)
            else { return }

            await KelasViewModel.shared.loadKelasData(forTableType: type)

            if let splitVC = AppDelegate.shared.mainWindow.contentViewController as? SplitVC,
               let contentContainerView = splitVC.contentContainerView?.viewController as? ContainerSplitView
            {
                _ = contentContainerView.kelasVC.view
                viewModel.kelasEvent.send(.kelasBerubah(data.id, fromKelas: kelasSekarang))
            }
        }
    }

    // MARK: - POPOVER

    private func getFirstVisibleRow(_ selectedRowIndexes: IndexSet,
                                    toolbarHeight: CGFloat = 70,
                                    toleranceRows: CGFloat = 0.5) -> Int?
    {
        guard !selectedRowIndexes.isEmpty, selectedRowIndexes.count > 1,
              var vr = scrollView?.contentView.bounds
        else {
            if let firstRow = selectedRowIndexes.first {
                tableView.scrollRowToVisible(firstRow)
                return firstRow
            }
            return nil
        }

        // Tambahkan toleransi dalam pixel
        let tolerancePx = toleranceRows * tableView.rowHeight

        // Potong offset toolbar + toleransi
        let totalSkipPx = toolbarHeight + tolerancePx
        let rowsToSkip = Int(floor(totalSkipPx / tableView.rowHeight))

        if rowsToSkip > 0 {
            if tableView.isFlipped {
                let deltaY = CGFloat(rowsToSkip) * tableView.rowHeight
                let newMinY = min(vr.minY + deltaY, vr.maxY)
                vr = NSRect(x: vr.minX, y: newMinY, width: vr.width,
                            height: max(0, vr.maxY - newMinY))
            } else {
                vr.size.height = max(0, vr.height - CGFloat(rowsToSkip) * tableView.rowHeight)
            }
        }

        // Hitung range baris visible setelah penyesuaian
        let nsr = tableView.rows(in: vr)
        guard nsr.location != NSNotFound, nsr.length > 0 else { return nil }

        let start = nsr.location
        let end = min(nsr.location + nsr.length, tableView.numberOfRows)
        let visibleIndexes = IndexSet(integersIn: start ..< end)

        // Interseksi dengan yang terpilih
        let visibleSelected = selectedRowIndexes.intersection(visibleIndexes)

        // Kalau nggak ada yang kelihatan (bahkan setelah toleransi), baru scroll
        guard let visibleRow = visibleSelected.first else {
            if let firstSel = selectedRowIndexes.first {
                tableView.scrollRowToVisible(firstSel)
                return firstSel
            }
            return nil
        }
        tableView.scrollRowToVisible(visibleRow)
        return visibleRow
    }

    /**
     Menampilkan NSPopover untuk proses aktivasi siswa atau kenaikan kelas.
     */
    private func showAktivasiPopover(at rows: IndexSet) {
        guard let visibleRow = getFirstVisibleRow(rows),
              let (naikKelasVC, anchorRect) = makeNaikKelasComponents(
                  tableView: tableView,
                  columnIndex: columnIndexOfKelasAktif,
                  row: visibleRow
              )
        else { return }

        let popover = NSPopover()
        popover.contentViewController = naikKelasVC
        popover.behavior = .semitransient

        naikKelasVC.onSimpanKelas = { [weak self, weak popover] _, tahunAjaran, semester in
            guard let self else { return }

            // Memanggil logika proses inti
            prosesSiswaNaik(
                "",
                selectedRowIndexes: rows,
                tahunAjaran: tahunAjaran,
                semester: semester,
                statusSiswa: .aktif
            )

            popover?.performClose(nil)
        }

        naikKelasVC.onClose = { [weak popover] in
            popover?.performClose(nil)
        }

        tableView.scrollColumnToVisible(columnIndexOfKelasAktif)
        popover.show(relativeTo: anchorRect, of: tableView.superview!, preferredEdge: .maxY)
    }
}
