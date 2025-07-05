//
//  Kelasswift
//  Data SDI
//
//  Created by Bismillah on 22/09/24.
//

import Cocoa
import SQLite

/// ViewModel untuk mengelola data kelas pada aplikasi Data SDI.
/// ViewModel ini bertanggung jawab untuk memuat, mengurutkan, dan memperbarui data kelas dari database.
/// Juga menyediakan fungsi untuk mengelola data siswa dalam kelas tertentu.
/// Menggunakan `DatabaseController` untuk berinteraksi dengan database SQLite.
class KelasViewModel {
    /// Membuat singleton
    static let shared = KelasViewModel()
    /// Semua data per kelas yang ter-fetch
    private(set) lazy var kelasData: [TableType: [KelasModels]] = [:]

    /// Properti untuk menyimpan data model kelas yang dicari.
    lazy var searchData: [KelasModels] = []
    
    /// Data per siswa (key: siswaID). Digunakan di ``DetailSiswaController``.
    private(set) lazy var siswaKelasData: [Int64: [TableType: [KelasModels]]] = [:]

    /// Properti untuk mengakses ``DatabaseController`` singleton.
    let dbController = DatabaseController.shared
    
    /// Properti untuk menyimpan ketika ``kelasData`` untuk kelas tertentu telah dimuat.
    private(set) var isDataLoaded: [TableType: Bool] = [:]
    
    /// Properti untuk menyimpan ketika ``siswaKelasData`` untuk kelas tertentu telah dimuat.
    private(set) var isSiswaDataLoaded: [Int64: [TableType: Bool]] = [:]

    /// Dijadikan private untuk singleton.
    private init() {}

    /// Fungsi untuk memuat data kelas berdasarkan tipe tabel yang diberikan.
    /// - Parameter tableType: Tipe tabel yang menentukan kelas mana yang akan dimuat.
    func loadKelasData(forTableType tableType: TableType) async {
        guard !(isDataLoaded[tableType] ?? false) else { return }
        var sortDescriptor: NSSortDescriptor!
        sortDescriptor = getSortDescriptor(forTableIdentifier: "table\(tableType.rawValue + 1)")
        kelasData[tableType] = await dbController.getAllKelas(ofType: tableType)
        sort(tableType: tableType, sortDescriptor: sortDescriptor)
        isDataLoaded[tableType] = true
    }
    
    func loadAllKelasData() async {
        await withTaskGroup(of: Void.self) { [weak self] group in
            guard let self else { return }
            for kelas in TableType.allCases {
                guard !(self.isDataLoaded[kelas] ?? false) else { continue }
                group.addTask {
                    await self.loadKelasData(forTableType: kelas)
                }
            }
        }
    }

