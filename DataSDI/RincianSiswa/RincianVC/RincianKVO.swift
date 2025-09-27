//
//  RincianKVO.swift
//  Data SDI
//
//  Created by MacBook on 21/07/25.
//

import SQLite

// MARK: - FUNGSI UNTUK MENANGANI NOTIFIKASI PEMBARUAN DATA.

extension DetailSiswaController {
    /**
         Menangani notifikasi `.dataSiswaDiEditDiSiswaView` ketika nama siswa diedit.

         Fungsi ini dipanggil ketika ada notifikasi yang memberitahukan bahwa nama siswa telah diedit.
         Fungsi ini akan memperbarui tampilan nama siswa jika ID siswa yang diedit sesuai dengan ID siswa yang ditampilkan.

         - Parameter payload: ``NotifSiswaDiedit`` untuk informasi data dari pengirim.

         - Note: Fungsi ini menggunakan ``TableType/fromString(_:completion:)`` untuk mengkonversi string kelas menjadi enum `TableType`.
                 Fungsi ini juga menggunakan ``KelasViewModel/findAllIndices(for:matchingID:namaBaru:siswaID:)`` untuk memperbarui data siswa di view model.
                 Fungsi ini memperbarui tampilan nama siswa pada thread utama.
     */
    func handleNamaSiswaDiedit(_ payload: NotifSiswaDiedit) {
        tableViewManager.handleNamaSiswaDiedit(payload)
        let id = payload.updateStudentID
        let namaBaru = payload.namaSiswa
        tableViewManager.updateNamaSiswa(in: &deletedDataArray, id: id, namaBaru: namaBaru)
        tableViewManager.updateNamaSiswa(in: &pastedData, id: id, namaBaru: namaBaru)
        DispatchQueue.main.async { [unowned self] in
            tableViewManager.handleNamaSiswaDiedit(payload)
            namaSiswa.stringValue = StringInterner.shared.intern(namaBaru)
        }
    }

