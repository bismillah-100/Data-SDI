//
//  CombineGuru.swift
//  Data SDI
//
//  Created by MacBook on 07/08/25.
//

import AppKit
import Combine

extension GuruVC {
    /// Fungsi ini mengatur combine untuk menangani event perubahan pada data guru.
    /// Fungsi ini akan mengupdate tabel berdasarkan event yang diterima dari ``GuruViewModel/guruEvent``.
    /// - Note: Fungsi ini menangani berbagai jenis event seperti `moveAndUpdate`, `remove`, dan `insert`.
    /// Setiap event akan memicu pembaruan pada tabel dengan cara yang sesuai, seperti memindahkan baris, menghapus baris, atau
    /// menyisipkan baris baru.
    /// - Note: Fungsi ini juga mengupdate undo/redo stack berdasarkan event yang diterima.
    /// - Note: Fungsi ini menggunakan `IndexSet` untuk menentukan kolom yang akan di-reload.
    func setupCombine() {
        // Columns yang akan di‐reload (semua kolom)
        let numberOfColumns = IndexSet(integersIn: 0 ..< tableView.numberOfColumns)
        viewModel.guruEvent
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case let .moveAndUpdate(updatedIndices, movedPairs):
                    tableView.deselectAll(event)
                    tableView.beginUpdates()
                    // 2a. Lakukan semua move
                    for (from, to) in movedPairs {
                        tableView.moveRow(at: from, to: to)
                        tableView.reloadData(forRowIndexes: IndexSet([to]),
                                             columnIndexes: numberOfColumns)
                        tableView.selectRowIndexes(IndexSet([to]), byExtendingSelection: true)
                    }

                    // 2b. Baru reload semuanya sekaligus
                    if !updatedIndices.isEmpty {
                        for index in updatedIndices {
                            tableView.reloadData(forRowIndexes: IndexSet([index]),
                                                 columnIndexes: numberOfColumns)
                            tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: true)
                        }
                    }
                    tableView.endUpdates()
                case let .remove(indexes):
                    tableView.beginUpdates()
                    for row in indexes.sorted(by: >) {
                        tableView.removeRows(at: IndexSet(integer: row), withAnimation: .slideDown)
                        if row + 1 < tableView.numberOfRows {
                            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                        }
                    }
                    tableView.endUpdates()
                case let .insert(indexes):
                    tableView.deselectAll(event)
                    tableView.beginUpdates()
                    for row in indexes.sorted(by: >) {
                        tableView.insertRows(at: IndexSet(integer: row), withAnimation: .slideUp)
                        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                    }
                    tableView.endUpdates()
                default: break
                }
            }
            .store(in: &cancellables)
    }

    /// Fungsi untuk membuka ``AddTugasGuruVC`` dan mengelola closure
    /// ``DataSDI/AddTugasGuruVC/onSimpanGuru`` dan closure ``DataSDI/AddTugasGuruVC/onClose``.
    /// - Parameters:
    ///   - sender: Objek pemicu.
    ///   - opsi: Opsi yang diteruskan ke ``DataSDI/AddTugasGuruVC``.
    ///   seperti opsi .tambahGuru dan .editGuru.
    func bukaJendelaAddTugas(_ sender: Any, opsi: AddGuruOrTugas) {
        let addVC = AddTugasGuruVC()
        addVC.options = opsi
        addVC.onSimpanGuru = { [weak self] newData in
            guard let self else { return }
            if opsi == .tambahGuru {
                guard let data = newData.first else { return }
                viewModel.insertGuruu([data.guru])
            } else {
                var guruToEdit = [GuruModel]()
                for data in newData {
                    guruToEdit.append(data.guru)
                }
                viewModel.updateGuruu(guruToEdit)
            }
            tutupSheet(sender)
        }
        addVC.onClose = { [weak self] in
            guard let self else { return }
            tutupSheet(sender)
        }
        if opsi == .editGuru {
            selectDataToEdit()
            addVC.dataToEdit = dataToEdit
        }
        addVCWindow.contentViewController = addVC
        view.window?.beginSheet(addVCWindow)
    }

    /// Fungsi ini membuka jendela untuk menambahkan atau mengedit guru.
    /// - Parameter sender: Objek yang memicu event ini, biasanya berupa tombol atau menu
    @objc
    func tambahGuru(_ sender: Any) {
        bukaJendelaAddTugas(sender, opsi: .tambahGuru)
    }

    /// Fungsi ini membuka jendela untuk mengedit guru yang dipilih.
    /// - Parameter sender: Objek yang memicu event ini, biasanya berupa tombol atau menu
    @objc
    func editGuru(_ sender: Any) {
        bukaJendelaAddTugas(sender, opsi: .editGuru)
    }

    /// Fungsi ini memilih data guru yang akan diedit berdasarkan baris yang diklik atau dipilih.
    /// Jika baris yang diklik tidak ada dalam indeks yang dipilih, maka data guru yang akan diedit
    /// adalah data guru pada baris yang diklik. Jika ada baris yang dipilih, maka data guru yang akan diedit
    /// adalah data guru pada baris yang dipilih.
    /// - Note: Fungsi ini mengupdate `dataToEdit`
    /// yang berisi daftar guru yang akan diedit.
    func selectDataToEdit() {
        let clickedRow = tableView.clickedRow
        let selectedRowIndexes = tableView.selectedRowIndexes

        if clickedRow != -1, !selectedRowIndexes.contains(clickedRow) {
            dataToEdit.append(viewModel.guru[clickedRow])
        } else {
            let selectedGuruu = selectedRowIndexes.compactMap { [weak self] index in
                self?.viewModel.guru.indices.contains(index) == true ? self?.viewModel.guru[index] : nil
            }
            dataToEdit = selectedGuruu
        }
    }

    /// Fungsi ini menghapus guru yang dipilih dari daftar guru.
    /// - Parameter sender: Objek yang memicu event ini, biasanya berupa tombol atau menu
    /// - Note: Fungsi ini akan menghapus guru berdasarkan baris yang dipilih di `tableView`.
    /// Jika baris yang diklik tidak ada dalam indeks yang dipilih,
    /// maka baris yang diklik akan dihapus. Jika ada baris yang dipilih,
    /// maka semua baris yang dipilih akan dihapus.
    @objc
    func hapusGuru(_: Any) {
        let clickedRow = tableView.clickedRow
        let selectedRowIndexes = tableView.selectedRowIndexes

        var selectedRows = IndexSet()
        if clickedRow != -1, !selectedRowIndexes.contains(clickedRow) {
            selectedRows.insert(clickedRow)
        } else {
            selectedRows = selectedRowIndexes
        }

        var hapusGuru = [GuruModel]()

        for row in selectedRows.sorted(by: >) {
            let guruModel = viewModel.guru[row]
            hapusGuru.append(guruModel)
        }

        viewModel.removeGuruu(hapusGuru)
    }

    /// Fungsi ini menangani penyalinan data dari baris yang dipilih di `outlineView`.
    /// - Parameter sender: Menu item yang dipilih untuk penyalinan.
    /// - Note: Fungsi ini akan mencoba mendapatkan indeks baris yang dipilih dari `outlineView`.
    /// Jika `sender.representedObject` adalah `IndexSet`, maka akan digunakan untuk menentukan baris yang akan disalin.
    /// Jika tidak, maka akan menyalin semua baris yang dipilih di `outlineView`.
    /// Fungsi ini akan memanggil `ReusableFunc.salinBaris` untuk melakukan penyalinan.
    /// - Note: Jika `sender.representedObject` bukan `IndexSet`, maka akan menganggap bahwa operasi penyalinan berlaku untuk semua baris yang dipilih.
    /// Jika `sender.representedObject` adalah `IndexSet`, maka akan digunakan untuk menentukan baris yang akan disalin.
    /// Jika `sender.representedObject` adalah `nil`, maka akan menganggap bahwa operasi penyalinan
    /// berlaku untuk semua baris yang dipilih.
    /// - Note: Fungsi ini juga akan memanggil ``ReusableFunc/resolveRowsToProcess(selectedRows:clickedRow:)`` untuk menentukan baris yang relevan berdasarkan baris yang diklik, baris yang dip
    @objc
    func salin(_: NSMenuItem) {
        // Mendapatkan semua indeks baris yang saat ini dipilih di `outlineView`.
        let selectedRows = tableView.selectedRowIndexes

        // Mendapatkan indeks baris yang terakhir diklik di `outlineView`.
        let clickedRow = tableView.clickedRow

        let rowsToProcess = ReusableFunc.resolveRowsToProcess(
            selectedRows: selectedRows,
            clickedRow: clickedRow
        )
        ReusableFunc.salinBaris(rowsToProcess, from: tableView)
    }

    /// Fungsi ini menutup jendela sheet yang sedang aktif.
    /// Fungsi ini akan mengakhiri sheet yang sedang aktif pada `view.window`.
    /// - Parameter sender: Objek yang memicu event ini, biasanya berupa tombol atau menu
    func tutupSheet(_: Any) {
        view.window?.endSheet(addVCWindow)
        addVCWindow.contentViewController = nil
        dataToEdit.removeAll()
        view.window?.makeFirstResponder(tableView)
    }
}