    /// Fungsi untuk mendapatkan deskriptor pengurutan berdasarkan identifier tabel.
    /// - Parameter identifier: Identifier tabel yang digunakan untuk menyimpan deskriptor pengurutan.
    /// - Returns: Deskriptor pengurutan yang sesuai, atau deskriptor default jika tidak ditemukan.
    func getSortDescriptor(forTableIdentifier identifier: String) -> NSSortDescriptor? {
        if let sortDescriptorData = UserDefaults.standard.data(forKey: "SortDescriptor_\(identifier)"),
           let sortDescriptor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSSortDescriptor.self, from: sortDescriptorData)
        {
            sortDescriptor
        } else {
            NSSortDescriptor(key: "namasiswa", ascending: true)
        }
    }

    /// Fungsi untuk mendapatkan deskriptor pengurutan detail berdasarkan identifier tabel.
    /// - Parameter identifier: Identifier tabel yang digunakan untuk menyimpan deskriptor pengurutan detail.
    /// - Returns: Deskriptor pengurutan detail yang sesuai, atau deskriptor default jika tidak ditemukan.
    func getSortDescriptorDetil(forTableIdentifier identifier: String) -> NSSortDescriptor? {
        if let sortDescriptorData = UserDefaults.standard.data(forKey: "SortDescriptorSiswa_\(identifier)"),
           let sortDescriptor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSSortDescriptor.self, from: sortDescriptorData)
        {
            sortDescriptor
        } else {
            NSSortDescriptor(key: "mapel", ascending: true)
        }
    }

    /// Fungsi untuk memuat data siswa berdasarkan ID siswa.
    /// - Parameter siswaID: ID siswa yang digunakan untuk memuat data kelas.
    func loadSiswaData(siswaID: Int64) async {
        await withTaskGroup(of: Void.self) { [weak self] group in
            guard let self else { return }
            for kelas in TableType.allCases {
                guard !(self.isSiswaDataLoaded[siswaID]?[kelas] ?? false) else { continue }
                group.addTask {
                    await self.loadSiswaData(forTableType: kelas, siswaID: siswaID)
                }
            }
        }
    }

    /// Fungsi untuk memuat data siswa berdasarkan tipe tabel dan ID siswa.
    /// - Parameters:
    /// - tableType: Tipe tabel yang menentukan kelas mana yang akan dimuat.
    /// - siswaID: ID siswa yang digunakan untuk memuat data kelas.
    /// - Note: Fungsi ini akan memuat data kelas sesuai dengan tipe tabel yang diberikan dan ID siswa yang diberikan.
    func loadSiswaData(forTableType tableType: TableType, siswaID: Int64) async {
        guard !(isSiswaDataLoaded[siswaID]?[tableType] ?? false) else {return}
        var sortDescriptor: NSSortDescriptor!
        sortDescriptor = getSortDescriptorDetil(forTableIdentifier: "table\(tableType.rawValue + 1)")
        siswaKelasData[siswaID] = await dbController.getAllKelas(for: siswaID)
        siswaKelasData[siswaID]?[tableType] = sortModel(siswaKelasData[siswaID]?[tableType] ?? [], by: sortDescriptor)
        isSiswaDataLoaded[siswaID, default: [:]][tableType] = true
    }

    /// Fungsi untuk mendapatkan jumlah baris untuk tipe tabel tertentu.
    /// - Parameter tableType: Tipe tabel yang digunakan untuk menentukan jumlah baris.
    /// - Parameter siswaID: ID unik siswa untuk menentukan data. Opsional, penting untuk menentukan model yang sesuai
    ///  siswa tertentu di ``siswaKelasData`` dan selalu diisi saat menampilkan data kelas untuk siswa tertentu di ``DetailSiswaController``.
    /// - Returns: Jumlah baris untuk tipe tabel yang diberikan.
    func numberOfRows(forTableType tableType: TableType, siswaID: Int64? = nil) -> Int {
        kelasModelForTable(tableType, siswaID: siswaID).count
    }

    /// Fungsi untuk mendapatkan model kelas berdasarkan tipe tabel.
    /// - Parameter tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    /// - Parameter siswaID: ID unik siswa untuk menentukan data. Opsional, penting untuk menentukan model yang sesuai
    ///  siswa tertentu di ``siswaKelasData`` dan selalu diisi saat menampilkan data kelas untuk siswa tertentu di ``DetailSiswaController``.
    /// - Returns: Array dari model kelas yang sesuai dengan tipe tabel yang diberikan.
    func kelasModelForTable(_ tableType: TableType, siswaID: Int64? = nil) -> [KelasModels] {
        if let siswaID {
            siswaKelasData[siswaID]?[tableType] ?? []
        } else {
            kelasData[tableType] ?? []
        }
    }

    /// Fungsi untuk mendapatkan model kelas untuk baris tertentu dan tipe tabel tertentu.
    /// - Parameters:
    ///   - row: Indeks baris yang digunakan untuk menentukan model kelas.
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    ///   - siswaID: ID unik siswa untuk menentukan data. Opsional, penting untuk menentukan model yang sesuai
    ///  siswa tertentu di ``siswaKelasData`` dan selalu diisi saat menampilkan data kelas untuk siswa tertentu di ``DetailSiswaController``.
    /// - Returns: Model kelas yang sesuai dengan indeks baris dan tipe tabel yang diberikan, atau `nil` jika tidak ditemukan.
    func modelForRow(at row: Int, tableType: TableType, siswaID: Int64? = nil) -> KelasModels? {
        if let siswaID {
            guard row < siswaKelasData[siswaID]?[tableType]?.count ?? 0 else { return nil }
            return siswaKelasData[siswaID]?[tableType]?[row]
        } else {
            guard row < kelasData[tableType]?.count ?? 0 else { return nil }
            return kelasData[tableType]?[row]
        }
    }

    /// Fungsi untuk memperbarui model kelas berdasarkan tipe tabel dan data yang dihapus.
    /// - Parameters:
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    ///   - deletedData: Data yang dihapus yang akan digunakan untuk memperbarui model kelas.
    ///   - sortDescriptor: Deskriptor pengurutan yang digunakan untuk mengurutkan model kelas setelah pembaruan.
    ///   - siswaID: ID unik siswa untuk menentukan data. Opsional, penting untuk menentukan model yang sesuai
    ///  siswa tertentu di ``siswaKelasData`` dan selalu diisi saat menampilkan data kelas untuk siswa tertentu di ``DetailSiswaController``.
    func updateModel(for tableType: TableType, deletedData: KelasModels, sortDescriptor: NSSortDescriptor, siswaID: Int64? = nil) {
        let data = kelasModelForTable(tableType, siswaID: siswaID)
        if let index = data.firstIndex(where: { $0.kelasID == deletedData.kelasID }) {
            data[index].namasiswa = StringInterner.shared.intern(deletedData.namasiswa)
        }
    }

    /// Fungsi untuk menemukan semua indeks yang cocok dengan ID siswa tertentu dan memperbarui nama siswa.
    /// - Parameters:
    ///  - tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    ///  - id: ID siswa di kelas yang digunakan untuk mencari indeks.
    ///  - namaBaru: Nama baru yang akan diperbarui untuk siswa yang cocok dengan ID.
    ///  - siswaID: ID unik siswa untuk menentukan data. Opsional, penting untuk menentukan model yang sesuai
    ///  siswa tertentu di ``siswaKelasData`` dan selalu diisi saat menampilkan data kelas untuk siswa tertentu di ``DetailSiswaController``.
    /// - Returns: Array dari indeks yang cocok dengan ID siswa tertentu.
    func findAllIndices(for tableType: TableType, matchingID id: Int64, namaBaru: String, siswaID: Int64? = nil) -> [Int] {
        let data = kelasModelForTable(tableType, siswaID: siswaID)
        let indices = data.enumerated().compactMap { index, element -> Int? in
            if element.siswaID == id {
                data[index].namasiswa = StringInterner.shared.intern(namaBaru)
                return index
            }
            print("return nil")
            return nil
        }
        return indices
    }

    /// Fungsi untuk memasukkan data baru ke dalam model kelas berdasarkan tipe tabel.
    /// - Parameters:
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    ///   - deletedData: Data yang akan dimasukkan ke dalam model kelas.
    ///   - sortDescriptor: Deskriptor pengurutan yang digunakan untuk menentukan posisi penyisipan.
    ///   - siswaID: ID unik siswa untuk menentukan data. Opsional, penting untuk menentukan model yang sesuai
    ///  siswa tertentu di ``siswaKelasData`` dan selalu diisi saat menampilkan data kelas untuk siswa tertentu di ``DetailSiswaController``.
    /// - Returns: Indeks tempat data baru disisipkan, atau `nil` jika data sudah ada.
    func insertData(for tableType: TableType, deletedData: KelasModels, sortDescriptor: NSSortDescriptor, siswaID: Int64? = nil) -> Int? {
        var dataArray = kelasModelForTable(tableType, siswaID: siswaID)

        let dataToInsert = createModel(for: tableType, from: deletedData)
        let insertionIndex = dataArray.insertionIndex(for: dataToInsert, using: sortDescriptor)
        if !dataArray.contains(where: { $0.kelasID == deletedData.kelasID }) {
            dataArray.insert(dataToInsert, at: insertionIndex)
        } else {
            // Jika data sudah ada, tidak perlu menyisipkan lagi
            return nil
        }

        // Memperbarui model kelas dengan data yang telah disisipkan
        setModel(dataArray, for: tableType, siswaID: siswaID)

        return insertionIndex
    }

    /// Fungsi untuk mendapatkan nama kelas berdasarkan tipe tabel.
    /// - Parameter tableType: Tipe tabel yang digunakan untuk menentukan nama kelas.
    /// - Returns: Nama kelas yang sesuai dengan tipe tabel yang diberikan.
    func getKelasName(for tableType: TableType) -> String {
        switch tableType {
        case .kelas1:
            "Kelas 1"
        case .kelas2:
            "Kelas 2"
        case .kelas3:
            "Kelas 3"
        case .kelas4:
            "Kelas 4"
        case .kelas5:
            "Kelas 5"
        case .kelas6:
            "Kelas 6"
        }
    }

    /// Fungsi untuk mengatur model kelas dengan data baru berdasarkan tipe tabel.
    /// - Parameters:
    ///   - newData: Data baru yang akan digunakan untuk mengatur model kelas.
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diatur.
    ///   - siswaID: ID unik siswa untuk menentukan data. Opsional, penting untuk menentukan model yang sesuai
    ///  siswa tertentu di ``siswaKelasData`` dan selalu diisi saat menampilkan data kelas untuk siswa tertentu di ``DetailSiswaController``.
    func setModel(_ newData: [KelasModels], for tableType: TableType, siswaID: Int64? = nil) {
        if let siswaID {
            siswaKelasData[siswaID, default: [:]][tableType] = newData
        } else {
            kelasData[tableType] = newData
        }
    }

    /// Fungsi untuk membuat model kelas berdasarkan tipe tabel dan data yang diberikan.
    /// - Parameters:
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan dibuat.
    ///   - data: Data yang akan digunakan untuk membuat model kelas.
    /// - Returns: Model kelas yang telah dibuat berdasarkan tipe tabel dan data yang diberikan.
    func createModel(for tableType: TableType, from data: KelasModels) -> KelasModels {
        KelasModels.create(from: data)
    }

    /// Fungsi untuk menghapus semua data dari model kelas.
    /// - Note: Fungsi ini akan menghapus semua data dari model kelas 1 hingga kelas 6.
    func removeAllData() {
        kelasData.removeAll()
    }
    
    /// Fungsi ini dijalankan ketika ``DetailSiswaController`` di-deinit (ditutup)
    /// untuk membersihkan data.
    /// - Parameter siswaID: ID unik pada data ``siswaKelasData`` yang dihapus.
    func removeSiswaData(siswaID: Int64) {
        siswaKelasData[siswaID]?.removeAll()
        for kelas in TableType.allCases {
            isSiswaDataLoaded[siswaID]?[kelas] = false
        }
    }
    
    /// Fungsi untuk memuat ulang data kelas.
    /// - Parameter tableType: Data ``kelasData`` yang sesuai tableType yang akan dimuat ulang.
    func reloadKelasData(_ tableType: TableType) async {
        isDataLoaded[tableType] = false
        await loadKelasData(forTableType: tableType)
    }
    
    /// Fungsi untuk memuat ulang data untuk siswa tertentu pada kelas tertentu.
    /// - Parameters:
    ///   - tableType: Data kelas di ``siswaKelasData``  yang sesuai tableType yang akan dimuat ulang.
    ///   - siswaID: Data kelas untuk siswaID tertentu di ``siswaKelasData`` yang sesuai siswaID yang akan dimuat ulang.
    func reloadSiswaKelasData(_ tableType: TableType, siswaID: Int64) async {
        isSiswaDataLoaded[siswaID, default: [:]][tableType] = false
        await loadSiswaData(forTableType: tableType, siswaID: siswaID)
    }

    /// Fungsi untuk menghapus data berdasarkan ID kelas dari model kelas yang ditentukan.
    /// - Parameters:
    ///   - allIDs: Array dari ID kelas yang akan dihapus.
    ///   - targetModel: Model kelas yang akan diperiksa untuk penghapusan.
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diperiksa.
    ///   - siswaID: ID unik siswa untuk menentukan data. Opsional, penting untuk menentukan model yang sesuai
    /// siswa tertentu di ``siswaKelasData`` dan selalu diisi saat menampilkan data kelas untuk siswa tertentu di ``DetailSiswaController``.
    /// - Returns: Tuple yang berisi indeks yang dihapus, data yang dihapus, dan pasangan ID kelas dan siswa yang dihapus.
    func removeData(withIDs allIDs: [Int64], forTableType tableType: TableType, siswaID: Int64? = nil) -> ([Int], [KelasModels], [(kelasID: Int64, siswaID: Int64)])? {
        var targetModel = kelasModelForTable(tableType, siswaID: siswaID)
        
        var deletedKelasAndSiswaIDs: [(kelasID: Int64, siswaID: Int64)] = []
        var dataDihapus: [KelasModels] = []
        var indexesToRemove: [Int] = []

        // Memeriksa apakah ada data yang cocok dengan ID yang diberikan
        for (index, model) in targetModel.enumerated().reversed() {
            if allIDs.contains(model.kelasID) {
                let deletedData = model.copy()
                deletedKelasAndSiswaIDs.append((kelasID: model.kelasID, siswaID: model.siswaID))
                dataDihapus.append(deletedData as! KelasModels)
                indexesToRemove.append(index)
            }
        }
        
        for index in indexesToRemove {
            targetModel.remove(at: index)
        }
        
        setModel(targetModel, for: tableType, siswaID: siswaID)
        
        return (indexesToRemove, dataDihapus, deletedKelasAndSiswaIDs)
    }

    /// Fungsi untuk menghapus data berdasarkan indeks dari model kelas yang ditentukan.
    /// - Parameters:
    ///   - index: Indeks data yang akan dihapus.
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diperiksa.
    ///   - siswaID: ID unik siswa untuk menentukan data. Opsional, penting untuk menentukan model yang sesuai
    /// siswa tertentu di ``siswaKelasData`` dan selalu diisi saat menampilkan data kelas untuk siswa tertentu di ``DetailSiswaController``.
    func removeData(index: Int, tableType: TableType, siswaID: Int64? = nil) {
        if let siswaID {
            siswaKelasData[siswaID]?[tableType]?.remove(at: index)
        } else {
            kelasData[tableType]?.remove(at: index)
        }
    }

    /// Fungsi untuk mengurutkan model kelas berdasarkan deskriptor pengurutan yang diberikan.
    /// - Parameters:
    ///    - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diurutkan.
    ///    - sortDescriptor: Deskriptor pengurutan yang digunakan untuk mengurutkan model kelas.
    func sort(tableType: TableType, sortDescriptor: NSSortDescriptor?) {
        guard let sortDescriptor, kelasData[tableType] != nil else { return }

        kelasData[tableType] = sortModel(kelasData[tableType]!, by: sortDescriptor)
    }

    /// Fungsi untuk mengurutkan model kelas berdasarkan deskriptor pengurutan yang diberikan.
    /// - Parameters:
    ///    - model: Array dari model kelas yang akan diurutkan.
    ///    - sortDescriptor: Deskriptor pengurutan yang digunakan untuk mengurutkan model kelas.
    /// - Returns: Array dari model kelas yang telah diurutkan.
    func sortModel(_ models: [KelasModels], by sortDescriptor: NSSortDescriptor) -> [KelasModels] {
        return models.sorted {
            $0.compare(to: $1, using: sortDescriptor) == .orderedAscending
        }
    }

    /// Fungsi untuk memperbarui model kelas berdasarkan kolom yang diedit.
    /// - Parameters:
    ///    - columnIdentifier: Identifier kolom yang diedit.
    ///    - rowIndex: Indeks baris yang diedit.
    ///    - newValue: Nilai baru yang dimasukkan ke dalam kolom.
    ///    - modelArray: Array dari model kelas yang akan diperbarui.
    ///    - tableView: Tabel yang digunakan untuk menampilkan data kelas.
    ///    - kelasId: ID kelas yang digunakan untuk memperbarui data di database.
    ///    - tableType: tableType yang digunakan untuk menentukan data yang sesuai kelas.
    ///    - siswaID: ID unik siswa untuk menentukan data. Opsional, penting untuk menentukan model yang sesuai
    /// siswa tertentu di ``siswaKelasData`` dan selalu diisi saat menampilkan data kelas untuk siswa tertentu di ``DetailSiswaController``.
    /// - Note: Fungsi ini akan memperbarui model kelas sesuai dengan kolom yang diedit dan mengirimkan notifikasi untuk memperbarui tampilan tabel.
    func updateKelasModel(tableType: TableType, columnIdentifier: KelasColumn, rowIndex: Int, newValue: String, kelasId: Int64, siswaID: Int64? = nil) {
        let modelArray = kelasModelForTable(tableType, siswaID: siswaID)
        let nilaiBaru = newValue.capitalizedAndTrimmed()
        switch columnIdentifier {
        case .mapel:
            if rowIndex < modelArray.count {
                modelArray[rowIndex].mapel = StringInterner.shared.intern(nilaiBaru)
            }
        case .nilai:
            // Handle editing for "nilai" columns
            if rowIndex < modelArray.count {
                if let newValueAsInt64 = Int64(newValue), !newValue.isEmpty {
                    var updatedNilaiValue = modelArray[rowIndex].nilai
                    updatedNilaiValue = newValueAsInt64
                    modelArray[rowIndex].nilai = updatedNilaiValue
                } else {
                    modelArray[rowIndex].nilai = 0
                }
            }
        case .semester:
            if rowIndex < modelArray.count {
                modelArray[rowIndex].semester = StringInterner.shared.intern(nilaiBaru)
            }
        case .guru:
            if rowIndex < modelArray.count {
                modelArray[rowIndex].namaguru = StringInterner.shared.intern(nilaiBaru)
            }
        default:
            break
        }
        setModel(modelArray, for: tableType, siswaID: siswaID)
    }

    /// Fungsi untuk memperbarui model kelas dan database berdasarkan kolom yang diedit.
    /// - Parameters:
    ///    - columnIdentifier: Identifier kolom yang diedit.
    ///    - rowIndex: Indeks baris yang diedit.
    ///    - newValue: Nilai baru yang dimasukkan ke dalam kolom.
    ///    - oldValue: Nilai lama sebelum diedit, digunakan untuk membuat undo.
    ///    - modelArray: Array dari model kelas yang akan diperbarui.
    ///    - table: Tabel yang digunakan untuk menyimpan data kelas di database.
    ///    - tableView: Tabel yang digunakan untuk menampilkan data kelas.
    ///    - kelasId: ID kelas yang digunakan untuk memperbarui data di database.
    ///    - undo: Boolean untuk menentukan apakah ini adalah operasi undo (default adalah false).
    ///    - updateNamaGuru: Boolean untuk menentukan untuk memperbarui nama-nama guru yang sama
    /// di mata pelajaran yang sama.
    func updateModelAndDatabase(columnIdentifier: KelasColumn, rowIndex: Int, newValue: String, oldValue: String, modelArray: [KelasModels], table: Table, tableView: String, kelasId: Int64, undo: Bool = false, updateNamaGuru: Bool = true) {
        let nilaiBaru = newValue.capitalizedAndTrimmed()
        switch columnIdentifier {
        case .mapel:
            if rowIndex < modelArray.count {
                modelArray[rowIndex].mapel = StringInterner.shared.intern(nilaiBaru)
                dbController.updateDataInKelas(kelasID: modelArray[rowIndex].kelasID, mapelValue: nilaiBaru, nilaiValue: modelArray[rowIndex].nilai, namaguruValue: modelArray[rowIndex].namaguru, semesterValue: modelArray[rowIndex].semester, table: table)
            }
        case .nilai:
            // Handle editing for "nilai" columns
            if rowIndex < modelArray.count {
                if let newValueAsInt64 = Int64(newValue), !newValue.isEmpty {
                    var updatedNilaiValue = modelArray[rowIndex].nilai
                    updatedNilaiValue = newValueAsInt64
                    modelArray[rowIndex].nilai = updatedNilaiValue
                    dbController.updateDataInKelas(kelasID: modelArray[rowIndex].kelasID, mapelValue: modelArray[rowIndex].mapel, nilaiValue: updatedNilaiValue, namaguruValue: modelArray[rowIndex].namaguru, semesterValue: modelArray[rowIndex].semester, table: table)
                } else {
                    dbController.deleteNilaiFromKelas(table: table, kelasID: modelArray[rowIndex].kelasID)
                    modelArray[rowIndex].nilai = 0
                }
            }
        case .semester:
            if rowIndex < modelArray.count {
                modelArray[rowIndex].semester = StringInterner.shared.intern(nilaiBaru)
                dbController.updateDataInKelas(kelasID: modelArray[rowIndex].kelasID, mapelValue: modelArray[rowIndex].mapel, nilaiValue: modelArray[rowIndex].nilai, namaguruValue: modelArray[rowIndex].namaguru, semesterValue: nilaiBaru, table: table)
            }
        case .guru:
            if rowIndex < modelArray.count {
                modelArray[rowIndex].namaguru = StringInterner.shared.intern(nilaiBaru)
                dbController.updateDataInKelas(kelasID: modelArray[rowIndex].kelasID, mapelValue: modelArray[rowIndex].mapel, nilaiValue: modelArray[rowIndex].nilai, namaguruValue: nilaiBaru, semesterValue: modelArray[rowIndex].semester, table: table)

                if !undo {
                    if UserDefaults.standard.bool(forKey: "tambahkanDaftarGuruBaru") == true {
                        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.2) {
                            self.dbController.addGuruMapel(namaGuruValue: newValue)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                NotificationCenter.default.post(name: DatabaseController.namaGuruUpdate, object: nil)
                            }
                        }
                    }
                }
            }
        default:
            break
        }
        NotificationCenter.default.post(name: .editDataSiswaKelas, object: nil, userInfo: ["columnIdentifier": columnIdentifier, "tableView": tableView, "newValue": newValue, "kelasId": kelasId])

        if columnIdentifier == .guru, updateNamaGuru {
            let userInfo: [String: Any] = [
                "columnIdentifier": columnIdentifier,
                "tableView": tableView,
                "newValue": newValue,
                "guruLama": modelArray[rowIndex].namaguru,
                "mapel": modelArray[rowIndex].mapel,
                "kelasId": modelArray[rowIndex].kelasID,
                "siswaid": modelArray[rowIndex].siswaID
            ]
            NotificationCenter.default.post(name: .editNamaGuruKelas, object: nil, userInfo: userInfo)
        }
    }

    /// Fungsi untuk mendapatkan nilai lama dari kolom yang diedit.
    /// - Parameters:
    ///    - tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    ///    - rowIndex: Indeks baris yang diedit.
    ///    - columnIdentifier: Identifier kolom yang diedit.
    ///    - modelArray: Array dari model kelas yang akan diperiksa.
    ///    - table: Tabel yang digunakan untuk menyimpan data kelas di database.
    /// - Returns: Nilai lama dari kolom yang diedit, atau string kosong jika tidak ditemukan.
    /// - Note: Fungsi ini digunakan untuk mendapatkan nilai lama sebelum diedit, yang dapat digunakan untuk operasi undo.
    func getOldValueForColumn(tableType: TableType, rowIndex: Int, columnIdentifier: KelasColumn, modelArray: [KelasModels], table: Table) -> String {
        switch columnIdentifier {
        case .mapel:
            modelArray[rowIndex].mapel
        case .nilai:
            String(modelArray[rowIndex].nilai)
        case .semester:
            modelArray[rowIndex].semester
        case .guru:
            modelArray[rowIndex].namaguru
        default:
            ""
        }
    }

    /// Fungsi untuk memeriksa apakah teks pencarian adalah nama bulan.
    /// - Parameter searchText: Teks yang akan diperiksa.
    /// - Returns: `true` jika teks adalah nama bulan, `false` jika tidak.
    /// - Note: Fungsi ini digunakan untuk memeriksa apakah teks pencarian adalah nama bulan dalam bahasa Indonesia.
    /// Contoh nama bulan yang valid: "januari", "februari", "maret", dll.
    /// - Note: Fungsi ini akan mengembalikan `true` jika teks pencarian adalah nama bulan, dan `false` jika tidak.
    func isMonth(_ searchText: String) -> Bool {
        let months = ["januari", "februari", "maret", "april", "mei", "juni", "juli", "agustus", "september", "oktober", "november", "desember"]
        return months.contains(searchText.lowercased())
    }

    /// Fungsi untuk mencari data berdasarkan bulan dalam model kelas.
    /// - Parameters:
    ///    - searchText: Teks yang akan digunakan untuk mencari bulan.
    ///    - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diperiksa.
    /// - Note: Fungsi ini akan mencari data berdasarkan bulan yang diberikan dalam teks pencarian, dan memperbarui model kelas yang sesuai dengan hasil pencarian.
    func cariBulan(_ searchText: String, tableType: TableType) async {
        var sortDescriptor: NSSortDescriptor!
        searchData = await dbController.getAllKelas(ofType: tableType)
        searchData = kelasData[tableType]?.filter {
            // Format tanggal sesuai dengan format "dd MMMM yyyy"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd MMMM yyyy"
            if let date = dateFormatter.date(from: $0.tanggal) {
                let formattedDate = dateFormatter.string(from: date)
                return formattedDate.lowercased().contains(searchText.lowercased())
            }
            return false
        } ?? []
        sortDescriptor = getSortDescriptor(forTableIdentifier: "table1")
        // Update model kelas yang sesuai dengan hasil pencarian
        kelasData[tableType] = searchData.map { $0 }.compactMap { $0 }

        sort(tableType: tableType, sortDescriptor: sortDescriptor)
    }

    /// Fungsi untuk mencari data berdasarkan teks pencarian dan tipe tabel.
    /// - Parameters:
    ///   - searchText: Teks yang akan digunakan untuk mencari data.
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diperiksa.
    func search(_ searchText: String, tableType: TableType) async {
        var effectiveSortDescriptor: NSSortDescriptor? // Use optional for clarity

        if isMonth(searchText) {
            await cariBulan(searchText, tableType: tableType)
            // Consider if sortDescriptor should be set here or if `sort` handles nil
        } else {
            let tableIdentifierStr: String

            switch tableType {
            case .kelas1:
                tableIdentifierStr = "table1"
            case .kelas2:
                tableIdentifierStr = "table2"
            case .kelas3:
                tableIdentifierStr = "table3"
            case .kelas4:
                tableIdentifierStr = "table4"
            case .kelas5:
                tableIdentifierStr = "table5"
            case .kelas6:
                tableIdentifierStr = "table6"
            }

            kelasData[tableType] = await dbController.searchGenericModels(
                query: searchText,
                table: tableType.table
            )

            effectiveSortDescriptor = getSortDescriptor(forTableIdentifier: tableIdentifierStr)
        }

        sort(tableType: tableType, sortDescriptor: effectiveSortDescriptor)
    }

    /// Fungsi untuk mendapatkan deskriptor pengurutan berdasarkan identifier tabel.
    /// - Parameters:
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan deskriptor pengurutan.
    ///   - dataToInsert: Data yang akan dimasukkan ke dalam model kelas.
    func updateDataArray(_ tableType: TableType, dataToInsert: KelasModels) {
        switch tableType {
        case .kelas1: SingletonData.dataArray.append((index: 0, data: dataToInsert))
        case .kelas2: SingletonData.dataArray.append((index: 1, data: dataToInsert))
        case .kelas3: SingletonData.dataArray.append((index: 2, data: dataToInsert))
        case .kelas4: SingletonData.dataArray.append((index: 3, data: dataToInsert))
        case .kelas5: SingletonData.dataArray.append((index: 4, data: dataToInsert))
        case .kelas6: SingletonData.dataArray.append((index: 5, data: dataToInsert))
        }
    }

    /// Fungsi untuk menghapus notifikasi berdasarkan indeks dan ID kelas.
    /// - Parameters:
    ///    - index: Indeks model kelas yang akan dihapus.
    ///    - id: ID kelas yang akan dihapus.
    /// - Returns: Indeks yang dihapus jika berhasil, atau `nil` jika tidak ditemukan.
    /// - Note: Fungsi ini akan menghapus model kelas berdasarkan indeks dan ID kelas yang diberikan, dan mengembalikan indeks yang dihapus jika berhasil.
    /// Jika tidak ditemukan, akan mengembalikan `nil`.
    func deleteNotif(_ index: Int, id: Int64) -> Int? {
        // Pastikan indeks berada dalam rentang yang valid
        guard let tableType = TableType(rawValue: index) else { return nil }
        guard let kelasIDIndex = kelasData[tableType]?.firstIndex(where: { $0.kelasID == id }) else { return nil }
        kelasData[tableType]?.remove(at: kelasIDIndex)
        return kelasIDIndex
    }

    /// Fungsi untuk membuka jendela progres dengan total item yang akan diperbarui.
    /// - Parameters:
    ///   - totalItems: Total item yang akan diperbarui.
    ///   - controller: Nama controller yang akan digunakan untuk memperbarui data.
    ///   - window: Jendela yang akan digunakan untuk menampilkan jendela progres.
    /// - Returns: Tuple yang berisi `NSWindowController` dan `ProgressBarVC` jika berhasil, atau `nil` jika gagal.
    /// - Note: Fungsi ini akan membuka jendela progres dengan total item yang akan diperbarui, dan mengembalikan controller dan view controller yang digunakan untuk menampilkan progres.
    func openProgressWindow(totalItems: Int, controller: String, window: NSWindow) -> (NSWindowController, ProgressBarVC)? {
        let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil)
        guard let progressWindowController = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController,
              let progressViewController = progressWindowController.contentViewController as? ProgressBarVC,
              let window = progressWindowController.window
        else {
            return nil
        }

        progressViewController.totalStudentsToUpdate = totalItems
        progressViewController.controller = controller
        window.beginSheet(window)

        return (progressWindowController, progressViewController)
    }

    deinit {
        #if DEBUG
            print("deinit kelasViewModel")
        #endif
        removeAllData()
    }
}

