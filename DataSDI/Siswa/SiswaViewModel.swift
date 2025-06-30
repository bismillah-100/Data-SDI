//
//  SiswaViewModel.swift
//  Data SDI
//
//  Created by Bismillah on 21/09/24.
//
import AppKit
import Foundation

/**
 Mengelola data siswa untuk ditampilkan di `SiswaViewController`.

 ViewModel ini menyediakan data yang diperlukan oleh `SiswaViewController` dan menangani logika bisnis terkait dengan data siswa.
 */
class SiswaViewModel {
    /// Properti undoManager untuk viewModel ini.
    static var siswaUndoManager: UndoManager = .init()
    /// Instans ``DatabaseController``.
    private var dbController: DatabaseController!
    /// Properti untuk menyimpan siswa dari database yang telah difilter sesuai pilihan
    /// seperti tampilkan siswa lulus, sembunyikan siswa berhenti dan filter lain.
    private(set) lazy var filteredSiswaData: [ModelSiswa] = []

    /**
         Grup siswa yang dikelompokkan berdasarkan kriteria kelas.

         Pengelompokan ini diimplementasikan sebagai array dua dimensi, di mana setiap elemen luar mewakili sebuah grup,
         dan setiap elemen dalam adalah array dari objek `ModelSiswa` yang termasuk dalam grup tersebut.

         - Note: Inisialisasi awal dilakukan dengan 8 grup kosong.
     */
    private(set) lazy var groupedSiswa: [[ModelSiswa]] = [[], [], [], [], [], [], [], []]

    /**
         Antrian operasi pribadi yang digunakan untuk mengelola tugas-tugas asinkron.

         Digunakan untuk menjalankan operasi secara bersamaan tanpa memblokir thread utama.
     */
    private let operationQueue = OperationQueue()

    /// Properti untuk menyimpan referensi ketika ``SiswaViewController`` menggunakan
    /// mode tampilan grup atau non-grup.
    /// Digunakan untuk membedakan logika pengelolaan data di dalam fungsi yang sama.
    var isGrouped: Bool = false

    /**
     Inisialisasi ``SiswaViewModel`` dengan ``DatabaseController`` yang diberikan.

     - Parameter dbController: Instance ``DatabaseController`` yang digunakan untuk berinteraksi dengan database.

     Inisialisasi ini juga mengatur jumlah operasi maksimum konkuren pada `operationQueue` menjadi 1 dan kualitas layanan menjadi `userInitiated`.
     */
    init(dbController: DatabaseController) {
        self.dbController = dbController
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInitiated
    }

    // MARK: - SISWADATA related View

    /**
         Mengambil data siswa dari database secara asinkron dan menyimpannya ke dalam `filteredSiswaData`.

         Fungsi ini menggunakan `Task` untuk menjalankan pengambilan data dengan prioritas `userInitiated` agar tidak memblokir thread utama.
         Data siswa yang diambil akan difilter berdasarkan status pengelompokan (``isGrouped``).
     */
    func fetchSiswaData() async {
        filteredSiswaData = await Task(priority: .userInitiated) {
            await self.dbController.getSiswa(isGrouped)
        }.value
    }

