//
//  SiswaViewHandleNotification.swift
//  Data SDI
//
//  Created by Bismillah on 12/01/25.
//

import Cocoa

extension SiswaViewController {
    // MARK: - EDIT DATA

    func handleUndoActionGrouped(id: Int64, groupIndex: Int? = nil, rowInSection: Int? = nil, columnIndex: Int) {
        let siswa = dbController.getSiswa(idValue: id)

        if isBerhentiHidden, siswa.status == .berhenti, let sortDescriptor = ModelSiswa.currentSortDescriptor {
            let newGroupIndex = siswa.status == .lulus
                ? getGroupIndex(forClassName: StatusSiswa.lulus.description) ?? groupIndex
                : getGroupIndex(forClassName: siswa.tingkatKelasAktif.rawValue)
            let insertIndex = viewModel.groupedSiswa[newGroupIndex!].insertionIndex(for: siswa, using: sortDescriptor)
            guard !viewModel.groupedSiswa[newGroupIndex!].contains(where: { $0.id == siswa.id }) else { return }
            viewModel.insertGroupSiswa(siswa, groupIndex: newGroupIndex!, index: insertIndex)
            let absoluteIndex = viewModel.getAbsoluteRowIndex(groupIndex: newGroupIndex!, rowIndex: insertIndex)
            tableView.insertRows(at: IndexSet([absoluteIndex]), withAnimation: .slideUp)
            tableView.selectRowIndexes(IndexSet([absoluteIndex]), byExtendingSelection: false)
            tableView.scrollRowToVisible(absoluteIndex)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.viewModel.removeGroupSiswa(groupIndex: newGroupIndex!, index: insertIndex)
                self?.tableView.removeRows(at: IndexSet(integer: absoluteIndex), withAnimation: .effectFade)
            }
            return
        }

