//
//  SiswaViewModel.swift
//  Data SDI
//
//  Created by Bismillah on 21/09/24.
//
import AppKit
import Combine

/**
 Mengelola data siswa untuk ditampilkan di `SiswaViewController`.

 ViewModel ini menyediakan data yang diperlukan oleh `SiswaViewController` dan menangani logika bisnis terkait dengan data siswa.
 */
class SiswaViewModel {
    /// Membuat singleton ``SiswaViewModel``.
    static let shared: SiswaViewModel = .init()
    /// Properti undoManager untuk viewModel ini.
    static var siswaUndoManager: UndoManager = .init()
    /// Instance ``DatabaseController``.
    private let dbController: DatabaseController = .shared
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

    /// Properti untuk menyimpan referensi ketika ``SiswaViewController`` menggunakan
    /// mode tampilan grup atau non-grup.
    /// Digunakan untuk membedakan logika pengelolaan data di dalam fungsi yang sama.
    var isGrouped: Bool = false

    /// Publisher ketika siswa berubah status atau kelas.
    let kelasEvent: PassthroughSubject<NaikKelasEvent, Never> = .init()

    /**
     Inisialisasi ``SiswaViewModel``.

     Inisialisasi ini mengatur jumlah operasi maksimum konkuren pada `operationQueue` menjadi 1 dan kualitas layanan menjadi `userInitiated`.
     */
    private init() {}

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

         - Parameter group: Menentukan apakah hasil harus dikelompokkan.

         Fungsi ini melakukan penyaringan siswa yang dihapus berdasarkan parameter yang diberikan,
         dan secara opsional mengelompokkan hasilnya jika `group` bernilai `true`.
     */
    func filterDeletedSiswa(group: Bool) async {
        await Task.detached { [weak self] in
            guard let self else { return }
            if group { await getGroupSiswa() }
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
        filteredSiswaData.remove(at: index)
    }

    func insertHiddenSiswa(_ id: Int64, comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) -> Int {
        let siswa = dbController.getSiswa(idValue: id)
        return insertSiswa(siswa, comparator: comparator)
    }

    func insertHiddenSiswaGroup(
        _ id: Int64,
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool
    )
        -> (
            groupIndex: Int,
            rowIndex: Int,
            absoluteRow: Int
        )
    {
        let siswa = dbController.getSiswa(idValue: id)
        let (groupIndex, rowIndex) = insertGroupSiswa(siswa, comparator: comparator)
        let absoluteRow = getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: rowIndex)
        return (groupIndex, rowIndex, absoluteRow)
    }

