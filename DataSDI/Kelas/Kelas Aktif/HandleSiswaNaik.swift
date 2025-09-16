//
//  Handle SiswaNaik.swift
//  Data SDI
//
//  Created by MacBook on 03/08/25.
//

import AppKit
import Combine

extension KelasVC {
    /// Mengatur langganan event dari SiswaViewModel menggunakan Combine framework
    ///
    /// Method ini melakukan setup subscriber untuk menangani berbagai event terkait siswa:
    /// - Aktivasi siswa ke kelas tertentu
    /// - Membatalkan aktivasi siswa
    /// - Perpindahan kelas siswa (promosi)
    /// - Membatalkan perpindahan kelas siswa
    ///
    /// Event-event tersebut diterima dari ``SiswaViewModel/kelasEvent`` publisher dan diproses
    /// di thread utama dengan delay 100ms untuk memastikan UI dapat terupdate dengan baik.
    ///
    /// Subscriber disimpan dalam `cancellables` untuk proper memory management.
    func setupCombine() {
        guard !isCombineSetup else { return }
        SiswaViewModel.shared.kelasEvent
            .receive(on: RunLoop.main)
            .delay(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case let .aktifkanSiswa(id, kelas: kelas):
                    aktifkanSiswa(id, kelas: kelas)
                case let .undoAktifkanSiswa(id, kelas: kelas):
                    undoAktifkanSiswa(id, kelas: kelas)
                case let .kelasBerubah(id, fromKelas: kelasAwal):
                    siswaDidPromote(id, fromKelas: kelasAwal)
                case let .undoUbahKelas(id, toKelas: kelasBaru, status: status):
                    undoSiswaDidPromote(id, toKelas: kelasBaru, status: status)
                }
            }
            .store(in: &cancellables)