    /**
         Saring siswa yang telah dihapus berdasarkan kriteria yang diberikan
         seperti menyembunyikan siswa berhenti atau siswa lulus.

         - Parameter sortDescriptor: Deskriptor pengurutan untuk hasil yang difilter.
         - Parameter group: Menentukan apakah hasil harus dikelompokkan.
         - Parameter filterBerhenti: Menentukan apakah siswa yang berhenti harus difilter.

         Fungsi ini melakukan penyaringan siswa yang dihapus berdasarkan parameter yang diberikan,
         dan secara opsional mengelompokkan hasilnya jika `group` bernilai `true`.
     */
    func filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper, group: Bool, filterBerhenti: Bool) async {
        await Task { [weak self] in
            guard let self else { return }
            if group { await self.getGroupSiswa() }
        }.value
    }

    /**
         Mencari siswa berdasarkan filter yang diberikan.

         Fungsi ini melakukan pencarian siswa di database berdasarkan filter yang diberikan.
         Hasil pencarian akan disimpan dalam properti `filteredSiswaData`.

         - Parameter filter: String yang digunakan sebagai filter pencarian.
     */
    func cariSiswa(_ filter: String) async {
        filteredSiswaData = await dbController.searchSiswa(query: filter)
    }

    /**
     Menghapus siswa pada indeks tertentu dari daftar yang difilter.

     Fungsi ini menghapus siswa dari daftar `filteredSiswaData` berdasarkan indeks yang diberikan.
     Siswa yang dihapus juga akan dihapus referensi gambarnya dari penyimpanan disk.

     - Parameter index: Indeks siswa yang akan dihapus dalam daftar `filteredSiswaData`.
     */
    func removeSiswa(at index: Int) {
        let siswaToRemove = filteredSiswaData[index]

        // Hapus dari database

        // Hapus dari siswaData dan filteredSiswaData
        if let siswaIndex = filteredSiswaData.firstIndex(where: { $0.id == siswaToRemove.id }) {
            filteredSiswaData.remove(at: siswaIndex)
        }
    }

    /**
     Menyisipkan objek `ModelSiswa` ke dalam `filteredSiswaData` pada indeks tertentu.

     Fungsi ini menambahkan siswa ke tampilan data yang difilter dan juga menangani penyimpanan referensi gambar ke disk.

     - Parameter siswa: Objek `ModelSiswa` yang akan disisipkan.
     - Parameter index: Indeks di mana siswa akan disisipkan dalam `filteredSiswaData`.
     */
    func insertSiswa(_ siswa: ModelSiswa, at index: Int) {
        // Tambahkan ke database

        // Tambahkan ke siswaData dan filteredSiswaData pada posisi yang sesuai
        filteredSiswaData.insert(siswa, at: index)
    }

    /**
     Memperbarui data siswa pada indeks tertentu.

     Fungsi ini memperbarui data siswa baik di sumber data utama (`siswaData`) maupun di array yang telah difilter (`filteredSiswaData`).
     Pembaruan juga mencakup penyimpanan referensi gambar siswa ke disk.

     - Parameter siswa: Objek `ModelSiswa` yang berisi data siswa yang telah diperbarui.
     - Parameter index: Indeks dari siswa yang akan diperbarui di dalam `filteredSiswaData`.

     - Note: Fungsi ini mengasumsikan bahwa `filteredSiswaData` telah diinisialisasi dan berisi data yang valid.
     */
    func updateSiswa(_ siswa: ModelSiswa, at index: Int) {
        let siswaToUpdate = filteredSiswaData[index]

        // Update di siswaData dan filteredSiswaData
        if let siswaIndex = filteredSiswaData.firstIndex(where: { $0.id == siswaToUpdate.id }) {
            filteredSiswaData[siswaIndex] = siswa
        }
    }

    /**
         Memperbarui data siswa dan mengirim notifikasi ke KelasVC dan DetailSiswaViewController.

         Fungsi ini melakukan serangkaian operasi, termasuk mengirim notifikasi berdasarkan perubahan data siswa,
         memperbarui database dengan data siswa yang baru, dan mengirim notifikasi setelah pembaruan database.

         - Parameter id: ID unik siswa yang akan diperbarui (Int64).
         - Parameter dataLama: ModelSiswa yang berisi data siswa sebelum pembaruan.
         - Parameter baru: ModelSiswa yang berisi data siswa yang telah diperbarui.

         **Logika Utama:**
         1. **Notifikasi Pra-Pembaruan:**
            - Memeriksa kondisi terkait perubahan kelas siswa dan mengirim notifikasi yang sesuai.
            - Kondisi yang diperiksa meliputi:
              - Kelas siswa tidak berubah dan bukan "Lulus".
              - Status siswa menjadi "Lulus".
              - Kelas siswa sebelumnya adalah "Lulus".
              - Kelas siswa yang baru kosong.
              - Selain kondisi di atas berarti kelas siswa telah berubah.

         2. **Pembaruan Database:**
            - Membandingkan setiap properti di `dataLama` dan `baru`.
            - Jika ada perbedaan, kolom yang sesuai di database akan diperbarui menggunakan `dbController`.
            - Properti yang diperbarui meliputi: nama, alamat, tanggal lahir, tahun daftar, nama wali, NIS, jenis kelamin, status, kelas saat ini, tanggal berhenti, foto, NISN, ayah, ibu, dan nomor telepon.
            - Juga memperbarui nama siswa di tabel kelas jika namanya berubah.

         3. **Notifikasi Pasca-Pembaruan:**
            - Mengirim notifikasi setelah database diperbarui, berdasarkan kondisi yang berbeda.
            - Kondisi yang diperiksa meliputi:
              - Kelas siswa tidak berubah dan bukan "Lulus".
              - Status siswa adalah "Lulus".
              - Kelas siswa sebelumnya adalah "Lulus".
              - Kelas siswa yang baru kosong.
              - Selain kondisi di atas berarti kelas siswa telah berubah.

         **Notifikasi yang Dikirim:**
         - `.siswaDihapus`: Dikirim ketika siswa dihapus (kelas menjadi kosong atau status menjadi "Lulus").
         - `.undoSiswaDihapus`: Dikirim ketika siswa dipulihkan (kelas sebelumnya "Lulus").
         - `.dataSiswaDiEditDiSiswaView`: Dikirim ketika data siswa diedit di SiswaView.

         **Catatan:**
         - Fungsi ini sangat bergantung pada `dbController` untuk interaksi database.
         - Fungsi ini menggunakan `NotificationCenter` untuk mengirim notifikasi ke komponen lain dalam aplikasi.
     */
    func updateDataSiswa(_ id: Int64, dataLama: ModelSiswa, baru: ModelSiswa) {
        /* kirim notifikasi sebelum database diupdate */
        if baru.kelasSekarang == dataLama.kelasSekarang, baru.kelasSekarang != "Lulus" {
            // kelasnya sama tapi kelas baru bukan lulus.
        } else if baru.status == "Lulus" {
            dbController.editSiswaLulus(namaSiswa: baru.nama, siswaID: baru.id, kelasBerikutnya: "Lulus")
            /* */
        } else if dataLama.kelasSekarang == "Lulus" {
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [baru.id],
                "kelasSekarang": baru.kelasSekarang,
                "isDeleted": true,
            ]
            NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
        } else if baru.kelasSekarang == "" {
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [baru.id],
                "kelasSekarang": dataLama.kelasSekarang,
                "isDeleted": true,
            ]
            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
        } else {
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [baru.id],
                "kelasSekarang": baru.kelasSekarang,
                "isDeleted": true,
            ]
            NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
        }

        /* update database */
        if dataLama.nama != baru.nama {
            dbController.updateKolomSiswa(id, kolom: "Nama", data: baru.nama)
            dbController.updateNamaSiswaInKelas(siswaID: id, namaValue: baru.nama)
        }
        if dataLama.alamat != baru.alamat {
            dbController.updateKolomSiswa(id, kolom: "Alamat", data: baru.alamat)
        }
        if dataLama.ttl != baru.ttl {
            dbController.updateKolomSiswa(id, kolom: "T.T.L.", data: baru.ttl)
        }
        if dataLama.tahundaftar != baru.tahundaftar {
            dbController.updateKolomSiswa(id, kolom: "Tahun Daftar", data: baru.tahundaftar)
        }
        if dataLama.namawali != baru.namawali {
            dbController.updateKolomSiswa(id, kolom: "Nama Wali", data: baru.namawali)
        }
        if dataLama.nis != baru.nis {
            dbController.updateKolomSiswa(id, kolom: "NIS", data: baru.nis)
        }
        if dataLama.jeniskelamin != baru.jeniskelamin {
            dbController.updateKolomSiswa(id, kolom: "Jenis Kelamin", data: baru.jeniskelamin)
        }
        if dataLama.status != baru.status {
            dbController.updateKolomSiswa(id, kolom: "Status", data: baru.status)
        }
        if dataLama.kelasSekarang != baru.kelasSekarang {
            dbController.updateKolomSiswa(id, kolom: "Kelas Aktif", data: baru.kelasSekarang)
        }
        if dataLama.tanggalberhenti != baru.tanggalberhenti {
            dbController.updateKolomSiswa(id, kolom: "Tgl. Lulus", data: baru.tanggalberhenti)
        }
        //if dataLama.foto != baru.foto {
            //dbController.updateFotoInDatabase(with: baru.foto, idx: id)
        //}
        if dataLama.nisn != baru.nisn {
            dbController.updateKolomSiswa(id, kolom: "NISN", data: baru.nisn)
        }
        if dataLama.ayah != baru.ayah {
            dbController.updateKolomSiswa(id, kolom: "Ayah", data: baru.ayah)
        }
        if dataLama.ibu != baru.ibu {
            dbController.updateKolomSiswa(id, kolom: "Ibu", data: baru.ibu)
        }
        if dataLama.tlv != baru.tlv {
            dbController.updateKolomSiswa(id, kolom: "Nomor Telepon", data: baru.tlv)
        }
        //if dataLama.foto != baru.foto {
            //dbController.updateFotoInDatabase(with: baru.foto, idx: id)
        //}

        /* kirim notifikasi setelah database diupdate */
        if baru.kelasSekarang == dataLama.kelasSekarang, baru.kelasSekarang != "Lulus" {
            // Ketika undo tidak merubah kelas sekarang dan kelas sekarang bukan Lulus
            let userInfo: [String: Any] = [
                "updateStudentIDs": baru.id,
                "kelasSekarang": baru.kelasSekarang,
                "namaSiswa": baru.nama,
            ]
            NotificationCenter.default.post(name: .dataSiswaDiEditDiSiswaView, object: nil, userInfo: userInfo)
        } else if baru.status == "Lulus" {
            /* */
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [baru.id],
                "kelasSekarang": dataLama.kelasSekarang,
                "isDeleted": true,
            ]
            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
        } else if dataLama.kelasSekarang == "Lulus" {
            // Kelas sekarang di dataLama adalah "Lulus"
        } else if baru.kelasSekarang == "" {
            // Kelas sekarang di data yang baru kosong
        } else {}
    }

    /**
         Menyaring data siswa berdasarkan status berhenti dan melakukan pengurutan.

         Fungsi ini menyaring data siswa berdasarkan status "berhenti". Jika `isBerhentiHidden` bernilai `true`,
         maka fungsi akan mencari index siswa yang memiliki status "berhenti" dari data `filteredSiswaData` yang sudah ada.
         Jika `isBerhentiHidden` bernilai `false`, fungsi akan mengambil data siswa terbaru dari database,
         mengurutkannya, dan kemudian mencari index siswa yang memiliki status "berhenti".

         - Parameter isBerhentiHidden: Boolean yang menentukan apakah siswa dengan status "berhenti" disembunyikan atau tidak.
                                       Jika `true`, pencarian dilakukan pada `filteredSiswaData` yang sudah ada.
                                       Jika `false`, data siswa diambil dari database dan diurutkan terlebih dahulu.
         - Parameter sortDescriptor:  Objek `SortDescriptorWrapper` yang digunakan untuk mengurutkan data siswa.
         - Returns: Array berisi index dari siswa yang memiliki status "berhenti".
     */
    func filterSiswaBerhenti(_ isBerhentiHidden: Bool, sortDescriptor: SortDescriptorWrapper) async -> [Int] {
        if isBerhentiHidden {
            return filteredSiswaData.enumerated().compactMap { index, siswa in
                siswa.status.lowercased() == "berhenti" ? index : nil
            }
        } else {
            filteredSiswaData = await dbController.getSiswa()
            await sortSiswa(by: sortDescriptor, isBerhenti: false)
            return filteredSiswaData.enumerated().compactMap { index, siswa in
                siswa.status.lowercased() == "berhenti" ? index : nil
            }
        }
    }

    /**
         Menyaring data siswa berdasarkan status kelulusan dan mengembalikan indeks siswa yang lulus.

         - Parameter tampilkanLulus: Boolean yang menentukan apakah akan menampilkan hanya siswa yang lulus atau tidak. Jika `false`, fungsi akan mengembalikan indeks siswa yang lulus dari data yang sudah difilter. Jika `true`, fungsi akan mengambil data siswa terbaru dari database, mengurutkannya, dan kemudian mengembalikan indeks siswa yang lulus.
         - Parameter sortDesc: Deskriptor pengurutan yang digunakan untuk mengurutkan data siswa jika `tampilkanLulus` adalah `true`.
         - Returns: Array berisi indeks dari siswa yang lulus. Jika tidak ada siswa yang lulus, array akan kosong.
     */
    func filterSiswaLulus(_ tampilkanLulus: Bool, sortDesc: SortDescriptorWrapper) async -> [Int] {
        if !tampilkanLulus {
            return filteredSiswaData.enumerated().compactMap { index, siswa in
                siswa.status.lowercased() == "lulus" ? index : nil
            }
        } else {
            filteredSiswaData = await dbController.getSiswa()
            await sortSiswa(by: sortDesc, isBerhenti: false)
            let indices = filteredSiswaData.enumerated().compactMap { index, siswa in
                siswa.status.lowercased() == "lulus" ? index : nil
            }

            // Print semua indeks sebelum mengembalikan
            return indices
        }
    }

    /**
         Mengambil nilai lama untuk kolom tertentu dari data siswa.

         Fungsi ini mengambil nilai dari properti tertentu dari objek `ModelSiswa`,
         berdasarkan `columnIdentifier` yang diberikan. Fungsi ini menangani baik data yang dikelompokkan maupun tidak dikelompokkan.

         - Parameter rowIndex: Indeks baris dalam array `data`. Opsional, defaultnya adalah `nil`.
         - Parameter columnIdentifier: String yang mengidentifikasi kolom yang nilainya akan diambil.
         - Parameter data: Array opsional dari `ModelSiswa` yang berisi data. Defaultnya adalah `nil`.
         - Parameter isGrouped: Boolean opsional yang menunjukkan apakah data dikelompokkan. Defaultnya adalah `false`.
         - Parameter groupIndex: Indeks grup dalam array `groupedSiswa`. Opsional, defaultnya adalah `nil`.
         - Parameter rowInSection: Indeks baris dalam bagian jika data dikelompokkan. Opsional, defaultnya adalah `nil`.

         - Returns: String yang mewakili nilai lama untuk kolom yang ditentukan. Mengembalikan string kosong jika `columnIdentifier` tidak cocok dengan kasus yang diketahui.
     */
    func getOldValueForColumn(rowIndex: Int? = nil, columnIdentifier: String, data: [ModelSiswa]? = nil, isGrouped: Bool? = false, groupIndex: Int? = nil, rowInSection: Int? = nil) -> String {
        switch columnIdentifier {
        case "Nama":
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].nama
            }
            return data![rowIndex!].nama
        case "Alamat":
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].alamat
            }
            return data![rowIndex!].alamat
        case "T.T.L":
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].ttl
            }
            return data![rowIndex!].ttl
        case "Nama Wali":
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].namawali
            }
            return data![rowIndex!].namawali
        case "NIS":
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].nis
            }
            return data![rowIndex!].nis
        case "NISN":
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].nisn
            }
            return data![rowIndex!].nisn
        case "Ayah":
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].ayah
            }
            return data![rowIndex!].ayah
        case "Ibu":
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].ibu
            }
            return data![rowIndex!].ibu
        case "Jenis Kelamin":
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].jeniskelamin
            }
            return data![rowIndex!].jeniskelamin
        case "Status":
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].status
            }
            return data![rowIndex!].status
        case "Nomor Telepon":
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].tlv
            }
            return data![rowIndex!].tlv
        default:
            return ""
        }
    }

    /**
     Memperbarui model data siswa dan database berdasarkan pengidentifikasi kolom yang diberikan.

     - Parameter id: ID unik siswa yang akan diperbarui.
     - Parameter columnIdentifier: Pengidentifikasi kolom yang akan diperbarui (misalnya, "Nama", "Alamat", dll.).
     - Parameter rowIndex: Indeks baris siswa dalam array `filteredSiswaData`, jika data tidak dikelompokkan. Opsional, defaultnya adalah `nil`.
     - Parameter newValue: Nilai baru untuk kolom yang ditentukan.
     - Parameter oldValue: Nilai lama untuk kolom yang ditentukan, digunakan untuk fungsi undo.
     - Parameter isGrouped: Menunjukkan apakah data siswa dikelompokkan atau tidak. Opsional, defaultnya adalah `nil`.
     - Parameter groupIndex: Indeks grup siswa dalam array `groupedSiswa`, jika data dikelompokkan. Opsional, defaultnya adalah `nil`.
     - Parameter rowInSection: Indeks baris siswa dalam bagian tertentu dari grup, jika data dikelompokkan. Opsional, defaultnya adalah `nil`.

     Fungsi ini melakukan hal berikut:
     1. Memperbarui database menggunakan fungsi `dbController` yang sesuai berdasarkan `columnIdentifier`.
     2. Memperbarui model data (`filteredSiswaData` atau `groupedSiswa`) dengan `newValue`.
     3. Memposting pemberitahuan (`NotificationCenter`) untuk memberi tahu bagian lain dari aplikasi tentang perubahan data.
     4. Memposting pemberitahuan undo dengan nilai sebelumnya.

     - Note: Fungsi ini menangani pembaruan untuk kolom-kolom seperti "Nama", "Alamat", "T.T.L", "Tahun Daftar", "Nama Wali", "NIS", "NISN", "Ayah", "Ibu", "Jenis Kelamin", "Status", "Tgl. Lulus", dan "Nomor Telepon".
     */
    func updateModelAndDatabase(id: Int64, columnIdentifier: String, rowIndex: Int? = nil, newValue: String, oldValue: String, isGrouped: Bool? = nil, groupIndex: Int? = nil, rowInSection: Int? = nil) {
        switch columnIdentifier {
        case "Nama":
            dbController.updateKolomNama(id, value: newValue)
            if UserDefaults.standard.bool(forKey: "sembunyikanSiswaBerhenti") || !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
                if let siswa = dbController.getKelasSiswa(id) {
                    let userInfo: [String: Any] = [
                        "updateStudentIDs": id,
                        "kelasSekarang": siswa.kelas,
                        "namaSiswa": siswa.nama,
                    ]
                    NotificationCenter.default.post(name: .dataSiswaDiEditDiSiswaView, object: nil, userInfo: userInfo)
                }
            }
            if isGrouped == true, let groupIndex, let rowInSection {
                let id = groupedSiswa[groupIndex][rowInSection].id
                groupedSiswa[groupIndex][rowInSection].nama = newValue
                let nama = groupedSiswa[groupIndex][rowInSection].nama
                let userInfo: [String: Any] = [
                    "updateStudentIDs": id,
                    "kelasSekarang": groupedSiswa[groupIndex][rowInSection].kelasSekarang,
                    "namaSiswa": nama,
                ]
                NotificationCenter.default.post(name: .dataSiswaDiEditDiSiswaView, object: nil, userInfo: userInfo)
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].nama = newValue
                let userInfo: [String: Any] = [
                    "updateStudentIDs": filteredSiswaData[rowIndex].id,
                    "kelasSekarang": filteredSiswaData[rowIndex].kelasSekarang,
                    "namaSiswa": filteredSiswaData[rowIndex].nama,
                ]
                NotificationCenter.default.post(name: .dataSiswaDiEditDiSiswaView, object: nil, userInfo: userInfo)
            }
        case "Alamat":
            dbController.updateKolomAlamat(id, value: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].alamat = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].alamat = newValue
            }
        case "T.T.L":
            dbController.updateKolomTglLahir(id, value: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].ttl = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].ttl = newValue
            }
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        case "Tahun Daftar":
            dbController.updateKolomTahunDaftar(id, value: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].tahundaftar = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].tahundaftar = newValue
            }
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        case "Nama Wali":
            dbController.updateKolomWali(id, value: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].namawali = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].namawali = newValue
            }
        case "NIS":
            dbController.updateKolomNIS(id, value: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].nis = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].nis = newValue
            }
        case "NISN":
            dbController.updateKolomNISN(id, value: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].nisn = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].nisn = newValue
            }
        case "Ayah":
            dbController.updateKolomAyah(id, value: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].ayah = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].ayah = newValue
            }
        case "Ibu":
            dbController.updateKolomIbu(id, value: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].ibu = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].ibu = newValue
                dbController.updateKolomIbu(filteredSiswaData[rowIndex].id, value: newValue)
            }
        case "Jenis Kelamin":
            dbController.updateKolomKelamin(id, value: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].jeniskelamin = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].jeniskelamin = newValue
            }
        case "Status":
            dbController.updateStatusSiswa(idSiswa: id, newStatus: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].status = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].status = newValue
            }
        case "Tgl. Lulus":
            dbController.updateTglBerhenti(kunci: id, editTglBerhenti: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].tanggalberhenti = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].tanggalberhenti = newValue
            }
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        case "Nomor Telepon":
            dbController.updateKolomTlv(id, value: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].tlv = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].tlv = newValue
            }
        default:
            break
        }
        if let rowIndex {
            NotificationCenter.default.post(name: .undoActionNotification, object: nil, userInfo: [
                "id": id,
                "rowIndex": rowIndex,
                "columnIdentifier": columnIdentifier,
                "newValue": oldValue,
            ])
        } else if isGrouped == true, let gi = groupIndex, let ris = rowInSection {
            NotificationCenter.default.post(name: .undoActionNotification, object: nil, userInfo: [
                "id": id,
                "groupIndex": gi,
                "rowInSection": ris,
                "columnIdentifier": columnIdentifier,
                "newValue": oldValue,
                "isGrouped": true,
            ])
        }
    }

    // MARK: - Image Kelas Aktif
    /**
     Menentukan nama gambar yang sesuai berdasarkan kelas siswa.

     - Parameter kelasSekarang: String yang merepresentasikan kelas siswa saat ini.
     - Returns: String yang merupakan nama gambar yang sesuai dengan kelas siswa. Mengembalikan "Kelas 1" hingga "Kelas 6" jika kelas sesuai, "lulus" jika kelas adalah "Lulus", dan "No Data" jika tidak ada kelas yang cocok.
     */
    func determineImageName(for kelasSekarang: String, bordered: Bool = false) -> String {
        let validClasses: Set<String> = [
            "Kelas 1", "Kelas 2", "Kelas 3", "Kelas 4", "Kelas 5", "Kelas 6", "lulus"
        ]

        if validClasses.contains(kelasSekarang) {
            return bordered ? "\(kelasSekarang) Bordered" : kelasSekarang
        } else {
            return bordered ? "No Data Bordered" : "No Data"
        }
    }


    // MARK: - GroupedSiswa related View

    /**
     Mengelompokkan data siswa ke dalam 8 grup berdasarkan kelas dan status.

     Fungsi ini memproses daftar siswa yang telah difilter (`filteredSiswaData`) dan mengelompokkannya ke dalam 8 grup berbeda.
     Pengelompokan didasarkan pada properti `kelasSekarang` dan `status` dari setiap siswa.

     - Grup 0-5: Siswa dikelompokkan berdasarkan `kelasSekarang`. Jika `kelasSekarang` adalah "Kelas 1", siswa akan masuk ke grup 0, "Kelas 2" ke grup 1, dan seterusnya hingga "Kelas 6" ke grup 5.
     - Grup 6: Siswa dengan `status` "Lulus" akan masuk ke grup ini.
     - Grup 7: Siswa yang tidak memiliki informasi `kelasSekarang` (kosong) dan `status` bukan "Lulus" akan masuk ke grup ini.

     Fungsi ini menggunakan `withTaskGroup` untuk melakukan pemrosesan secara konkuren, meningkatkan kinerja saat menangani sejumlah besar data siswa.
     Setelah pengelompokan selesai, fungsi ini memperbarui properti `groupedSiswa` dengan hasil yang dikelompokkan.

     - Note: Fungsi ini mengasumsikan bahwa `filteredSiswaData` sudah diinisialisasi dan berisi data siswa yang akan diproses.
     */
    func getGroupSiswa() async {
        // Inisialisasi ulang groupedSiswa dengan 8 grup kosong
        var tempGroupedSiswa = Array(repeating: [ModelSiswa](), count: 8)

        // Gunakan withTaskGroup untuk memproses setiap siswa secara konkuren
        await withTaskGroup(of: (Int, ModelSiswa)?.self) { group in
            for siswa in filteredSiswaData {
                group.addTask {
                    // Jika status siswa "Lulus", kita masukkan ke grup indeks 6
                    if siswa.status.lowercased() == "lulus" {
                        return (6, siswa)
                    }
                    // Jika field kelas kosong dan status bukan "Lulus", masukkan ke grup indeks 7
                    else if siswa.kelasSekarang.isEmpty, siswa.status.lowercased() != "lulus" {
                        return (7, siswa)
                    } else {
                        // Bersihkan string, menghilangkan kata "Kelas "
                        let cleanedString = siswa.kelasSekarang.replacingOccurrences(of: "Kelas ", with: "")

                        // Konversi string ke bilangan bulat
                        if let kelasIndex = Int(cleanedString), kelasIndex >= 1, kelasIndex <= 6 {
                            // Kurangi 1 karena indeks array mulai dari 0
                            return (kelasIndex - 1, siswa)
                        } else {
                            // Jika terjadi kesalahan konversi atau di luar range, kembalikan nil
                            return nil
                        }
                    }
                }
            }

            // Kumpulkan hasil dari setiap task secara sequential
            for await result in group {
                guard let (groupIndex, siswa) = result else { continue }
                tempGroupedSiswa[groupIndex].append(siswa)
            }
        }

        // Update variabel groupedSiswa (misalnya property class) dengan hasil penggabungan
        groupedSiswa = tempGroupedSiswa
    }

    /**
     Memperbarui data siswa dalam grup yang ditentukan.

     Fungsi ini memperbarui data siswa pada indeks tertentu dalam grup yang ditentukan. Jika grup belum ada, grup akan dibuat.
     Jika indeks yang diberikan berada di luar batas, siswa akan ditambahkan di awal grup.

     - Parameter:
        - siswa: Objek `ModelSiswa` yang akan diperbarui.
        - groupIndex: Indeks grup tempat siswa berada.
        - index: Indeks siswa dalam grup yang akan diperbarui.
     */
    func updateGroupSiswa(_ siswa: ModelSiswa, groupIndex: Int, index: Int) {
        while groupedSiswa.count <= groupIndex {
            groupedSiswa.append([])
        }
        let safeIndex = min(index, groupedSiswa[groupIndex].count - 1)
        if safeIndex >= 0 {
            groupedSiswa[groupIndex][safeIndex] = siswa
        } else {
            groupedSiswa[groupIndex].insert(siswa, at: 0)
        }
    }

    /**
     Menghapus siswa dari grup tertentu berdasarkan indeks grup dan indeks siswa.

     - Parameter groupIndex: Indeks grup siswa yang ingin dihapus.
     - Parameter index: Indeks siswa dalam grup yang ingin dihapus.

     Fungsi ini melakukan langkah-langkah berikut:
     1. Memastikan bahwa `groupIndex` dan `index` berada dalam batas yang valid dari array `groupedSiswa`. Jika indeks tidak valid, fungsi akan keluar tanpa melakukan apa pun.
     2. Menghapus referensi gambar ke disk untuk siswa yang akan dihapus menggunakan `removeImageReferenceToDisk(for:)`.
     3. Menghapus siswa dari grup yang ditentukan pada indeks yang diberikan.
     */
    func removeGroupSiswa(groupIndex: Int, index: Int) {
        guard groupIndex < groupedSiswa.count, index < groupedSiswa[groupIndex].count else {
            return
        }
        groupedSiswa[groupIndex].remove(at: index)
    }

    /**
     Memasukkan siswa ke dalam grup tertentu pada indeks tertentu.

     Fungsi ini menambahkan siswa ke dalam array `groupedSiswa` pada indeks grup dan indeks siswa yang ditentukan.
     Jika grup yang ditentukan belum ada, grup baru akan dibuat.
     Fungsi ini juga memastikan bahwa indeks siswa yang diberikan valid dan siswa tidak duplikat dalam grup.

     - Parameter:
        - siswa: Objek `ModelSiswa` yang akan dimasukkan.
        - groupIndex: Indeks grup tempat siswa akan dimasukkan.
        - index: Indeks dalam grup tempat siswa akan dimasukkan.
     */
    func insertGroupSiswa(_ siswa: ModelSiswa, groupIndex: Int, index: Int) {
        // Tambahkan grup kosong jika perlu
        while groupedSiswa.count <= groupIndex {
            groupedSiswa.append([])
        }
        // Pastikan index tidak melebihi jumlah siswa
        if index <= groupedSiswa[groupIndex].count {
            if !groupedSiswa[groupIndex].contains(where: { $0.id == siswa.id }) {
                groupedSiswa[groupIndex].insert(siswa, at: index)
            }
        }
    }

    /**
     Mencari siswa dalam grup berdasarkan ID siswa.

     Fungsi ini mencari siswa dengan ID yang sesuai dalam array `groupedSiswa`.
     Jika siswa ditemukan, fungsi ini mengembalikan indeks grup dan indeks baris siswa tersebut dalam grup.

     - Parameter:
        - id: ID siswa yang ingin dicari.

     - Returns:
        Tuple yang berisi indeks grup dan indeks baris siswa jika siswa ditemukan. Mengembalikan `nil` jika siswa tidak ditemukan dalam grup manapun.
     */
    func findSiswaInGroups(id: Int64) -> (Int, Int)? {
        for (groupIndex, group) in groupedSiswa.enumerated() {
            if let rowIndex = group.firstIndex(where: { $0.id == id }) {
                return (groupIndex, rowIndex)
            }
        }
        return nil
    }

    /**
     Menghitung indeks baris absolut dalam tampilan tabel yang dikelompokkan.

     - Parameter groupIndex: Indeks grup.
     - Parameter rowIndex: Indeks baris dalam grup.
     - Returns: Indeks baris absolut.
     */
    func getAbsoluteRowIndex(groupIndex: Int, rowIndex: Int) -> Int {
        var absoluteRowIndex = 0
        for i in 0 ..< groupIndex {
            absoluteRowIndex += groupedSiswa[i].count + 1 // +1 for header
        }
        return absoluteRowIndex + rowIndex + 1 // +1 for header
    }

    /**
         Mengurutkan data siswa berdasarkan deskriptor pengurutan yang diberikan.

         Fungsi ini mengurutkan array `filteredSiswaData` berdasarkan kunci dan urutan yang ditentukan dalam `sortDescriptor`.
         Jika nilai untuk kunci pengurutan sama untuk dua siswa, fungsi ini akan membandingkan nama siswa untuk menentukan urutan.
         Untuk kunci tanggal (seperti "tahundaftar" dan "tanggalberhenti"), fungsi ini menggunakan `DateFormatter` untuk mengonversi string tanggal menjadi objek `Date` untuk perbandingan.

         - Parameter:
             - sortDescriptor: Objek `SortDescriptorWrapper` yang berisi kunci dan urutan pengurutan (menaik atau menurun).
             - isBerhenti: Boolean yang menunjukkan apakah siswa tersebut berhenti atau tidak. Parameter ini tidak digunakan dalam implementasi fungsi.

         - Catatan:
             Fungsi ini menggunakan metode bantu `compareStrings` dan `compareDates` untuk melakukan perbandingan string dan tanggal, masing-masing.
             Jika konversi tanggal gagal, fungsi ini akan mengembalikan `false`, yang dapat memengaruhi urutan pengurutan.
     */
    func sortSiswa(by sortDescriptor: SortDescriptorWrapper, isBerhenti: Bool) async {
        filteredSiswaData.sort { $0.compare(to: $1, using: sortDescriptor.asNSSortDescriptor) == .orderedAscending }
    }

    /**
     Mengambil ID siswa berdasarkan indeks baris dalam mode yang dikelompokkan.

     Fungsi ini mencari ID siswa berdasarkan indeks baris yang diberikan dalam tampilan yang dikelompokkan.
     Ini mengiterasi melalui setiap kelompok siswa dan memeriksa apakah indeks baris yang diberikan berada dalam rentang kelompok tersebut.
     Jika ditemukan, ia menghitung indeks siswa relatif dalam kelompok dan mengembalikan ID siswa tersebut.

     - Parameter row: Indeks baris dalam tampilan yang dikelompokkan.
     - Returns: ID siswa (Int64) jika ditemukan dalam indeks baris yang diberikan; jika tidak, mengembalikan -1.
     */
    func getSiswaIdInGroupedMode(row: Int) -> Int64 {
        for (groupIndex, siswaGroup) in groupedSiswa.enumerated() {
            let absoluteRowIndex = getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: 0)
            let endRowIndex = absoluteRowIndex + siswaGroup.count
            if row >= absoluteRowIndex, row < endRowIndex {
                let siswaIndex = row - absoluteRowIndex
                return siswaGroup[siswaIndex].id
            }
        }
        return -1 /// nilai default negatif jika tidak ditemukan
    }

    /**
         Mengurutkan grup siswa berdasarkan deskriptor pengurutan yang diberikan.

         Fungsi ini mengambil array `groupedSiswa`, yang berisi array siswa yang dikelompokkan,
         dan mengurutkan setiap grup berdasarkan properti yang ditentukan dalam `sortDescriptor`.
         Pengurutan dilakukan secara in-place, memodifikasi array `groupedSiswa` secara langsung.

         - Parameter sortDescriptor: Deskriptor yang menentukan properti yang akan diurutkan dan urutan pengurutan (menaik atau menurun).

         Properti yang Didukung untuk Pengurutan:
         - "nama": Nama siswa (String).
         - "alamat": Alamat siswa (String). Jika alamat sama, urutkan berdasarkan nama.
         - "ttl": Tanggal lahir siswa (String). Jika tanggal lahir sama, urutkan berdasarkan nama.
         - "tahundaftar": Tahun pendaftaran siswa (String dengan format "dd MMMM yyyy"). Jika tahun pendaftaran sama, urutkan berdasarkan nama.
         - "namawali": Nama wali siswa (String). Jika nama wali sama, urutkan berdasarkan nama.
         - "nis": Nomor Induk Siswa (String). Jika NIS sama, urutkan berdasarkan nama.
         - "ayahkandung": Nama ayah kandung siswa (String). Jika nama ayah sama, urutkan berdasarkan nama.
         - "ibukandung": Nama ibu kandung siswa (String). Jika nama ibu sama, urutkan berdasarkan nama.
         - "nisn": Nomor Induk Siswa Nasional (String). Jika NISN sama, urutkan berdasarkan nama.
         - "tlv": Nomor Telepon/HP siswa (String). Jika nomor telepon sama, urutkan berdasarkan nama.
         - "jeniskelamin": Jenis kelamin siswa (String). Jika jenis kelamin sama, urutkan berdasarkan nama.
         - "status": Status siswa (String). Jika status sama, urutkan berdasarkan nama.
         - "tanggalberhenti": Tanggal berhenti sekolah siswa (String dengan format "dd MMMM yyyy"). Jika tanggal berhenti sama, urutkan berdasarkan nama.

         Jika properti yang ditentukan dalam `sortDescriptor` tidak dikenali, tidak ada pengurutan yang dilakukan untuk grup tersebut.
     */
    func sortGroupSiswa(by sortDescriptor: SortDescriptorWrapper) async {
        let nsDescriptor = sortDescriptor.asNSSortDescriptor

        let sortedGroupedSiswa = groupedSiswa.map { group in
            group.sorted { $0.compare(to: $1, using: nsDescriptor) == .orderedAscending }
        }

        // Perbarui grup yang ada dengan grup yang sudah diurutkan
        for (index, sortedGroup) in sortedGroupedSiswa.enumerated() {
            groupedSiswa[index] = sortedGroup
        }
    }

    deinit {
        operationQueue.cancelAllOperations()
    }
}

