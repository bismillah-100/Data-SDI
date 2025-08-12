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

         - Parameter notification: Notifikasi yang berisi informasi tentang siswa yang diedit.
                                    Notifikasi ini diharapkan memiliki `userInfo` yang berisi:
                                        - "updateStudentIDs": `Int64` ID siswa yang diedit.
                                        - "namaSiswa": `String` Nama siswa yang baru.
                                        - "kelasSekarang": `String` Kelas siswa saat ini.

         - Note: Fungsi ini menggunakan ``TableType/fromString(_:completion:)`` untuk mengkonversi string kelas menjadi enum `TableType`.
                 Fungsi ini juga menggunakan ``KelasViewModel/findAllIndices(for:matchingID:namaBaru:siswaID:)`` untuk memperbarui data siswa di view model.
                 Fungsi ini memperbarui tampilan nama siswa pada thread utama.
     */
    @objc func handleNamaSiswaDiedit(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedIDs = userInfo["updateStudentIDs"] as? Int64,
           let namaBaru = userInfo["namaSiswa"] as? String
        {
            guard deletedIDs == siswa?.id else { return }

            if let kelasSekarang = userInfo["kelasSekarang"] as? String {
                TableType.fromString(kelasSekarang) { [weak self] kelas in
                    self?.viewModel.findAllIndices(for: kelas, matchingID: deletedIDs, namaBaru: namaBaru, siswaID: self?.siswaID)
                }

                DispatchQueue.main.async { [unowned self] in
                    namaSiswa.stringValue = StringInterner.shared.intern(namaBaru)
                }
            }
        }
    }

    /**
         Menangani notifikasi bahwa siswa telah dihapus.

         Fungsi ini dipanggil ketika notifikasi `.siswaDihapus` diposting. Fungsi ini akan memeriksa informasi yang diberikan dalam notifikasi,
         dan jika ID siswa yang dihapus cocok dengan ID siswa yang sedang ditampilkan, fungsi ini akan menonaktifkan berbagai elemen UI dan menandai nama siswa dengan strikethrough.
         Fungsi ini juga memperbarui data model dan tampilan tabel yang sesuai berdasarkan kelas siswa yang dihapus.

         - Parameter notification: Notifikasi yang berisi informasi tentang siswa yang dihapus. Informasi ini mencakup:
             - deletedStudentIDs: Array ID siswa yang dihapus.
             - kelasSekarang: String yang merepresentasikan kelas siswa yang dihapus.
             - isDeleted: Boolean yang menunjukkan apakah siswa telah dihapus.
             - hapusDiSiswa: Boolean yang menunjukkan apakah penghapusan dilakukan dari tampilan detail siswa.

         - Catatan: Fungsi ini berjalan pada thread utama untuk memperbarui UI.
     */
    @objc func handleSiswaDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let deletedIDs = userInfo["deletedStudentIDs"] as? [Int64],
           let kelasSekarang = userInfo["kelasSekarang"] as? String,
           let isDeleted = userInfo["isDeleted"] as? Bool
        {
            let hapusSiswa = userInfo["hapusDiSiswa"] as? Bool ?? false
            guard let siswaID = siswa?.id, deletedIDs.contains(siswaID) else {
                return
            }
            if isDeleted, hapusSiswa {
                DispatchQueue.main.async { [unowned self] in
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
                }
            }

            TableType.fromString(kelasSekarang) { [weak self] kelas in
                guard let self else { return }
                guard let table = getTableView(for: kelas.rawValue) else { return }
                var modifiableModel = viewModel.kelasModelForTable(kelas, siswaID: siswaID)
                updateRows(from: &modifiableModel, tableView: table, deletedIDs: deletedIDs, kelasSekarang: kelasSekarang, isDeleted: isDeleted, hapusSiswa: hapusSiswa, hapusData: false, naikKelas: false)
                viewModel.setModel(modifiableModel, for: kelas, siswaID: siswaID)
            }
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
         - Parameter isDeleted: Boolean yang menandakan apakah item dihapus.
         - Parameter hapusSiswa: Boolean yang menandakan apakah siswa dihapus. Jika `true`, baris akan dihapus dari tabel.
         - Parameter hapusData: Boolean yang menandakan apakah data dihapus.
         - Parameter naikKelas: Boolean yang menandakan apakah siswa naik kelas.
     */
    func updateRows(from model: inout [KelasModels], tableView: NSTableView, deletedIDs: [Int64], kelasSekarang: String, isDeleted: Bool, hapusSiswa: Bool, hapusData: Bool, naikKelas: Bool) {
        var indexesToUpdate = IndexSet()
        var indexesToDelete = IndexSet()
        var itemsToDelete: [KelasModels] = []
        // Simpan state model sebelum penghapusan untuk undo
        if undoUpdateStack[kelasSekarang] == nil {
            undoUpdateStack[kelasSekarang] = []
        }
        if isDeleted == true {
            undoUpdateStack[kelasSekarang]?.append(model.filter { deletedIDs.contains($0.siswaID) }.map { $0.copy() as! KelasModels })
        }
        if hapusData == true, naikKelas == false {
            undoUpdateStack[kelasSekarang]?.append(model.filter { deletedIDs.contains($0.kelasID) }.map { $0.copy() as! KelasModels })
        }
        // Cari indeks di model yang sesuai dengan deletedIDs
        for (index, item) in model.enumerated() {
            if hapusData == false {
                if deletedIDs.contains(item.siswaID) {
                    if hapusSiswa == true {
                        indexesToDelete.insert(index)
                        itemsToDelete.append(item)
                    } else {
                        model[index].namasiswa = ""
                        indexesToUpdate.insert(index)
                    }
                }
            } else if naikKelas == true {
                if deletedIDs.contains(item.siswaID) {
                    model[index].namasiswa = ""
                    indexesToUpdate.insert(index)
                }
            } else {
                if deletedIDs.contains(item.kelasID) {
                    model[index].namasiswa = ""
                    indexesToUpdate.insert(index)
                }
            }
        }

        // Hapus data dari model
        if hapusSiswa == true {
            for index in indexesToDelete.sorted(by: >) {
                TableType.fromString(kelasSekarang) { [weak self] kelas in
                    self?.viewModel.removeData(index: index, tableType: kelas, siswaID: self?.siswaID)
                }
            }
            model.removeAll { item in deletedIDs.contains(item.siswaID) }

            OperationQueue.main.addOperation { [weak self] in
                tableView.beginUpdates()
                tableView.removeRows(at: indexesToDelete, withAnimation: .slideUp)
                tableView.endUpdates()
                self?.updateSemesterTeks()
            }
        } else {
            OperationQueue.main.addOperation { [weak self] in
                tableView.reloadData(forRowIndexes: indexesToUpdate, columnIndexes: IndexSet(integersIn: 0 ..< tableView.numberOfColumns))
                self?.updateSemesterTeks()
            }
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
    @objc
    func handleUndoSiswaDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let kelasSekarang = userInfo["kelasSekarang"] as? String
        {
            let hapusSiswa = userInfo["hapusDiSiswa"] as? Bool ?? false

            if hapusSiswa {
                DispatchQueue.main.async { [unowned self] in
                    tmblTambah.isEnabled = true
                    let text = "\(siswa?.nama ?? "")"
                    let attributedString = NSMutableAttributedString(string: text)
                    // Menambahkan atribut strikethrough
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
                    for (table, _) in tableInfo {
                        table.isEnabled = true
                    }
                }
            }
            TableType.fromString(kelasSekarang) { [weak self] kelas in
                guard let self, let tableView = getTableView(for: kelas.rawValue) else { return }
                var modifiableModel = viewModel.kelasModelForTable(kelas, siswaID: siswaID)
                undoUpdateRows(from: &modifiableModel, tableView: tableView, kelasSekarang: kelasSekarang, hapusSiswa: hapusSiswa, hapusData: false)
            }
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
           - hapusSiswa: Boolean yang menandakan apakah operasi sebelumnya adalah penghapusan siswa. Jika `true`, fungsi akan mengembalikan baris siswa yang dihapus.
           - hapusData: Boolean yang menandakan apakah operasi sebelumnya adalah penghapusan data selain siswa. Jika `true`, fungsi akan mengembalikan data yang dihapus.

        - Catatan:
           - Fungsi ini menggunakan stack undo (`undoUpdateStack`) untuk menyimpan state data sebelumnya.
           - Fungsi ini menggunakan `TableType` untuk mengidentifikasi tabel yang sesuai berdasarkan nama kelas.
           - Fungsi ini menggunakan `viewModel` untuk melakukan operasi insert dan update data.
           - Fungsi ini menggunakan `dbController` untuk melakukan operasi undo penghapusan data di database.
           - Setelah pengembalian data, tabel akan diperbarui untuk menampilkan data yang dikembalikan.
     */
    func undoUpdateRows(from model: inout [KelasModels], tableView: NSTableView, kelasSekarang: String, hapusSiswa: Bool, hapusData: Bool) {
        let sortDescriptor = KelasModels.siswaSortDescriptor ?? NSSortDescriptor(key: "mapel", ascending: true)

        var insertionIndexes = IndexSet()

        if hapusSiswa == true {
            guard var undoStackForKelas = undoUpdateStack[kelasSekarang], !undoStackForKelas.isEmpty else { return }

            // Ambil state terakhir dari stack undo untuk kelas yang sesuai
            let previousState = undoStackForKelas.removeLast()
            undoUpdateStack[kelasSekarang] = undoStackForKelas // Perbarui stack undo

            TableType.fromString(kelasSekarang) { [weak self] kelas in
                tableView.beginUpdates()
                for deletedData in previousState.reversed() {
                    guard let insertIndex = self?.viewModel.insertData(for: kelas, deletedData: deletedData, sortDescriptor: sortDescriptor, siswaID: self?.siswaID) else { continue }
                    insertionIndexes.insert(insertIndex)
                    #if DEBUG
                        print("insertionIndex:", insertIndex)
                    #endif
                    tableView.insertRows(at: IndexSet(integer: insertIndex), withAnimation: .slideDown)
                }
                tableView.endUpdates()
            }
        } else if hapusSiswa == false || hapusData == true {
            TableType.fromString(kelasSekarang) { [weak self] kelas in
                tableView.beginUpdates()
                for deletedData in model.reversed() {
                    self?.viewModel.updateModel(for: kelas, deletedData: deletedData, sortDescriptor: sortDescriptor, siswaID: self?.siswaID)
                }
                tableView.endUpdates()
            }
        }
        // Update table view untuk menampilkan baris yang diinsert
        if hapusSiswa == false {
            tableView.reloadData(forRowIndexes: insertionIndexes, columnIndexes: IndexSet(integersIn: 0 ..< tableView.numberOfColumns))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateSemesterTeks()
        }
    }

    /**
     Menangani notifikasi penghapusan kelas. Fungsi ini dipanggil ketika notifikasi `kelasDihapusNotification` diposting.

     - Parameter notification: Objek `Notification` yang berisi informasi tentang kelas yang dihapus.
                               Informasi ini mencakup `tableType` (jenis tabel kelas yang terpengaruh) dan
                               `deletedKelasIDs` (array ID kelas yang dihapus).

     Fungsi ini melakukan langkah-langkah berikut:
     1. Mengambil informasi dari notifikasi, termasuk `tableType` dan `deletedKelasIDs`.
     2. Memilih model data yang sesuai berdasarkan `tableType`.
     3. Mendapatkan referensi ke `UITableView` yang sesuai berdasarkan `tableType`.
     4. Memeriksa apakah operasi yang dilakukan adalah penghapusan data, kenaikan kelas, atau penghapusan kelas biasa.
     5. Memanggil fungsi yang sesuai (`updateRows` atau `deleteKelasRows`) untuk memperbarui tampilan tabel dan model data.
     6. Memperbarui model data di `viewModel` dengan model yang telah dimodifikasi.

     - Note: Fungsi ini mengasumsikan bahwa `notification.userInfo` berisi kunci "tableType" dengan nilai `TableType` dan
             kunci "deletedKelasIDs" dengan nilai array `Int64`.
     */
    @objc func handleKelasDihapusNotification(_ notification: Notification) {
        // Ambil informasi dari notifikasi
        if let userInfo = notification.userInfo,
           let tableType = userInfo["tableType"] as? TableType,
           let deletedKelasIDs = userInfo["deletedKelasIDs"] as? [Int64]
        {
            // Pilih model berdasarkan tableType dan lakukan operasi yang sesuai
            var modifiableModel = viewModel.kelasModelForTable(tableType, siswaID: siswaID)

            guard let table = getTableView(for: tableType.rawValue) else { return }

            // Cek apakah hapus data atau naik kelas
            if let hapusData = userInfo["hapusData"] as? Bool {
                guard hapusData == true else { return }
                updateRows(from: &modifiableModel, tableView: table, deletedIDs: deletedKelasIDs, kelasSekarang: viewModel.getKelasName(for: tableType), isDeleted: false, hapusSiswa: false, hapusData: hapusData, naikKelas: false)

            } else if let naikKelas = userInfo["naikKelas"] as? Bool {
                guard naikKelas == true else { return }
                updateRows(from: &modifiableModel, tableView: table, deletedIDs: deletedKelasIDs, kelasSekarang: viewModel.getKelasName(for: tableType), isDeleted: false, hapusSiswa: false, hapusData: true, naikKelas: true)

            } else {
                deleteKelasRows(from: &modifiableModel, tableView: table, tableType: tableType, deletedKelasIDs: deletedKelasIDs)
            }

            // Update model menggunakan setModel
            viewModel.setModel(modifiableModel, for: tableType, siswaID: siswaID)
        }
    }

    /**
         Menghapus baris kelas dari model data dan NSTableView.

         Fungsi ini menghapus baris kelas berdasarkan daftar ID kelas yang diberikan, memperbarui model data, dan menghapus baris yang sesuai dari NSTableView dengan animasi. Fungsi ini juga menyimpan data yang dihapus ke dalam undo stack.

         - Parameter:
             - model: Array `KelasModels` yang akan dimodifikasi. Parameter ini bersifat `inout` sehingga perubahan akan memengaruhi array asli.
             - tableView: NSTableView yang barisnya akan dihapus.
             - tableType: Enum `TableType` yang mengidentifikasi jenis tabel (misalnya, tabel utama atau tabel arsip). Ini digunakan untuk mengelola undo stack secara terpisah untuk setiap jenis tabel.
             - deletedKelasIDs: Array berisi `kelasID` dari baris yang akan dihapus.

         - Catatan:
             - Fungsi ini menggunakan `IndexSet` untuk menghapus baris secara efisien dari NSTableView.
             - Penghapusan baris dari NSTableView dilakukan secara asinkron dengan penundaan singkat untuk memungkinkan animasi berjalan dengan lancar.
             - Fungsi ini juga memanggil `updateSemesterTeks()` setelah penghapusan untuk memperbarui tampilan semester.
             - Data yang dihapus disimpan dalam `undoStack` untuk memungkinkan operasi undo di masa mendatang.
     */
    func deleteKelasRows(from model: inout [KelasModels], tableView: NSTableView, tableType: TableType, deletedKelasIDs: [Int64]) {
        var indexesToDelete = IndexSet()
        // Temukan indeks dari kelasID di model
        if undoStack[tableType] == nil {
            undoStack[tableType] = []
        }

        undoStack[tableType]?.append(model.filter { deletedKelasIDs.contains($0.kelasID) }.map { $0.copy() as! KelasModels })

        for (index, item) in model.enumerated() {
            if deletedKelasIDs.contains(item.kelasID) {
                indexesToDelete.insert(index) // Tambahkan indeks ke IndexSet untuk penghapusan
            }
        }
        // Hapus data dari model
        model.removeAll { item in
            deletedKelasIDs.contains(item.kelasID)
        }

        // Hapus baris dari NSTableView
        if !indexesToDelete.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                tableView.beginUpdates()
                tableView.removeRows(at: indexesToDelete, withAnimation: .slideUp)
                tableView.endUpdates()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateSemesterTeks()
        }
    }

    /**
     Menangani notifikasi pembatalan penghapusan kelas. Fungsi ini dipanggil ketika notifikasi `undoKelasDihapusNotification` diterima.

     - Parameter notification: Notifikasi yang berisi informasi tentang kelas yang dibatalkan penghapusannya.
                                 Informasi ini mencakup `tableType` (tipe tabel kelas), `deletedKelasIDs` (daftar ID kelas yang dihapus),
                                 dan `hapusData` (bendera yang menunjukkan apakah data telah dihapus).

     Fungsi ini melakukan langkah-langkah berikut:
     1. Mengekstrak informasi dari `userInfo` notifikasi.
     2. Berdasarkan `tableType`, menentukan model data dan tabel yang sesuai.
     3. Memeriksa nilai `hapusData`. Jika `true`, memanggil ``undoUpdateRows(from:tableView:kelasSekarang:hapusSiswa:hapusData:)`` untuk membatalkan pembaruan baris.
        Jika `false`, memanggil ``undoDeleteRows(from:tableView:tableType:)`` untuk membatalkan penghapusan baris.
     4. Memperbarui tampilan semester setelah operasi selesai.
     */
    @objc
    func handleUndoKelasDihapusNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let tableType = userInfo["tableType"] as? TableType,
           var data = userInfo["deletedData"] as? [KelasModels]
        {
            guard let tableView = getTableView(for: tableType.rawValue) else { return }

            if let hapusData = userInfo["hapusData"] as? Bool {
                undoUpdateRows(from: &data, tableView: tableView, kelasSekarang: tableType.stringValue, hapusSiswa: false, hapusData: hapusData)
            } else {
                undoDeleteRows(from: &data, tableView: tableView, tableType: tableType)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateSemesterTeks()
        }
    }

    /**
     Membatalkan penghapusan baris pada tabel. Fungsi ini mengambil state sebelumnya dari data yang dihapus dari stack undo,
     memasukkan kembali data tersebut ke dalam model, dan memperbarui tampilan tabel untuk mencerminkan perubahan.

     - Parameter model: Model data yang akan dimodifikasi.
     - Parameter tableView: Tampilan tabel yang akan diperbarui.
     - Parameter tableType: Jenis tabel yang sedang dioperasikan (misalnya, siswa, guru, dll.).
     - Parameter idBaru: Array berisi ID baru yang akan di insert.
     */
    func undoDeleteRows(from model: inout [KelasModels], tableView: NSTableView, tableType: TableType) {
        KelasModels.siswaSortDescriptor = tableView.sortDescriptors.first
        guard let sortDescriptor = KelasModels.siswaSortDescriptor else { return }

        var insertionIndexes = [Int]()
        for deletedData in model {
            guard let insertionIndex = viewModel.insertData(for: tableType, deletedData: deletedData, sortDescriptor: sortDescriptor, siswaID: siswaID) else {
                #if DEBUG
                    print("error insertionIndex undoDeleteRows DetailSiswaController")
                #endif
                continue
            }
            insertionIndexes.append(insertionIndex)
        }
        // Update table view untuk menampilkan baris yang diinsert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak tableView] in
            tableView?.beginUpdates()
            for index in insertionIndexes.sorted() {
                tableView?.insertRows(at: IndexSet(integer: index), withAnimation: .slideDown)
            }
            tableView?.endUpdates()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.updateSemesterTeks()
            }
        }
    }
}