// MARK: - FUNC UNTUK KALKULASI NILAI
extension KelasViewModel {
    /// Menulis nilai dari setiap siswa ke NSTextView (resultTextView)
    /// - Parameter index: Tentukan kelas sesuai index: Kelas 1 (0) - Kelas 6 (5)
    func updateTextViewWithCalculations(for tableType: TableType, in textView: NSTextView, label: String? = nil) {
        guard let kelasModel = kelasData[tableType] else { return }

        let uniqueSemesters = Set(kelasModel.map(\.semester)).sorted {
            ReusableFunc.semesterOrder($0, $1)
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 2

        let normalFont = NSFont.systemFont(ofSize: 12)
        let boldFont = NSFont.boldSystemFont(ofSize: 12)
        let largeBlackFont = NSFont.systemFont(ofSize: 16, weight: .black)

        let result = NSMutableAttributedString()

        // Header untuk label/title
        if let label {
            result.append(NSAttributedString(
                string: "\(label)\n",
                attributes: [
                    .font: largeBlackFont,
                    .paragraphStyle: paragraphStyle
                ]
            ))
        }
        
        // Bagian header total semua semester
        let totalNilaiSemua = calculateTotalNilai(forKelas: kelasModel)
        let totalHeader = NSAttributedString(
            string: "Jumlah Nilai Semua Semester: \(totalNilaiSemua)\n\n",
            attributes: [
                .font: boldFont,
                .paragraphStyle: paragraphStyle
            ]
        )
        result.append(totalHeader)
        
        for semester in uniqueSemesters {
            let formattedSemester = ReusableFunc.formatSemesterName(semester)
            let (totalNilai, topSiswa) = calculateTotalAndTopSiswa(forKelas: kelasModel, semester: semester)
            if let rataRataNilaiUmum = calculateRataRataNilaiUmumKelas(forKelas: kelasModel, semester: semester) {

                // 🔥 Judul bold
                let header: String = "Jumlah Nilai \(formattedSemester): \(totalNilai)\n"
                let nilaiUmum = "Rata-rata Nilai Umum \(formattedSemester): \(rataRataNilaiUmum).\n"
                let nilaiMapel = "Rata-rata Nilai Per Mapel \(formattedSemester):\n"
                
                result.append(NSAttributedString(
                    string: header,
                    attributes: [
                        .font: boldFont,
                        .paragraphStyle: paragraphStyle
                    ]
                ))

                // Nilai Umum Header
                result.append(NSAttributedString(
                    string: nilaiUmum,
                    attributes: [
                        .font: boldFont,
                        .paragraphStyle: paragraphStyle
                    ]
                ))
                // 🔥 Top siswa join (normal)
                let topSiswaText = topSiswa.joined(separator: "\n") + "\n"
                
                result.append(NSAttributedString(
                    string: topSiswaText,
                    attributes: [
                        .font: normalFont,
                        .paragraphStyle: paragraphStyle
                    ]
                ))
                
                // Nilai Mapel Header
                result.append(NSAttributedString(
                    string: nilaiMapel,
                    attributes: [
                        .font: boldFont,
                        .paragraphStyle: paragraphStyle
                    ]
                ))

                // 🔥 Rata-rata per mapel (normal)
                let rataMapelText = (calculateRataRataNilaiPerMapel(forKelas: kelasModel, semester: semester) ?? "") + "\n\n"
                result.append(NSAttributedString(
                    string: rataMapelText,
                    attributes: [
                        .font: normalFont,
                        .paragraphStyle: paragraphStyle
                    ]
                ))
            }
        }

        // Tampilkan di text view
        textView.textStorage?.setAttributedString(result)
    }

    /// Jumlah Nilai keseluruhan kelas di semua semester
    /// - Parameter kelas: data kelas yang akan dikalkulasi berupa model data KelasModels
    /// - Returns: Mengembalikan nilai dalam format nilai Int
    func calculateTotalNilai(forKelas kelas: [KelasModels]) -> Int {
        var total = 0
        for siswa in kelas {
            total += Int(siswa.nilai)
        }
        return total
    }

    /// Jumlah nilai siswa di kelas tertentu untuk semester tertentu
    /// - Parameters:
    ///   - kelas: data kelas yang akan dikalkulasi berupa model data KelasModels
    ///   - semester: pilihan semester yang akan dikalkulasi
    /// - Returns: Nilai yang dikalkukasi dalam format Array [Int64, [String]]
    func calculateTotalAndTopSiswa(forKelas kelas: [KelasModels], semester: String) -> (totalNilai: Int64, topSiswa: [String]) {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }

        // Calculate total nilai for the selected semester
        let totalNilai = siswaSemester.reduce(0) { $0 + $1.nilai }

        // Calculate top siswa for the selected semester
        let topSiswa = calculateTopSiswa(forKelas: siswaSemester, semester: semester)

        return (totalNilai, topSiswa)
    }