extension SiswaViewModel {
    /**
         Melakukan operasi 'undo' pada perubahan data siswa.

         Fungsi ini membalikkan perubahan terakhir yang dilakukan pada data siswa, baik dalam mode pengelompokan maupun tidak.
         Operasi 'undo' dicatat menggunakan `UndoManager` untuk memungkinkan operasi 'redo'.

         - Parameter originalModel: Objek `DataAsli` yang berisi informasi tentang perubahan yang akan dibatalkan,
                                   termasuk ID siswa, pengidentifikasi kolom, nilai baru, dan nilai lama.

         - Precondition: `filteredSiswaData` harus terinisialisasi dengan benar.
         - Postcondition: Data siswa di model dan database telah dikembalikan ke nilai sebelumnya.
         - Note: Fungsi ini juga memposting notifikasi `undoActionNotification` untuk memberitahu komponen lain tentang operasi 'undo'.
     */
    func undoAction(originalModel: DataAsli) {
        if isGrouped == true {
            guard let siswa = findSiswaInGroups(id: originalModel.ID) else {
                updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, newValue: originalModel.oldValue, oldValue: originalModel.newValue)

                NotificationCenter.default.post(name: .undoActionNotification, object: nil, userInfo: [
                    "id": originalModel.ID,
                    "columnIdentifier": originalModel.columnIdentifier,
                ])
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                    self.redoAction(originalModel: originalModel)
                })
                return
            }
            updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, newValue: originalModel.oldValue, oldValue: originalModel.oldValue, isGrouped: true, groupIndex: siswa.0, rowInSection: siswa.1)
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                targetSelf.redoAction(originalModel: originalModel)
            })
        } else if !isGrouped {
            // Cari indeks di model berdasarkan ID
            guard let rowIndexToUpdate = filteredSiswaData.firstIndex(where: { $0.id == originalModel.ID }) else {
                updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, newValue: originalModel.oldValue, oldValue: originalModel.newValue)
                NotificationCenter.default.post(name: .undoActionNotification, object: nil, userInfo: [
                    "id": originalModel.ID,
                    "columnIdentifier": originalModel.columnIdentifier,
                ])
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { [weak self] targetSelf in
                    self?.redoAction(originalModel: originalModel)
                })
                return
            }

            // Perbarui data di model
            updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, rowIndex: rowIndexToUpdate, newValue: originalModel.oldValue, oldValue: originalModel.oldValue)
            SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                targetSelf.redoAction(originalModel: originalModel)
            })
        }
    }

    /**
     Melakukan aksi redo berdasarkan model data asli. Fungsi ini menangani pembaruan data baik dalam mode berkelompok (grouped) maupun tidak berkelompok (non-grouped),
     serta mendaftarkan aksi undo yang sesuai menggunakan `UndoManager`.

     - Parameter originalModel: Model `DataAsli` yang berisi informasi tentang perubahan yang akan di-redo, termasuk ID, pengidentifikasi kolom, nilai baru, dan nilai lama.

     ## Logika Fungsi:
     1. **Mode Berkelompok (isGrouped == true):**
        - Mencari siswa dalam kelompok menggunakan ID.
        - Jika siswa tidak ditemukan dalam kelompok, data akan diperbarui langsung di database dan model, kemudian memposting notifikasi `undoActionNotification`.
        - Mendaftarkan aksi undo untuk mengembalikan perubahan ini.
        - Jika siswa ditemukan dalam kelompok, data akan diperbarui dalam kelompok tersebut.
     2. **Mode Tidak Berkelompok (isGrouped == false):**
        - Mencari indeks baris yang sesuai dalam `filteredSiswaData` berdasarkan ID.
        - Jika indeks tidak ditemukan, data akan diperbarui langsung di database dan model, kemudian memposting notifikasi `undoActionNotification`.
        - Mendaftarkan aksi undo untuk mengembalikan perubahan ini.
        - Jika indeks ditemukan, data akan diperbarui pada indeks tersebut.
     3. **Pendaftaran Undo:**
        - Setelah pembaruan data, fungsi ini selalu mendaftarkan aksi undo menggunakan `SiswaViewModel.siswaUndoManager` untuk memungkinkan pengguna membatalkan (undo) perubahan yang telah dilakukan.

     ## Catatan:
     - Fungsi ini menggunakan `NotificationCenter` untuk memposting notifikasi `undoActionNotification` yang dapat digunakan oleh komponen lain dalam aplikasi untuk merespons aksi undo.
     - Fungsi ini bergantung pada `SiswaViewModel.siswaUndoManager` untuk mengelola operasi undo dan redo.
     */
    func redoAction(originalModel: DataAsli) {
        if isGrouped == true {
            guard let siswa = findSiswaInGroups(id: originalModel.ID) else {
                updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, newValue: originalModel.newValue, oldValue: originalModel.oldValue)
                NotificationCenter.default.post(name: .undoActionNotification, object: nil, userInfo: [
                    "id": originalModel.ID,
                    "columnIdentifier": originalModel.columnIdentifier,
                ])
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                    self.undoAction(originalModel: originalModel)
                })
                return
            }
            updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, newValue: originalModel.newValue, oldValue: originalModel.oldValue, isGrouped: true, groupIndex: siswa.0, rowInSection: siswa.1)
        } else if !isGrouped {
            // Cari indeks di model berdasarkan ID
            guard let rowIndexToUpdate = filteredSiswaData.firstIndex(where: { $0.id == originalModel.ID }) else {
                updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, newValue: originalModel.newValue, oldValue: originalModel.oldValue)

                NotificationCenter.default.post(name: .undoActionNotification, object: nil, userInfo: [
                    "id": originalModel.ID,
                    "columnIdentifier": originalModel.columnIdentifier,
                ])
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                    self.undoAction(originalModel: originalModel)
                })
                return
            }

            // Perbarui data di model
            updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, rowIndex: rowIndexToUpdate, newValue: originalModel.newValue, oldValue: originalModel.oldValue)
        }
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
            targetSelf.undoAction(originalModel: originalModel)
        })
    }

    /**
     Membatalkan perubahan data siswa dan mendaftarkan operasi undo.

     Fungsi ini membatalkan perubahan yang dilakukan pada data siswa dan mengembalikan data ke keadaan sebelumnya.
     Operasi ini juga mendaftarkan tindakan undo dengan `UndoManager`, memungkinkan pengguna untuk membatalkan operasi ini.

     - Parameter data: Array `ModelSiswa` yang berisi data siswa yang akan dikembalikan ke keadaan sebelumnya.
                       Data ini digunakan untuk mencari data siswa yang sesuai dan mengembalikannya ke nilai sebelumnya.

     - Note: Fungsi ini memposting notifikasi `updateEditSiswa` untuk memberitahu komponen lain tentang perubahan data.
     */
    func undoEditSiswa(_ data: [ModelSiswa]) {
        var oldData = [ModelSiswa]()
        for snapshotSiswa in data {
            if UserDefaults.standard.bool(forKey: "sembunyikanSiswaBerhenti") {
                oldData.append(dbController.getSiswa(idValue: snapshotSiswa.id))
                continue
            }
            if !isGrouped {
                if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
                    oldData.append(dbController.getSiswa(idValue: snapshotSiswa.id))
                    continue
                }

                if let matchedSiswaData = filteredSiswaData.first(where: { $0.id == snapshotSiswa.id }) {
                    oldData.append(matchedSiswaData)
                }
            } else {
                for (_, group) in groupedSiswa.enumerated() {
                    // Cari matchedSiswaData dalam grup saat ini
                    if let matchedSiswaData = group.first(where: { $0.id == snapshotSiswa.id }) {
                        oldData.append(matchedSiswaData)
                    }
                }
            }
        }
        NotificationCenter.default.post(name: .updateEditSiswa, object: nil, userInfo: ["data": data])
        // Daftarkan undo dengan metode redoEditSiswa
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] target in
            guard let self else { return }
            self.undoEditSiswa(oldData)
        }
    }
}

/**
    Struktur pembungkus untuk `NSSortDescriptor` agar sesuai dengan protokol `Sendable`.

    Struktur ini merangkum properti kunci dan urutan menaik dari sebuah `NSSortDescriptor`,
    memungkinkannya untuk dilewatkan dengan aman antar thread.

    - Note: Digunakan untuk membungkus `NSSortDescriptor` agar sesuai dengan protokol `Sendable`.
 */
struct SortDescriptorWrapper: Sendable {
    let key: String
    let ascending: Bool

    var asNSSortDescriptor: NSSortDescriptor {
        NSSortDescriptor(key: self.key, ascending: self.ascending)
    }

    static func from(_ descriptor: NSSortDescriptor) -> SortDescriptorWrapper {
        SortDescriptorWrapper(key: descriptor.key ?? "", ascending: descriptor.ascending)
    }
}