    /**
     Menyisipkan objek `ModelSiswa` ke dalam `filteredSiswaData` pada indeks tertentu.

     Fungsi ini menambahkan siswa ke tampilan data yang difilter dan juga menangani penyimpanan referensi gambar ke disk.

     - Parameter siswa: Objek `ModelSiswa` yang akan disisipkan.
     - Parameter comparator: Comparator perbandingan objek untuk urutan *insert*.
     */
    func insertSiswa(_ siswa: ModelSiswa, comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) -> Int {
        if let index = filteredSiswaData.firstIndex(where: { $0.id == siswa.id }) {
            return index
        } else {
            let index = filteredSiswaData.insertionIndex(for: siswa, using: comparator)
            filteredSiswaData.insert(siswa, at: index)
            return index
        }
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
        if baru.tingkatKelasAktif == dataLama.tingkatKelasAktif, baru.tingkatKelasAktif != .lulus {
            // kelasnya sama tapi kelas bukan lulus.
        } else if baru.status == .lulus {
            dbController.editSiswaLulus(siswaID: baru.id, tanggalLulus: baru.tanggalberhenti, statusEnrollment: .lulus, registerUndo: false)
            /* */
        } else if dataLama.tingkatKelasAktif == .lulus {
            dbController.editSiswaLulus(siswaID: baru.id, tanggalLulus: nil, statusEnrollment: .aktif, registerUndo: false)
        }

        /* update database */
        if dataLama.nama != baru.nama {
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.nama, data: baru.nama)
            addAutocomplete(baru.nama, to: &ReusableFunc.namasiswa)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.nama: baru.nama])
            NotifSiswaDiedit.sendNotif(baru)
        }
        if dataLama.alamat != baru.alamat {
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.alamat, data: baru.alamat)
            addAutocomplete(baru.alamat, to: &ReusableFunc.alamat)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.alamat: baru.alamat])
        }
        if dataLama.ttl != baru.ttl {
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.ttl, data: baru.ttl)
            addAutocomplete(baru.ttl, to: &ReusableFunc.ttl)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.ttl: baru.ttl])
        }
        if dataLama.tahundaftar != baru.tahundaftar {
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.tahundaftar, data: baru.tahundaftar)
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        }
        if dataLama.namawali != baru.namawali {
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.namawali, data: baru.namawali)
            addAutocomplete(baru.namawali, to: &ReusableFunc.namawali)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.namawali: baru.namawali])
        }
        if dataLama.nis != baru.nis {
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.nis, data: baru.nis)
            addAutocomplete(baru.nis, to: &ReusableFunc.nis)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.namawali: baru.nis])
        }
        if dataLama.jeniskelamin != baru.jeniskelamin {
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.jeniskelaminColumn, data: String(baru.jeniskelamin.rawValue))
        }
        if dataLama.status != baru.status {
            dbController.updateStatusSiswa(idSiswa: id, newStatus: baru.status)
        }
        if dataLama.tingkatKelasAktif != baru.tingkatKelasAktif {
            // dbController.updateKolomSiswa(id, kolom: "Kelas Aktif", data: baru.tingkatKelasAktif.rawValue)
        }
        if dataLama.tanggalberhenti != baru.tanggalberhenti {
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.tanggalberhenti, data: baru.tanggalberhenti)
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        }
        if dataLama.nisn != baru.nisn {
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.nisn, data: baru.nisn)
            addAutocomplete(baru.nisn, to: &ReusableFunc.nisn)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.nisn: baru.nisn])
        }
        if dataLama.ayah != baru.ayah {
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.ayah, data: baru.ayah)
            addAutocomplete(baru.ayah, to: &ReusableFunc.namaAyah)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.ayah: baru.ayah])
        }
        if dataLama.ibu != baru.ibu {
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.ibu, data: baru.ibu)
            addAutocomplete(baru.ibu, to: &ReusableFunc.namaIbu)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.ibu: baru.ibu])
        }
        if dataLama.tlv != baru.tlv {
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.tlv, data: baru.tlv)
            addAutocomplete(baru.tlv, to: &ReusableFunc.tlvString)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.tlv: baru.tlv])
        }
        // if dataLama.foto != baru.foto {
        // dbController.updateFotoInDatabase(with: baru.foto, idx: id)
        // }

        /* kirim notifikasi setelah database diupdate */
        if baru.tingkatKelasAktif == dataLama.tingkatKelasAktif, baru.tingkatKelasAktif != .lulus {
        } else if baru.status == .lulus {
            /* */
        } else if dataLama.tingkatKelasAktif == .lulus {
            // Kelas sekarang di dataLama adalah "Lulus"
        } else if baru.tingkatKelasAktif == .belumDitentukan {
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
                siswa.status == .berhenti ? index : nil
            }
        } else {
            filteredSiswaData = await dbController.getSiswa()
            sortSiswa(by: sortDescriptor.asNSSortDescriptor, isBerhenti: false)
            return filteredSiswaData.enumerated().compactMap { index, siswa in
                siswa.status == .berhenti ? index : nil
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
                siswa.status == .lulus ? index : nil
            }
        } else {
            filteredSiswaData = await dbController.getSiswa()
            sortSiswa(by: sortDesc.asNSSortDescriptor, isBerhenti: false)
            let indices = filteredSiswaData.enumerated().compactMap { index, siswa in
                siswa.status == .lulus ? index : nil
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
    func getOldValueForColumn(rowIndex: Int? = nil, columnIdentifier: SiswaColumn, data: [ModelSiswa]? = nil, isGrouped: Bool? = false, groupIndex: Int? = nil, rowInSection: Int? = nil) -> String {
        switch columnIdentifier {
        case .nama:
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].nama
            }
            return data![rowIndex!].nama
        case .alamat:
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].alamat
            }
            return data![rowIndex!].alamat
        case .ttl:
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].ttl
            }
            return data![rowIndex!].ttl
        case .namawali:
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].namawali
            }
            return data![rowIndex!].namawali
        case .nis:
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].nis
            }
            return data![rowIndex!].nis
        case .nisn:
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].nisn
            }
            return data![rowIndex!].nisn
        case .ayah:
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].ayah
            }
            return data![rowIndex!].ayah
        case .ibu:
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].ibu
            }
            return data![rowIndex!].ibu
        case .jeniskelamin:
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].jeniskelamin.description
            }
            return data![rowIndex!].jeniskelamin.description
        case .status:
            if isGrouped == true {
                return groupedSiswa[groupIndex!][rowInSection!].status.description
            }
            return data![rowIndex!].status.description
        case .tlv:
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
    func updateModelAndDatabase(id: Int64, columnIdentifier: SiswaColumn, rowIndex: Int? = nil, newValue: String, oldValue: String, isGrouped: Bool? = nil, groupIndex: Int? = nil, rowInSection: Int? = nil) {
        switch columnIdentifier {
        case .nama:
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.nama, data: StringInterner.shared.intern(newValue))
            if UserDefaults.standard.bool(forKey: "sembunyikanSiswaBerhenti") || !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
                if let siswa = dbController.getKelasSiswa(id) {
                    let userInfo = NotifSiswaDiedit(
                        updateStudentID: id,
                        kelasSekarang: siswa.kelas,
                        namaSiswa: siswa.nama
                    )
                    NotificationCenter.default.post(name: .dataSiswaDiEditDiSiswaView, object: nil, userInfo: userInfo.asUserInfo)
                }
            }
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].nama = StringInterner.shared.intern(newValue)
                NotifSiswaDiedit.sendNotif(groupedSiswa[groupIndex][rowInSection])
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].nama = StringInterner.shared.intern(newValue)
                NotifSiswaDiedit.sendNotif(filteredSiswaData[rowIndex])
            }
            addAutocomplete(newValue, to: &ReusableFunc.namasiswa)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.nama: newValue])
        case .alamat:
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.alamat, data: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].alamat = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].alamat = newValue
            }
            addAutocomplete(newValue, to: &ReusableFunc.alamat)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.alamat: newValue])
        case .ttl:
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.ttl, data: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].ttl = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].ttl = newValue
            }
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
            addAutocomplete(newValue, to: &ReusableFunc.ttl)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.alamat: newValue])
        case .tahundaftar:
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.tahundaftar, data: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].tahundaftar = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].tahundaftar = newValue
            }
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        case .namawali:
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.namawali, data: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].namawali = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].namawali = newValue
            }
            addAutocomplete(newValue, to: &ReusableFunc.namawali)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.namawali: newValue])
        case .nis:
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.nis, data: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].nis = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].nis = newValue
            }
            addAutocomplete(newValue, to: &ReusableFunc.nis)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.nis: newValue])
        case .nisn:
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.nisn, data: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].nisn = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].nisn = newValue
            }
            addAutocomplete(newValue, to: &ReusableFunc.nisn)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.nisn: newValue])
        case .ayah:
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.ayah, data: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].ayah = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].ayah = newValue
            }
            addAutocomplete(newValue, to: &ReusableFunc.namaAyah)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.ayah: newValue])
        case .ibu:
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.ibu, data: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].ibu = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].ibu = newValue
            }
            addAutocomplete(newValue, to: &ReusableFunc.namaIbu)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.ibu: newValue])
        case .jeniskelamin:
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.jeniskelaminColumn, data: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].jeniskelamin = JenisKelamin.from(description: newValue) ?? .lakiLaki
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].jeniskelamin = JenisKelamin.from(description: newValue) ?? .lakiLaki
            }
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        case .status:
            if let statusSiswa = StatusSiswa.from(description: newValue) {
                dbController.updateStatusSiswa(idSiswa: id, newStatus: statusSiswa)
            }
            if isGrouped == true, let groupIndex, let rowInSection {
                if let status = StatusSiswa.from(description: newValue) {
                    groupedSiswa[groupIndex][rowInSection].status = status
                } else {
                    groupedSiswa[groupIndex][rowInSection].status = .aktif
                }
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                if let status = StatusSiswa.from(description: newValue) {
                    filteredSiswaData[rowIndex].status = status
                } else {
                    filteredSiswaData[rowIndex].status = .aktif
                }
            }
        case .tanggalberhenti:
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.tanggalberhenti, data: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].tanggalberhenti = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].tanggalberhenti = newValue
            }
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        case .tlv:
            dbController.updateKolomSiswa(id, kolom: SiswaColumns.tlv, data: newValue)
            if isGrouped == true, let groupIndex, let rowInSection {
                groupedSiswa[groupIndex][rowInSection].tlv = newValue
            } else if isGrouped == nil, let rowIndex, rowIndex < filteredSiswaData.count {
                filteredSiswaData[rowIndex].tlv = newValue
            }
            addAutocomplete(newValue, to: &ReusableFunc.tlvString)
            DatabaseController.shared.catatSuggestions(data: [SiswaColumn.tlv: newValue])
        default:
            break
        }
        if let rowIndex {
            UndoActionNotification.sendNotif(id, columnIdentifier: columnIdentifier, rowIndex: rowIndex, newValue: oldValue)
        } else if isGrouped == true, let gi = groupIndex, let ris = rowInSection {
            UndoActionNotification.sendNotif(id, columnIdentifier: columnIdentifier, groupIndex: gi, rowIndex: ris, newValue: oldValue, isGrouped: true)
        }
    }

    private func addAutocomplete(_ value: String, to set: inout Set<String>) {
        var words: Set<String> = []
        words.formUnion(value.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 || ($0.count > 1 && $0.first?.isLetter == true) })
        words.insert(value.capitalizedAndTrimmed())
        set.formUnion(words)
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
                    if siswa.status == .lulus {
                        return (6, siswa)
                    }
                    // Jika field kelas kosong dan status bukan "Lulus", masukkan ke grup indeks 7
                    else if siswa.tingkatKelasAktif.rawValue.isEmpty {
                        return (7, siswa)
                    } else {
                        // Bersihkan string, menghilangkan kata "Kelas "
                        let cleanedString = siswa.tingkatKelasAktif.rawValue.replacingOccurrences(of: "Kelas ", with: "")

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

     Fungsi ini menambahkan siswa ke dalam array ``groupedSiswa`` pada indeks grup dan indeks siswa yang ditentukan.
     Jika grup yang ditentukan belum ada, grup baru akan dibuat.
     Fungsi ini juga memastikan bahwa indeks siswa yang diberikan valid dan siswa tidak duplikat dalam grup.

     - Parameter siswa: Objek ``ModelSiswa`` yang akan dimasukkan.
     - Parameter groupIndex: Indeks grup tempat siswa akan dimasukkan.
     - Parameter index: Indeks dalam grup tempat siswa akan dimasukkan.
     - Parameter comparator: Comparator perbandingan objek untuk urutan *insert*.
     - Returns: **Tuple (groupIndex: Int, rowIndex: Int)** - Index group dan index data
                di dalam group yang baru ditambahkan ke array ``groupedSiswa``.
     */
    func insertGroupSiswa(_ siswa: ModelSiswa, comparator:
        @escaping (ModelSiswa, ModelSiswa) -> Bool) -> (groupIndex: Int, rowIndex: Int)
    {
        let groupIndex = getGroupIndexForStudent(siswa) ?? 7
        // Tambahkan grup kosong jika perlu
        while groupedSiswa.count <= groupIndex {
            groupedSiswa.append([])
        }

        let index = groupedSiswa[groupIndex].insertionIndex(for: siswa, using: comparator)

        // Pastikan index tidak melebihi jumlah siswa
        if index <= groupedSiswa[groupIndex].count {
            if !groupedSiswa[groupIndex].contains(where: { $0.id == siswa.id }) {
                groupedSiswa[groupIndex].insert(siswa, at: index)
            }
        }

        return (groupIndex, index)
    }

    /// Mengembalikan indeks grup yang sesuai siswa berdasarkan status kelulusan atau tingkat kelasnya.
    ///
    /// Fungsi ini bertindak sebagai helper untuk menentukan di mana seorang siswa harus
    /// ditempatkan dalam tampilan tabel yang dikelompokkan. Jika siswa berstatus
    /// 'lulus', fungsi akan mencari indeks grup untuk status kelulusan. Jika tidak,
    /// ia akan mencari indeks grup berdasarkan tingkat kelas aktif siswa.
    ///
    /// - Parameter siswa: Objek `ModelSiswa` yang mewakili siswa yang akan diperiksa.
    /// - Returns: Indeks grup (`Int`) dari siswa tersebut, atau `nil` jika grup
    ///            yang sesuai tidak ditemukan.
    func getGroupIndexForStudent(_ siswa: ModelSiswa) -> Int? {
        siswa.status == .lulus
            ? getGroupIndex(forClassName: StatusSiswa.lulus.description)
            : getGroupIndex(forClassName: siswa.tingkatKelasAktif.rawValue)
    }

    /**
         Menentukan indeks grup berdasarkan nama kelas siswa.

         Fungsi ini menerima nama kelas sebagai input dan mengembalikan indeks grup yang sesuai.
         Kelas "Lulus" akan dimasukkan ke dalam grup dengan indeks 6. Kelas dengan nama kosong "" akan dimasukkan ke grup dengan indeks 7.
         Untuk kelas dengan format "Kelas [nomor]", fungsi akan mengekstrak nomor kelas dan menggunakannya untuk menentukan indeks grup.
         Nomor kelas 1-6 akan menghasilkan indeks grup 0-5 secara berurutan.

         - Parameter className: Nama kelas siswa (misalnya, "Kelas 1", "Kelas 6", "Lulus").

         - Returns:
             Indeks grup yang sesuai dengan nama kelas. Mengembalikan `nil` jika nama kelas tidak valid atau tidak dikenali.
     */
    func getGroupIndex(forClassName className: String) -> Int? {
        if className == KelasAktif.lulus.rawValue {
            return 6 // Jika kelas adalah "Lulus", masukkan ke indeks ke-7 (indeks dimulai dari 0)
        } else if className == "" {
            return 7
        } else {
            // Menghapus "Kelas " dari string untuk mendapatkan nomor kelas
            let cleanedString = className.replacingOccurrences(of: "Kelas ", with: "")

            // Konversi nomor kelas dari String ke Int
            if let kelasIndex = Int(cleanedString) {
                // Periksa apakah kelasIndex berada dalam rentang yang diharapkan (1 hingga 6)
                if kelasIndex >= 1, kelasIndex <= 6 {
                    // Mengembalikan indeks grup berdasarkan nomor kelas (kurangi 1 karena array dimulai dari indeks 0)
                    return kelasIndex - 1
                }
            }
        }
        // Jika kelas tidak ditemukan atau nomor kelas tidak valid, kembalikan nilai nil
        return nil
    }

    /**
     Mencari siswa dalam grup berdasarkan ID siswa.

     Fungsi ini mencari siswa dengan ID yang sesuai dalam array `groupedSiswa`.
     Jika siswa ditemukan, fungsi ini mengembalikan indeks grup dan indeks baris siswa tersebut dalam grup.

     - Parameter id: ID siswa yang ingin dicari.

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

    /// Merelokasi (memindahkan) data siswa ke posisi yang benar dalam model data.
    ///
    /// Fungsi ini bertindak sebagai dispatcher, mengarahkan pemanggilan ke fungsi
    /// yang sesuai untuk mode tabel yang sedang aktif. Fungsi ini menentukan apakah
    /// siswa harus direlokasi dalam mode datar (`.plain`) atau mode group (`.grouped`)
    /// dan mengembalikan objek ``UpdateData`` yang sesuai untuk memperbarui UI.
    ///
    /// - Parameters:
    ///   - siswa: Objek ``ModelSiswa`` yang akan direlokasi.
    ///   - comparator: Sebuah closure yang digunakan untuk membandingkan dua
    ///     siswa untuk menentukan posisi pengurutan yang benar.
    ///   - mode: Mode tampilan tabel saat ini, `.plain` atau `.grouped`.
    ///   - columnIndex: Indeks kolom opsional untuk pembaruan UI yang lebih spesifik.
    /// - Returns: Sebuah objek ``UpdateData`` yang berisi detail pembaruan yang diperlukan
    ///   untuk UI, atau `nil` jika siswa tidak ditemukan.
    func relocateSiswa(
        _ siswa: ModelSiswa,
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool,
        mode: TableViewMode,
        columnIndex: Int? = nil
    ) -> UpdateData? {
        switch mode {
        case .plain: relocateSiswa(siswa, comparator: comparator, columnIndex: columnIndex)
        case .grouped: relocateSiswaInGroup(siswa, comparator: comparator, columnIndex: columnIndex)
        }
    }

    /// Menghapus siswa dari model data berdasarkan mode tampilan.
    ///
    /// Fungsi ini mencari siswa berdasarkan ID dan menghapusnya dari model data
    /// yang sesuai, baik ``filteredSiswaData`` untuk mode `.plain` atau
    /// ``groupedSiswa`` untuk mode `.grouped`. Setelah menghapus, fungsi ini
    /// mengembalikan objek ``UpdateData`` yang merepresentasikan tindakan penghapusan
    /// untuk diperbarui di UI.
    ///
    /// - Parameters:
    ///   - siswa: Objek ``ModelSiswa`` yang akan dihapus.
    ///   - mode: Mode tampilan tabel saat ini, `.plain` atau `.grouped`.
    /// - Returns: Sebuah objek ``UpdateData`` yang berisi detail penghapusan,
    ///   atau `nil` jika siswa tidak ditemukan dalam model.
    func removeSiswa(_ siswa: ModelSiswa, mode: TableViewMode) -> UpdateData? {
        switch mode {
        case .plain:
            guard let index = filteredSiswaData.firstIndex(where: { $0.id == siswa.id }) else { return nil }
            removeSiswa(at: index)
            return .remove(index: index)

        case .grouped:
            guard let (groupIndex, rowIndex) = findSiswaInGroups(id: siswa.id) else { return nil }
            removeGroupSiswa(groupIndex: groupIndex, index: rowIndex)
            let absoluteIndex = getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: rowIndex)
            return .remove(index: absoluteIndex)
        }
    }

    private func relocateSiswa(
        _ siswa: ModelSiswa,
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool,
        columnIndex: Int? = nil
    ) -> UpdateData? {
        // Cek apakah siswa sudah ada
        if let oldIndex = filteredSiswaData.firstIndex(where: { $0.id == siswa.id }) {
            // Hapus dari lokasi lama
            removeSiswa(at: oldIndex)

            // Sisipkan ke lokasi baru
            let newIndex = insertSiswa(siswa, comparator: comparator)

            // Tentukan jenis update berdasarkan perubahan
            if oldIndex == newIndex {
                return columnIndex != nil ?
                    .moveRowAndReloadColumn(from: oldIndex, to: newIndex, columnIndex: columnIndex!) :
                    .reload(index: newIndex, selectRow: true, extendSelection: true)
            } else {
                return columnIndex != nil ?
                    .moveRowAndReloadColumn(from: oldIndex, to: newIndex, columnIndex: columnIndex!) :
                    .move(from: oldIndex, to: newIndex)
            }
        } else {
            // Siswa tidak ditemukan, mungkin tersembunyi - sisipkan kembali
            let newIndex = insertSiswa(siswa, comparator: comparator)
            return .insert(index: newIndex)
        }
    }

    // Modifikasi fungsi yang sudah ada untuk Grouped Mode
    private func relocateSiswaInGroup(
        _ siswa: ModelSiswa,
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool,
        columnIndex: Int? = nil
    ) -> UpdateData? {
        guard let oldLocation = findSiswaInGroups(id: siswa.id) else { return nil }
        removeGroupSiswa(groupIndex: oldLocation.0, index: oldLocation.1)
        let newLocation = insertGroupSiswa(siswa, comparator: comparator)

        let oldAbsoluteIndex = getAbsoluteRowIndex(groupIndex: oldLocation.0, rowIndex: oldLocation.1)
        let newAbsoluteIndex = getAbsoluteRowIndex(groupIndex: newLocation.groupIndex, rowIndex: newLocation.rowIndex)

        let update: UpdateData = if oldAbsoluteIndex == newAbsoluteIndex {
            if let columnIndex {
                .moveRowAndReloadColumn(from: oldAbsoluteIndex, to: newAbsoluteIndex, columnIndex: columnIndex)
            } else {
                .reload(index: newAbsoluteIndex, selectRow: true, extendSelection: true)
            }
        } else {
            if let columnIndex {
                .moveRowAndReloadColumn(from: oldAbsoluteIndex, to: newAbsoluteIndex, columnIndex: columnIndex)
            } else {
                .move(from: oldAbsoluteIndex, to: newAbsoluteIndex)
            }
        }

        return update
    }

    /**
         Mengurutkan data siswa berdasarkan deskriptor pengurutan yang diberikan.

         Fungsi ini mengurutkan array `filteredSiswaData` berdasarkan kunci dan urutan yang ditentukan dalam `sortDescriptor`.
         Jika nilai untuk kunci pengurutan sama untuk dua siswa, fungsi ini akan membandingkan nama siswa untuk menentukan urutan.
         Untuk kunci tanggal (seperti "tahundaftar" dan "tanggalberhenti"), fungsi ini menggunakan `DateFormatter` untuk mengonversi string tanggal menjadi objek `Date` untuk perbandingan.

         - Parameter sortDescriptor: Objek `SortDescriptorWrapper` yang berisi kunci dan urutan pengurutan (menaik atau menurun).
         - Parameter isBerhenti: Boolean yang menunjukkan apakah siswa tersebut berhenti atau tidak. Parameter ini tidak digunakan dalam implementasi fungsi.

         - Catatan:
             Fungsi ini menggunakan metode bantu `compareStrings` dan `compareDates` untuk melakukan perbandingan string dan tanggal, masing-masing.
             Jika konversi tanggal gagal, fungsi ini akan mengembalikan `false`, yang dapat memengaruhi urutan pengurutan.
     */
    func sortSiswa(by sortDescriptor: NSSortDescriptor, isBerhenti _: Bool) {
        guard let comparator = ModelSiswa.comparator(from: sortDescriptor) else { return }
        filteredSiswaData.sort(by: comparator)
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
    func sortGroupSiswa(by sortDescriptor: NSSortDescriptor) {
        guard let comparator = ModelSiswa.comparator(from: sortDescriptor) else { return }
        let sortedGroupedSiswa = groupedSiswa.map { group in
            group.sorted(by: comparator)
        }

        // Perbarui grup yang ada dengan grup yang sudah diurutkan
        for (index, sortedGroup) in sortedGroupedSiswa.enumerated() {
            groupedSiswa[index] = sortedGroup
        }
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
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
            targetSelf.redoAction(originalModel: originalModel)
        })
        let id = originalModel.ID
        let columnIdentifier = originalModel.columnIdentifier
        let oldValue = originalModel.oldValue
        let newValue = originalModel.newValue
        if isGrouped == true {
            guard let siswa = findSiswaInGroups(id: originalModel.ID) else {
                updateDataAndRegisterUndo(id, column: columnIdentifier, newValue: oldValue, oldValue: newValue)
                UndoActionNotification.sendNotif(id, columnIdentifier: columnIdentifier)
                return
            }
            updateDataAndRegisterUndo(id, column: columnIdentifier, newValue: oldValue, oldValue: newValue, isGrouped: true, groupIndex: siswa.0, rowInSection: siswa.1)
        } else if !isGrouped {
            // Cari indeks di model berdasarkan ID
            guard let rowIndexToUpdate = filteredSiswaData.firstIndex(where: { $0.id == originalModel.ID }) else {
                updateDataAndRegisterUndo(id, column: columnIdentifier, newValue: oldValue, oldValue: newValue)
                UndoActionNotification.sendNotif(id, columnIdentifier: columnIdentifier)
                return
            }

            updateDataAndRegisterUndo(originalModel.ID, column: originalModel.columnIdentifier, rowIndex: rowIndexToUpdate, newValue: originalModel.oldValue, oldValue: originalModel.oldValue)
        }
    }

    private func updateDataAndRegisterUndo(_ id: Int64, column: SiswaColumn, rowIndex: Int? = nil, newValue: String, oldValue: String, isGrouped: Bool? = nil, groupIndex: Int? = nil, rowInSection: Int? = nil) {
        updateModelAndDatabase(id: id, columnIdentifier: column, rowIndex: rowIndex, newValue: newValue, oldValue: oldValue, isGrouped: isGrouped, groupIndex: groupIndex, rowInSection: rowInSection)
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
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
            targetSelf.undoAction(originalModel: originalModel)
        })
        let id = originalModel.ID
        let columnIdentifier = originalModel.columnIdentifier
        let oldValue = originalModel.oldValue
        let newValue = originalModel.newValue
        if isGrouped == true {
            guard let siswa = findSiswaInGroups(id: originalModel.ID) else {
                updateDataAndRegisterUndo(id, column: columnIdentifier, newValue: newValue, oldValue: oldValue)
                UndoActionNotification.sendNotif(id, columnIdentifier: columnIdentifier)
                return
            }
            updateDataAndRegisterUndo(id, column: columnIdentifier, newValue: newValue, oldValue: oldValue, isGrouped: true, groupIndex: siswa.0, rowInSection: siswa.1)
        } else if !isGrouped {
            // Cari indeks di model berdasarkan ID
            guard let rowIndexToUpdate = filteredSiswaData.firstIndex(where: { $0.id == originalModel.ID }) else {
                updateDataAndRegisterUndo(id, column: columnIdentifier, newValue: newValue, oldValue: oldValue)
                UndoActionNotification.sendNotif(id, columnIdentifier: columnIdentifier)
                return
            }
            updateDataAndRegisterUndo(id, column: columnIdentifier, rowIndex: rowIndexToUpdate, newValue: newValue, oldValue: oldValue)
        }
    }

    /**
     Membatalkan perubahan data siswa dan mendaftarkan operasi undo.

     Fungsi ini membatalkan perubahan yang dilakukan pada data siswa dan mengembalikan data ke keadaan sebelumnya.
     Operasi ini juga mendaftarkan tindakan undo dengan `UndoManager`, memungkinkan pengguna untuk membatalkan operasi ini.

     - Parameter data: Array `ModelSiswa` yang berisi data siswa yang akan dikembalikan ke keadaan sebelumnya.
     Data ini digunakan untuk mencari data siswa yang sesuai dan mengembalikannya ke nilai sebelumnya.
     - Parameter registerUndo: Opsional, untuk menonaktifkan registrasi undo dan hanya memperbarui data dan UI.

     - Note: Fungsi ini memposting notifikasi `updateEditSiswa` untuk memberitahu komponen lain tentang perubahan data.
     */
    func undoEditSiswa(_ data: [ModelSiswa], registerUndo: Bool = true) {
        var oldData = [ModelSiswa]()
        for snapshotSiswa in data {
            if UserDefaults.standard.bool(forKey: "sembunyikanSiswaBerhenti") {
                let databaseData = dbController.getSiswa(idValue: snapshotSiswa.id)
                oldData.append(databaseData)
                updateDataSiswa(snapshotSiswa.id, dataLama: databaseData, baru: snapshotSiswa)
                continue
            }
            if !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
                let databaseData = dbController.getSiswa(idValue: snapshotSiswa.id)
                oldData.append(databaseData)
                updateDataSiswa(snapshotSiswa.id, dataLama: databaseData, baru: snapshotSiswa)
                continue
            }
            if !isGrouped {
                if let matchedSiswaData = filteredSiswaData.first(where: { $0.id == snapshotSiswa.id }) {
                    oldData.append(matchedSiswaData)
                    updateDataSiswa(snapshotSiswa.id, dataLama: matchedSiswaData, baru: snapshotSiswa)
                }
            } else {
                for (_, group) in groupedSiswa.enumerated() {
                    // Cari matchedSiswaData dalam grup saat ini
                    if let matchedSiswaData = group.first(where: { $0.id == snapshotSiswa.id }) {
                        oldData.append(matchedSiswaData)
                        updateDataSiswa(snapshotSiswa.id, dataLama: matchedSiswaData, baru: snapshotSiswa)
                    }
                }
            }
        }
        NotificationCenter.default.post(name: .updateEditSiswa, object: nil, userInfo: ["data": data])
        guard registerUndo else { return }
        // Daftarkan undo dengan metode redoEditSiswa
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            guard let self else { return }
            undoEditSiswa(oldData)
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
        NSSortDescriptor(key: key, ascending: ascending)
    }

    static func from(_ descriptor: NSSortDescriptor) -> SortDescriptorWrapper {
        SortDescriptorWrapper(key: descriptor.key ?? "", ascending: descriptor.ascending)
    }
}
