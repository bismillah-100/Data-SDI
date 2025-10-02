//
//  UpdateData.swift
//  Data SDI
//
//  Created by MacBook on 20/07/25.
//

import Foundation

private let suppressionKey = "hapusDiSiswaAlert"

extension SiswaViewController {
    // MARK: - ADD DATA

    /**
     Menangani aksi penambahan siswa baru.

     Fungsi ini dipanggil ketika tombol "Tambah Siswa" ditekan. Fungsi ini akan:
     1. Mengosongkan array `rowDipilih`.
     2. Membuat dan menampilkan popover yang berisi `AddDataViewController`.
     3. Mengatur `sourceViewController` pada `AddDataViewController` menjadi `.siswaViewController`.
     4. Menampilkan popover relatif terhadap tombol yang ditekan.
     5. Menonaktifkan fitur drag pada `AddDataViewController`.
     6. Menambahkan indeks baris yang dipilih ke array `rowDipilih` jika ada baris yang dipilih.
     7. Menghapus semua pilihan baris pada `tableView`.
     8. Mereset menu items.

     - Parameter sender: Objek yang memicu aksi ini (biasanya tombol).
     */
    @IBAction func addSiswa(_ sender: Any?) {
        rowDipilih.removeAll()
        let popover = AppDelegate.shared.popoverAddSiswa

        if let button = sender as? NSButton {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .maxX)
        }

        if let vc = popover?.contentViewController as? AddDataViewController {
            vc.sourceViewController = .siswaViewController
        }