    /**
         Menangani notifikasi bahwa siswa telah dihapus.

         Fungsi ini dipanggil ketika notifikasi `.siswaDihapus` diposting. Fungsi ini akan memeriksa informasi yang diberikan dalam notifikasi,
         dan jika ID siswa yang dihapus cocok dengan ID siswa yang sedang ditampilkan, fungsi ini akan menonaktifkan berbagai elemen UI dan menandai nama siswa dengan strikethrough.
         Fungsi ini juga memperbarui data model dan tampilan tabel yang sesuai berdasarkan kelas siswa yang dihapus.

         - Parameter payload: ``NotifSiswaDihapus`` yang berisi informasi tentang siswa yang dihapus.

         - Catatan: Fungsi ini berjalan pada thread utama untuk memperbarui UI.
     */
    func handleSiswaDihapusNotification(_ payload: NotifSiswaDihapus) {
        tmblTambah.isEnabled = false
        let text = "Nama Siswa"
        let attributedString = NSMutableAttributedString(string: text)
        // Menambahkan atribut strikethrough
        attributedString.addAttributes([
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: NSColor.secondaryLabelColor,
        ], range: NSMakeRange(0, text.count))
        // Mengatur attributed string ke NSTextField
        namaSiswa.attributedStringValue = attributedString

        namaSiswa.isEnabled = false
        tmblSimpan.isEnabled = false
        undoButton.isEnabled = false
        redoButton.isEnabled = false
        statistik.isEnabled = false
        imageView.isEnabled = false
        opsiSiswa.isEnabled = false
        kelasSC.isEnabled = false
        nilaiKelasAktif.isEnabled = false
        smstr.isEnabled = false
        alert.window.close()
        for (table, _) in tableInfo {
            table.isEnabled = false
        }

        TableType.fromString(payload.kelasSekarang) { [weak self] kelas in
            guard let self else { return }
            guard let table = tableViewManager.getTableView(for: kelas.rawValue) else { return }
            var modifiableModel = viewModel.kelasModelForTable(kelas, siswaID: siswaID)
            updateRows(from: &modifiableModel, tableView: table, deletedIDs: payload.deletedStudentIDs, kelasSekarang: payload.kelasSekarang)
            viewModel.setModel(modifiableModel, for: kelas, siswaID: siswaID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateSemesterTeks()
        }
    }

    /**
         Memperbarui baris pada tampilan tabel berdasarkan perubahan pada model data.

         Fungsi ini memungkinkan untuk memperbarui atau menghapus baris pada `NSTableView` berdasarkan ID yang diberikan.
         Fungsi ini juga menangani penyimpanan state model sebelum perubahan untuk mendukung fungsi undo.

         - Parameter model: Array `KelasModels` yang akan diperbarui.
         - Parameter tableView: `NSTableView` yang akan diperbarui tampilannya.
         - Parameter deletedIDs: Array berisi ID (`Int64`) dari item yang akan dihapus atau diperbarui.
         - Parameter kelasSekarang: String yang merepresentasikan kelas saat ini.
     */
    func updateRows(from model: inout [KelasModels], tableView: NSTableView, deletedIDs: [Int64], kelasSekarang: String) {
        var indexesToDelete = IndexSet()
        var itemsToDelete: [KelasModels] = []
        // Simpan state model sebelum penghapusan untuk undo
        if undoUpdateStack[kelasSekarang] == nil {
            undoUpdateStack[kelasSekarang] = []
        }

        undoUpdateStack[kelasSekarang]?.append(model.filter { deletedIDs.contains($0.siswaID) }.map { $0.copy() as! KelasModels })

        // Cari indeks di model yang sesuai dengan deletedIDs
        for (index, item) in model.enumerated() {
            if deletedIDs.contains(item.siswaID) {
                indexesToDelete.insert(index)
                itemsToDelete.append(item)
            }
        }

        var updates: [UpdateData] = []
        for index in indexesToDelete.sorted(by: >) {
            TableType.fromString(kelasSekarang) { [weak self] kelas in
                guard let self else { return }
                let update = viewModel.removeData(index: index, tableType: kelas, siswaID: siswaID)
                updates.append(update)
            }
        }

        model.removeAll { item in deletedIDs.contains(item.siswaID) }

        Task { @MainActor [updates] in
            UpdateData.applyUpdates(updates, tableView: tableView)
        }
    }

    /**
     Menangani notifikasi `.undoSiswaDihapus` yang diposting ketika operasi penghapusan siswa dibatalkan.

     Fungsi ini memperbarui tampilan antarmuka pengguna untuk mencerminkan status siswa yang dipulihkan,
     termasuk mengaktifkan kembali elemen UI yang relevan dan memperbarui tampilan tabel yang sesuai.

     - Parameter notification: Objek `Notification` yang berisi informasi tentang operasi undo,
                         termasuk kelas siswa saat ini dan apakah siswa dihapus.
                         `userInfo` diharapkan mengandung kunci "kelasSekarang" (String) dan "hapusDiSiswa" (Bool).

     - Catatan: Fungsi ini berjalan pada antrian utama untuk pembaruan UI.
     */
    func handleUndoSiswaDihapusNotification(_ payload: NotifSiswaDihapus) {
        let kelasSekarang = payload.kelasSekarang
        tmblTambah.isEnabled = true
        let text = "\(siswa?.nama ?? "")"
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttributes([
            .foregroundColor: NSColor.textColor,
        ], range: NSMakeRange(0, text.count))
        namaSiswa.attributedStringValue = attributedString
        namaSiswa.isEnabled = true
        tmblSimpan.isEnabled = true
        undoButton.isEnabled = true
        redoButton.isEnabled = true
        statistik.isEnabled = true
        imageView.isEnabled = true
        opsiSiswa.isEnabled = true
        kelasSC.isEnabled = true
        nilaiKelasAktif.isEnabled = true
        smstr.isEnabled = true
        for (table, _) in tableViewManager.tableInfo {
            table.isEnabled = true
        }
        TableType.fromString(kelasSekarang) { [weak self] kelas in
            guard let self, let tableView = tableViewManager.getTableView(for: kelas.rawValue) else { return }
            var modifiableModel = viewModel.kelasModelForTable(kelas, siswaID: siswaID)
            undoUpdateRows(from: &modifiableModel, tableView: tableView, kelasSekarang: kelasSekarang)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateSemesterTeks()
        }
    }

    /**
        Mengembalikan perubahan terakhir yang dilakukan pada data siswa dalam tabel, berdasarkan kelas yang dipilih.

        Fungsi ini mengambil state data siswa sebelumnya dari stack undo, dan mengembalikan data tersebut ke tabel.
        Fungsi ini mendukung pengembalian data baik untuk penghapusan siswa maupun penghapusan data lainnya.

        - Parameter:
           - model: Array `KelasModels` yang akan dimodifikasi. Parameter ini bersifat `inout` sehingga perubahan akan langsung mempengaruhi array asli.
           - tableView: `NSTableView` yang akan diperbarui untuk mencerminkan perubahan data.
           - kelasSekarang: String yang merepresentasikan kelas yang datanya akan dikembalikan.

        - Catatan:
           - Fungsi ini menggunakan stack undo (`undoUpdateStack`) untuk menyimpan state data sebelumnya.
           - Fungsi ini menggunakan `TableType` untuk mengidentifikasi tabel yang sesuai berdasarkan nama kelas.
           - Fungsi ini menggunakan `viewModel` untuk melakukan operasi insert dan update data.
           - Fungsi ini menggunakan `dbController` untuk melakukan operasi undo penghapusan data di database.
           - Setelah pengembalian data, tabel akan diperbarui untuk menampilkan data yang dikembalikan.
     */
    func undoUpdateRows(from _: inout [KelasModels], tableView: NSTableView, kelasSekarang: String) {
        let sortDescriptor = tableView.sortDescriptors.first ?? NSSortDescriptor(key: "mapel", ascending: true)
        guard let comparator = KelasModels.comparator(from: sortDescriptor) else { return }

        var insertionIndexes = [Int]()

        guard var undoStackForKelas = undoUpdateStack[kelasSekarang], !undoStackForKelas.isEmpty else { return }

        // Ambil state terakhir dari stack undo untuk kelas yang sesuai
        let previousState = undoStackForKelas.removeLast()
        undoUpdateStack[kelasSekarang] = undoStackForKelas // Perbarui stack undo

        TableType.fromString(kelasSekarang) { [weak self] kelas in
            for deletedData in previousState.reversed() {
                guard let insertIndex = self?.viewModel.insertData(for: kelas, deletedData: deletedData, comparator: comparator, siswaID: self?.siswaID) else { continue }
                insertionIndexes.append(insertIndex)
            }
        }
        tableView.beginUpdates()
        for row in insertionIndexes {
            tableView.insertRows(at: IndexSet(integer: row), withAnimation: .slideDown)
        }
        tableView.endUpdates()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateSemesterTeks()
        }
    }

