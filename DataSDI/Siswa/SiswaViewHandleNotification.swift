//
//  SiswaViewHandleNotification.swift
//  Data SDI
//
//  Created by Bismillah on 12/01/25.
//

import Cocoa

extension SiswaViewController {
    func handleUndoActionGrouped(id: Int64, groupIndex: Int? = nil, rowInSection: Int? = nil, columnIndex: Int) {
        let siswa = dbController.getSiswa(idValue: id)

        if isBerhentiHidden, siswa.status.lowercased() == "berhenti", let sortDescriptor = ModelSiswa.currentSortDescriptor {
            let newGroupIndex = getGroupIndex(forClassName: siswa.kelasSekarang)
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
        guard let userInfo = notification.userInfo,
              let id = userInfo["id"] as? Int64,
              let columnIdentifier = userInfo["columnIdentifier"] as? String
        else {
            return
        }
        guard let columnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnIdentifier }) else { return }

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
            if isBerhentiHidden, siswaToUpdate.status.lowercased() == "berhenti" {
                guard let sortDescriptor = ModelSiswa.currentSortDescriptor else { return }
                let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswaToUpdate, using: sortDescriptor)
                guard !viewModel.filteredSiswaData.contains(where: { $0.id == siswaToUpdate.id }) else { return }
                viewModel.insertSiswa(siswaToUpdate, at: insertIndex)
                tableView.insertRows(at: IndexSet([insertIndex]), withAnimation: .slideUp)
                tableView.selectRowIndexes(IndexSet([insertIndex]), byExtendingSelection: false)
                rowIndexToUpdate = insertIndex
            }
            if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus"), siswaToUpdate.status.lowercased() == "lulus" {
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
                self.viewModel.removeSiswa(at: rowIndexToUpdate)
                self.tableView.removeRows(at: IndexSet([rowIndexToUpdate]), withAnimation: .effectFade)
            }
        }
        updateUndoRedo(self)
    }

    @objc func receivedNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let ids = userInfo["ids"] as? [Int64]
        else { return }
        var indexset = IndexSet()
        if currentTableViewMode == .plain {
            for id in ids {
                if let index = viewModel.filteredSiswaData.firstIndex(where: { $0.id == id }) {
                    indexset.insert(index)
                }
            }
        } else {
            // Dapatkan indeks siswa terpilih di `groupedSiswa`
            for id in ids {
                for (section, siswaGroup) in viewModel.groupedSiswa.enumerated() {
                    if let rowIndex = siswaGroup.firstIndex(where: { $0.id == id }) {
                        // Konversikan indeks ke IndexSet untuk NSTableView
                        let tableIndex = viewModel.getAbsoluteRowIndex(groupIndex: section, rowIndex: rowIndex)
                        indexset.insert(tableIndex)
                        break
                    }
                }
            }
        }
        // Perbarui selectedRowIndexes setelah pembaruan
        // tableView.selectRowIndexes(previousSelectedRowIndexes, byExtendingSelection: false)
        DispatchQueue.main.async { [unowned self] in
            // Lakukan pembaruan data di latar belakang
            updateDataInBackground(selectedRowIndexes: indexset)
        }
    }

    func updateDataInBackground(selectedRowIndexes: IndexSet) {
        deleteAllRedoArray(self) /* hapus data redo */

        guard let sortDescriptor = ModelSiswa.currentSortDescriptor else {
            print("sortDescriptor Error")
            return
        } /// * key urutan data

        let tampilkanSiswaLulus = UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") /// * pengaturan status siswa lulus ditampilkan atau tidak

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
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] target in
                self?.viewModel.undoEditSiswa(selectedSiswaRow)
            }
            
            /*
             Sangat penting untuk menghentikan undo grouping jika sebelumnya telah dimulai ketika memperbarui foto siswa
             di EditData.
             */
            SiswaViewModel.siswaUndoManager.endUndoGrouping()
            
            var siswaData: [(index: Int, data: ModelSiswa)] = []

            view.window?.beginSheet(progressWindowController.window!)

            for (index, siswa) in selectedSiswaList.reversed().enumerated() {
                guard let SiswaIndex = viewModel.filteredSiswaData.firstIndex(where: { $0.id == siswa.id }) else { return }
                var siswas = viewModel.filteredSiswaData[SiswaIndex]
                siswas = dbController.getSiswa(idValue: viewModel.filteredSiswaData[SiswaIndex].id)
                viewModel.removeSiswa(at: SiswaIndex)
                let insertIndex = viewModel.filteredSiswaData.insertionIndex(for: siswas, using: sortDescriptor)
                viewModel.insertSiswa(siswas, at: insertIndex)
                // Reload baris yang diperbarui
                DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(index) * 0.1) { [unowned self] in
                    progressViewController.controller = siswas.nama
                    tableView.moveRow(at: SiswaIndex, to: insertIndex)
                    tableView.scrollRowToVisible(insertIndex)
                    tableView.reloadData(forRowIndexes: IndexSet(integer: insertIndex), columnIndexes: IndexSet(integersIn: 0 ..< tableView.numberOfColumns))
                    progressViewController.currentStudentIndex = index + 1

                    if (isBerhentiHidden && siswas.status == "Berhenti") || (!tampilkanSiswaLulus && siswas.status == "Lulus") {
                        siswaData.append((insertIndex, siswas))
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(selectedSiswaList.count) * 0.12) { [unowned self] in
                if isBerhentiHidden || !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
                    for (int, data) in siswaData.reversed() {
                        if (data.status.lowercased() == "berhenti" && isBerhentiHidden) || (data.status.lowercased() == "lulus" && !tampilkanSiswaLulus) {
                            viewModel.removeSiswa(at: int)

                            if int == tableView.numberOfRows - 1 {
                                tableView.selectRowIndexes(IndexSet([tableView.numberOfRows - 2]), byExtendingSelection: false)
                            }
                            tableView.removeRows(at: IndexSet([int]), withAnimation: .effectFade)
                        }
                    }
                }

                self.view.window?.endSheet(progressWindowController.window!)
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

            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] target in
                self?.viewModel.undoEditSiswa(selectedSiswaRow)
            }
            
            /*
             Sangat penting untuk menghentikan undo grouping jika sebelumnya telah dimulai ketika memperbarui foto siswa
             di EditData.
             */
            SiswaViewModel.siswaUndoManager.endUndoGrouping()
            var siswaData: [(group: Int, index: Int, data: ModelSiswa)] = []

            /// * tampilkan jendela progress sheets
            view.window?.beginSheet(progressWindowController.window!)

            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: scrollView.contentView)

            for (index, siswa) in selectedSiswaList.reversed().enumerated() {
                guard let (groupIndex, rowIndex) = viewModel.findSiswaInGroups(id: siswa.id) else { continue }

                let updatedSiswa = dbController.getSiswa(idValue: siswa.id)

                viewModel.updateGroupSiswa(updatedSiswa, groupIndex: groupIndex, index: rowIndex)

                if siswa.kelasSekarang != updatedSiswa.kelasSekarang {
                    let oldAbsoluteVisualIndex = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: rowIndex) // Hitung SEBELUM remove/insert berikutnya

                    let newGroupIndex = getGroupIndex(forClassName: updatedSiswa.kelasSekarang) ?? groupIndex
                    let insertIndex = viewModel.groupedSiswa[newGroupIndex].insertionIndex(for: updatedSiswa, using: sortDescriptor)

                    viewModel.removeGroupSiswa(groupIndex: groupIndex, index: rowIndex)
                    viewModel.insertGroupSiswa(updatedSiswa, groupIndex: newGroupIndex, index: insertIndex)
                    let newAbsoluteVisualIndex = viewModel.getAbsoluteRowIndex(groupIndex: newGroupIndex, rowIndex: insertIndex) // Hitung SETELAH remove/insert
                    lastMovedToVisualIndex = newAbsoluteVisualIndex // Simpan untuk scroll nanti

                    operations.append { [weak self] in // Tambahkan operasi move ke antrian
                        self?.tableView.moveRow(at: oldAbsoluteVisualIndex, to: newAbsoluteVisualIndex)
                    }
                    if isBerhentiHidden, updatedSiswa.status.lowercased() == "berhenti" {
                        siswaData.append((groupIndex, rowIndex, updatedSiswa))
                    }
                } else {
                    let absoluteRowIndex = viewModel.getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: rowIndex)
                    lastMovedToVisualIndex = absoluteRowIndex // Simpan untuk scroll nanti

                    operations.append { [weak self] in // Tambahkan operasi reload ke antrian
                        self?.tableView.reloadData(forRowIndexes: IndexSet(integer: absoluteRowIndex), columnIndexes: IndexSet(integersIn: 0 ..< (self?.tableView.numberOfColumns ?? 0)))
                    }
                    if isBerhentiHidden && updatedSiswa.status.lowercased() == "berhenti" || (!UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") && updatedSiswa.status.lowercased() == "lulus") {
                        siswaData.append((groupIndex, rowIndex, updatedSiswa))
                    }
                }
                // Update progress bar bisa tetap di sini atau digabungkan dengan loop berikutnya
                // Untuk efek visual per item, jeda kecil masih bisa dipertahankan untuk progress bar saja
                DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(index) * 0.01) { // Jeda sangat kecil
                    progressViewController.controller = updatedSiswa.nama
                    progressViewController.currentStudentIndex = index + 1
                }
            }

            let finalDelay = max(TimeInterval(selectedSiswaList.count) * 0.01, 0.5) /// * Delay setelah data di viewModel diperbarui.
            DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) { [weak self] in
                guard let self else { return }
                self.view.window?.endSheet(progressWindowController.window!)

                self.tableView.beginUpdates() /// ** Perbarui TableView secara komprehensif

                operations.forEach { $0() } /// * Jalankan semua moveRow dan reloadData

                /// * Scroll ke lokasi baris yang dipindahkan.
                if let targetIndex = lastMovedToVisualIndex, targetIndex < tableView.numberOfRows {
                    self.tableView.scrollRowToVisible(targetIndex)
                }
                /// * Dengarkan lagi notifikasi perubahan clipView
                NotificationCenter.default.addObserver(self, selector: #selector(scrollViewDidScroll(_:)), name: NSView.boundsDidChangeNotification, object: self.scrollView.contentView)

                self.tableView.endUpdates() /// ** Selesai memperbarui tableView

                /// * Handle Siswa Berhenti
                if self.isBerhentiHidden, !siswaData.isEmpty {
                    self.tableView.beginUpdates()
                    for (group, row, data) in siswaData {
                        if data.status.lowercased() == "berhenti" || data.status.lowercased() == "lulus" || data.kelasSekarang == "lulus" {
                            self.viewModel.removeGroupSiswa(groupIndex: group, index: row)
                            let absoluteRowIndex = self.viewModel.getAbsoluteRowIndex(groupIndex: group, rowIndex: row)
                            self.tableView.removeRows(at: IndexSet([absoluteRowIndex]), withAnimation: .effectFade)
                        }
                    }
                    self.tableView.endUpdates()
                }

                /// * Perbarui NSTableHeaderView
                if let frame = self.tableView.headerView?.frame {
                    let modFrame = NSRect(x: frame.origin.x, y: 0, width: frame.width, height: 28)
                    self.tableView.headerView = NSTableHeaderView(frame: modFrame)
                    self.tableView.headerView?.needsDisplay = true
                    #if DEBUG
                        print("add new nstableViewHeaderView")
                    #endif
                }

                /// * Kirim notifikasi perubahan lokasi scroll
                NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: self.scrollView.contentView)

                self.updateUndoRedo(nil) /// * Perbarui kontrol undo/redo KeyBoard ⌘-Z / ⌘-⇧-Z di menuBar
            }
        }
    }
}