    /// Mengkalkulasi nilai semester tertentu setiap siswa di data kelas tertentu
    /// - Parameters:
    ///   - kelas: data kelas yang akan dikalkulasi berupa model data KelasModels
    ///   - semester: pilihan semester yang akan dikalkulasi
    /// - Returns: Nilai yang dikalkulasi dalam format Array String (namaSiswa, jumlahNilai, Rata-rata)
    func calculateTopSiswa(forKelas kelas: [KelasModels], semester: String) -> [String] {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }

        // Hitung jumlah nilai dan rata-rata untuk setiap siswa.
        var nilaiSiswaDictionary: [String: (totalNilai: Int64, jumlahSiswa: Int64)] = [:]
        for siswa in siswaSemester {
            if var siswaData = nilaiSiswaDictionary[siswa.namasiswa] {
                siswaData.totalNilai += siswa.nilai
                siswaData.jumlahSiswa += 1
                nilaiSiswaDictionary[siswa.namasiswa] = siswaData
            } else {
                nilaiSiswaDictionary[siswa.namasiswa] = (totalNilai: siswa.nilai, jumlahSiswa: 1)
            }
        }
        // Urutkan siswa berdasarkan total nilai dari yang tertinggi ke terendah.
        let sortedSiswa = nilaiSiswaDictionary.sorted { $0.value.totalNilai > $1.value.totalNilai }

