//
//  UpdateData.swift
//  Data SDI
//
//  Created by MacBook on 20/07/25.
//

import Foundation

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
        if tableView.numberOfRows == 0 {
            tableView.reloadData()
        }

        // Dapatkan data yang ada di clipboard
        let pasteboard = NSPasteboard.general
        var errorMessages: [String] = []
        guard let stringData = pasteboard.string(forType: .string) else { return }

        // Parse data yang ditempelkan
        let lines = stringData.components(separatedBy: .newlines)
        // Array untuk menyimpan siswa yang akan ditambahkan
        var siswaToAdd: [ModelSiswa] = []
        siswaToAdd.removeAll()
        let allColumns = tableView.tableColumns

        // Periksa setiap kolom dan cari yang sesuai dengan identifikasi yang Anda gunakan
        var columnIndexNamaSiswa: Int? = nil
        var columnIndexOfAlamat: Int? = nil
        var columnIndexOfTanggalLahir: Int? = nil
        var columnIndexOrtu: Int? = nil
        var columnIndexOfStatus: Int? = nil
        var columnIndexTahunDaftar: Int? = nil
        var columnIndexNIS: Int? = nil
        var columnIndexKelamin: Int? = nil
        var columnIndexOfTglBerhenti: Int? = nil
        var columnIndexNISN: Int? = nil
        var columnIndexAyah: Int? = nil
        var columnIndexIbu: Int? = nil
        var columnIndexTlv: Int? = nil
        for (index, column) in allColumns.enumerated() {
            if column.identifier.rawValue == "Nama" {
                columnIndexNamaSiswa = index
            } else if column.identifier.rawValue == "Alamat" {
                columnIndexOfAlamat = index
            } else if column.identifier.rawValue == "T.T.L" {
                columnIndexOfTanggalLahir = index
            } else if column.identifier.rawValue == "Nama Wali" {
                columnIndexOrtu = index
            } else if column.identifier.rawValue == "Tahun Daftar" {
                columnIndexTahunDaftar = index
            } else if column.identifier.rawValue == "NIS" {
                columnIndexNIS = index
            } else if column.identifier.rawValue == "Jenis Kelamin" {
                columnIndexKelamin = index
            } else if column.identifier.rawValue == "Status" {
                columnIndexOfStatus = index
            } else if column.identifier.rawValue == "Tgl. Lulus" {
                columnIndexOfTglBerhenti = index
            } else if column.identifier.rawValue == "NISN" {
                columnIndexNISN = index
            } else if column.identifier.rawValue == "Ayah" {
                columnIndexAyah = index
            } else if column.identifier.rawValue == "Ibu" {
                columnIndexIbu = index
            } else if column.identifier.rawValue == "Nomor Telepon" {
                columnIndexTlv = index
            }
        }
        for line in lines {
            // Parsing data dalam baris yang ditempelkan
            var rowComponents: [String]
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines
            if trimmedLine.isEmpty {
                continue
            }
            if trimmedLine.contains("\t") {
                rowComponents = trimmedLine.components(separatedBy: "\t")
            } else if trimmedLine.contains(", ") {
                rowComponents = trimmedLine.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
            } else {
                // Handle jika tidak ada separator yang valid
                errorMessages.append("Format tidak valid untuk baris: \(trimmedLine)")
                continue
            }

            if line.contains("\t") {
                rowComponents = line.components(separatedBy: "\t")
            } else if line.contains(", ") {
                rowComponents = line.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
            } else {
                // Handle jika tidak ada separator yang valid
                errorMessages.append("Format tidak valid untuk baris: \(line)")
                continue
            }

            let isRowEmpty = rowComponents.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if isRowEmpty {
                continue
            }
            // Buat objek BentukSiswa dan sesuaikan dengan urutan kolom
            let siswa = ModelSiswa()
            while rowComponents.count < allColumns.count {
                rowComponents.append("") // Isi dengan string kosong
            }

            // Buat objek BentukSiswa dan sesuaikan dengan urutan kolom
            if let index = columnIndexNamaSiswa {
                siswa.nama = rowComponents[index]

            } else {}
            if let index = columnIndexOfAlamat {
                siswa.alamat = rowComponents[index]
            }
            if let index = columnIndexOfTanggalLahir {
                siswa.ttl = rowComponents[index]
            }
            if let index = columnIndexOrtu {
                siswa.namawali = rowComponents[index]
            }
            if let index = columnIndexNIS {
                siswa.nis = rowComponents[index]
            }
            if let index = columnIndexKelamin {
                siswa.jeniskelamin = JenisKelamin.from(description: rowComponents[index]) ?? .lakiLaki
            }
            if let index = columnIndexTahunDaftar {
                siswa.tahundaftar = rowComponents[index]
            }
            if let index = columnIndexOfStatus {
                if let status = StatusSiswa.from(description: rowComponents[index]) {
                    siswa.status = status
                } else {
                    siswa.status = .aktif
                }
            }
            if let index = columnIndexOfTglBerhenti {
                siswa.tanggalberhenti = rowComponents[index]
            }
            if let index = columnIndexNISN {
                siswa.nisn = rowComponents[index]
            }
            if let index = columnIndexAyah {
                siswa.ayah = rowComponents[index]
            }
            if let index = columnIndexIbu {
                siswa.ibu = rowComponents[index]
            }
            if let index = columnIndexTlv {
                siswa.tlv = rowComponents[index]
            }

            // Tambahkan objek BentukSiswa ke array siswaToAdd
            siswaToAdd.append(siswa)
        }
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor else {
            return
        }
        if !errorMessages.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Format input tidak didukung"

            // Ambil maksimal 3 error pertama
            let maxErrorsToShow = 3
            let displayedErrors = errorMessages.prefix(maxErrorsToShow)
            var informativeText = displayedErrors.joined(separator: "\n")

            // Jika ada lebih dari 3 error, tambahkan keterangan bahwa ada lebih banyak error
            if errorMessages.count > maxErrorsToShow {
                informativeText += "\n...dan \(errorMessages.count - maxErrorsToShow) lainnya"
            }

            alert.informativeText = informativeText
            alert.alertStyle = .warning
            alert.icon = NSImage(named: NSImage.stopProgressFreestandingTemplateName)
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        } else {
            tableView.deselectAll(sender)
        }
        var tempDeletedSiswaArray = [ModelSiswa]()
        var tempDeletedIndexes = [Int]()

        // Buat array untuk menyimpan insertedSiswaID
        var insertedSiswaIDs: [Int64] = []

        // Background queue untuk proses database

        DispatchQueue.global(qos: .background).async { [unowned self] in
            for siswa in siswaToAdd {
                // Tambahkan siswa ke database
                let dataSiswaUntukDicatat: SiswaDefaultData = (
                    nama: siswa.nama,
                    alamat: siswa.alamat,
                    ttl: siswa.ttl,
                    tahundaftar: siswa.tahundaftar,
                    namawali: siswa.namawali,
                    nis: siswa.nis,
                    nisn: siswa.nisn,
                    ayah: siswa.ayah,
                    ibu: siswa.ibu,
                    jeniskelamin: siswa.jeniskelamin,
                    status: .aktif,
                    tanggalberhenti: siswa.tanggalberhenti,
                    tlv: siswa.tlv,
                    foto: selectedImageData
                )
                if let insertedSiswaID = dbController.catatSiswa(dataSiswaUntukDicatat) {
                    // Simpan insertedSiswaID ke array
                    insertedSiswaIDs.append(insertedSiswaID)
                }
            }

            // Setelah semua siswa ditambahkan, proses hasilnya di main thread
            DispatchQueue.main.async { [unowned self] in
                tableView.beginUpdates()
                for insertedSiswaID in insertedSiswaIDs {
                    // Dapatkan data siswa yang baru ditambahkan dari database
                    let insertedSiswa = dbController.getSiswa(idValue: insertedSiswaID)

                    if currentTableViewMode == .plain {
                        // Pastikan siswa yang baru ditambahkan belum ada di tabel
                        guard !viewModel.filteredSiswaData.contains(where: { $0.id == insertedSiswaID }) else {
                            continue
                        }
                        // Tentukan indeks untuk menyisipkan siswa baru ke dalam array viewModel.filteredSiswaData sesuai dengan urutan kolom
                        let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: insertedSiswa, using: sortDescriptor)

                        // Masukkan siswa baru ke dalam array viewModel.filteredSiswaData
                        viewModel.insertSiswa(insertedSiswa, at: insertIndex)

                        // Tambahkan baris baru ke tabel dengan animasi
                        tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
                        // Pilih baris yang baru ditambahkan
                        tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)

                        // Simpan siswa yang baru ditambahkan ke array untuk dihapus nanti jika diperlukan
                        tempDeletedIndexes.append(insertIndex)
                    } else {
                        // Pastikan siswa yang baru ditambahkan belum ada di groupedSiswa
                        let siswaAlreadyExists = viewModel.groupedSiswa.flatMap { $0 }.contains(where: { $0.id == insertedSiswaID })

                        if siswaAlreadyExists {
                            continue // Jika siswa sudah ada, lanjutkan ke siswa berikutnya
                        }
                        // Hitung ulang indeks penyisipan berdasarkan grup yang baru
                        let insertIndex = viewModel.groupedSiswa[7].insertionIndex(for: insertedSiswa, using: sortDescriptor)

                        // Sisipkan siswa kembali ke dalam array viewModel.groupedSiswa pada grup yang tepat
                        viewModel.insertGroupSiswa(insertedSiswa, groupIndex: 7, index: insertIndex)

                        // Menghitung jumlah baris dalam grup-grup sebelum grup saat ini
                        let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: 7, rowIndexInSection: insertIndex)

                        tableView.insertRows(at: IndexSet(integer: absoluteRowIndex + 1), withAnimation: .slideDown)
                        tableView.selectRowIndexes(IndexSet(integer: absoluteRowIndex + 1), byExtendingSelection: true)
                        tempDeletedIndexes.append(absoluteRowIndex + 1)
                    }
                    tempDeletedSiswaArray.append(insertedSiswa)
                }
                tableView.endUpdates()
                if let maxIndex = tempDeletedIndexes.max() {
                    if maxIndex >= tableView.numberOfRows - 1 {
                        tableView.scrollToEndOfDocument(sender)
                    } else {
                        tableView.scrollRowToVisible(maxIndex + 1)
                    }
                }

                // Tambahkan informasi siswa yang dipaste ke dalam array pastedSiswasArray
                pastedSiswasArray.append(tempDeletedSiswaArray)

                // Daftarkan aksi undo untuk paste
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
                    targetSelf.undoPaste(sender)
                }

                // Hapus semua informasi dari array redo
                deleteAllRedoArray(sender)
                // Perbarui tombol undo dan redo
                updateUndoRedo(self)
            }
        }
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

        if currentTableViewMode == .plain {
            if let index = viewModel.filteredSiswaData.firstIndex(where: { $0.id == siswa.id }) {
                ulangsiswaBaruArray.append(viewModel.filteredSiswaData[index])
                viewModel.removeSiswa(at: index)
                // Hapus data dari tabel
                if index + 1 < tableView.numberOfRows - 1 {
                    tableView.selectRowIndexes(IndexSet([index + 1]), byExtendingSelection: false)
                }
                tableView.scrollRowToVisible(index)
                tableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
            }
        } else {
            if let groupIndex = viewModel.groupedSiswa.firstIndex(where: { $0.contains { $0.id == siswa.id } }) {
                // Temukan indeks siswa dalam grup tersebut
                if let siswaIndex = viewModel.groupedSiswa[groupIndex].firstIndex(where: { $0.id == siswa.id }) {
                    // Hapus siswa dari grup
                    ulangsiswaBaruArray.append(viewModel.groupedSiswa[groupIndex][siswaIndex])
                    viewModel.removeGroupSiswa(groupIndex: groupIndex, index: siswaIndex)
                    // Dapatkan informasi baris untuk id siswa yang dihapus
                    let rowInfo = getRowInfoForRow(siswaIndex)
                    // Pastikan baris yang dipilih adalah baris siswa, bukan header kelas

                    // Hitung indeks absolut untuk menghapus baris dari NSTableView
                    var absoluteRowIndex = 0
                    for i in 0 ..< groupIndex {
                        let section = viewModel.groupedSiswa[i]
                        // Tambahkan jumlah baris dalam setiap grup sebelum grup saat ini
                        absoluteRowIndex += section.count + 1 // jumlah siswa dalam grup + 1 untuk header kelas
                    }
                    // Tambahkan indeks baris dalam grup ke indeks absolut
                    let rowtoDelete = absoluteRowIndex + rowInfo.rowIndexInSection + 1 // tambahkan 1 karena header kelas
                    // Hapus baris dari NSTableView
                    if rowtoDelete + 2 < tableView.numberOfRows {
                        tableView.scrollRowToVisible(rowtoDelete + 1)
                        tableView.selectRowIndexes(IndexSet([rowtoDelete + 2]), byExtendingSelection: false)
                    } else {
                        tableView.scrollRowToVisible(rowtoDelete)
                    }
                    tableView.removeRows(at: IndexSet(integer: rowtoDelete + 1), withAnimation: .slideUp)
                }
            }
        }
        // Catat tindakan undo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.ulangSiswaBaru(sender)
        }
        SiswaViewModel.siswaUndoManager.setActionName("Undo Add New Data")

        SingletonData.undoAddSiswaArray.append([siswa])
        SingletonData.deletedStudentIDs.append(siswa.id)
        // Entah kenapa harus dibungkus dengan task.
        Task { @MainActor in
            updateUndoRedo(self)
            try? await Task.sleep(nanoseconds: 300_000_000)
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [siswa.id],
                "kelasSekarang": siswa.tingkatKelasAktif.rawValue,
                "isDeleted": true,
                "hapusDiSiswa": true,
            ]
            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
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
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor else { return }

        let siswa = ulangsiswaBaruArray.removeLast()
        urungsiswaBaruArray.append(siswa)
        // Kembalikan data yang dihapus ke array
        if currentTableViewMode == .plain {
            // Temukan indeks yang sesuai untuk memasukkan siswa kembali sesuai dengan sort descriptor saat ini
            let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
            viewModel.insertSiswa(siswa, at: insertIndex)
            #if DEBUG
                print("siswa:", viewModel.filteredSiswaData[insertIndex].nama)
            #endif
            // Perbarui tampilan tabel setelah memasukkan data yang dihapus
            tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
            tableView.scrollRowToVisible(insertIndex)
            tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)
        } else {
            guard let group = siswa.status == .lulus
                ? getGroupIndex(forClassName: StatusSiswa.lulus.description)
                : getGroupIndex(forClassName: siswa.tingkatKelasAktif.rawValue)
            else { return }

            // Kemudian, hitung kembali indeks penyisipan berdasarkan grup yang baru
            let updatedGroupIndex = min(group, viewModel.groupedSiswa.count - 1)

            // Hitung ulang indeks penyisipan berdasarkan grup yang baru
            let insertIndex = viewModel.groupedSiswa[updatedGroupIndex].insertionIndex(for: siswa, using: sortDescriptor)

            // Sisipkan siswa kembali ke dalam array viewModel.groupedSiswa pada grup yang tepat
            viewModel.insertGroupSiswa(siswa, groupIndex: group, index: insertIndex)
            // Perbarui tampilan tabel setelah menyisipkan data yang dihapus
            let rowInfo = getRowInfoForRow(insertIndex)
            // Pastikan baris yang dipilih adalah baris siswa, bukan header kelas

            // Hitung indeks absolut untuk menghapus baris dari NSTableView
            var absoluteRowIndex = 0
            for i in 0 ..< group {
                let section = viewModel.groupedSiswa[i]
                // Tambahkan jumlah baris dalam setiap grup sebelum grup saat ini
                absoluteRowIndex += section.count + 1 // jumlah siswa dalam grup + 1 untuk header kelas
            }

            // Tambahkan indeks baris dalam grup ke indeks absolut
            let rowtoDelete = absoluteRowIndex + rowInfo.rowIndexInSection + 1 // tambahkan 1 karena header kelas
            tableView.insertRows(at: IndexSet(integer: rowtoDelete + 1), withAnimation: .slideDown)
            tableView.scrollRowToVisible(rowtoDelete + 1)
            tableView.selectRowIndexes(IndexSet(integer: rowtoDelete + 1), byExtendingSelection: false)
        }
        let mgr = SiswaViewModel.siswaUndoManager
        mgr.registerUndo(withTarget: self) { targetSelf in
            targetSelf.urungSiswaBaru(sender)
        }
        mgr.setActionName("Redo Add New Data")

        SingletonData.undoAddSiswaArray.removeLast()
        SingletonData.deletedStudentIDs.removeAll { $0 == siswa.id }

        // Entah kenapa tapi harus dibungkus dengan task.
        Task {
            updateUndoRedo(self)
            try? await Task.sleep(nanoseconds: 300_000_000)
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [siswa.id],
                "kelasSekarang": siswa.tingkatKelasAktif.rawValue,
                "isDeleted": true,
                "hapusDiSiswa": true,
            ]
            NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
        }
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
        let clickedRow = tableView.clickedRow
        var selectedRows = tableView.selectedRowIndexes
        selectedSiswaList.removeAll()
        let editView = EditData(nibName: "EditData", bundle: nil)

        // Jika mode adalah .grouped
        if currentTableViewMode == .grouped {
            if selectedRows.contains(clickedRow), selectedRows.count > 1 {
                guard !selectedRows.isEmpty else { return }
                for rowIndex in selectedRows {
                    let selectedRowInfo = getRowInfoForRow(rowIndex)
                    let groupIndex = selectedRowInfo.sectionIndex
                    let rowIndexInSection = selectedRowInfo.rowIndexInSection
                    let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]

                    // Tambahkan selectedSiswa ke dalam array
                    selectedSiswaList.append(selectedSiswa)
                }

                // Atur selectedSiswaList ke editView.selectedSiswaList
                editView.selectedSiswaList = selectedSiswaList
            } else if !selectedRows.isEmpty, clickedRow < 0 {
                // Lebih dari satu baris yang dipilih
                for rowIndex in selectedRows {
                    let selectedRowInfo = getRowInfoForRow(rowIndex)
                    let groupIndex = selectedRowInfo.sectionIndex
                    let rowIndexInSection = selectedRowInfo.rowIndexInSection
                    let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]

                    // Tambahkan selectedSiswa ke dalam array
                    selectedSiswaList.append(selectedSiswa)
                }
                editView.selectedSiswaList = selectedSiswaList
            } else if selectedRows.count == 1, selectedRows.contains(clickedRow) {
                selectedRows = IndexSet(integer: clickedRow)
                let selectedRowInfo = getRowInfoForRow(clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                editView.selectedSiswaList = [selectedSiswa]
                selectedSiswaList = [selectedSiswa]
            } else if selectedRows.isEmpty, clickedRow >= 0 {
                selectedRows = IndexSet(integer: clickedRow)
                let selectedRowInfo = getRowInfoForRow(clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                editView.selectedSiswaList = [selectedSiswa]
                selectedSiswaList = [selectedSiswa]
                tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            } else if !selectedRows.isEmpty, clickedRow >= 0 {
                selectedRows = IndexSet(integer: clickedRow)
                let selectedRowInfo = getRowInfoForRow(clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                let selectedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                editView.selectedSiswaList = [selectedSiswa]
                selectedSiswaList = [selectedSiswa]
                tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            }
        } else {
            selectedSiswaList = selectedRows.map { viewModel.filteredSiswaData[$0] }
            // Jika mode bukan .grouped, menggunakan pendekatan sebelumnya
            if selectedRows.contains(clickedRow) {
                guard !selectedRows.isEmpty else { return }
                editView.selectedSiswaList = selectedSiswaList
            } else if !selectedRows.isEmpty, clickedRow < 0 {
                editView.selectedSiswaList = selectedSiswaList
            } else if !selectedRows.isEmpty, clickedRow >= 0 {
                tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
                editView.selectedSiswaList = [viewModel.filteredSiswaData[clickedRow]]
                selectedSiswaList = [viewModel.filteredSiswaData[clickedRow]]
            } else if selectedRows.isEmpty, clickedRow >= 0 {
                tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
                editView.selectedSiswaList = [viewModel.filteredSiswaData[clickedRow]]
                selectedSiswaList = [viewModel.filteredSiswaData[clickedRow]]
            }
        }
        editView.preferredContentSize = NSSize(width: 428, height: 500)
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

        var dataToEdit = IndexSet()

        if currentTableViewMode == .grouped {
            if (selectedRows.contains(clickedRow) && selectedRows.count > 1) || (!selectedRows.isEmpty && clickedRow < 0) {
                dataToEdit = selectedRows
            } else if (selectedRows.count == 1 && selectedRows.contains(clickedRow)) ||
                (selectedRows.isEmpty && clickedRow >= 0) ||
                (!selectedRows.isEmpty && clickedRow >= 0)
            {
                dataToEdit = IndexSet([clickedRow])
                tableView.selectRowIndexes(dataToEdit, byExtendingSelection: false)
            }
        } else if currentTableViewMode == .plain {
            if clickedRow >= 0, clickedRow < viewModel.filteredSiswaData.count {
                if tableView.selectedRowIndexes.contains(clickedRow) {
                    dataToEdit = selectedRows
                } else {
                    dataToEdit = IndexSet([clickedRow])
                    tableView.selectRowIndexes(dataToEdit, byExtendingSelection: false)
                }
            } else {
                dataToEdit = selectedRows
            }
        }

        for row in dataToEdit {
            if currentTableViewMode == .plain {
                editVC.objectData.append(viewModel.filteredSiswaData[row].toDictionary())
            } else {
                let selectedRowInfo = getRowInfoForRow(row)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                guard rowIndexInSection >= 0 else { continue }
                editVC.objectData.append(viewModel.groupedSiswa[groupIndex][rowIndexInSection].toDictionary())
            }
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
            if currentTableViewMode == .plain {
                let selectedSiswaRow: [ModelSiswa] = tableView.selectedRowIndexes.compactMap { row in
                    let originalSiswa = self.viewModel.filteredSiswaData[row]
                    return originalSiswa.copy() as? ModelSiswa
                }
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
                    self?.viewModel.undoEditSiswa(selectedSiswaRow)
                }
            } else {
                let selectedSiswaRow = tableView.selectedRowIndexes.compactMap { rowIndex -> ModelSiswa? in
                    let selectedRowInfo = self.getRowInfoForRow(rowIndex)
                    let groupIndex = selectedRowInfo.sectionIndex
                    let rowIndexInSection = selectedRowInfo.rowIndexInSection
                    guard rowIndexInSection >= 0 else { return nil }
                    return self.viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                }
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
                    self?.viewModel.undoEditSiswa(selectedSiswaRow)
                }
            }

            // Lakukan iterasi terhadap setiap row yang di-update
            for updatedData in updatedRows {
                guard let idValue = updatedData["id"] as? Int64 else {
                    continue
                }

                let updatedSiswa = ModelSiswa.fromDictionary(updatedData)

                if currentTableViewMode == .plain, let siswaIndex = viewModel.filteredSiswaData.firstIndex(where: { $0.id == idValue }) {
                    viewModel.updateDataSiswa(idValue, dataLama: viewModel.filteredSiswaData[siswaIndex], baru: updatedSiswa)
                    viewModel.updateSiswa(updatedSiswa, at: siswaIndex)
                    tableView.reloadData(forRowIndexes: IndexSet(integer: siswaIndex), columnIndexes: IndexSet(integer: tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: selectedColumn))))
                } else if currentTableViewMode == .grouped, let (groupIndex, rowIndex) = viewModel.findSiswaInGroups(id: idValue) {
                    viewModel.updateDataSiswa(idValue, dataLama: viewModel.groupedSiswa[groupIndex][rowIndex], baru: updatedSiswa)
                    viewModel.updateGroupSiswa(updatedSiswa, groupIndex: groupIndex, index: rowIndex)
                    let absoluteRowIndex = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: rowIndex)
                    tableView.reloadData(forRowIndexes: IndexSet(integer: absoluteRowIndex), columnIndexes: IndexSet(integer: tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: selectedColumn))))
                }
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
                guard currentTableViewMode == .grouped else {
                    SiswaViewModel.siswaUndoManager.undo()
                    return
                }
                if let sortDescriptor = tableView.sortDescriptors.first {
                    urutkanDataPencarian(with: sortDescriptor)
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
        ReusableFunc.workItemUpdateUndoRedo?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let undoMenuItem = ReusableFunc.undoMenuItem,
                  let redoMenuItem = ReusableFunc.redoMenuItem
            else {
                return
            }

            let canUndo = SiswaViewModel.siswaUndoManager.canUndo
            let canRedo = SiswaViewModel.siswaUndoManager.canRedo

            redoMenuItem.isEnabled = canRedo
            redoMenuItem.target = canRedo ? self : nil
            redoMenuItem.action = canRedo ? #selector(mulaiRedo(_:)) : nil

            undoMenuItem.target = canUndo ? self : nil
            undoMenuItem.action = canUndo ? #selector(performUndo(_:)) : nil
            undoMenuItem.isEnabled = canUndo
            #if DEBUG
                print("---- BEGIN UPDATE UNDO REDO SISWAVIEWCONTROLLER -----")
                print("canUndo:", canUndo, "canRedo:", canRedo)
            #endif
            NotificationCenter.default.post(name: .bisaUndo, object: nil)
        }
        ReusableFunc.workItemUpdateUndoRedo = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: ReusableFunc.workItemUpdateUndoRedo!)
    }

    /**
         Menghapus baris yang dipilih dari tabel.

         Fungsi ini menampilkan dialog konfirmasi sebelum menghapus data siswa yang dipilih.
         Jika pengguna memilih untuk menghapus, data akan dihapus dari sumber data dan tabel akan diperbarui.
         Pengguna juga memiliki opsi untuk menekan (suppress) peringatan di masa mendatang.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func deleteSelectedRowsAction(_ sender: Any) {
        let selectedRows = tableView.selectedRowIndexes
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
        alert.addButton(withTitle: "Hapus")
        alert.addButton(withTitle: "Batalkan")
        let suppressionKey = "hapusDiSiswaAlert"
        let isSuppressed = UserDefaults.standard.bool(forKey: suppressionKey)
        // Dapatkan indeks baris yang dipilih

        var uniqueSelectedStudentNames = Set<String>()
        var allStudentNames = [String]() // Untuk menyimpan semua nama siswa
        for index in selectedRows {
            if currentTableViewMode == .plain {
                guard index < viewModel.filteredSiswaData.count else {
                    continue
                }
                let namasiswa = viewModel.filteredSiswaData[index].nama
                allStudentNames.append(namasiswa)
                uniqueSelectedStudentNames.insert(namasiswa)
            } else if currentTableViewMode == .grouped {
                // Dapatkan informasi baris berdasarkan indeks
                let rowInfo = getRowInfoForRow(index)
                let groupIndex = rowInfo.sectionIndex
                let rowIndexInSection = rowInfo.rowIndexInSection

                //                             Pastikan indeks valid
                guard groupIndex < viewModel.groupedSiswa.count, rowIndexInSection < viewModel.groupedSiswa[groupIndex].count else {
                    continue
                }

                let namasiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection].nama
                allStudentNames.append(namasiswa)
                uniqueSelectedStudentNames.insert(namasiswa)
            }
            // Batasi nama siswa yang ditampilkan hingga 10 nama
            let limitedNames = Array(uniqueSelectedStudentNames.sorted().prefix(10))
            let additionalCount = allStudentNames.count - limitedNames.count
            let namaSiswaText = limitedNames.joined(separator: ", ")

            // Tampilkan jumlah nama yang melebihi batas
            let additionalText = additionalCount > 0 ? "\n...dan \(additionalCount) lainnya" : ""

            // Buat peringatan konfirmasi
            alert.messageText = "Konfirmasi Penghapusan Data"
            alert.informativeText = "Apakah Anda yakin ingin menghapus data \(namaSiswaText)\(additionalText)?\nData di setiap kelas juga akan dihapus."
        }
        alert.showsSuppressionButton = true // Menampilkan tombol suppress
        guard !isSuppressed else {
            hapus(sender)
            return
        }
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if alert.suppressionButton?.state == .on {
                // Simpan status suppress ke UserDefaults
                UserDefaults.standard.set(true, forKey: suppressionKey)
            }
            hapus(sender)
        }
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
    @IBAction func hapusMenu(_ sender: NSMenuItem) {
        guard let tableView else { return }
        let selectedRows = tableView.selectedRowIndexes
        let clickedRow = tableView.clickedRow
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: .none)
        alert.addButton(withTitle: "Hapus")
        alert.addButton(withTitle: "Batalkan")
        let suppressionKey = "hapusDiSiswaAlert"
        let isSuppressed = UserDefaults.standard.bool(forKey: suppressionKey)
        // Dapatkan indeks baris yang dipilih

        var uniqueSelectedStudentNames = Set<String>()
        var allStudentNames = [String]() // Untuk menyimpan semua nama siswa
        // Menambahkan nama-nama siswa yang unik ke dalam Set dan array
        // Pastikan ada baris yang dipilih
        if (tableView.selectedRowIndexes.contains(tableView.clickedRow) && clickedRow != -1) || (tableView.numberOfSelectedRows >= 1 && clickedRow == -1) {
            guard selectedRows.count > 0 else { return }
            for index in selectedRows {
                if currentTableViewMode == .plain {
                    if index < viewModel.filteredSiswaData.count {
                        guard index < viewModel.filteredSiswaData.count else {
                            continue
                        }
                        let namasiswa = viewModel.filteredSiswaData[index].nama
                        allStudentNames.append(namasiswa)
                        uniqueSelectedStudentNames.insert(namasiswa)
                    }
                } else if currentTableViewMode == .grouped {
                    // Dapatkan informasi baris berdasarkan indeks
                    let rowInfo = getRowInfoForRow(index)
                    let groupIndex = rowInfo.sectionIndex
                    let rowIndexInSection = rowInfo.rowIndexInSection

                    //                             Pastikan indeks valid
                    guard groupIndex < viewModel.groupedSiswa.count, rowIndexInSection < viewModel.groupedSiswa[groupIndex].count else {
                        continue
                    }

                    let namasiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection].nama
                    allStudentNames.append(namasiswa)
                    uniqueSelectedStudentNames.insert(namasiswa)
                }
                // Batasi nama siswa yang ditampilkan hingga 10 nama
                let limitedNames = Array(uniqueSelectedStudentNames.sorted().prefix(10))
                let additionalCount = allStudentNames.count - limitedNames.count
                let namaSiswaText = limitedNames.joined(separator: ", ")

                // Tampilkan jumlah nama yang melebihi batas
                let additionalText = additionalCount > 0 ? "\n...dan \(additionalCount) lainnya" : ""

                // Buat peringatan konfirmasi
                alert.messageText = "Konfirmasi Penghapusan Data"
                alert.informativeText = "Apakah Anda yakin ingin menghapus data \(namaSiswaText)\(additionalText)?\nData di setiap kelas juga akan dihapus."
            }
        } else {
            var nama = ""
            guard clickedRow >= 0 else { return }
            if currentTableViewMode == .plain {
                // Jika mode adalah .plain, ambil nama siswa dari data siswa langsung
                nama = viewModel.filteredSiswaData[clickedRow].nama
            } else {
                // Jika mode adalah .grouped, dapatkan informasi baris dari metode getRowInfoForRow
                let selectedRowInfo = getRowInfoForRow(clickedRow)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                // Ambil nama siswa dari data siswa yang terkait dengan indeks baris yang dipilih
                nama = viewModel.groupedSiswa[groupIndex][rowIndexInSection].nama
            }
            alert.messageText = "Konfirmasi Penghapusan data \(nama)"
            alert.informativeText = "Apakah Anda yakin ingin menghapus data \(nama)? Data yang ada di setiap Kelas juga akan dihapus."
        }
        alert.showsSuppressionButton = true // Menampilkan tombol suppress
        // Menampilkan peringatan dan menunggu respons
        guard !isSuppressed else {
            if currentTableViewMode == .grouped {
                if selectedRows.contains(clickedRow), selectedRows.count > 1 { hapus(sender) }
                else if !selectedRows.isEmpty, clickedRow < 0 { hapus(sender) }
                else if selectedRows.count == 1, selectedRows.contains(clickedRow) { deleteDataClicked(clickedRow) }
                else if selectedRows.isEmpty, clickedRow >= 0 { deleteDataClicked(clickedRow) }
                else if !selectedRows.isEmpty, clickedRow >= 0 { deleteDataClicked(clickedRow) }
            } else if currentTableViewMode == .plain {
                // Jika ada baris yang diklik
                if tableView.clickedRow >= 0, tableView.clickedRow < viewModel.filteredSiswaData.count {
                    if tableView.selectedRowIndexes.contains(tableView.clickedRow) {
                        hapus(sender)
                    } else {
                        deleteDataClicked(clickedRow)
                    }
                } else {
                    hapus(sender)
                }
            }
            return
        }
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if alert.suppressionButton?.state == .on {
                // Simpan status suppress ke UserDefaults
                UserDefaults.standard.set(true, forKey: suppressionKey)
            }
            if currentTableViewMode == .grouped {
                if selectedRows.contains(clickedRow), selectedRows.count > 1 { hapus(sender) }
                else if !selectedRows.isEmpty, clickedRow < 0 { hapus(sender) }
                else if selectedRows.count == 1, selectedRows.contains(clickedRow) { deleteDataClicked(clickedRow) }
                else if selectedRows.isEmpty, clickedRow >= 0 { deleteDataClicked(clickedRow) }
                else if !selectedRows.isEmpty, clickedRow >= 0 { deleteDataClicked(clickedRow) }
            } else if currentTableViewMode == .plain {
                // Jika ada baris yang diklik
                if clickedRow >= 0, clickedRow < viewModel.filteredSiswaData.count {
                    if tableView.selectedRowIndexes.contains(clickedRow) {
                        hapus(sender)
                    } else {
                        deleteDataClicked(clickedRow)
                    }
                } else {
                    hapus(sender)
                }
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
    @IBAction func hapus(_ sender: Any) {
        let selectedRows = tableView.selectedRowIndexes
        // Pastikan ada baris yang dipilih
        guard selectedRows.count > 0 else { return }
        var deletedStudentIDs = [Int64]()
        // Jika pengguna menekan tombol "Hapus"
        var tempDeletedSiswaArray = [ModelSiswa]()
        var tempDeletedIndexes = [Int]()
        deleteAllRedoArray(sender)
        // Catat tindakan undo dengan data yang dihapus
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoDeleteMultipleData(sender)
        }
        SiswaViewModel.siswaUndoManager.setActionName("Delete Multiple Data")
        // Hapus data dari array
        if currentTableViewMode == .plain {
            var deletedRows = Set<Int>() // Gunakan Set untuk menyimpan indeks yang dihapus
            for index in selectedRows {
                tempDeletedSiswaArray.append(viewModel.filteredSiswaData[index])
                tempDeletedIndexes.append(index)
                let siswaID = viewModel.filteredSiswaData[index].id
                let kelasSekarang = viewModel.filteredSiswaData[index].tingkatKelasAktif.rawValue
                deletedRows.insert(index) // Tambahkan indeks yang dihapus ke Set
                deletedStudentIDs.append(siswaID)
                DispatchQueue.main.async {
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": deletedStudentIDs,
                        "kelasSekarang": kelasSekarang as String,
                        "isDeleted": true,
                        "hapusDiSiswa": true,
                    ]

                    NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                    SingletonData.deletedStudentIDs.append(siswaID)
                }
            }
            let sortedIndexes = tempDeletedIndexes.sorted(by: >)
            SingletonData.deletedSiswasArray.append(tempDeletedSiswaArray)
            for index in sortedIndexes {
                viewModel.removeSiswa(at: index)
            }

            DispatchQueue.main.async { [unowned self] in
                // Simpan aksi penghapusan secara bertahap
                if let lastIndex = sortedIndexes.max(), (lastIndex + 1) < tableView.numberOfRows {
                    tableView.selectRowIndexes(IndexSet(integer: lastIndex + 1), byExtendingSelection: true)
                }
                tableView.beginUpdates()
                tableView.removeRows(at: IndexSet(deletedRows), withAnimation: .slideUp)
                tableView.endUpdates()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
                    updateUndoRedo(sender)
                }
            }
        } else {
            var deletedRows = Set<Int>() // Gunakan Set untuk menyimpan indeks yang dihapus

            for index in selectedRows {
                let rowInfo = getRowInfoForRow(index)
                let groupIndex = rowInfo.sectionIndex
                let rowIndexInSection = rowInfo.rowIndexInSection
                guard groupIndex < viewModel.groupedSiswa.count, rowIndexInSection < viewModel.groupedSiswa[groupIndex].count else {
                    continue
                }

                // Simpan data siswa yang akan dihapus
                let deletedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]
                tempDeletedSiswaArray.append(deletedSiswa)
                tempDeletedIndexes.append(index)
                deletedRows.insert(index) // Tambahkan indeks yang dihapus ke Set
                deletedStudentIDs.append(deletedSiswa.id)
                SingletonData.deletedStudentIDs.append(deletedSiswa.id)
                DispatchQueue.main.async { [unowned self] in
                    if index == tableView.numberOfRows - 1 {
                        tableView.selectRowIndexes(IndexSet(integer: index - 1), byExtendingSelection: false)
                    } else {
                        tableView.selectRowIndexes(IndexSet(integer: index + 1), byExtendingSelection: false)
                    }
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": deletedStudentIDs,
                        "kelasSekarang": deletedSiswa.tingkatKelasAktif.rawValue,
                        "isDeleted": true,
                        "hapusDiSiswa": true,
                    ]
                    NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                }
            }

            SingletonData.deletedSiswasArray.append(tempDeletedSiswaArray)

            // Urutkan indeks yang dihapus secara descending
            let sortedIndexes = tempDeletedIndexes.sorted(by: >)

            for index in sortedIndexes {
                let rowInfo = getRowInfoForRow(index)
                let groupIndex = rowInfo.sectionIndex
                // Hapus baris dari grup
                viewModel.removeGroupSiswa(groupIndex: groupIndex, index: rowInfo.rowIndexInSection)
            }
            // Hapus baris dari tabel
            DispatchQueue.main.async { [unowned self] in
                tableView.beginUpdates()
                tableView.removeRows(at: IndexSet(deletedRows), withAnimation: .slideUp)
                tableView.endUpdates()
                updateUndoRedo(sender)
            }
        }
    }

    /**
     *  Fungsi ini dipanggil ketika sebuah baris (data siswa) dipilih untuk dihapus.
     *  Fungsi ini menangani penghapusan data siswa dari sumber data dan memperbarui tampilan tabel.
     *  Selain itu, fungsi ini juga mencatat tindakan penghapusan untuk mendukung fitur undo.
     *
     *  @param row Indeks baris yang diklik kanan dan akan dihapus.
     *
     *  Proses:
     *  1. Memastikan indeks baris yang diberikan valid.
     *  2. Mendaftarkan tindakan undo dengan `SiswaViewModel.siswaUndoManager`.
     *  3. Menentukan mode tampilan tabel saat ini (plain atau grouped).
     *  4. Menghapus data siswa yang sesuai dari sumber data berdasarkan mode tampilan.
     *  5. Memposting pemberitahuan (`siswaDihapus`) untuk memberitahu komponen lain tentang penghapusan.
     *  6. Menghapus baris dari tampilan tabel dengan animasi slide up.
     *  7. Memperbarui pilihan baris setelah penghapusan.
     *  8. Memperbarui status undo/redo setelah penundaan singkat.
     */
    @objc func deleteDataClicked(_ row: Int) {
        // Dapatkan baris yang diklik kanan
        let clickedRow = row
        guard row >= 0 else { return }
        deleteAllRedoArray(self)
        // Catat tindakan undo dengan data yang dihapus
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoDeleteMultipleData(self)
        }
        SiswaViewModel.siswaUndoManager.setActionName("Delete Data")
        if currentTableViewMode == .plain {
            let deletedSiswa = viewModel.filteredSiswaData[clickedRow]
            SingletonData.deletedSiswasArray.append([deletedSiswa])
            viewModel.removeSiswa(at: clickedRow)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SingletonData.deletedStudentIDs.append(deletedSiswa.id)
                let userInfo: [String: Any] = [
                    "deletedStudentIDs": [deletedSiswa.id],
                    "kelasSekarang": deletedSiswa.tingkatKelasAktif.rawValue,
                    "isDeleted": true,
                    "hapusDiSiswa": true,
                ]
                NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
            }
        } else if currentTableViewMode == .grouped {
            let selectedRowInfo = getRowInfoForRow(clickedRow)
            let groupIndex = selectedRowInfo.sectionIndex
            let rowIndexInSection = selectedRowInfo.rowIndexInSection
            let deletedSiswa = viewModel.groupedSiswa[groupIndex][rowIndexInSection]

            // Retrieve the name of the student before removal
            // let removedSiswaName = viewModel.groupedSiswa[groupIndex][rowIndexInSection].nama
            SingletonData.deletedSiswasArray.append([deletedSiswa])
            // Remove the student from viewModel.groupedSiswa
            viewModel.removeGroupSiswa(groupIndex: groupIndex, index: rowIndexInSection)
            SingletonData.deletedStudentIDs.append(deletedSiswa.id)
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [deletedSiswa.id],
                "kelasSekarang": deletedSiswa.tingkatKelasAktif.rawValue,
                "isDeleted": true,
                "hapusDiSiswa": true,
            ]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
            }
        }
        // Hapus data dari tabel
        tableView.removeRows(at: IndexSet(integer: clickedRow), withAnimation: .slideUp)

        if clickedRow == tableView.numberOfRows {
            tableView.selectRowIndexes(IndexSet(integer: clickedRow - 1), byExtendingSelection: false)
        } else {
            tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(self)
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
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor, !SingletonData.deletedSiswasArray.isEmpty else {
            return
        }
        handleSearchField()
        var tempDeletedIndexes = Set<Int>()
        let lastDeletedSiswaArray = SingletonData.deletedSiswasArray.last!
        tableView.beginUpdates()
        for siswa in lastDeletedSiswaArray {
            if (isBerhentiHidden && siswa.status.description.lowercased() == "berhenti") || (!UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") && siswa.status.description.lowercased() == "lulus") {
                SingletonData.deletedStudentIDs.removeAll { $0 == siswa.id }
                DispatchQueue.main.async {
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": [siswa.id],
                        "kelasSekarang": siswa.tingkatKelasAktif.rawValue,
                        "isDeleted": true,
                        "hapusDiSiswa": true,
                    ]
                    NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
                }
                break
            }
            if currentTableViewMode == .plain {
                let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
                viewModel.insertSiswa(siswa, at: insertIndex)
                tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
                tempDeletedIndexes.insert(insertIndex)
                SingletonData.deletedStudentIDs.removeAll { $0 == siswa.id }
                DispatchQueue.main.async {
                    let userInfo: [String: Any] = [
                        "deletedStudentIDs": [siswa.id],
                        "kelasSekarang": siswa.tingkatKelasAktif.rawValue,
                        "isDeleted": true,
                        "hapusDiSiswa": true,
                    ]
                    NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
                }
            } else if currentTableViewMode == .grouped {
                if let groupIndex = siswa.status == .lulus
                    ? getGroupIndex(forClassName: StatusSiswa.lulus.description)
                    : getGroupIndex(forClassName: siswa.tingkatKelasAktif.rawValue)
                {
                    let insertIndex = viewModel.groupedSiswa[groupIndex].insertionIndex(for: siswa, using: sortDescriptor)
                    viewModel.insertGroupSiswa(siswa, groupIndex: groupIndex, index: insertIndex)
                    let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: groupIndex, rowIndexInSection: insertIndex)
                    tableView.insertRows(at: IndexSet(integer: absoluteRowIndex + 1), withAnimation: .slideDown)
                    tempDeletedIndexes.insert(absoluteRowIndex + 1)
                    SingletonData.deletedStudentIDs.removeAll { $0 == siswa.id }
                    DispatchQueue.main.async {
                        let userInfo: [String: Any] = [
                            "deletedStudentIDs": [siswa.id],
                            "kelasSekarang": siswa.tingkatKelasAktif.rawValue,
                            "isDeleted": true,
                            "hapusDiSiswa": true,
                        ]
                        NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
                    }
                }
            }
        }
        previouslySelectedRows = tableView.selectedRowIndexes
        for index in tableView.selectedRowIndexes {
            tableView.deselectRow(index)
        }
        for selection in lastDeletedSiswaArray {
            if currentTableViewMode == .plain {
                if let index = viewModel.filteredSiswaData.firstIndex(where: { $0.id == selection.id }) {
                    DispatchQueue.main.async {
                        self.tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: true)
                    }
                }
            } else {
                for (groupIndex, group) in viewModel.groupedSiswa.enumerated() {
                    if let siswaIndex = group.firstIndex(where: { $0.id == selection.id }) {
                        let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: groupIndex, rowIndexInSection: siswaIndex) + 1
                        tableView.selectRowIndexes(IndexSet(integer: absoluteRowIndex), byExtendingSelection: true)
                    }
                }
            }
        }
        tableView.endUpdates()
        SingletonData.deletedSiswasArray.removeLast()
        if let maxIndex = tempDeletedIndexes.max() {
            tableView.scrollRowToVisible(maxIndex)
        }
        // Simpan data yang dihapus untuk redo
        redoDeletedSiswaArray.append(lastDeletedSiswaArray)

        // Catat tindakan redo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.redoDeleteMultipleData(sender)
        }

        // Update UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(sender)
        }
        let hasBerhentiAndFiltered = lastDeletedSiswaArray.contains(where: { $0.status.description == "Berhenti" }) && isBerhentiHidden
        let hasLulusAndDisplayed = lastDeletedSiswaArray.contains(where: { $0.status.description == "Lulus" }) && !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus")

        if hasBerhentiAndFiltered {
            ReusableFunc.showAlert(
                title: "Filter Tabel Siswa Berhenti Aktif",
                message: "Data status siswa yang akan diinsert adalah siswa yang difilter. Data yang difilter akan ditampilkan saat filter dinonaktifkan."
            )
        }
        if hasLulusAndDisplayed {
            ReusableFunc.showAlert(
                title: "Filter Tabel Siswa Lulus Aktif",
                message: "Data status siswa yang akan diinsert adalah siswa yang difilter. Data yang difilter akan ditampilkan saat filter dinonaktifkan."
            )
        }
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
     *
     *  - Versi: 1.0
     */
    func redoDeleteMultipleData(_ sender: Any) {
        delegate?.didUpdateTable(.siswa)
        handleSearchField()
        let lastRedoDeletedSiswaArray = redoDeletedSiswaArray.removeLast()
        // Simpan data yang dihapus untuk undo
        SingletonData.deletedSiswasArray.append(lastRedoDeletedSiswaArray)
        // Lakukan penghapusan kembali
        var lastIndex = [Int]()
        tableView.beginUpdates()
        var deletedStudentIDs = [Int64]()
        for deletedSiswa in lastRedoDeletedSiswaArray {
            if currentTableViewMode == .plain {
                if let index = viewModel.filteredSiswaData.firstIndex(where: { $0.id == deletedSiswa.id }) {
                    viewModel.removeSiswa(at: index)
                    // Hapus data dari tabel
                    tableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                    if index == tableView.numberOfRows - 1 {
                        tableView.selectRowIndexes(IndexSet(integer: index - 1), byExtendingSelection: false)
                        lastIndex.append(index - 1)
                    } else {
                        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                        lastIndex.append(index)
                    }
                    deletedStudentIDs.append(deletedSiswa.id)
                    SingletonData.deletedStudentIDs.append(deletedSiswa.id)
                    DispatchQueue.main.async {
                        let userInfo: [String: Any] = [
                            "deletedStudentIDs": deletedStudentIDs,
                            "kelasSekarang": deletedSiswa.tingkatKelasAktif.rawValue,
                            "isDeleted": true,
                            "hapusDiSiswa": true,
                        ]
                        NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                    }
                }
            } else if currentTableViewMode == .grouped {
                // Temukan grup yang berisi siswa yang dihapus
                for (groupIndex, group) in viewModel.groupedSiswa.enumerated() {
                    if let siswaIndex = group.firstIndex(where: { $0.id == deletedSiswa.id }) {
                        let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: groupIndex, rowIndexInSection: siswaIndex) + 1
                        // Hapus siswa dari grup dan tabel
                        if absoluteRowIndex == tableView.numberOfRows - 1 {
                            tableView.selectRowIndexes(IndexSet(integer: absoluteRowIndex - 1), byExtendingSelection: false)
                            lastIndex.append(absoluteRowIndex - 1)
                        } else {
                            tableView.selectRowIndexes(IndexSet(integer: absoluteRowIndex + 1), byExtendingSelection: false)
                            lastIndex.append(absoluteRowIndex + 1)
                        }
                        deletedStudentIDs.append(deletedSiswa.id)
                        viewModel.removeGroupSiswa(groupIndex: groupIndex, index: siswaIndex)
                        tableView.removeRows(at: IndexSet(integer: absoluteRowIndex), withAnimation: .slideUp)
                        SingletonData.deletedStudentIDs.append(deletedSiswa.id)
                        DispatchQueue.main.async {
                            let userInfo: [String: Any] = [
                                "deletedStudentIDs": deletedStudentIDs,
                                "kelasSekarang": deletedSiswa.tingkatKelasAktif.rawValue,
                                "isDeleted": true,
                                "hapusDiSiswa": true,
                            ]
                            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
                        }
                    }
                }
//                tableView.reloadData()
//                tableView.hideRows(at: IndexSet(integer: 0), withAnimation: .slideUp)
            }
        }
        tableView.endUpdates()
        if let maxIndeks = lastIndex.max() {
            if maxIndeks >= tableView.numberOfRows - 1 {
                tableView.scrollToEndOfDocument(sender)
            } else {
                tableView.scrollRowToVisible(maxIndeks)
            }
        }
        // Catat tindakan undo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoDeleteMultipleData(sender)
        }

        // Update UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(sender)
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

    private func handleSearchField(_ handleGroup: Bool = true) {
        if !stringPencarian.isEmpty {
            view.window?.makeFirstResponder(tableView)
            if currentTableViewMode == .plain {
                filterDeletedSiswa()
                if let toolbar = view.window?.toolbar,
                   let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem
                {
                    stringPencarian.removeAll()
                    searchFieldToolbarItem.searchField.stringValue = ""
                }
            } else if handleGroup {
                if let sortDescriptor = tableView.sortDescriptors.first {
                    urutkanDataPencarian(with: sortDescriptor)
                }
            }
        }
    }

    /**
     * Fungsi ini membatalkan operasi tempel terakhir yang dilakukan pada tabel siswa.
     *
     * Fungsi ini melakukan langkah-langkah berikut:
     * 1. Membatalkan pilihan semua baris yang dipilih pada tabel.
     * 2. Jika ada string pencarian yang aktif, fungsi ini akan membersihkan string pencarian dan memperbarui tampilan tabel sesuai.
     * 3. Mengambil array siswa yang terakhir ditempel dari `pastedSiswasArray`.
     * 4. Menyimpan array siswa yang dihapus ke `SingletonData.redoPastedSiswaArray` untuk operasi redo.
     * 5. Menghapus siswa dari sumber data dan tabel.
     * 6. Memilih baris yang sesuai setelah penghapusan dan menggulir tampilan ke baris tersebut.
     * 7. Mendaftarkan tindakan undo dengan `SiswaViewModel.siswaUndoManager` untuk memungkinkan operasi redo.
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
        var tempDeletedIndexes = [Int]()
        // Simpan data yang dihapus untuk undo
        SingletonData.redoPastedSiswaArray.append(lastRedoDeletedSiswaArray)
        // Lakukan penghapusan kembali
        tableView.beginUpdates()
        for deletedSiswa in lastRedoDeletedSiswaArray {
            if !SingletonData.deletedStudentIDs.contains(deletedSiswa.id) {
                SingletonData.deletedStudentIDs.append(deletedSiswa.id)
            }
            if currentTableViewMode == .plain, let index = viewModel.filteredSiswaData.firstIndex(where: { $0.id == deletedSiswa.id }) {
                viewModel.removeSiswa(at: index)
                // Hapus data dari tabel
                tableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                tempDeletedIndexes.append(index)
            } else {
                for (groupIndex, group) in viewModel.groupedSiswa.enumerated() {
                    // Cari matchedSiswaData dalam grup saat ini
                    if let matchedSiswaData = group.first(where: { $0.id == deletedSiswa.id }),
                       let siswaIndex = group.firstIndex(where: { $0.id == matchedSiswaData.id })
                    {
                        viewModel.removeGroupSiswa(groupIndex: groupIndex, index: siswaIndex)
                        let rowIndex = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: siswaIndex)
                        tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .effectFade)
                        tempDeletedIndexes.append(rowIndex)
                    }
                }
            }
            // dbController.hapusDaftar(idValue: deletedSiswa.id)
        }
        tableView.endUpdates()

        for index in tempDeletedIndexes {
            if index >= tableView.numberOfRows - 1 {
                tableView.selectRowIndexes(IndexSet(integer: index - 1), byExtendingSelection: false)
                tableView.scrollToEndOfDocument(sender)
            } else {
                tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                tableView.scrollRowToVisible(index + 1)
            }
        }

        // Catat tindakan undo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { target in
            target.redoPaste(sender)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(sender)
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
     *      - Fungsi ini memanggil `updateUndoRedo` untuk memperbarui status tombol 'undo' dan 'redo' pada antarmuka pengguna.
     */
    func redoPaste(_ sender: Any) {
        delegate?.didUpdateTable(.siswa)
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor else {
            return
        }
        handleSearchField()

        var tempDeletedSiswaArray = [ModelSiswa]()
        var tempDeletedIndexes = [Int]()
        let lastDeletedSiswaArray = SingletonData.redoPastedSiswaArray.removeLast()
        tableView.deselectAll(sender)
        tableView.beginUpdates()
        for siswa in lastDeletedSiswaArray {
            SingletonData.deletedStudentIDs.removeAll { $0 == siswa.id }
            if currentTableViewMode == .plain {
                let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
                viewModel.insertSiswa(siswa, at: insertIndex)
                tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
                tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)
                tempDeletedSiswaArray.append(siswa)
                tempDeletedIndexes.append(insertIndex)
            } else {
                // Hitung ulang indeks penyisipan berdasarkan grup yang baru
                let insertIndex = viewModel.groupedSiswa[7].insertionIndex(for: siswa, using: sortDescriptor)

                // Sisipkan siswa kembali ke dalam array viewModel.groupedSiswa pada grup yang tepat
                viewModel.insertGroupSiswa(siswa, groupIndex: 7, index: insertIndex)

                // Menghitung jumlah baris dalam grup-grup sebelum grup saat ini
                let absoluteRowIndex = calculateAbsoluteRowIndex(groupIndex: 7, rowIndexInSection: insertIndex)

                tableView.insertRows(at: IndexSet(integer: absoluteRowIndex + 1), withAnimation: .slideDown)
                tableView.selectRowIndexes(IndexSet(integer: absoluteRowIndex + 1), byExtendingSelection: true)
                tempDeletedSiswaArray.append(siswa)
                tempDeletedIndexes.append(insertIndex)
            }
        }
        tableView.endUpdates()
        if let maxIndex = tempDeletedIndexes.max() {
            if maxIndex >= tableView.numberOfRows - 1 {
                tableView.scrollToEndOfDocument(sender)
            } else {
                tableView.scrollRowToVisible(maxIndex)
            }
        }
        // Simpan data yang dihapus untuk redo
        pastedSiswasArray.append(tempDeletedSiswaArray)
        // Catat tindakan redo
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.undoPaste(sender)
        }
        // Update UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            updateUndoRedo(sender)
        }
    }

    // Fungsi pembantu untuk membungkus pembaruan UI
    /**
         Memperbarui tampilan foto kelas aktif dengan border pada baris tertentu dalam tabel.

         Fungsi ini secara asinkron memperbarui gambar (image view) pada sel tabel yang sesuai dengan baris yang diberikan.
         Gambar yang ditampilkan bergantung pada nilai `kelas`. Jika `kelas` adalah "Lulus", gambar "lulus Bordered" akan ditampilkan.
         Jika `kelas` kosong, gambar "No Data Bordered" akan ditampilkan. Jika tidak, gambar dengan nama "\(kelas) Bordered" akan ditampilkan.

         - Parameter:
            - selectedRowIndexes: Indeks baris yang akan diperbarui.
            - newKelasAktifString: String yang menentukan kelas yang akan ditampilkan. String ini digunakan untuk menentukan gambar yang akan ditampilkan.
     */
    func refreshTableViewCells(for selectedRowIndexes: IndexSet, newKelasAktifString: String) {
        for rowIndex in selectedRowIndexes {
            if let namaView = tableView.view(atColumn: columnIndexOfKelasAktif, row: rowIndex, makeIfNecessary: false) as? NSTableCellView,
               let imageView = namaView.imageView
            {
                if let kelasAktif = KelasAktif(rawValue: newKelasAktifString) {
                    let imageName = kelasAktif.rawValue
                    if tableView.selectedRowIndexes.contains(rowIndex) {
                        imageView.image = NSImage(named: "\(imageName) Bordered")
                    } else {
                        imageView.image = NSImage(named: "\(imageName)")
                    }
                }
            }
            if let tglView = tableView.view(atColumn: ReusableFunc.columnIndex(of: tglLulusColumn, in: tableView), row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                tglView.textField?.stringValue = ""
            }
        }
        tableView.reloadData(forRowIndexes: selectedRowIndexes, columnIndexes: IndexSet(integer: columnIndexOfStatus))
    }

    /// Hapus semua array untuk redo.
    /// - Parameter sender: Objek pemicu apapun.
    func deleteAllRedoArray(_: Any) {
        if !redoDeletedSiswaArray.isEmpty { redoDeletedSiswaArray.removeAll() }
        if !SingletonData.redoPastedSiswaArray.isEmpty { SingletonData.redoPastedSiswaArray.removeAll() }
        ulangsiswaBaruArray.removeAll()
    }
}