    /// Memperbarui nama guru atau mata pelajaran pada dua koleksi data kelas sekaligus.
    ///
    /// Fungsi ini memanggil ``KelasTableManager/updateGuruOrMapel(in:idGuru:idTugas:newValue:updateGuru:)``
    /// untuk memperbarui data pada `deletedDataArray` dan `pastedData`.
    /// Perubahan dilakukan jika `guruID` pada elemen sesuai dengan `idGuru` yang diberikan.
    /// - Jika `updateGuru` bernilai `true`, maka properti ``KelasModels/namaguru`` akan diperbarui.
    /// - Jika `updateGuru` bernilai `false` dan `tugasID` sesuai dengan `idTugas`, maka properti ``KelasModels/mapel`` akan diperbarui.
    ///
    /// > Catatan: Karena ``KelasModels`` adalah *reference type* (`class`), perubahan akan langsung
    ///   memengaruhi instance asli di memori.
    ///
    /// ### Parameter
    /// - `idGuru`: ID guru yang menjadi target pembaruan.
    /// - `idTugas`: ID tugas yang menjadi target pembaruan mata pelajaran (opsional).
    /// - `newValue`: Nilai baru untuk nama guru atau mata pelajaran.
    /// - `updateGuru`: `true` untuk memperbarui nama guru, `false` untuk memperbarui mata pelajaran.
    ///
    /// ### Contoh
    /// ```swift
    /// handleNamaOrTugasGuru(
    ///     idGuru: 123,
    ///     idTugas: 456,
    ///     newValue: "Bahasa Arab",
    ///     updateGuru: false
    /// )
    /// ```
    /// Pada contoh di atas, semua elemen dengan `guruID == 123` dan `tugasID == 456`
    /// di ``deletedDataArray`` dan ``pastedData`` akan memiliki nilai `mapel` yang diperbarui menjadi `"Bahasa Arab"`.
    func handleNamaOrTugasGuru(
        idGuru: Int64,
        idTugas: Int64? = nil,
        newValue: String,
        updateGuru: Bool = true
    ) {
        guard let tableViewManager else { return }
        tableViewManager.updateGuruOrMapel(
            in: &deletedDataArray,
            idGuru: idGuru,
            idTugas: idTugas,
            newValue: newValue,
            updateGuru: updateGuru
        )

        tableViewManager.updateGuruOrMapel(
            in: &pastedData,
            idGuru: idGuru,
            idTugas: idTugas,
            newValue: newValue,
            updateGuru: updateGuru
        )
    }
}