        #if DEBUG
            print("combine KelasVC is set.")
        #endif
    }

    /// Menangani promosi siswa dari kelas awal ke kelas berikutnya
    /// - Parameters:
    ///   - siswaID: ID unik siswa yang akan dipromosikan
    ///   - fromKelas: String yang menunjukkan kelas asal siswa
    /// - Note: Fungsi ini akan:
    ///   1. Mencari data siswa di kelas awal berdasarkan siswaID
    ///   2. Menyimpan salinan data siswa ke array siswaNaikArray
    ///   3. Menghapus data siswa dari kelas awal
    ///   4. Memperbarui tampilan tabel untuk mencerminkan perubahan
    func siswaDidPromote(_ siswaID: Int64, fromKelas: String) {
        TableType.fromString(fromKelas) { kelasAwal in
            guard let kelasData = viewModel.kelasData[kelasAwal] else { return }

            updateTableViewAndModel(kelasData: kelasData, kelasAwal: kelasAwal)
        }

        func updateTableViewAndModel(kelasData: [KelasModels], kelasAwal: TableType) {
            var updates: [UpdateData] = []
            for (index, dataKelas) in kelasData.enumerated().reversed() {
                if dataKelas.siswaID == siswaID {
                    KelasViewModel.siswaNaikArray[kelasAwal, default: []].append(kelasData[index].copy() as! KelasModels)
                    #if DEBUG
                        print("insertsiswaNaikArray:", KelasViewModel.siswaNaikArray[kelasAwal]?.first?.nilai as Any)
                    #endif
                    let update = viewModel.removeData(index: index, tableType: kelasAwal)
                    updates.append(update)
                }
            }

            guard let tableView = tableViewManager.getTableView(for: kelasAwal.rawValue),
                  tableView.numberOfRows >= 1
            else { return }
            UpdateData.applyUpdates(updates, tableView: tableView, deselectAll: false)
        }
    }

    /// Membatalkan perpindahan siswa yang telah dinaikan ke kelas berikutnya.
    ///
    /// Fungsi ini akan mengembalikan data siswa ke kelas awalnya setelah sebelumnya dinaikan.
    /// Hanya berlaku untuk siswa dengan status aktif.
    ///
    /// - Parameters:
    ///   - siswaID: ID unik dari siswa yang akan dibatalkan kenaikannya
    ///   - toKelas: Nama kelas tujuan siswa sebelumnya dalam bentuk string
    ///   - status: Status siswa yang harus berupa `.aktif`
    ///
    /// - Note:
    ///   - Fungsi ini akan memperbarui tampilan tabel dan data array sesuai dengan pembatalan
    ///   - Proses update tabel dilakukan dalam satu transaksi menggunakan `beginUpdates()` dan `endUpdates()`
    ///   - Data siswa akan dihapus dari array kenaikan kelas setelah dikembalikan ke kelas awal
    func undoSiswaDidPromote(_ siswaID: Int64, toKelas: String, status: StatusSiswa) {
        guard status == .aktif else { return }

        TableType.fromString(toKelas) { kelasAwal in
            guard let kelasData = KelasViewModel.siswaNaikArray[kelasAwal] else {
                KelasViewModel.siswaNaikArray[kelasAwal, default: []].removeAll(where: { $0.siswaID == siswaID })
                return
            }

            guard let tableView = tableViewManager.getTableView(for: kelasAwal.rawValue),
                  let sd = tableView.sortDescriptors.first,
                  let comparator = KelasModels.comparator(from: sd)
            else { return }

            tableView.beginUpdates()
            for data in kelasData where data.siswaID == siswaID {
                guard let index = viewModel.insertData(for: kelasAwal, deletedData: data, comparator: comparator) else { continue }
                tableView.insertRows(at: IndexSet(integer: index))
            }
            tableView.endUpdates()

            KelasViewModel.siswaNaikArray[kelasAwal, default: []].removeAll(where: { $0.siswaID == siswaID })
        }
    }

    /// Mengaktifkan kembali data siswa yang sebelumnya telah dinaikkan ke kelas yang lebih tinggi
    /// - Parameters:
    ///   - siswaID: ID siswa yang akan diaktifkan kembali
    ///   - kelas: String yang merepresentasikan kelas siswa ("A", "B", "C", dst)
    /// - Note: Fungsi ini akan:
    ///   1. Mengambil data siswa dari database berdasarkan ID dan kelas
    ///   2. Menambahkan kembali data tersebut ke dalam tabel view yang sesuai
    ///   3. Memperbarui tampilan tabel secara atomik dengan animasi
    /// - Important: Operasi database dijalankan secara asinkron di thread terpisah untuk menjaga performa UI
    func aktifkanSiswa(_ siswaID: Int64, kelas: String) {
        TableType.fromString(kelas) { type in
            guard let tableView = tableViewManager.getTableView(for: type.rawValue),
                  viewModel.isDataLoaded[type] == true
            else { return }

            Task.detached { [weak self, tableView] in
                guard let self else { return }

                let data = await dbController.getKelas(type, siswaID: siswaID, priority: .userInitiated)
                #if DEBUG
                    print("dataCount:", data.count)
                #endif
                await MainActor.run { [weak self] in
                    guard let self, let sortDescriptor = tableView.sortDescriptors.first,
                          let comparator = KelasModels.comparator(from: sortDescriptor)
                    else { return }

                    tableView.beginUpdates()
                    for i in data {
                        guard let index = viewModel.insertData(for: type, deletedData: i, comparator: comparator) else { continue }
                        tableView.insertRows(at: IndexSet(integer: index))
                    }
                    tableView.endUpdates()
                }
            }
        }
    }

    /**
     Membatalkan aktivasi siswa dari kelas tertentu.

     Fungsi ini melakukan:
     1. Mencari data siswa berdasarkan ID di kelas yang ditentukan
     2. Memindahkan data siswa ke array siswaNaik
     3. Menghapus data siswa dari kelas awal
     4. Memperbarui tampilan tabel

     - Parameters:
        - siswaID: ID unik siswa yang akan dibatalkan aktivasinya
        - kelas: String yang merepresentasikan kelas awal siswa

     - Important: Fungsi ini menggunakan `TableType.fromString` untuk mengkonversi string kelas menjadi enum `TableType`

     - Note: Operasi ini akan memperbarui:
       * Array `siswaNaikArray` di `KelasViewModel`
       * Data kelas di `viewModel`
       * Tampilan tabel yang sesuai
     */
    func undoAktifkanSiswa(_ siswaID: Int64, kelas: String) {
        var updates: [UpdateData] = []
        TableType.fromString(kelas) { kelasAwal in
            guard viewModel.isDataLoaded[kelasAwal] == true,
                  let kelasData = viewModel.kelasData[kelasAwal],
                  let tableView = tableViewManager.getTableView(for: kelasAwal.rawValue)
            else { return }
            for (index, dataKelas) in kelasData.enumerated().reversed() where dataKelas.siswaID == siswaID {
                let update = viewModel.removeData(index: index, tableType: kelasAwal)
                updates.append(update)
            }

            UpdateData.applyUpdates(updates, tableView: tableView, deselectAll: false)
        }
    }
}