        guard tableView.selectedRowIndexes.count > 0 else { return }
        rowDipilih.append(tableView.selectedRowIndexes)
        tableView.deselectAll(sender)
        ReusableFunc.resetMenuItems()
    }

    /**
         Menangani aksi untuk menambahkan siswa melalui jendela baru.

         Fungsi ini mencoba untuk memicu aksi tombol "add" yang ada di toolbar jendela utama. Jika tombol "add" tidak ditemukan di toolbar, fungsi ini akan membuka jendela baru untuk menambahkan data siswa.

         Jika jendela dengan identifier "addSiswaWindow" sudah ada, jendela tersebut akan ditampilkan dan dijadikan key window. Jika tidak, jendela baru akan dibuat dengan `AddDataViewController` sebagai kontennya. Jendela baru ini memiliki beberapa konfigurasi khusus seperti tombol zoom dan minimize yang dinonaktifkan, titlebar yang transparan, dan animasi fade-in saat ditampilkan.

         - Parameter:
            - sender: Objek yang memicu aksi ini. Bisa berupa `Any?`.
     */
    @IBAction func addSiswaNewWindow(_ sender: Any?) {
        if let window = NSApp.mainWindow?.windowController as? WindowController,
           let addItem = window.addDataToolbar, addItem.isVisible
        {
            if addButton == nil {
                addButton = addItem.view as? NSButton
            }
            addButton.performClick(sender)
        } else {
            AppDelegate.shared.showInputSiswaBaru()
        }
    }

    /**
         Menangani penempelan data dari clipboard ke dalam tampilan tabel siswa.

         Fungsi ini mengambil data dari clipboard, menguraikannya menjadi objek `ModelSiswa`,
         dan menambahkannya ke database dan tampilan tabel. Fungsi ini mendukung format
         yang dipisahkan oleh tab dan dipisahkan oleh koma. Fungsi ini juga menangani
         pelaporan kesalahan untuk format data yang tidak valid dan menyediakan
         fungsionalitas undo untuk operasi tempel.

         - Parameter:
            - sender: Objek yang memicu aksi.
     */
    @IBAction func pasteClicked(_ sender: Any) {
        guard let raw = NSPasteboard.general.string(forType: .string) else { return }
        let visibleColumns = tableView.tableColumns.filter { !$0.isHidden }

        let columnOrder: [SiswaColumn] = visibleColumns
            .compactMap { SiswaColumn(rawValue: $0.identifier.rawValue) }

        let (parsedSiswas, errors) = viewModel.parseClipboard(raw, columnOrder: columnOrder)
        guard errors.isEmpty else {
            showPasteErrors(errors)
            return
        }

        guard let sortDescriptor = tableView.sortDescriptors.first,
              let comparator = ModelSiswa.comparator(from: sortDescriptor)
        else { return }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            let insertedDatabaseSiswa = viewModel.insertToDatabase(parsedSiswas)
            insertMultipleSiswas(insertedDatabaseSiswa, comparator: comparator, postNotification: false)
            pastedSiswasArray.append(insertedDatabaseSiswa)

            deleteAllRedoArray(sender)
            DispatchQueue.main.async {
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { target in
                    target.undoPaste(sender)
                }
            }
        }
    }

    private func showPasteErrors(_ errors: [String]) {
        let maxErrors = 3
        let displayed = errors.prefix(maxErrors)
        var info = displayed.joined(separator: "\n")
        if errors.count > maxErrors {
            info += "\n...dan \(errors.count - maxErrors) lainnya"
        }
        ReusableFunc.showAlert(title: "Format input tidak didukung", message: info)
    }

    /// Action dari menu item paste di Menu Bar yang menjalankan
    /// ``paste(_:)``.
    /// - Parameter sender: Objek yang memicu.
    @IBAction func paste(_: Any) {
        pasteClicked(self)
    }

    // MARK: - TAMBAHKAN DATA BARU

    /**
     * Fungsi ini membatalkan penambahan siswa baru.
     *
     * Fungsi ini menghapus siswa terakhir dari array `urungsiswaBaruArray`, memperbarui tampilan tabel,
     * dan mendaftarkan tindakan undo dengan `SiswaViewModel.siswaUndoManager`.
     * Fungsi ini juga memperbarui `SingletonData` dan mengirimkan pemberitahuan (`NotificationCenter`)
     * tentang penghapusan siswa.
     *
     * - Parameter sender: Objek yang memicu tindakan ini (misalnya, tombol undo).
     */
    func urungSiswaBaru(_ sender: Any) {
        delegate?.didUpdateTable(.siswa)
        let siswa = urungsiswaBaruArray.removeLast()

        let removedIndexes = removeSiswas([siswa]) {
            SingletonData.undoAddSiswaArray.append([siswa])
            SingletonData.deletedStudentIDs.append(siswa.id)
            self.ulangsiswaBaruArray.append(siswa)
        }

        // Catat tindakan undo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.ulangSiswaBaru(sender)
        }
        SiswaViewModel.siswaUndoManager.setActionName("Undo Add New Data")

        selectAfterRemoval(removedIndexes)
        scrollRow(removedIndexes)

        // Entah kenapa harus dibungkus dengan task.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            NotifSiswaDihapus.sendNotif(siswa)
        }
    }

    /**
     * Fungsi ini mengembalikan data siswa yang baru ditambahkan ke tampilan tabel dan memperbarui antrian undo/redo.
     *
     * - Parameter sender: Objek yang memicu aksi ini.
     *
     * Fungsi ini melakukan langkah-langkah berikut:
     * 1. Mengambil descriptor pengurutan saat ini. Jika tidak ada, fungsi akan keluar.
     * 2. Menghapus siswa terakhir dari array `ulangsiswaBaruArray` dan menambahkannya ke array `urungsiswaBaruArray`.
     * 3. Membatalkan pilihan semua baris di tampilan tabel.
     * 4. Memulai pembaruan tampilan tabel.
     * 5. Jika tampilan tabel dalam mode plain:
     *    - Menemukan indeks yang sesuai untuk memasukkan siswa kembali sesuai dengan descriptor pengurutan saat ini.
     *    - Memasukkan siswa ke dalam array `viewModel.filteredSiswaData` pada indeks yang ditemukan.
     *    - Memperbarui tampilan tabel dengan memasukkan baris baru pada indeks yang sesuai.
     *    - Menggulir tampilan tabel ke baris yang baru dimasukkan.
     *    - Memilih baris yang baru dimasukkan.
     * 6. Jika tampilan tabel dalam mode grup:
     *    - Mendapatkan indeks grup untuk kelas siswa saat ini. Jika tidak ada, fungsi akan keluar.
     *    - Menghitung ulang indeks penyisipan berdasarkan grup yang baru.
     *    - Memasukkan siswa kembali ke dalam array `viewModel.groupedSiswa` pada grup dan indeks yang tepat.
     *    - Memperbarui tampilan tabel dengan menyisipkan baris baru pada indeks yang sesuai.
     *    - Menggulir tampilan tabel ke baris yang baru dimasukkan.
     *    - Memilih baris yang baru dimasukkan.
     * 7. Mengakhiri pembaruan tampilan tabel.
     * 8. Mencatat tindakan redo ke dalam `SiswaViewModel.siswaUndoManager`.
     * 9. Menetapkan nama aksi undo menjadi "Redo Add New Data".
     * 10. Menghapus siswa terakhir dari array `SingletonData.undoAddSiswaArray`.
     * 11. Menghapus ID siswa dari array `SingletonData.deletedStudentIDs`.
     * 12. Memposting notifikasi `undoSiswaDihapus` untuk memberitahu komponen lain tentang tindakan undo.
     * 13. Memperbarui status tombol undo/redo.
     */
    func ulangSiswaBaru(_ sender: Any) {
        delegate?.didUpdateTable(.siswa)
        guard let sortDescriptor = tableView.sortDescriptors.first,
              let comparator = ModelSiswa.comparator(from: sortDescriptor)
        else { return }

        let siswa = ulangsiswaBaruArray.removeLast()
        urungsiswaBaruArray.append(siswa)

        insertMultipleSiswas(
            [siswa],
            comparator: comparator,
            postNotification: true
        )

        let mgr = SiswaViewModel.siswaUndoManager
        mgr.registerUndo(withTarget: self) { $0.urungSiswaBaru(sender) }
        mgr.setActionName("Redo Add New Data")

        SingletonData.undoAddSiswaArray.removeLast()
    }

    // MARK: - EDIT DATA

    /**
      Menangani aksi penyuntingan data siswa.

      Fungsi ini dipanggil ketika tombol edit ditekan. Fungsi ini menangani logika pemilihan baris pada tabel,
      baik dalam mode tampilan `.grouped` maupun mode lainnya, dan mempersiapkan tampilan `EditData`
      untuk menampilkan dan mengedit data siswa yang dipilih.

      - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol edit).

      - Catatan: Fungsi ini mempertimbangkan beberapa skenario pemilihan baris, termasuk pemilihan tunggal,
         pemilihan ganda, dan tidak ada baris yang dipilih. Fungsi ini juga membedakan antara mode tampilan
         `.grouped` dan mode lainnya untuk menentukan cara mengambil data siswa yang sesuai.

      - Precondition: `tableView` harus sudah diinisialisasi dan memiliki data yang valid.
         `viewModel` harus sudah diinisialisasi dengan data siswa yang sesuai.

      - Postcondition: Tampilan `EditData` akan ditampilkan sebagai sheet dengan data siswa yang dipilih,
         dan menu item akan direset.
     */
    @IBAction func edit(_: Any) {
        rowDipilih.removeAll()
        selectedSiswaList.removeAll()

        let clickedRow = tableView.clickedRow
        let selectedRows = ReusableFunc.resolveRowsToProcess(
            selectedRows: tableView.selectedRowIndexes,
            clickedRow: clickedRow
        )

        // Ambil semua siswa dari row yang sudah di-resolve
        let siswaList = viewModel.getSiswas(for: selectedRows)
        guard !siswaList.isEmpty else { return }

        selectedSiswaList = siswaList

        let editView = EditData(nibName: "EditData", bundle: nil)
        editView.selectedSiswaList = siswaList
        editView.preferredContentSize = NSSize(width: 428, height: 500)

        // Pastikan tableView menyorot baris yang dipilih
        tableView.selectRowIndexes(selectedRows, byExtendingSelection: false)

        presentAsSheet(editView)
        ReusableFunc.resetMenuItems()
    }

    /**
     Menampilkan tampilan untuk mencari dan mengganti data siswa.

     Metode ini menangani logika pemilihan baris pada `tableView`, baik dalam mode tampilan berkelompok (`grouped`) maupun datar (`plain`),
     untuk menentukan data siswa mana yang akan diedit. Kemudian, data yang dipilih ditampilkan dalam tampilan `CariDanGanti`.

     - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol atau item menu).

     - Catatan:
        - Jika tidak ada baris yang dipilih atau diklik, tampilan `CariDanGanti` tetap ditampilkan, memungkinkan pengguna untuk mencari dan mengganti data secara manual.
        - Metode ini juga menangani pendaftaran `undo` untuk mengembalikan perubahan yang dilakukan pada data siswa.
        - Setelah pembaruan selesai, sebuah jendela progress akan ditampilkan untuk memberi tahu pengguna bahwa pembaruan telah berhasil disimpan.
     */
    @IBAction func findAndReplace(_: Any) {
        // Metode tidak ada row yang diklik dan juga dipilih
        let editVC = CariDanGanti.instantiate()

        let selectedRows = tableView.selectedRowIndexes
        let clickedRow = tableView.clickedRow

        // Pakai helper untuk menentukan IndexSet final
        let dataToEdit = ReusableFunc.resolveRowsToProcess(selectedRows: selectedRows, clickedRow: clickedRow)
        tableView.selectRowIndexes(dataToEdit, byExtendingSelection: false)
        let processDataToEdit = viewModel.getSiswas(for: dataToEdit)

        for siswa in processDataToEdit {
            editVC.objectData.append(siswa.toDictionary())
        }
        for column in tableView.tableColumns {
            guard column != statusColumn,
                  column != tahunDaftarColumn,
                  column != tglLulusColumn,
                  column != kelaminColumn
            else { continue }
            editVC.columns.append(column.identifier.rawValue)
        }

        editVC.onUpdate = { [weak self] updatedRows, selectedColumn in
            guard let self else { return }

            let selectedSiswaRow = viewModel.getSiswas(for: tableView.selectedRowIndexes)
            let snapshotSiswa = selectedSiswaRow.map {
                $0.copy() as! ModelSiswa
            }
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
                self?.viewModel.undoEditSiswa(snapshotSiswa)
            }

            // Lakukan iterasi terhadap setiap row yang di-update
            for updatedData in updatedRows {
                let updatedSiswa = ModelSiswa.fromDictionary(updatedData)
                guard let idValue = updatedData["id"] as? Int64,
                      let oldData = selectedSiswaRow.first(where: { $0.id == updatedSiswa.id })
                else {
                    continue
                }
                viewModel.updateDataSiswa(idValue, dataLama: oldData, baru: updatedSiswa)

                guard let index = viewModel.updateSiswa(updatedSiswa) else { continue }

                tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: selectedColumn))))
            }

            deleteAllRedoArray(self)
            ReusableFunc.showProgressWindow(3, pesan: "Pembaruan berhasil disimpan", image: NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: .none) ?? ReusableFunc.menuOnStateImage)
        }
        editVC.onClose = {
            self.updateUndoRedo(nil)
        }
        ReusableFunc.resetMenuItems()
        presentAsSheet(editVC)
    }

    /// Fungsi untuk menjalankan undo.
    @objc func mulaiRedo(_: Any) {
        if SiswaViewModel.siswaUndoManager.canRedo {
            SiswaViewModel.siswaUndoManager.redo()
        }
    }

    /**
         Melakukan operasi undo pada `SiswaViewModel.siswaUndoManager`.

         Fungsi ini memeriksa apakah operasi undo dapat dilakukan. Jika ya, fungsi ini akan melakukan undo,
         dengan penanganan khusus jika ada string pencarian dan mode tampilan tabel adalah `.grouped`.
         Jika ada string pencarian, fungsi ini akan mengurutkan data pencarian sebelum melakukan undo.

         - Parameter:
             - sender: Objek yang memicu aksi undo (misalnya, tombol undo).
     */
    @objc func performUndo(_: Any) {
        if SiswaViewModel.siswaUndoManager.canUndo {
            if !stringPencarian.isEmpty {
                if let sortDescriptor = tableView.sortDescriptors.first {
                    sortData(with: sortDescriptor, selectedIds: updateSelectedIDs())
                    SiswaViewModel.siswaUndoManager.undo()
                }
            } else {
                SiswaViewModel.siswaUndoManager.undo()
            }
        }
    }

    /// Fungsi untuk memperbarui action dan target menu item undo/redo di Menu Bar.
    /// yang sesuai dengan class ``SiswaViewController``.
    /// - Parameter sender: Objek pemicu apapun.
    @objc func updateUndoRedo(_: Any?) {
        UndoRedoManager.shared.updateUndoRedoState(
            for: self,
            undoManager: SiswaViewModel.siswaUndoManager,
            undoSelector: #selector(performUndo(_:)),
            redoSelector: #selector(mulaiRedo(_:)),
            debugName: "SiswaViewController"
        )
        UndoRedoManager.shared.startObserving()
    }

    private func makeDeleteAlert(selectedRows: IndexSet, clickedRow: Int) -> NSAlert {
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: nil)
        alert.addButton(withTitle: "Hapus")
        alert.addButton(withTitle: "Batalkan")
        alert.showsSuppressionButton = true

        if isMultiSelection(selectedRows: selectedRows, clickedRow: clickedRow) {
            let names = getSelectedNames(from: selectedRows)
            let limitedNames = Array(names.prefix(10))
            let additionalCount = names.count - limitedNames.count
            let additionalText = additionalCount > 0 ? "\n...dan \(additionalCount) lainnya" : ""
            alert.messageText = "Konfirmasi Penghapusan Data"
            alert.informativeText = "Apakah Anda yakin ingin menghapus data \(limitedNames.joined(separator: ", "))\(additionalText)?\nData di setiap kelas juga akan dihapus."
        } else {
            let name = getSelectedNames(from: [clickedRow])
            alert.messageText = "Konfirmasi Penghapusan data \(name)"
            alert.informativeText = "Apakah Anda yakin ingin menghapus data \(name)? Data yang ada di setiap Kelas juga akan dihapus."
        }
        return alert
    }

    private func getSelectedNames(from rows: IndexSet) -> [String] {
        viewModel.getSiswas(for: rows).map(\.nama)
    }

    private func isMultiSelection(selectedRows: IndexSet, clickedRow: Int) -> Bool {
        (selectedRows.contains(clickedRow) && clickedRow != -1) || (selectedRows.count >= 1 && clickedRow == -1)
    }

    private func executeDelete(sender: Any, selectedRows: IndexSet, clickedRow: Int) {
        let rows = ReusableFunc.resolveRowsToProcess(selectedRows: selectedRows, clickedRow: clickedRow)
        hapus(sender, selectedRows: rows)
    }

    /**
     Menampilkan dialog konfirmasi penghapusan data siswa.

     Fungsi ini menampilkan peringatan (alert) untuk mengonfirmasi apakah pengguna yakin ingin menghapus data siswa yang dipilih.
     Peringatan ini mencakup opsi untuk menekan (suppress) peringatan di masa mendatang.

     - Parameter sender: Objek `NSMenuItem` yang memicu aksi ini.

     Fungsi ini menangani beberapa skenario:
     1. **Mode Tampilan Datar (Plain):**
        - Jika ada baris yang diklik dan dipilih, fungsi `hapus(sender)` dipanggil untuk menghapus semua baris yang dipilih.
        - Jika ada baris yang diklik tetapi tidak dipilih, fungsi `deleteDataClicked(clickedRow)` dipanggil untuk menghapus hanya baris yang diklik.
        - Jika tidak ada baris yang diklik, fungsi `hapus(sender)` dipanggil untuk menghapus semua baris yang dipilih.

     2. **Mode Tampilan Berkelompok (Grouped):**
        - Jika baris yang diklik termasuk dalam baris yang dipilih dan jumlah baris yang dipilih lebih dari 1, fungsi `hapus(sender)` dipanggil.
        - Jika ada baris yang dipilih tetapi tidak ada baris yang diklik, fungsi `hapus(sender)` dipanggil.
        - Jika hanya satu baris yang dipilih dan baris yang diklik termasuk di dalamnya, fungsi `deleteDataClicked(clickedRow)` dipanggil.
        - Jika tidak ada baris yang dipilih tetapi ada baris yang diklik, fungsi `deleteDataClicked(clickedRow)` dipanggil.
        - Jika ada baris yang dipilih dan ada baris yang diklik, fungsi `deleteDataClicked(clickedRow)` dipanggil.

     Jika pengguna memilih untuk menekan peringatan, pilihan ini akan disimpan di `UserDefaults` dan peringatan tidak akan ditampilkan lagi di masa mendatang sampai diubah.
     */
    @IBAction func hapusMenu(_ sender: Any) {
        let selectedRows = tableView.selectedRowIndexes
        let clickedRow = tableView.clickedRow
        let isSuppressed = UserDefaults.standard.bool(forKey: suppressionKey)

        let alert = makeDeleteAlert(
            selectedRows: selectedRows,
            clickedRow: clickedRow
        )

        guard !isSuppressed else {
            executeDelete(sender: sender, selectedRows: selectedRows, clickedRow: clickedRow)
            return
        }

        if alert.runModal() == .alertFirstButtonReturn {
            if alert.suppressionButton?.state == .on {
                UserDefaults.standard.set(true, forKey: suppressionKey)
            }
            executeDelete(sender: sender, selectedRows: selectedRows, clickedRow: clickedRow)
        }
    }

    /// Menghapus satu atau lebih siswa dari table view dan model data yang sesuai.
    ///
    /// Fungsi ini melakukan penghapusan baik pada model data (`viewModel`) maupun
    /// antarmuka pengguna (`tableView`) secara terkoordinasi. Fungsi ini mendukung
    /// dua mode tampilan, yaitu mode biasa (`.plain`) dan mode kelompok (`.grouped`).
    /// Agar animasi UI berjalan lancar, proses penghapusan dibungkus dalam
    /// `tableView.beginUpdates()` dan `tableView.endUpdates()`.
    ///
    /// - Parameters:
    ///   - siswas: Array dari objek ``ModelSiswa`` yang akan dihapus.
    ///   - animation: Opsi animasi untuk penghapusan baris, seperti `.effectFade`.
    ///   - afterRemove: Sebuah closure opsional yang akan dijalankan setelah
    ///     semua baris dihapus.
    ///   - hideLulusBerhenti: Parameter yang tidak digunakan di dalam fungsi ini.
    /// - Returns: Array dari indeks baris yang telah dihapus dari table view
    /// untuk keperluan scroll/select row.
    func removeSiswas(
        _ siswas: [ModelSiswa],
        afterRemove: (() -> Void)? = nil
    ) -> [Int] {
        var removedIndexes = [Int]()
        let updates: [UpdateData] = viewModel.performBatchUpdates {
            siswas.compactMap { siswa -> UpdateData? in
                guard let (index, update) = viewModel.removeSiswa(siswa) else {
                    return nil
                }
                removedIndexes.append(index)
                return update
            }
        }
        UpdateData.applyUpdates(updates, tableView: tableView, deselectAll: true)
        afterRemove?()
        return removedIndexes
    }

    private func selectAfterRemoval(_ indexes: [Int]) {
        guard !indexes.isEmpty else { return }

        let currentRowCount = tableView.numberOfRows
        guard currentRowCount > 0 else { return } // Pastikan masih ada row

        let lastDeletedIndex = indexes.max() ?? 0

        // Tentukan index selection yang aman
        let selectionIndex: Int = if lastDeletedIndex >= currentRowCount {
            currentRowCount - 1 // Pilih terakhir
        } else {
            lastDeletedIndex // Pilih index yang sama
        }

        tableView.selectRowIndexes(IndexSet(integer: selectionIndex), byExtendingSelection: false)

        // Scroll ke row yang dipilih
        if selectionIndex == currentRowCount - 1 {
            tableView.scrollToEndOfDocument(nil)
        } else {
            tableView.scrollRowToVisible(selectionIndex)
        }
    }

    private func scrollRow(_ indexes: [Int]) {
        if let maxIndeks = indexes.max() {
            if maxIndeks >= tableView.numberOfRows - 1 {
                tableView.scrollToEndOfDocument(nil)
            } else {
                tableView.scrollRowToVisible(maxIndeks)
            }
        }
    }

    /**
         * Fungsi ini menangani aksi penghapusan data siswa dari tampilan tabel.
         *
         * Fungsi ini dipanggil ketika pengguna menekan tombol "Hapus". Fungsi ini menghapus baris yang dipilih dari tampilan tabel,
         * baik dalam mode tampilan biasa maupun mode tampilan yang dikelompokkan. Fungsi ini juga menangani pendaftaran aksi undo
         * dan mengirimkan notifikasi tentang penghapusan siswa.
         *
         * - Parameter sender: Objek yang memicu aksi ini (misalnya, tombol "Hapus").
         *
         * - Precondition: `tableView` harus sudah diinisialisasi dan diisi dengan data siswa.
         * - Postcondition: Baris yang dipilih akan dihapus dari `tableView`, dan aksi undo akan didaftarkan.
     */
    @objc func hapus(_ sender: Any, selectedRows: IndexSet) {
        guard !selectedRows.isEmpty else { return }

        let siswasToDelete: [ModelSiswa] = viewModel.getSiswas(for: selectedRows)

        let removedIndexes = removeSiswas(siswasToDelete)

        selectAfterRemoval(removedIndexes)

        deleteAllRedoArray(sender)
        SingletonData.deletedSiswasArray.append(siswasToDelete)
        SingletonData.deletedStudentIDs.append(contentsOf: siswasToDelete.map(\.id))

        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoDeleteMultipleData(sender)
        }
        SiswaViewModel.siswaUndoManager.setActionName("Delete Multiple Data")

        for siswa in siswasToDelete {
            NotifSiswaDihapus.sendNotif(siswa)
        }
    }

    /// Memasukkan satu siswa ke dalam table view dan model data.
    ///
    /// Fungsi ini adalah metode utama untuk menyisipkan satu objek ``ModelSiswa``.
    /// Fungsi ini memanggil fungsi ``SiswaViewModel/insertSiswa(_:comparator:)`` yang mendasari untuk melakukan
    /// pembaruan data yang sebenarnya, lalu membersihkan ID siswa dari data
    /// global yang dihapus. Jika diperlukan, fungsi ini juga memposting notifikasi
    /// untuk mendukung fitur _undo_.
    ///
    /// - Parameters:
    ///   - siswa: Objek ``ModelSiswa`` yang akan dimasukkan.
    ///   - comparator: Closure yang menentukan posisi pengurutan yang benar.
    ///   - animation: Opsi animasi untuk penyisipan baris. Secara default, menggunakan `.slideDown`.
    ///   - extendSelection: Boolean yang menentukan apakah pilihan yang ada harus
    ///     diperluas. Secara default, `true`.
    ///   - postNotification: Boolean yang menentukan apakah notifikasi _undo_ harus
    ///     diposting. Secara default, `false`.
    /// - Returns: Sebuah objek ``UpdateData`` opsional yang berisi detail pembaruan
    ///   untuk UI. Mengembalikan `nil` jika penyisipan gagal.
    @discardableResult
    private func insertSiswa(
        _ siswa: ModelSiswa,
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool,
        postNotification: Bool = false
    ) -> UpdateData? {
        let update = viewModel.insertSiswa(siswa, comparator: comparator)

        SingletonData.deletedStudentIDs.removeAll { $0 == siswa.id }

        if postNotification {
            NotifSiswaDihapus.sendNotif(siswa, notificationName: .undoSiswaDihapus)
        }
        return update
    }

    /// Memasukkan beberapa siswa ke dalam table view.
    ///
    /// Fungsi ini mengiterasi melalui array siswa  untuk setiap siswa secara individual. Setelah mengumpulkan semua 
    /// pembaruan, fungsi ini memanggil ``UpdateData/applyUpdates(_:tableView:deselectAll:batchUpdate:)``
    /// untuk menerapkan semua perubahan UI secara bersamaan dalam satu blok,
    /// yang mengoptimalkan kinerja dan animasi.
    ///
    /// - Parameters:
    ///   - siswas: Array dari objek ``ModelSiswa`` yang akan dimasukkan.
    ///   - comparator: Closure untuk menentukan posisi pengurutan yang benar untuk
    ///     setiap siswa.
    ///   - postNotification: Boolean yang menentukan apakah notifikasi harus
    ///     diposting setelah setiap penyisipan. Secara default, `false`.
    ///   - deselectAll: Pilihan untuk menghapus seleksi tableView sebelum melakukan
    ///     pembaruan.
    func insertMultipleSiswas(
        _ siswas: [ModelSiswa],
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool,
        postNotification: Bool = false,
        deselectAll: Bool = true
    ) {
        let updates: [UpdateData] = viewModel.performBatchUpdates {
            siswas.compactMap { siswa -> UpdateData? in
                if let update = insertSiswa(
                    siswa, comparator: comparator,
                    postNotification: postNotification
                ) {
                    return update
                }
                return nil
            }
        }
        DispatchQueue.main.async { [weak self, updates] in
            guard let self else { return }
            UpdateData.applyUpdates(updates, tableView: tableView, deselectAll: deselectAll)
        }
    }

    /**
     Mengembalikan tindakan penghapusan data siswa yang sebelumnya dibatalkan.

     Fungsi ini mengembalikan data siswa yang terakhir dihapus dari array `SingletonData.deletedSiswasArray` ke tampilan tabel.
     Fungsi ini menangani penyisipan data yang dikembalikan ke dalam tampilan tabel, baik dalam mode tampilan biasa maupun berkelompok,
     dan juga menangani pemulihan pilihan baris sebelumnya.

     - Parameter sender: Objek yang memicu tindakan undo.
     */
    func undoDeleteMultipleData(_ sender: Any) {
        delegate?.didUpdateTable(.siswa)
        guard let sortDescriptor = tableView.sortDescriptors.first,
              let comparator = ModelSiswa.comparator(from: sortDescriptor),
              !SingletonData.deletedSiswasArray.isEmpty else { return }

        handleSearchField()
        let lastDeletedSiswaArray = SingletonData.deletedSiswasArray.removeLast()

        insertMultipleSiswas(
            lastDeletedSiswaArray,
            comparator: comparator,
            postNotification: true
        )

        redoDeletedSiswaArray.append(lastDeletedSiswaArray)

        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.redoDeleteMultipleData(sender)
        }

        let message = "Siswa yang akan diinsert adalah siswa yang difilter. Data ini akan dihapus setelah konfirmasi."

        // Alert filter aktif
        if lastDeletedSiswaArray.contains(where: { $0.status.description == "Berhenti" }), isBerhentiHidden {
            ReusableFunc.showAlert(
                title: "Filter Tabel Siswa Berhenti Aktif",
                message: message
            )
        }
        if lastDeletedSiswaArray.contains(where: { $0.status.description == "Lulus" }), !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
            ReusableFunc.showAlert(
                title: "Filter Tabel Siswa Lulus Aktif",
                message: message
            )
        }

        /// Hapus siswa yang berhenti/lulus sesuai filter yang sedang aktif.
        var filterUpdates = [UpdateData]()
        for siswa in lastDeletedSiswaArray {
            if handleHiddenSiswa(siswa),
               let result = viewModel.removeSiswa(siswa)
            {
                filterUpdates.append(result.update)
            }
        }
        UpdateData.applyUpdates(filterUpdates, tableView: tableView, deselectAll: false)
    }

    /**
     *  Melakukan penghapusan kembali data siswa yang sebelumnya telah dibatalkan penghapusannya (redo).
     *
     *  Fungsi ini mengambil data siswa yang terakhir kali dibatalkan penghapusannya dari `redoDeletedSiswaArray`,
     *  menghapusnya dari tampilan tabel, dan menyimpannya dalam `deletedSiswasArray` untuk kemungkinan pembatalan (undo) di masa mendatang.
     *  Fungsi ini juga menangani pembaruan UI, notifikasi, dan pendaftaran tindakan undo.
     *
     *  - Parameter:
     *      - sender: Objek yang memicu aksi ini (misalnya, tombol redo).
     *
     *  - Catatan:
     *      - Fungsi ini mempertimbangkan mode tampilan tabel saat ini (`.plain` atau `.grouped`) untuk menghapus data dengan benar.
     *      - Fungsi ini juga menangani kasus di mana data yang dihapus adalah data yang difilter atau data dengan status tertentu (misalnya, "Berhenti" atau "Lulus") dan menampilkan peringatan yang sesuai.
     *      - Fungsi ini menggunakan `SingletonData` untuk menyimpan data yang dihapus dan `NotificationCenter` untuk mengirim notifikasi tentang penghapusan siswa.
     */
    func redoDeleteMultipleData(_ sender: Any) {
        delegate?.didUpdateTable(.siswa)
        handleSearchField()
        let lastRedoDeletedSiswaArray = redoDeletedSiswaArray.removeLast()
        // Simpan data yang dihapus untuk undo
        SingletonData.deletedSiswasArray.append(lastRedoDeletedSiswaArray)

        // Lakukan penghapusan kembali
        let removedIndexes = removeSiswas(lastRedoDeletedSiswaArray)

        selectAfterRemoval(removedIndexes)
        scrollRow(removedIndexes)

        // Catat tindakan undo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoDeleteMultipleData(sender)
        }

        for siswa in lastRedoDeletedSiswaArray {
            if !SingletonData.deletedStudentIDs.contains(siswa.id) {
                SingletonData.deletedStudentIDs.append(siswa.id)
            }
            NotifSiswaDihapus.sendNotif(siswa)
        }

        let hasBerhentiAndFiltered = lastRedoDeletedSiswaArray.contains(where: { $0.status.description == "Berhenti" }) && isBerhentiHidden
        let hasLulusAndDisplayed = lastRedoDeletedSiswaArray.contains(where: { $0.status.description == "Lulus" }) && !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus")

        if hasBerhentiAndFiltered {
            ReusableFunc.showAlert(title: "Filter Tabel Siswa Berhenti Aktif", message: "Data status siswa yang akan dihapus adalah siswa yang difilter dan telah dihapus dari tabel. Data ini akan dihapus ketika menyimpan file ke database.")
        }
        if hasLulusAndDisplayed {
            ReusableFunc.showAlert(
                title: "Filter Tabel Siswa Lulus Aktif",
                message: "Data status siswa yang akan dihapus adalah siswa yang difilter dan telah dihapus dari tabel. Data ini akan dihapus ketika menyimpan file ke database."
            )
        }
    }

    private func handleSearchField() {
        if !stringPencarian.isEmpty {
            view.window?.makeFirstResponder(tableView)
            filterDeletedSiswa()
        }
    }

    /**
     * Fungsi ini membatalkan operasi tempel terakhir yang dilakukan pada tabel siswa.
     *
     * Fungsi ini melakukan langkah-langkah berikut:
     * 1. Membatalkan pilihan semua baris yang dipilih pada tabel.
     * 2. Jika ada string pencarian yang aktif, fungsi ini akan membersihkan string pencarian dan memperbarui tampilan tabel sesuai.
     * 3. Mengambil array siswa yang terakhir ditempel dari ``pastedSiswasArray``.
     * 4. Menyimpan array siswa yang dihapus ke ``SingletonData/redoPastedSiswaArray`` untuk operasi redo.
     * 5. Menghapus siswa dari sumber data dan tabel.
     * 6. Memilih baris yang sesuai setelah penghapusan dan menggulir tampilan ke baris tersebut.
     * 7. Mendaftarkan tindakan undo dengan ``SiswaViewModel/siswaUndoManager`` untuk memungkinkan operasi redo.
     * 8. Memperbarui status undo/redo setelah penundaan singkat.
     *
     * - Parameter:
     *   - sender: Objek yang memicu tindakan undo.
     */
    func undoPaste(_ sender: Any) {
        delegate?.didUpdateTable(.siswa)
        tableView.deselectAll(sender)
        handleSearchField()

        let lastRedoDeletedSiswaArray = pastedSiswasArray.removeLast()

        let removedIndexes = removeSiswas(lastRedoDeletedSiswaArray) {
            // Optional: update SingletonData.deletedStudentIDs
            SingletonData.redoPastedSiswaArray.append(lastRedoDeletedSiswaArray)
            for siswa in lastRedoDeletedSiswaArray {
                if !SingletonData.deletedStudentIDs.contains(siswa.id) {
                    SingletonData.deletedStudentIDs.append(siswa.id)
                }
            }
        }

        selectAfterRemoval(removedIndexes)
        scrollRow(removedIndexes)

        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { target in
            target.redoPaste(sender)
        }
    }

    /**
     *  Melakukan operasi 'redo' untuk tindakan 'paste' (tempel).
     *
     *  Fungsi ini mengembalikan tindakan 'paste' yang sebelumnya dibatalkan (undo), menyisipkan kembali data siswa yang telah dihapus ke dalam tampilan tabel.
     *  Fungsi ini menangani penyisipan data baik dalam mode tampilan 'plain' maupun 'grouped', memastikan data disisipkan pada indeks yang tepat berdasarkan urutan yang ditentukan.
     *
     *  - Parameter:
     *      - sender: Objek yang memicu tindakan ini (misalnya, tombol 'redo').
     *
     *  - Catatan:
     *      - Fungsi ini menggunakan `SingletonData.redoPastedSiswaArray` untuk mendapatkan data siswa yang akan dikembalikan.
     *      - Fungsi ini memperbarui tampilan tabel dengan animasi slide-down.
     *      - Fungsi ini mendaftarkan tindakan 'undo' baru untuk memungkinkan pembatalan tindakan 'redo' ini.
     */
    func redoPaste(_ sender: Any) {
        delegate?.didUpdateTable(.siswa)
        guard let sortDescriptor = tableView.sortDescriptors.first,
              let comparator = ModelSiswa.comparator(from: sortDescriptor)
        else { return }
        handleSearchField()

        let lastDeletedSiswaArray = SingletonData.redoPastedSiswaArray.removeLast()

        insertMultipleSiswas(
            lastDeletedSiswaArray,
            comparator: comparator,
            postNotification: true
        )

        pastedSiswasArray.append(lastDeletedSiswaArray)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { $0.undoPaste(sender) }
    }

    // Fungsi pembantu untuk membungkus pembaruan UI
    /**
         Memuat ulang kolom namasiswa, tanggal lulus, dan kolom status.
         - Parameter:
            - selectedRowIndexes: Indeks baris yang akan diperbarui.
     */
    func refreshTableViewCells(for selectedRowIndexes: IndexSet) {
        for rowIndex in selectedRowIndexes {
            if let tglView = tableView.view(atColumn: ReusableFunc.columnIndex(of: tglLulusColumn, in: tableView), row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                tglView.textField?.stringValue = ""
            }
        }
        tableView.reloadData(forRowIndexes: selectedRowIndexes, columnIndexes: IndexSet([columnIndexOfKelasAktif, columnIndexOfStatus]))
    }

    /// Hapus semua array untuk redo.
    /// - Parameter sender: Objek pemicu apapun.
    func deleteAllRedoArray(_: Any) {
        if !redoDeletedSiswaArray.isEmpty { redoDeletedSiswaArray.removeAll() }
        if !SingletonData.redoPastedSiswaArray.isEmpty { SingletonData.redoPastedSiswaArray.removeAll() }
        ulangsiswaBaruArray.removeAll()
    }
}