        // Kembalikan hasil dalam format yang sesuai.
        var result: [String] = []
        for (namaSiswa, dataSiswa) in sortedSiswa {
            let totalNilai = dataSiswa.totalNilai
            let jumlahSiswa = dataSiswa.jumlahSiswa
            let rataRataNilai = Double(totalNilai) / Double(jumlahSiswa)
            let formattedRataRataNilai = String(format: "%.2f", rataRataNilai)
            result.append("・ \(namaSiswa) (Jumlah Nilai: \(totalNilai), Rata-rata Nilai: \(formattedRataRataNilai))")
        }
        return result
    }

    /// Rata-rata nilai umum untuk kelas dan semester tertentu
    /// - Parameters:
    ///   - kelas: data kelas yang akan dikalkulasi berupa model data KelasModels
    ///   - semester: pilihan semester yang akan dikalkulasi
    /// - Returns: Nilai rata-rata yang telah dikalkulasi dalam format string. nilai ini opsional dan bisa mengembalikan nil.
    func calculateRataRataNilaiUmumKelas(forKelas kelas: [KelasModels], semester: String) -> String? {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }

        // Jumlah total nilai untuk semua siswa pada semester tersebut.
        let totalNilai = siswaSemester.reduce(0) { $0 + $1.nilai }

        // Jumlah siswa pada semester tersebut.
        let jumlahSiswa = siswaSemester.count

        // Hitung rata-rata nilai umum kelas untuk semester tersebut.
        guard jumlahSiswa > 0 else {
            return nil // Menghindari pembagian oleh nol.
        }

        let rataRataNilai = Double(totalNilai) / Double(jumlahSiswa)

        // Mengubah nilai rata-rata menjadi format dua desimal
        let formattedRataRataNilai = String(format: "%.2f", rataRataNilai)

        return formattedRataRataNilai
    }

    /// Kalkulasi nilai rata-rata mata pelajaran untuk kelas dengan model data yang dikirim
    /// - Parameters:
    ///   - kelas: Ini adalah model data KelasModels yang menampung semua data siswa. data ini digunakan untuk kalkulasi.
    ///   - semester: pilihan semester yang akan dikalkulasi
    /// - Returns: Nilai rata-rata mata pelajaran yang telah dikalkulasi dalam format string. nilai ini opsional dan bisa mengembalikan nil.
    func calculateRataRataNilaiPerMapel(forKelas kelas: [KelasModels], semester: String) -> String? {
        // Filter siswa berdasarkan semester yang diinginkan.
        let siswaSemester = kelas.filter { $0.semester == semester }

        // Membuat set unik dari semua mata pelajaran yang ada di semester tersebut.
        let uniqueMapels = Set(siswaSemester.map(\.mapel))

        // Dictionary untuk menyimpan hasil per-mapel.
        var totalNilaiPerMapel: [String: Int] = [:]
        var jumlahSiswaPerMapel: [String: Int] = [:]

        // Menghitung total nilai per-mapel dan jumlah siswa per-mapel.
        for mapel in uniqueMapels {
            // Filter siswa berdasarkan mata pelajaran.
            let siswaMapel = siswaSemester.filter { $0.mapel == mapel }

            // Jumlah total nilai untuk semua siswa pada mata pelajaran tersebut.
            let totalNilai = siswaMapel.reduce(0) { $0 + $1.nilai }

            // Jumlah siswa pada mata pelajaran tersebut.
            let jumlahSiswa = siswaMapel.count

            // Menyimpan hasil total nilai dan jumlah siswa per-mapel.
            totalNilaiPerMapel[mapel] = totalNilaiPerMapel[mapel, default: 0] + Int(totalNilai)
            jumlahSiswaPerMapel[mapel] = jumlahSiswaPerMapel[mapel, default: 0] + jumlahSiswa
        }

        // Menghitung rata-rata nilai per-mapel.
        var rataRataPerMapel: [String: String] = [:]
        for mapel in uniqueMapels {
            guard let totalNilai = totalNilaiPerMapel[mapel], let jumlahSiswa = jumlahSiswaPerMapel[mapel], jumlahSiswa > 0 else {
                rataRataPerMapel[mapel] = "Data tidak tersedia"
                continue
            }

            let rataRataNilai = Double(totalNilai) / Double(jumlahSiswa)

            // Mengubah nilai rata-rata menjadi format dua desimal.
            let formattedRataRataNilai = String(format: "%.2f", rataRataNilai)

            // Menyimpan hasil rata-rata per-mapel dengan paragraf baru.
            rataRataPerMapel[mapel] = formattedRataRataNilai
        }

        // Menggabungkan hasil rata-rata per-mapel dengan paragraf baru.
        let resultString = rataRataPerMapel.map { "・ \($0.key): \($0.value)" }.joined(separator: "\n")

        return resultString
    }
}