extension DetailSiswaController {
    /**
     Mengatur Combine event subscriber untuk memproses perubahan status dan kelas siswa.

     Method ini mengatur subscriber untuk menangani berbagai event dari `SiswaViewModel.kelasEvent` yang terkait dengan:
     - Aktivasi/deaktivasi status siswa
     - Perubahan kelas siswa (naik/pindah kelas)
     - Pembatalan (undo) perubahan status dan kelas

     Events yang ditangani:
     - `aktifkanSiswa`: Mengaktifkan siswa di kelas tertentu
     - `undoAktifkanSiswa`: Membatalkan aktivasi siswa
     - `kelasBerubah`: Memproses kenaikan/perpindahan kelas siswa
     - `undoUbahKelas`: Membatalkan perubahan kelas siswa

     - Note: Event diproses di background thread dengan delay 200ms untuk menghindari race condition
     */
    func setupCombine() {
        SiswaViewModel.shared.kelasEvent
            .receive(on: DispatchQueue.global(qos: .background))
            .delay(for: .milliseconds(200), scheduler: DispatchQueue.global(qos: .background))
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case let .aktifkanSiswa(id, kelas: kelas):
                    aktifkanSiswa(id, kelas: kelas)
                case let .undoAktifkanSiswa(id, kelas: kelas):
                    undoAktifkanSiswa(id, kelas: kelas)
                case let .kelasBerubah(id, fromKelas: kelasAwal):
                    siswaDidPromote(id, fromKelas: kelasAwal)
                case let .undoUbahKelas(id, kelasBaru, status):
                    undoSiswaDidPromote(id, toKelas: kelasBaru, status: status)
                }
            }
            .store(in: &cancellables)
    }

    /// Menangani proses ketika seorang siswa naik kelas
    /// - Parameters:
    ///   - siswaID: ID unik dari siswa yang naik kelas
    ///   - fromKelas: String yang merepresentasikan kelas asal siswa
    /// - Important: Fungsi ini akan mengubah status aktif siswa di kelas sebelumnya menjadi tidak aktif
    /// - Note: Fungsi ini akan:
    ///   1. Memeriksa apakah siswaID sesuai
    ///   2. Mengonversi string kelas ke TableType
    ///   3. Memperbarui status aktif siswa di kelas sebelumnya
    ///   4. Memperbarui data kelas di viewModel
    ///   5. Memperbarui tampilan semester secara asinkron
    func siswaDidPromote(_ siswaID: Int64, fromKelas: String) {
        guard self.siswaID == siswaID else { return }

        TableType.fromString(fromKelas) { kelasAwal in
            guard let kelasData = viewModel.siswaKelasData[siswaID]?[kelasAwal] else { return }

            for (index, _) in kelasData.enumerated().reversed() {
                kelasData[index].aktif = false
            }

            viewModel.setModel(kelasData, for: kelasAwal, siswaID: siswaID)

            DispatchQueue.main.async { [weak self] in
                self?.updateSemesterTeks()
            }
        }
    }

    /// Membatalkan proses kenaikan siswa dan mengembalikan status siswa ke kelas sebelumnya
    /// - Parameters:
    ///   - siswaID: ID unik siswa yang akan dibatalkan kenaikannya
    ///   - toKelas: String yang merepresentasikan kelas tujuan awal siswa
    ///   - status: Status siswa (aktif/tidak aktif) yang akan diterapkan
    /// - Note: Fungsi ini akan:
    ///   1. Memeriksa kesesuaian ID siswa
    ///   2. Mengubah status keaktifan siswa di kelas awal
    ///   3. Memperbarui data kelas siswa
    ///   4. Memperbarui tampilan teks semester
    func undoSiswaDidPromote(_ siswaID: Int64, toKelas: String, status: StatusSiswa) {
        guard self.siswaID == siswaID else { return }

        TableType.fromString(toKelas) { kelasAwal in
            guard let kelasData = viewModel.siswaKelasData[siswaID]?[kelasAwal] else { return }

            for data in kelasData {
                data.aktif = status == .aktif
            }
            viewModel.setModel(kelasData, for: kelasAwal, siswaID: siswaID)

            DispatchQueue.main.async { [weak self] in
                self?.updateSemesterTeks()
            }
        }
    }

    /// Mengaktifkan status siswa untuk kelas tertentu
    /// - Parameters:
    ///   - siswaID: ID unik siswa yang akan diaktifkan
    ///   - kelas: String yang merepresentasikan tipe kelas
    /// - Note: Fungsi ini akan:
    ///   - Memeriksa apakah siswaID sesuai
    ///   - Mengubah status aktif menjadi true untuk semua data kelas siswa
    ///   - Memperbarui tampilan teks semester pada thread utama
    func aktifkanSiswa(_ siswaID: Int64, kelas: String) {
        guard self.siswaID == siswaID else { return }

        TableType.fromString(kelas) { type in
            guard let kelasData = viewModel.siswaKelasData[siswaID]?[type] else { return }

            for i in kelasData {
                i.aktif = true
            }

            DispatchQueue.main.async { [weak self] in
                self?.updateSemesterTeks()
            }
        }
    }

    /// Membatalkan pengaktifan status siswa pada kelas tertentu
    /// - Parameters:
    ///   - siswaID: ID siswa yang akan dibatalkan pengaktifannya
    ///   - kelas: String yang merepresentasikan kelas siswa
    /// - Note: Fungsi ini akan:
    ///   1. Memeriksa kecocokan siswaID
    ///   2. Mengubah status aktif menjadi false untuk semua data kelas siswa
    ///   3. Memperbarui model data
    ///   4. Memperbarui tampilan teks semester di UI
    func undoAktifkanSiswa(_ siswaID: Int64, kelas: String) {
        guard self.siswaID == siswaID else { return }
        TableType.fromString(kelas) { kelasAwal in
            guard let kelasData = viewModel.siswaKelasData[siswaID]?[kelasAwal] else { return }
            for dataKelas in kelasData {
                dataKelas.aktif = false
            }
            viewModel.setModel(kelasData, for: kelasAwal, siswaID: siswaID)

            DispatchQueue.main.async { [weak self] in
                self?.updateSemesterTeks()
            }
        }
    }
}
