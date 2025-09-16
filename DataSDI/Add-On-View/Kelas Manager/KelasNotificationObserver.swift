//
//  KelasNotificationObserver.swift
//  Data SDI
//
//  Created by MacBook on 12/09/25.
//

import Cocoa

extension KelasTableManager {
    /// Menangani notifikasi dari `.findDeletedData` / `.kelasDihapus`
    /// untuk menghapus row di tabel dan model data.
    /// - Parameter payload: Objek ``DeleteNilaiKelasNotif`` yang memuat informasi data.
    @MainActor
    func updateDeletion(_ payload: DeleteNilaiKelasNotif) {
        let nilaiId = payload.nilaiIDs
        let tableType = payload.tableType

        guard let table = getTableView(for: tableType.rawValue),
              let results = viewModel.removeData(
                  withIDs: nilaiId,
                  forTableType: tableType,
                  siswaID: siswaID
              )
        else { return }

        UpdateData.applyUpdates(results.updates, tableView: table, deselectAll: false)
    }

    /**
     Menangani notifikasi pembatalan penghapusan kelas. Fungsi ini dipanggil ketika notifikasi `.undoKelasDihapus`
     dan `.updateRedoInDetilSiswa` diterima.

     - Parameter notification: Notifikasi yang berisi informasi tentang kelas yang dibatalkan penghapusannya.
                                 Informasi ini mencakup `tableType` (tipe tabel kelas ``TableType``), `deletedData` (``KelasModels``),
                                 dan `hapusData` (bendera yang menunjukkan apakah data telah dihapus).

     Fungsi ini melakukan langkah-langkah berikut:
     1. Mengekstrak informasi dari `userInfo` notifikasi.
     2. Berdasarkan `tableType`, menentukan model data dan tabel yang sesuai.
     */
    @objc
    func handleUndoKelasDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let tableType = userInfo["tableType"] as? TableType,
           var data = userInfo["deletedData"] as? [KelasModels]
        {
            undoDeleteRows(from: &data, tableType: tableType, completion: nil)
        }
    }

    /// Fungsi ini menangani pembaruan data siswa yang diedit di tabel kelas manapun.
    /// - Parameter payload: ``NilaiKelasNotif`` untuk data dari pengirim.
    func updateDataKelas(_ payload: NilaiKelasNotif) {
        let columnIdentifier = payload.columnIdentifier
        let tableType = payload.tableType
        let dataBaru = payload.dataBaru
        let idNilai = payload.idNilai

        guard let table = !arsip ? getTableView(for: tableType.rawValue) : tables[0],
              let rowIndexToUpdate = getData().firstIndex(where: { $0.nilaiID == idNilai })
        else { return }

        // Lakukan pembaruan model dan database dengan nilai baru
        viewModel.updateKelasModel(tableType: tableType, columnIdentifier: columnIdentifier, rowIndex: rowIndexToUpdate, newValue: dataBaru, siswaID: siswaID, arsip: arsip)

        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let columnIndex = table.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnIdentifier.rawValue }),
                  let cellView = table.view(atColumn: columnIndex, row: rowIndexToUpdate, makeIfNecessary: false) as? NSTableCellView
            else { return }

            if columnIdentifier == .nilai {
                let numericValue = Int(dataBaru) ?? 0
                cellView.textField?.textColor = (numericValue <= 59) ? NSColor.red : NSColor.controlTextColor
            }
            cellView.textField?.stringValue = dataBaru
            selectionDelegate?.didEndUpdate?()
        }
    }

    /**
     * @function updateNamaGuruNotification
     * @abstract Menangani notifikasi pembaruan nama guru, mengelola sinkronisasi antara UI dan database secara asinkron.
     * @discussion Fungsi ini dipicu oleh notifikasi `.updateGuruMapel`.
     * Ia melakukan validasi data, membaca informasi UI di main thread,
     * memproses pembaruan data dan interaksi database di background thread
     * untuk menjaga responsivitas UI, dan kemudian memperbarui UI kembali di main thread.
     * Fungsionalitas undo juga didukung dengan menyimpan data asli sebelum perubahan.
     *
     * @param notification: Notification - Objek `Notification` yang berisi informasi pembaruan.
     * Diharapkan `userInfo` dari notifikasi ini mengandung kunci `[String: Any] = ["namaGuru": String, "idGuru": Int64]`
     * dengan nilai `[[String: Any]]` yang merinci pembaruan nama guru.
     *
     * @returns: void
     */
    @objc func updateNamaGuruNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let namaGuru = userInfo["namaGuru"] as? String,
              let idGuru = userInfo["idGuru"] as? Int64
        else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            updateGuruOrMapel(idGuru: idGuru, newValue: namaGuru)
        }
    }

    /**
     * @function updateTugasMapelNotification
     * @abstract Menangani notifikasi pembaruan nama mapel, mengelola sinkronisasi antara UI dan database secara asinkron.
     * @discussion Fungsi ini dipicu oleh notifikasi `.updateTugasMapel`.
     * Ia melakukan validasi data viewModel,
     * memproses pembaruan data dan interaksi database di background thread
     * untuk menjaga responsivitas UI.
     * Fungsionalitas undo juga didukung dengan menyimpan data asli sebelum perubahan.
     *
     * @param notification: Notification - Objek `Notification` yang berisi informasi pembaruan.
     * Diharapkan `userInfo` dari notifikasi ini mengandung kunci `[String: Any] = ["namaMapel": String, "idTugas": Int64, "idGuru": Int64]`
     * dengan nilai `[[String: Any]]` yang merinci pembaruan nama guru.
     *
     * @returns: void
     */
    @objc func updateTugasMapelNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let mapel = userInfo["namaMapel"] as? String,
              let idTugas = userInfo["idTugas"] as? Int64,
              let id = userInfo["idGuru"] as? Int64
        else { return }

        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.updateGuruOrMapel(idGuru: id, idTugas: idTugas, newValue: mapel, updateGuru: false)
        }
    }

    private func updateGuruOrMapel(idGuru: Int64, idTugas: Int64? = nil, newValue: String, updateGuru: Bool = true) {
        // Precompute values yang digunakan berulang
        let kolom: KelasColumn = updateGuru ? .guru : .mapel

        for info in tableInfo {
            let type = info.type
            let model = getData()
            var needsUpdate = false
            var affectedRows = Set<Int64>()

            // Update model data dengan enumerasi yang lebih efisien
            for (row, data) in model.enumerated() {
                let shouldUpdate: Bool = if updateGuru {
                    data.guruID == idGuru
                } else {
                    data.guruID == idGuru && data.tugasID == idTugas
                }

                if shouldUpdate {
                    viewModel.updateKelasModel(
                        tableType: type,
                        columnIdentifier: kolom,
                        rowIndex: row,
                        newValue: newValue,
                        siswaID: siswaID
                    )
                    affectedRows.insert(data.guruID)
                    needsUpdate = true
                }
            }

            if needsUpdate {
                needsReloadForTableType[type] = true
                if pendingReloadRows[type] != nil {
                    pendingReloadRows[type]!.formUnion(affectedRows)
                } else {
                    pendingReloadRows[type] = affectedRows
                }
            }
        }

        // Update data yang dihapus dengan filtering yang lebih efisien
        for (index, data) in SingletonData.deletedDataArray.enumerated() {
            let updatedData = data.map { kelas -> KelasModels in
                let updatedSiswa = kelas
                if kelas.guruID == idGuru {
                    if updateGuru {
                        updatedSiswa.namaguru = newValue
                    } else if kelas.tugasID == idTugas {
                        updatedSiswa.mapel = newValue
                    }
                }
                return updatedSiswa
            }
            SingletonData.deletedDataArray[index] = updatedData
        }

        // Update siswaNaikArray dengan filtering yang lebih efisien
        for (type, siswaNaikArray) in KelasViewModel.siswaNaikArray {
            let updatedArray = siswaNaikArray.map { data -> KelasModels in
                let updatedData = data
                if data.guruID == idGuru {
                    if updateGuru {
                        updatedData.namaguru = newValue
                    } else if data.tugasID == idTugas {
                        updatedData.mapel = newValue
                    }
                }
                return updatedData
            }
            KelasViewModel.siswaNaikArray[type] = updatedArray
        }

        if siswaID != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.performPendingReloads()
            }
        }
    }

    /// Reload nama guru dan mata pelajaran yang diperbarui.
    func performPendingReloads() {
        guard let tableView = activeTableView,
              let type = tableType(tableView)
        else { return }

        guard needsReloadForTableType[type] == true else { return }

        let columnIndex = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("namaguru"))
        let mapelColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(KelasColumn.mapel.rawValue))
        guard columnIndex != -1, mapelColumn != -1 else {
            needsReloadForTableType[type] = false
            pendingReloadRows[type] = []
            return
        }

        guard let guruIDs = pendingReloadRows[type], !guruIDs.isEmpty else {
            needsReloadForTableType[type] = false
            pendingReloadRows[type] = []
            return
        }

        // Remap nilaiID ke rowIndex saat ini
        let model = getData()
        var indexSet = IndexSet()
        for (i, item) in model.enumerated() {
            if guruIDs.contains(item.guruID) {
                indexSet.insert(i)
                #if DEBUG
                    print("indexes to reload:", i)
                #endif
            }
        }

        guard !indexSet.isEmpty else {
            needsReloadForTableType[type] = false
            pendingReloadRows[type] = []
            return
        }

        tableView.reloadData(forRowIndexes: indexSet, columnIndexes: IndexSet(arrayLiteral: columnIndex, mapelColumn))

        // Reset
        needsReloadForTableType[type] = false
        pendingReloadRows[type] = []
    }
}