        if let groupIndex, let rowInSection {
            let rowTable = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: rowInSection)
            tableView.reloadData(forRowIndexes: IndexSet([rowTable]), columnIndexes: IndexSet([columnIndex]))
            tableView.selectRowIndexes(IndexSet([rowTable]), byExtendingSelection: false)
            tableView.scrollRowToVisible(rowTable)
        }
    }

    @objc func handleUndoActionNotification(_ notification: Notification) {
        delegate?.didUpdateTable(.siswa)
        guard let userInfo = notification.userInfo,
              let id = userInfo["id"] as? Int64,
              let columnIdentifier = userInfo["columnIdentifier"] as? SiswaColumn
        else {
            return
        }
        guard let columnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnIdentifier.rawValue }) else { return }

        if currentTableViewMode == .grouped {
            if notification.userInfo?["isGrouped"] as? Bool == true,
               let groupIndex = userInfo["groupIndex"] as? Int,
               let rowInSection = userInfo["rowInSection"] as? Int
            {
                handleUndoActionGrouped(id: id, groupIndex: groupIndex, rowInSection: rowInSection, columnIndex: columnIndex)
            } else {
                handleUndoActionGrouped(id: id, columnIndex: columnIndex)
            }
            updateUndoRedo(nil)
            return
        }

        // Perbarui tabel
        if let indexTableView = viewModel.filteredSiswaData.firstIndex(where: { $0.id == id }) {
            tableView.reloadData(forRowIndexes: IndexSet(integer: indexTableView), columnIndexes: IndexSet(integer: columnIndex))
            tableView.selectRowIndexes(IndexSet([indexTableView]), byExtendingSelection: false)
            tableView.scrollRowToVisible(indexTableView)
        } else {
            var rowIndexToUpdate: Int!
            let siswaToUpdate = dbController.getSiswa(idValue: id)
            if isBerhentiHidden, siswaToUpdate.status == .berhenti {
                guard let sortDescriptor = ModelSiswa.currentSortDescriptor else { return }
                let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswaToUpdate, using: sortDescriptor)
                guard !viewModel.filteredSiswaData.contains(where: { $0.id == siswaToUpdate.id }) else { return }
                viewModel.insertSiswa(siswaToUpdate, at: insertIndex)
                tableView.insertRows(at: IndexSet([insertIndex]), withAnimation: .slideUp)
                tableView.selectRowIndexes(IndexSet([insertIndex]), byExtendingSelection: false)
                rowIndexToUpdate = insertIndex
            }
            if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus"), siswaToUpdate.status == .lulus {
                guard let sortDescriptor = ModelSiswa.currentSortDescriptor else { return }
                let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswaToUpdate, using: sortDescriptor)
                guard !viewModel.filteredSiswaData.contains(where: { $0.id == siswaToUpdate.id }) else { return }
                viewModel.insertSiswa(siswaToUpdate, at: insertIndex)
                tableView.insertRows(at: IndexSet([insertIndex]), withAnimation: .slideUp)
                tableView.selectRowIndexes(IndexSet([insertIndex]), byExtendingSelection: false)
                rowIndexToUpdate = insertIndex
            }
            guard rowIndexToUpdate != nil else { return }

            // Perbarui tampilan tabel hanya untuk baris yang diubah
            tableView.reloadData(forRowIndexes: IndexSet([rowIndexToUpdate]), columnIndexes: IndexSet([columnIndex]))
            tableView.selectRowIndexes(IndexSet([rowIndexToUpdate]), byExtendingSelection: false)
            tableView.scrollRowToVisible(rowIndexToUpdate)

            // Simpan nilai lama ke dalam array redo
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                viewModel.removeSiswa(at: rowIndexToUpdate)
                tableView.removeRows(at: IndexSet([rowIndexToUpdate]), withAnimation: .effectFade)
            }
        }
        updateUndoRedo(self)
    }

    @objc func receivedNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let ids = userInfo["ids"] as? [Int64],
              let updateKelas = userInfo["updateKelas"] as? Bool,
              let tahunAjaran = userInfo["tahunAjaran"] as? String,
              let semester = userInfo["semester"] as? String,
              let kelas = userInfo["kelas"] as? String,
              let status = userInfo["status"] as? StatusSiswa
        else { return }

        Task.detached(priority: .userInitiated) { [unowned self, ids, updateKelas, tahunAjaran, semester, status] in
            // Gunakan tuple untuk mengembalikan dua nilai dari setiap Task
            let results: [(IndexSet, UndoNaikKelasContext?)] = await withTaskGroup(of: (IndexSet, UndoNaikKelasContext?).self) { group in
                var results = [(IndexSet, UndoNaikKelasContext?)]()

                let formatSemester = semester.hasPrefix("Semester ")
                    ? semester.replacingOccurrences(of: "Semester ", with: "")
                    : semester
                let tingkatKelas = kelas.replacingOccurrences(of: "Kelas ", with: "")
                let intoKelasID = await dbController.insertOrGetKelasID(nama: "A", tingkat: tingkatKelas, tahunAjaran: tahunAjaran, semester: formatSemester)
                for id in ids {
                    var snapshot: UndoNaikKelasContext? = nil

                    if updateKelas,
                       let newSnapshot = dbController.naikkanSiswa(
                           id,
                           intoKelasId: intoKelasID,
                           tingkatBaru: tingkatKelas,
                           tahunAjaran: tahunAjaran,
                           semester: formatSemester,
                           tanggalNaik: ReusableFunc.buatFormatTanggal(Date())!,
                           statusEnrollment: status
                       )
                    {
                        snapshot = newSnapshot
                    }
                    group.addTask { [snapshot, weak self] in
                        guard let self else { return (IndexSet(integer: -1), nil) }
                        // Cari IndexSet
                        var indexSet = IndexSet()
                        if await currentTableViewMode == .plain {
                            if let index = viewModel.filteredSiswaData.firstIndex(where: { $0.id == id }) {
                                indexSet.insert(index)
                            }
                        } else {
                            for (section, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                                if let rowIndex = siswaGroup.firstIndex(where: { $0.id == id }) {
                                    let tableIndex = viewModel.getAbsoluteRowIndex(groupIndex: section, rowIndex: rowIndex)
                                    indexSet.insert(tableIndex)
                                    break
                                }
                            }
                        }

                        return (indexSet, snapshot)
                    }
                }

                // Kumpulkan hasil dari semua task
                for await result in group {
                    results.append(result)
                }

                return results
            }

            // Gabungkan hasil di sini
            var combinedIndexSet = IndexSet()
            var combinedSnapshot = [UndoNaikKelasContext]()

            for (indexSet, snapshot) in results {
                combinedIndexSet.formUnion(indexSet)
                if let snapshot {
                    combinedSnapshot.append(snapshot)
                }
            }

            // Lakukan pembaruan UI di Main Actor setelah semua data siap
            await MainActor.run { [combinedIndexSet, combinedSnapshot] in
                updateDataInBackground(selectedRowIndexes: combinedIndexSet, updateKelas: updateKelas, snapshot: combinedSnapshot)
            }
        }
    }

    func updateDataInBackground(selectedRowIndexes: IndexSet, updateKelas: Bool, snapshot: [UndoNaikKelasContext]) {
        deleteAllRedoArray(self) /* hapus data redo */
        func sendKelasEvent(_ updatedSiswa: ModelSiswa, siswa: ModelSiswa) {
            if updatedSiswa.status == .berhenti || updatedSiswa.status == .lulus {
                viewModel.kelasEvent.send(.undoAktifkanSiswa(siswa.id, kelas: siswa.tingkatKelasAktif.rawValue))
            }
        }
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor else {
            #if DEBUG
                print("sortDescriptor Error")
            #endif
            return
        } /// * key urutan data

        let tampilkanSiswaLulus = UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") /// * pengaturan status siswa lulus ditampilkan atau tidak

        let numberOfColumns = tableView.numberOfColumns /// * Jumlah kolom tableView

        let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil) /// * storyboard progress untuk pembaruan

        /// * pemeriksaan instantiate (initial view) di storyboard (initial view di storyboard di atas di-set ke Window dengan owner UpdateProgressWindowController) dan pemeriksaan viewController untuk progressWindowController (di storyboard di atas viewController berupa ProgressBarVC).
        guard let progressWindowController = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController,
              let progressViewController = progressWindowController.contentViewController as? ProgressBarVC else { return }

        progressViewController.totalStudentsToUpdate = selectedSiswaList.count /// * Menetapkan total siswa yang akan diperbarui
        progressViewController.controller = "Siswa" /// * Menetapkan label default di jendela progress

        /// * Loop melalui setiap rowIndex yang dipilih
        if currentTableViewMode == .plain {
            let selectedSiswaRow: [ModelSiswa] = tableView.selectedRowIndexes.compactMap { row in
                let originalSiswa = viewModel.filteredSiswaData[row]
                return originalSiswa.copy() as? ModelSiswa
            }
            let selectedRows = selectedRowIndexes
            selectedSiswaList = selectedRows.map { viewModel.filteredSiswaData[$0] }

            var siswaData: [(index: Int, data: ModelSiswa)] = []
            var updatedSiswa: [ModelSiswa] = []

            view.window?.beginSheet(progressWindowController.window!)

            for (index, siswa) in selectedSiswaList.reversed().enumerated() {
                guard let SiswaIndex = viewModel.filteredSiswaData.firstIndex(where: { $0.id == siswa.id }) else { return }
                let siswas = dbController.getSiswa(idValue: viewModel.filteredSiswaData[SiswaIndex].id)
                viewModel.removeSiswa(at: SiswaIndex)
                let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswas, using: sortDescriptor)
                viewModel.insertSiswa(siswas, at: insertIndex)
                updatedSiswa.append(siswas)
                // Reload baris yang diperbarui
                DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(index) * 0.1) { [unowned self] in
                    progressViewController.controller = siswas.nama
                    tableView.moveRow(at: SiswaIndex, to: insertIndex)
                    tableView.scrollRowToVisible(insertIndex)
                    tableView.reloadData(forRowIndexes: IndexSet(integer: insertIndex), columnIndexes: IndexSet(integersIn: 0 ..< numberOfColumns))
                    progressViewController.currentStudentIndex = index + 1

                    if (isBerhentiHidden && siswas.status == .berhenti) || (!tampilkanSiswaLulus && siswas.status == .lulus) {
                        siswaData.append((insertIndex, siswas))
                    }
                    sendKelasEvent(siswas, siswa: siswa)
                }
            }

            if updateKelas {
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
                    self?.handleUndoNaikKelas(contexts: snapshot, siswa: selectedSiswaRow)
                }
            } else {
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
                    self?.viewModel.undoEditSiswa(selectedSiswaRow)
                }
            }

            /*
             Sangat penting untuk menghentikan undo grouping jika sebelumnya telah dimulai ketika memperbarui foto siswa
             di EditData.
             */
            SiswaViewModel.siswaUndoManager.endUndoGrouping()

            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(selectedSiswaList.count) * 0.12) { [unowned self] in
                if isBerhentiHidden || !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
                    for (int, data) in siswaData.reversed() {
                        if (data.status == .berhenti && isBerhentiHidden) || (data.status == .lulus && !tampilkanSiswaLulus) {
                            viewModel.removeSiswa(at: int)

                            if int == tableView.numberOfRows - 1 {
                                tableView.selectRowIndexes(IndexSet([tableView.numberOfRows - 2]), byExtendingSelection: false)
                            }
                            tableView.removeRows(at: IndexSet([int]), withAnimation: .effectFade)
                        }
                    }
                }

                view.window?.endSheet(progressWindowController.window!)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
                    updateUndoRedo(self)
                }
            }
        }

        /// * Logika untuk mode grouped
        else if currentTableViewMode == .grouped {
            var operations: [() -> Void] = [] /// * Kumpulkan operasi tableView
            var lastMovedToVisualIndex: Int? /// * Untuk scroll ke item terakhir yang diproses

            let selectedSiswaRow = tableView.selectedRowIndexes.compactMap { rowIndex -> ModelSiswa? in
                let selectedRowInfo = getRowInfoForRow(rowIndex)
                let groupIndex = selectedRowInfo.sectionIndex
                let rowIndexInSection = selectedRowInfo.rowIndexInSection
                guard rowIndexInSection >= 0 else { return nil }
                return viewModel.groupedSiswa[groupIndex][rowIndexInSection]
            }

            var siswaData: [(group: Int, index: Int, data: ModelSiswa)] = []

            /// * tampilkan jendela progress sheets
            view.window?.beginSheet(progressWindowController.window!)

            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
            for (index, siswa) in selectedSiswaList.reversed().enumerated() {
                guard let (groupIndex, rowIndex) = viewModel.findSiswaInGroups(id: siswa.id) else { continue }

                let updatedSiswa = dbController.getSiswa(idValue: siswa.id)

                viewModel.updateGroupSiswa(updatedSiswa, groupIndex: groupIndex, index: rowIndex)

                if siswa.tingkatKelasAktif != updatedSiswa.tingkatKelasAktif {
                    let oldAbsoluteVisualIndex = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: rowIndex) // Hitung SEBELUM remove/insert berikutnya

                    guard let newGroupIndex = updatedSiswa.status == .lulus
                        ? getGroupIndex(forClassName: KelasAktif.lulus.rawValue) ?? groupIndex
                        : getGroupIndex(forClassName: updatedSiswa.tingkatKelasAktif.rawValue)
                    else { continue }

                    viewModel.removeGroupSiswa(groupIndex: groupIndex, index: rowIndex)

                    let insertIndex = viewModel.groupedSiswa[newGroupIndex].insertionIndex(for: updatedSiswa, using: sortDescriptor)

                    viewModel.insertGroupSiswa(updatedSiswa, groupIndex: newGroupIndex, index: insertIndex)
                    let newAbsoluteVisualIndex = viewModel.getAbsoluteRowIndex(groupIndex: newGroupIndex, rowIndex: insertIndex) // Hitung SETELAH remove/insert
                    lastMovedToVisualIndex = newAbsoluteVisualIndex // Simpan untuk scroll nanti

                    operations.append { [weak self] in // Tambahkan operasi move ke antrian
                        self?.tableView.moveRow(at: oldAbsoluteVisualIndex, to: newAbsoluteVisualIndex)
                        self?.tableView.reloadData(forRowIndexes: IndexSet(integer: newAbsoluteVisualIndex), columnIndexes: IndexSet(integersIn: 0 ..< numberOfColumns))
                    }
                    if isBerhentiHidden, updatedSiswa.status == .berhenti || !tampilkanSiswaLulus, updatedSiswa.status == .lulus {
                        siswaData.append((groupIndex, rowIndex, updatedSiswa))
                    }
                } else {
                    let absoluteRowIndex = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: rowIndex)
                    lastMovedToVisualIndex = absoluteRowIndex // Simpan untuk scroll nanti

                    operations.append { [weak self] in // Tambahkan operasi reload ke antrian
                        self?.tableView.reloadData(forRowIndexes: IndexSet(integer: absoluteRowIndex), columnIndexes: IndexSet(integersIn: 0 ..< numberOfColumns))
                    }
                    if isBerhentiHidden && updatedSiswa.status == .berhenti || (!UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") && updatedSiswa.status == .lulus) {
                        siswaData.append((groupIndex, rowIndex, updatedSiswa))
                    }
                }
                // Update progress bar bisa tetap di sini atau digabungkan dengan loop berikutnya
                // Untuk efek visual per item, jeda kecil masih bisa dipertahankan untuk progress bar saja
                DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(index) * 0.01) { // Jeda sangat kecil
                    progressViewController.controller = updatedSiswa.nama
                    progressViewController.currentStudentIndex = index + 1
                    sendKelasEvent(updatedSiswa, siswa: siswa)
                }
            }

            let finalDelay = max(TimeInterval(selectedSiswaList.count) * 0.01, 0.5) /// * Delay setelah data di viewModel diperbarui.
            DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) { [weak self] in
                guard let self else { return }
                view.window?.endSheet(progressWindowController.window!)

                tableView.beginUpdates() /// ** Perbarui TableView secara komprehensif

                operations.forEach { $0() } /// * Jalankan semua moveRow dan reloadData

                /// * Scroll ke lokasi baris yang dipindahkan.
                if let targetIndex = lastMovedToVisualIndex, targetIndex < tableView.numberOfRows {
                    tableView.scrollRowToVisible(targetIndex)
                }
                /// * Dengarkan lagi notifikasi perubahan clipView
                NotificationCenter.default.addObserver(self, selector: #selector(scrollViewDidScroll(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)

                tableView.endUpdates() /// ** Selesai memperbarui tableView

                /// * Handle Siswa Berhenti
                if isBerhentiHidden || !tampilkanSiswaLulus, !siswaData.isEmpty {
                    tableView.beginUpdates()
                    for (group, row, data) in siswaData {
                        if data.status == .berhenti || data.status == .lulus || data.tingkatKelasAktif == .lulus {
                            viewModel.removeGroupSiswa(groupIndex: group, index: row)
                            let absoluteRowIndex = viewModel.getAbsoluteRowIndex(groupIndex: group, rowIndex: row)
                            tableView.removeRows(at: IndexSet([absoluteRowIndex]), withAnimation: .effectFade)
                        }
                    }
                    tableView.endUpdates()
                }

                /// * Perbarui NSTableHeaderView
                if let frame = tableView.headerView?.frame {
                    let modFrame = NSRect(x: frame.origin.x, y: 0, width: frame.width, height: 28)
                    tableView.headerView = NSTableHeaderView(frame: modFrame)
                    tableView.headerView?.needsDisplay = true
                    #if DEBUG
                        print("add new nstableViewHeaderView")
                    #endif
                }

                /// * Kirim notifikasi perubahan lokasi scroll
                NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: scrollView.contentView)

                updateUndoRedo(nil) /// * Perbarui kontrol undo/redo KeyBoard ⌘-Z / ⌘-⇧-Z di menuBar
            }

            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
                if updateKelas {
                    self?.handleUndoNaikKelas(contexts: snapshot, siswa: selectedSiswaRow)
                }
                self?.viewModel.undoEditSiswa(selectedSiswaRow)
            }

            /*
             Sangat penting untuk menghentikan undo grouping jika sebelumnya telah dimulai ketika memperbarui foto siswa
             di EditData.
             */
            SiswaViewModel.siswaUndoManager.endUndoGrouping()
        }
    }

    /**
         * Fungsi ini menangani proses pembatalan (undo) perubahan data siswa.
         * Fungsi ini dipanggil ketika ada notifikasi yang menandakan bahwa operasi undo edit siswa perlu dilakukan.
         *
         * - Parameter notification: Notifikasi yang berisi informasi tentang data siswa yang akan dikembalikan.
         *   Notifikasi ini diharapkan memiliki `userInfo` yang berisi:
         *     - "data": Array `ModelSiswa` yang berisi snapshot data siswa sebelum perubahan.
         *
         * Proses:
         * 1. Memastikan bahwa notifikasi memiliki data yang diperlukan dan data tidak kosong.
         * 2. Membatalkan semua pilihan baris di tabel.
         * 3. Memulai pembaruan tabel secara batch.
         * 4. Berdasarkan mode tampilan tabel (`.plain` atau `.grouped`), lakukan langkah-langkah berikut:
         *    - Mode `.plain`:
         *      - Iterasi melalui setiap snapshot siswa.
         *      - Memeriksa apakah siswa tersebut harus ditampilkan berdasarkan status "berhenti" atau "lulus".
         *      - Memperbarui data siswa di `viewModel`.
         *      - Menghapus baris yang sesuai dari tabel dan menyisipkan kembali di posisi yang benar.
         *      - Memindahkan baris di tabel untuk mencerminkan perubahan urutan.
         *      - Memuat ulang data di kolom yang sesuai.
         *    - Mode `.grouped`:
         *      - Iterasi melalui setiap snapshot siswa.
         *      - Mencari data siswa yang sesuai di setiap grup.
         *      - Memperbarui data siswa di `viewModel`.
         *      - Memindahkan siswa antar grup jika kelasnya berubah.
         *      - Memperbarui tampilan tabel untuk mencerminkan perubahan grup dan urutan.
         * 5. Mengakhiri pembaruan tabel secara batch.
         * 6. Memperbarui tampilan tombol undo dan redo setelah beberapa saat.
         * 7. Memposting notifikasi jika ada perubahan pada tanggal berhenti siswa.
         *
         * Catatan:
         * - Fungsi ini menggunakan `viewModel` untuk mengelola data siswa.
         * - Fungsi ini menggunakan `dbController` untuk mengakses data siswa dari database.
         * - Fungsi ini menggunakan `SingletonData.siswaNaikArray` dan `// SingletonData.siswaNaikId` untuk menyimpan data siswa yang naik kelas.
         * - Animasi yang digunakan adalah `.effectGap` untuk penyisipan dan `.effectFade` untuk penghapusan.
     */
    @objc func undoEditSiswa(_ notification: Notification) {
        delegate?.didUpdateTable(.siswa)
        guard let userInfo = notification.userInfo,
              let snapshotSiswas = userInfo["data"] as? [ModelSiswa],
              !snapshotSiswas.isEmpty,
              let sortDescriptor = ModelSiswa.currentSortDescriptor
        else { return }

        var updateJumlahSiswa = false
        // Buat array untuk menyimpan data baris yang belum diubah
        tableView.deselectAll(self)
        tableView.beginUpdates()
        if currentTableViewMode == .plain {
            for snapshotSiswa in snapshotSiswas {
                // Ambil nilai kelasSekarang dari objek viewModel.filteredSiswaData yang sesuai dengan snapshotSiswa
                let oldSiswa = dbController.getSiswa(idValue: snapshotSiswa.id)
                if isBerhentiHidden, oldSiswa.status == .berhenti {
                    let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: oldSiswa, using: sortDescriptor)
                    guard !viewModel.filteredSiswaData.contains(where: { $0.id == oldSiswa.id }) else { continue }
                    viewModel.insertSiswa(oldSiswa, at: insertIndex)
                    tableView.insertRows(at: IndexSet([insertIndex]), withAnimation: .effectGap)
                    tableView.selectRowIndexes(IndexSet([insertIndex]), byExtendingSelection: true)
                    tableView.scrollRowToVisible(insertIndex)
                } else if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus"), oldSiswa.status == .lulus {
                    let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: oldSiswa, using: sortDescriptor)
                    guard !viewModel.filteredSiswaData.contains(where: { $0.id == oldSiswa.id }) else { continue }
                    viewModel.insertSiswa(oldSiswa, at: insertIndex)
                    tableView.insertRows(at: IndexSet([insertIndex]), withAnimation: .effectGap)
                    tableView.selectRowIndexes(IndexSet([insertIndex]), byExtendingSelection: true)
                    tableView.scrollRowToVisible(insertIndex)
                }
                guard let matchedSiswaData = viewModel.filteredSiswaData.first(where: { $0.id == snapshotSiswa.id }) else {
                    continue
                }
                if !SingletonData.siswaNaikArray.isEmpty {
                    SingletonData.siswaNaikArray.removeLast()
                }
                // SingletonData.siswaNaikId.removeAll(where: { $0 == snapshotSiswa.id })

                viewModel.updateDataSiswa(snapshotSiswa.id, dataLama: matchedSiswaData, baru: snapshotSiswa)

                if let rowIndex = viewModel.filteredSiswaData.firstIndex(where: { $0.id == snapshotSiswa.id }) {
                    let siswa = snapshotSiswa.copy() as! ModelSiswa
                    siswa.tingkatKelasAktif = snapshotSiswa.tingkatKelasAktif
                    viewModel.removeSiswa(at: rowIndex)

                    if isBerhentiHidden && snapshotSiswa.status == .berhenti {
                        tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .effectFade)
                        continue
                    }

                    if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") && snapshotSiswa.status == .lulus {
                        tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .effectFade)
                        continue
                    }

                    let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswa, using: sortDescriptor)
                    viewModel.insertSiswa(siswa, at: insertIndex)
                    let namaSiswaColumnIndex = ReusableFunc.columnIndex(of: namaColumn, in: tableView)
                    // Reload baris yang diperbarui
                    tableView.moveRow(at: rowIndex, to: insertIndex)
                    for columnIndex in 0 ..< tableView.numberOfColumns {
                        guard columnIndex != namaSiswaColumnIndex else { continue }
                        tableView.reloadData(forRowIndexes: IndexSet(integer: insertIndex), columnIndexes: IndexSet(integer: columnIndex))
                    }
                    tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)
                    tableView.reloadData(forRowIndexes: IndexSet(integer: insertIndex), columnIndexes: IndexSet(integer: namaSiswaColumnIndex))
                    refreshTableViewCells(for: IndexSet(integer: insertIndex), newKelasAktifString: snapshotSiswa.tingkatKelasAktif.rawValue)
                    tableView.scrollRowToVisible(insertIndex)
                    if matchedSiswaData.tahundaftar != siswa.tahundaftar ||
                        matchedSiswaData.tanggalberhenti != siswa.tanggalberhenti ||
                        matchedSiswaData.jeniskelamin != siswa.jeniskelamin
                    {
                        updateJumlahSiswa = true
                    }
                }
            }
        } else if currentTableViewMode == .grouped {
            // Loop melalui setiap siswa di snapshot
            for snapshotSiswa in snapshotSiswas {
                let siswa = dbController.getSiswa(idValue: snapshotSiswa.id)
                if isBerhentiHidden, siswa.status == .berhenti {
                    let newGroupIndex = siswa.status == .lulus
                        ? getGroupIndex(forClassName: StatusSiswa.lulus.description)
                        : getGroupIndex(forClassName: siswa.tingkatKelasAktif.rawValue)
                    if !viewModel.groupedSiswa[newGroupIndex!].contains(where: { $0.id == siswa.id }) {
                        let insertIndex = viewModel.groupedSiswa[newGroupIndex!].insertionIndex(for: siswa, using: sortDescriptor)
                        viewModel.insertGroupSiswa(siswa, groupIndex: newGroupIndex!, index: insertIndex)
                        let absoluteIndex = viewModel.getAbsoluteRowIndex(groupIndex: newGroupIndex!, rowIndex: insertIndex)
                        tableView.insertRows(at: IndexSet([absoluteIndex]), withAnimation: .slideUp)
                        tableView.selectRowIndexes(IndexSet([absoluteIndex]), byExtendingSelection: true)
                        tableView.scrollRowToVisible(absoluteIndex)
                    }
                }

                if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus"), siswa.status == .lulus {
                    let newGroupIndex = siswa.status == .lulus
                        ? getGroupIndex(forClassName: StatusSiswa.lulus.description)
                        : getGroupIndex(forClassName: siswa.tingkatKelasAktif.rawValue)

                    let insertIndex = viewModel.groupedSiswa[newGroupIndex!].insertionIndex(for: siswa, using: sortDescriptor)
                    guard !viewModel.groupedSiswa[newGroupIndex!].contains(where: { $0.id == siswa.id }) else { continue }
                    viewModel.insertGroupSiswa(siswa, groupIndex: newGroupIndex!, index: insertIndex)
                    let absoluteIndex = viewModel.getAbsoluteRowIndex(groupIndex: newGroupIndex!, rowIndex: insertIndex)
                    tableView.insertRows(at: IndexSet([absoluteIndex]), withAnimation: .slideUp)
                    tableView.selectRowIndexes(IndexSet([absoluteIndex]), byExtendingSelection: false)
                }

                for (groupIndex, group) in viewModel.groupedSiswa.enumerated() {
                    // Cari matchedSiswaData dalam grup saat ini
                    if let matchedSiswaData = group.first(where: { $0.id == snapshotSiswa.id }),
                       let siswaIndex = group.firstIndex(where: { $0.id == matchedSiswaData.id })
                    {
                        if !SingletonData.siswaNaikArray.isEmpty {
                            SingletonData.siswaNaikArray.removeLast()
                        }
                        // SingletonData.siswaNaikId.removeAll(where: { $0 == snapshotSiswa.id })

                        viewModel.updateDataSiswa(snapshotSiswa.id, dataLama: matchedSiswaData, baru: snapshotSiswa)

                        let updated = snapshotSiswa.copy() as! ModelSiswa
                        updated.tingkatKelasAktif = snapshotSiswa.tingkatKelasAktif

                        // Perbarui tampilan tabel setelah menyisipkan data yang dihapus
                        viewModel.removeGroupSiswa(groupIndex: groupIndex, index: siswaIndex)

                        // Hitung ulang indeks penyisipan berdasarkan grup yang baru
                        let newGroupIndex = updated.status == .lulus
                            ? getGroupIndex(forClassName: KelasAktif.lulus.rawValue) ?? groupIndex
                            : getGroupIndex(forClassName: updated.tingkatKelasAktif.rawValue) ?? groupIndex
                        #if DEBUG
                            print("groupIndex:", groupIndex)
                            print("groupIndex:", newGroupIndex)
                        #endif
                        let insertIndex = viewModel.groupedSiswa[newGroupIndex].insertionIndex(for: updated, using: sortDescriptor)

                        if isBerhentiHidden && snapshotSiswa.status == .berhenti {
                            let rowIndex = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: siswaIndex)
                            tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .effectFade)
                            continue
                        }

                        if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") && snapshotSiswa.status == .lulus {
                            viewModel.removeGroupSiswa(groupIndex: groupIndex, index: siswaIndex)
                            let rowIndex = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: siswaIndex)
                            tableView.removeRows(at: IndexSet([rowIndex]), withAnimation: .effectFade)
                            continue
                        }

                        viewModel.insertGroupSiswa(updated, groupIndex: newGroupIndex, index: insertIndex)
                        // Perbarui tampilan tabel
                        updateTableViewForSiswaMove(from: (groupIndex, siswaIndex), to: (newGroupIndex, insertIndex))
                        if matchedSiswaData.tahundaftar != updated.tahundaftar ||
                            matchedSiswaData.tanggalberhenti != updated.tanggalberhenti ||
                            matchedSiswaData.jeniskelamin != updated.jeniskelamin
                        {
                            updateJumlahSiswa = true
                        }
                    }
                }
            }
        }
        tableView.endUpdates()

        // Perbarui tampilan undo dan redo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateUndoRedo(notification)
            if updateJumlahSiswa {
                NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
            }
        }
    }

    // MARK: - TAMBAHKAN DATA BARU

    /**
     Menangani notifikasi DatabaseController.siswaBaru.
     Fungsi ini akan menyisipkan siswa baru ke dalam tampilan tabel,
     baik dalam mode tampilan biasa maupun mode tampilan berkelompok, dan memperbarui tampilan tabel sesuai.

     - Parameter notification: Notifikasi yang berisi informasi tentang perubahan data siswa.

     - Catatan: Fungsi ini juga menangani pendaftaran dan pembatalan undo untuk operasi penyisipan siswa,
       serta memperbarui status tombol undo/redo.
     */
    @objc func handleDataDidChangeNotification(_ notification: Notification) {
        delegate?.didUpdateTable(.siswa)
        guard let info = notification.userInfo,
              let insertedSiswa = info["siswaBaru"] as? ModelSiswa,
              let insertedSiswaID = info["idSiswaBaru"] as? Int64
        else { return }
        guard let sortDescriptor = ModelSiswa.currentSortDescriptor else { return }
        // Hanya tambahkan data baru ke tabel jika belum ada dalam viewModel.filteredSiswaData
        if currentTableViewMode == .plain {
            guard !viewModel.filteredSiswaData.contains(where: { $0.id == insertedSiswaID }) else { return }
            let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: insertedSiswa, using: sortDescriptor)
            viewModel.insertSiswa(insertedSiswa, at: insertIndex)
            // Perbarui tampilan tabel setelah memasukkan data yang dihapus
            tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
            tableView.scrollRowToVisible(insertIndex)
            tableView.selectRowIndexes(IndexSet(integer: insertIndex), byExtendingSelection: true)
            NotificationCenter.default.removeObserver(self, name: DatabaseController.siswaBaru, object: nil)
        } else {
            guard let group = insertedSiswa.status == .lulus
                ? getGroupIndex(forClassName: StatusSiswa.lulus.description)
                : getGroupIndex(forClassName: insertedSiswa.tingkatKelasAktif.rawValue),
                let sortDescriptor = ModelSiswa.currentSortDescriptor
            else {
                return
            }

            let updatedGroupIndex = min(group, viewModel.groupedSiswa.count - 1)

            // Hitung ulang indeks penyisipan berdasarkan grup yang baru
            let insertIndex = viewModel.groupedSiswa[updatedGroupIndex].insertionIndex(for: insertedSiswa, using: sortDescriptor)

            // Sisipkan siswa kembali ke dalam array viewModel.groupedSiswa pada grup yang tepat
            viewModel.insertGroupSiswa(insertedSiswa, groupIndex: group, index: insertIndex)
            // Perbarui tampilan tabel setelah menyisipkan data yang dihapus
            let rowInfo = getRowInfoForRow(insertIndex)
            // Pastikan baris yang dipilih adalah baris siswa, bukan header kelas

            // Menghitung jumlah baris dalam grup-grup sebelum grup saat ini
            let absoluteRowIndex = viewModel.groupedSiswa.prefix(group).reduce(0) { result, section in
                result + section.count + 1 // jumlah siswa dalam grup + 1 untuk header kelas
            }

            // Tambahkan indeks baris dalam grup ke indeks absolut
            let rowToInsert = absoluteRowIndex + rowInfo.rowIndexInSection + 1 // tambahkan 1 karena header kelas
            tableView.insertRows(at: IndexSet(integer: rowToInsert + 1), withAnimation: .slideDown)
            tableView.selectRowIndexes(IndexSet(integer: rowToInsert + 1), byExtendingSelection: true)
            tableView.scrollRowToVisible(rowToInsert + 1)

            NotificationCenter.default.removeObserver(self, name: DatabaseController.siswaBaru, object: nil)
        }
        urungsiswaBaruArray.append(insertedSiswa)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { targetSelf in
            targetSelf.urungSiswaBaru(self)
        }
        deleteAllRedoArray(self)
        updateUndoRedo(self)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataDidChangeNotification(_:)), name: DatabaseController.siswaBaru, object: nil)
    }

    // MARK: - NOTIFICATION

    /**
     Menyimpan data siswa setelah menerima notifikasi.

     Fungsi ini dipanggil sebagai respons terhadap notifikasi, dan melakukan serangkaian operasi asinkron untuk menyimpan data siswa,
     membersihkan array yang tidak diperlukan, memfilter siswa yang dihapus, dan memperbarui status undo/redo.

     - Parameter:
        - notification: Notifikasi yang memicu penyimpanan data.
     */
    @objc func saveData(_: Notification) {
        guard isDataLoaded else { return }

        // Inisialisasi DispatchGroup
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        dbController.notifQueue.async { [weak self] in
            guard let self else { return }
            urungsiswaBaruArray.removeAll()
            pastedSiswasArray.removeAll()
            deleteAllRedoArray(self)
            dispatchGroup.leave()
        }
        dispatchGroup.enter()
        dbController.notifQueue.asyncAfter(deadline: .now() + 0.1) {
            self.filterDeletedSiswa()
            dispatchGroup.leave()
        }
        // Setelah semua tugas selesai
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }
            dbController.notifQueue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    SiswaViewModel.siswaUndoManager.removeAllActions()
                    updateUndoRedo(self)
                }
            }
        }
    }
}