extension KelasViewModel {
    /// Fungsi ini akan mengembalikan data yang telah dihapus ke dalam tabel yang sesuai, dengan menampilkan progres selama proses pemulihan.
    /// Fungsi ini juga akan memperbarui tampilan tabel dan mengelola undo manager untuk memungkinkan pengguna membatalkan tindakan pemulihan jika diperlukan.
    /// - Parameters:
    ///   - deletedData: Tuple yang berisi tabel dan data yang telah dihapus.
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diperbarui.
    ///   - sortDescriptor: Deskriptor pengurutan yang digunakan untuk mengurutkan data yang akan dipulihkan.
    ///   - table: Tabel yang digunakan untuk menampilkan data kelas.
    ///   - viewController: NSViewController yang digunakan untuk mengelola tampilan dan interaksi pengguna.
    ///   - undoManager: UndoManager yang digunakan untuk mengelola tindakan undo dan redo.
    ///   - operationQueue: NSOperationQueue yang digunakan untuk menjalankan operasi pemulihan secara asinkron.
    ///   - window: NSWindow yang digunakan untuk menampilkan jendela progres.
    ///   - onlyDataKelasAktif: Boolean yang menentukan apakah hanya data kelas aktif yang akan dipulihkan.
    ///   - kelasID: Array yang digunakan untuk menyimpan ID kelas yang telah dipulihkan.
    func restoreDeletedDataWithProgress(
        deletedData: (table: Table, data: [KelasModels]),
        tableType: TableType,
        sortDescriptor: NSSortDescriptor,
        table: NSTableView,
        viewController: NSViewController,
        undoManager: UndoManager,
        operationQueue: OperationQueue,
        window: NSWindow,
        onlyDataKelasAktif: Bool,
        kelasID: inout [[Int64]]
    ) {
        // Pastikan bahwa deletedData.data tidak kosong
        guard !deletedData.data.isEmpty else {
            print("Tidak ada data yang dihapus untuk dipulihkan.")
            return
        }
        guard let (progressWindowController, progressViewController) = openProgressWindow(totalItems: deletedData.data.count, controller: "data kelas", window: window),
              let lastDeletedTable = SingletonData.dbTable(forTableType: tableType) else { return }

        let totalStudents = deletedData.data.count
        var processedStudentsCount = 0
        let batchSize = max(totalStudents / 20, 1)
        var allIDs: [Int64] = []
        var lastIndex: [Int] = []
        progressViewController.totalStudentsToUpdate = totalStudents
        progressViewController.controller = "Kelas Aktif"

        operationQueue.addOperation { [weak self, weak table] in
            guard let self, let table else { return }
            for (_, data) in deletedData.data.enumerated().reversed() {
                allIDs.append(data.kelasID)
                guard let insertionIndex = self.insertData(for: tableType, deletedData: data, sortDescriptor: sortDescriptor) else { return }
                OperationQueue.main.addOperation { [weak self] in
                    self?.updateDataArray(tableType, dataToInsert: data)
                    table.insertRows(at: IndexSet(integer: insertionIndex), withAnimation: [])
                    table.selectRowIndexes(IndexSet(integer: insertionIndex), byExtendingSelection: true)
                    lastIndex.append(insertionIndex)
                    processedStudentsCount += 1

                    if processedStudentsCount == totalStudents || processedStudentsCount % batchSize == 0 {
                        progressViewController.currentStudentIndex = processedStudentsCount
                    }
                }

                // Logika kompleks yang bisa diperbarui
                // jika namaguru diperbarui setelah dihapus dari kelasVC.
                if onlyDataKelasAktif {
                    operationQueue.addOperation { [weak self, weak table] in
                        guard let self, let table else { return }
                        guard let siswaData = self.dbController.getKelasData(for: tableType, kelasID: data.kelasID) else { return }
                        if siswaData.namaguru != data.namaguru {
                            self.updateKelasModel(tableType: tableType, columnIdentifier: .guru, rowIndex: insertionIndex, newValue: siswaData.namaguru, kelasId: siswaData.kelasID)
                            OperationQueue.main.addOperation { [weak table] in
                                guard let columnIndex = table?.tableColumns.firstIndex(where: { $0.identifier.rawValue == "namaguru" }) else { print("error columnindex"); return }
                                table?.reloadData(forRowIndexes: IndexSet(integer: insertionIndex), columnIndexes: IndexSet(integer: columnIndex))
                            }
                        }
                    }
                }
            }
        }

        kelasID.append(allIDs)
        operationQueue.addOperation {
            OperationQueue.main.addOperation {
                if let maxIndex = lastIndex.max() {
                    table.scrollRowToVisible(maxIndex)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    window.endSheet(progressWindowController.window!)
                }
            }
        }
        if !onlyDataKelasAktif {
            undoManager.registerUndo(withTarget: viewController) { [weak viewController] _ in
                (viewController as? KelasVC)?.redoHapus(table: table, tableType: tableType)
            }
            SingletonData.deletedKelasID.append((table: lastDeletedTable, kelasID: allIDs))
            NotificationCenter.default.post(name: .undoKelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedData": deletedData.data])
        } else {
            undoManager.registerUndo(withTarget: viewController) { [weak viewController] _ in
                (viewController as? KelasVC)?.redoHapusData(tableType: tableType, table: table)
            }
            NotificationCenter.default.post(name: .undoKelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedData": deletedData.data, "hapusData": true])
        }
    }

    /// Fungsi ini akan mengembalikan data yang telah dihapus ke dalam tabel yang sesuai.
    /// Fungsi ini juga akan memperbarui tampilan tabel dan mengelola undo manager untuk memungkinkan pengguna membatalkan tindakan pemulihan jika diperlukan.
    /// - Parameters:
    ///   - deletedData: Tuple yang berisi tabel dan data yang telah dihapus.
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diperbarui.
    ///   - sortDescriptor: Deskriptor pengurutan yang digunakan untuk mengurutkan data yang akan dipulihkan.
    ///   - table: Tabel yang digunakan untuk menampilkan data kelas.
    ///   - viewController: NSViewController yang digunakan untuk mengelola tampilan dan interaksi pengguna.
    ///   - undoManager: UndoManager yang digunakan untuk mengelola tindakan undo dan redo.
    ///   - window: NSWindow yang digunakan untuk menampilkan jendela progres.
    ///   - onlyDataKelasAktif: Boolean yang menentukan apakah hanya data kelas aktif yang akan dipulihkan.
    ///   - kelasID: Array yang digunakan untuk menyimpan ID kelas yang telah dipulihkan.
    func restoreDeletedDataDirectly(
        deletedData: (table: Table, data: [KelasModels]),
        tableType: TableType,
        sortDescriptor: NSSortDescriptor,
        table: NSTableView,
        viewController: NSViewController,
        undoManager: UndoManager,
        onlyDataKelasAktif: Bool,
        kelasID: inout [[Int64]]
    ) {
        // 1) Validasi cepat
        guard !deletedData.data.isEmpty,
              let lastDeletedTable = SingletonData.dbTable(forTableType: tableType)
        else {
            print("Tidak ada data yang dihapus untuk dipulihkan.")
            return
        }

        // 2) Nested helper: insert data & kumpulkan indeks/ID
        let restoreBatch: () -> (indices: [Int], ids: [Int64]) = { [weak self, weak table] in
            guard let self, let table else { return ([], []) }
            var rows: [Int] = []
            var ids: [Int64] = []
            for model in deletedData.data.reversed() {
                guard let idx = insertData(
                    for: tableType,
                    deletedData: model,
                    sortDescriptor: sortDescriptor
                ) else { continue }
                updateDataArray(tableType, dataToInsert: model)
                table.insertRows(at: IndexSet(integer: idx), withAnimation: .slideDown)
                rows.append(idx)
                ids.append(model.kelasID)
            }
            return (rows, ids)
        }

        // 3) Nested helper: cek & update nama guru di background
        let updateGuruIfNeeded: (_ model: KelasModels, _ row: Int) -> Void = { [weak self, weak table] model, row in
            DispatchQueue.global(qos: .background).async { [weak self, weak table, weak model] in
                guard let self, let table, let model,
                      let fresh = dbController.getKelasData(for: tableType, kelasID: model.kelasID),
                      fresh.namaguru != model.namaguru
                else { return }
                updateKelasModel(
                    tableType: tableType,
                    columnIdentifier: .guru,
                    rowIndex: row,
                    newValue: fresh.namaguru,
                    kelasId: fresh.kelasID
                )
                DispatchQueue.main.async { [weak table] in
                    guard let col = table?.tableColumns.firstIndex(
                        where: { $0.identifier.rawValue == "namaguru" })
                    else { return }
                    table?.reloadData(
                        forRowIndexes: IndexSet(integer: row),
                        columnIndexes: IndexSet(integer: col)
                    )
                }
            }
        }

        table.beginUpdates()
        let (restoredRows, restoredIDs) = restoreBatch()
        if onlyDataKelasAktif {
            for (offset, row) in restoredRows.enumerated() {
                let model = deletedData.data.reversed()[offset] // match urutan restoreBatch
                updateGuruIfNeeded(model, row)
            }
        }
        table.endUpdates()

        // 4) Scroll & select
        table.selectRowIndexes(IndexSet(restoredRows), byExtendingSelection: false)
        if let maxRow = restoredRows.max() {
            table.scrollRowToVisible(maxRow)
        }
        kelasID.append(restoredIDs)

        // 5) Undo & Notification
        if onlyDataKelasAktif {
            undoManager.registerUndo(withTarget: viewController) { [weak viewController] _ in
                (viewController as? KelasVC)?
                    .redoHapusData(tableType: tableType, table: table)
            }
            NotificationCenter.default.post(
                name: .undoKelasDihapus,
                object: self,
                userInfo: [
                    "tableType": tableType,
                    "deletedData": deletedData.data,
                    "hapusData": true
                ]
            )
        } else {
            undoManager.registerUndo(withTarget: viewController) { [weak viewController] _ in
                (viewController as? KelasVC)?
                    .redoHapus(table: table, tableType: tableType)
            }
            SingletonData.deletedKelasID.append((table: lastDeletedTable, kelasID: restoredIDs))
            SingletonData.deletedKelasAndSiswaIDs.removeAll { pairList in
                pairList.contains { restoredIDs.contains($0.kelasID) }
            }
            NotificationCenter.default.post(
                name: .undoKelasDihapus,
                object: self,
                userInfo: [
                    "tableType": tableType,
                    "deletedData": deletedData.data
                ]
            )
        }
    }
}

extension KelasViewModel {
    /// Menyaring data nilai berdasarkan tab yang dipilih, semester, dan status filter tertentu.
    ///
    /// Fungsi ini akan mengambil data nilai siswa berdasarkan beberapa parameter filter,
    /// seperti indeks tab, nama semester, status kelas aktif, semua nilai, nilai bukan kelas aktif,
    /// dan ID siswa yang ingin difilter. Fungsi ini mengembalikan data yang sudah difilter dalam bentuk tuple,
    /// yang berisi data tabel, total nilai, rata-rata nilai, dan indeks baris yang disembunyikan.
    ///
    /// - Parameters:
    ///   - tabIndex: Indeks tab yang sedang aktif dipilih pengguna.
    ///   - semesterName: Nama semester yang digunakan sebagai filter (misalnya: "Ganjil", "Genap").
    ///   - kelasAktifState: Status apakah hanya menampilkan nilai dari kelas yang aktif.
    ///   - semuaNilaiState: Status apakah menampilkan semua nilai tanpa filter.
    ///   - bukanKelasAktifState: Status apakah menampilkan nilai dari kelas selain kelas aktif.
    ///   - siswaID: ID siswa yang datanya ingin difilter.
    ///
    /// - Returns: Tuple yang berisi:
    ///   - `tableData`: Array dari `KelasModels` yang sudah difilter.
    ///   - `totalNilai`: Total nilai dari data yang ditampilkan.
    ///   - `averageNilai`: Nilai rata-rata dari data yang ditampilkan.
    ///   - `hiddenIndices`: Kumpulan indeks baris (`IndexSet`) yang disembunyikan berdasarkan filter.
    func filterNilai(
        tabIndex: Int,
        semesterName: String,
        kelasAktifState: Bool,
        semuaNilaiState: Bool,
        bukanKelasAktifState: Bool,
        siswaID: Int64
    ) -> (
        tableData: [KelasModels],
        totalNilai: Int,
        averageNilai: Double,
        hiddenIndices: IndexSet
    )? {
        let kelasData = kelasModelForTable(TableType(rawValue: tabIndex)!, siswaID: siswaID)

        let semesterValue = semesterName.replacingOccurrences(of: "Semester ", with: "")
        var filtered: [KelasModels] = []
        var table: [KelasModels] = []

        if kelasAktifState {
            filtered = kelasData.filter { $0.semester == semesterValue && $0.aktif }
            table = kelasData.filter { $0.aktif }
        } else if semuaNilaiState {
            filtered = kelasData.filter { $0.semester == semesterValue }
            table = kelasData
        } else if bukanKelasAktifState {
            filtered = kelasData.filter { $0.semester == semesterValue && !$0.aktif }
            table = kelasData.filter { !$0.aktif }
        }

        let total = filtered.map { Int($0.nilai) }.reduce(0, +)
        let avg = filtered.isEmpty ? 0 : Double(total) / Double(filtered.count)

        var hidden: IndexSet = []
        for (index, item) in kelasData.enumerated() {
            if !table.contains(where: { $0.kelasID == item.kelasID }) {
                hidden.insert(index)
            }
        }

        return (table, total, avg, hidden)
    }
}
