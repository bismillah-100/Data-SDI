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
    /// Properti untuk menyimpan data model kelas 1.
    private(set) var kelas1Model: [Kelas1Model] = []
    /// Properti untuk menyimpan data model kelas 2.
    private(set) var kelas2Model: [Kelas2Model] = []
    /// Properti untuk menyimpan data model kelas 3.
    private(set) var kelas3Model: [Kelas3Model] = []
    /// Properti untuk menyimpan data model kelas 4.
    private(set) var kelas4Model: [Kelas4Model] = []
    /// Properti untuk menyimpan data model kelas 5.
    private(set) var kelas5Model: [Kelas5Model] = []
    /// Properti untuk menyimpan data model kelas 6.
    private(set) var kelas6Model: [Kelas6Model] = []
    /// Properti untuk menyimpan data model kelas yang dicari.
    lazy var searchData: [KelasModels] = []
    /// Properti untuk menyimpan data model kelas 1 yang dicari dan telah difilter.
    lazy var searchKelas1: [Kelas1Model] = []
    /// Properti untuk menyimpan data model kelas 2 yang dicari dan telah difilter
    lazy var searchKelas2: [Kelas2Model] = []
    /// Properti untuk menyimpan data model kelas 3 yang dicari dan telah difilter
    lazy var searchKelas3: [Kelas3Model] = []
    /// Properti untuk menyimpan data model kelas 4 yang dicari dan telah difilter
    lazy var searchKelas4: [Kelas4Model] = []
    /// Properti untuk menyimpan data model kelas 5 yang dicari dan telah difilter
    lazy var searchKelas5: [Kelas5Model] = []
    /// Properti untuk menyimpan data model kelas 6 yang dicari dan telah difilter
    lazy var searchKelas6: [Kelas6Model] = []
    /// Properti untuk mengakses ``DatabaseController`` singleton.
    let dbController = DatabaseController.shared

    init() {}

    /// Fungsi untuk memuat data kelas berdasarkan tipe tabel yang diberikan.
    /// - Parameter tableType: Tipe tabel yang menentukan kelas mana yang akan dimuat.
    func loadKelasData(forTableType tableType: TableType) async {
        var sortDescriptor: NSSortDescriptor!
        switch tableType {
        case .kelas1:
            sortDescriptor = getSortDescriptor(forTableIdentifier: "table1")
            kelas1Model = await dbController.getallKelas1()
        case .kelas2:
            sortDescriptor = getSortDescriptor(forTableIdentifier: "table2")
            kelas2Model = await dbController.getallKelas2()
        case .kelas3:
            sortDescriptor = getSortDescriptor(forTableIdentifier: "table3")
            kelas3Model = await dbController.getallKelas3()
        case .kelas4:
            sortDescriptor = getSortDescriptor(forTableIdentifier: "table4")
            kelas4Model = await dbController.getallKelas4()
        case .kelas5:
            sortDescriptor = getSortDescriptor(forTableIdentifier: "table5")
            kelas5Model = await dbController.getallKelas5()
        case .kelas6:
            sortDescriptor = getSortDescriptor(forTableIdentifier: "table6")
            kelas6Model = await dbController.getallKelas6()
        }

        sort(tableType: tableType, sortDescriptor: sortDescriptor)
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
    func loadSiswaData(siswaID: Int64) {
        kelas1Model = dbController.getKelas1(siswaID: siswaID)
        kelas2Model = dbController.getKelas2(siswaID: siswaID)
        kelas3Model = dbController.getKelas3(siswaID: siswaID)
        kelas4Model = dbController.getKelas4(siswaID: siswaID)
        kelas5Model = dbController.getKelas5(siswaID: siswaID)
        kelas6Model = dbController.getKelas6(siswaID: siswaID)
    }

    /// Fungsi untuk memuat data siswa berdasarkan tipe tabel dan ID siswa.
    /// - Parameters:
    /// - tableType: Tipe tabel yang menentukan kelas mana yang akan dimuat.
    /// - siswaID: ID siswa yang digunakan untuk memuat data kelas.
    /// - Note: Fungsi ini akan memuat data kelas sesuai dengan tipe tabel yang diberikan dan ID siswa yang diberikan.
    func loadSiswaData(forTableType tableType: TableType, siswaID: Int64) {
        var sortDescriptor: NSSortDescriptor!
        switch tableType {
        case .kelas1:
            sortDescriptor = getSortDescriptorDetil(forTableIdentifier: "table1")
            kelas1Model = dbController.getKelas1(siswaID: siswaID)
        case .kelas2:
            sortDescriptor = getSortDescriptorDetil(forTableIdentifier: "table2")
            kelas2Model = dbController.getKelas2(siswaID: siswaID)
        case .kelas3:
            sortDescriptor = getSortDescriptorDetil(forTableIdentifier: "table3")
            kelas3Model = dbController.getKelas3(siswaID: siswaID)
        case .kelas4:
            sortDescriptor = getSortDescriptorDetil(forTableIdentifier: "table4")
            kelas4Model = dbController.getKelas4(siswaID: siswaID)
        case .kelas5:
            sortDescriptor = getSortDescriptorDetil(forTableIdentifier: "table5")
            kelas5Model = dbController.getKelas5(siswaID: siswaID)
        case .kelas6:
            sortDescriptor = getSortDescriptorDetil(forTableIdentifier: "table6")
            kelas6Model = dbController.getKelas6(siswaID: siswaID)
        }
        sort(tableType: tableType, sortDescriptor: sortDescriptor)
    }

    /// Fungsi untuk mendapatkan jumlah baris untuk tipe tabel tertentu.
    /// - Parameter tableType: Tipe tabel yang digunakan untuk menentukan jumlah baris.
    /// - Returns: Jumlah baris untuk tipe tabel yang diberikan.
    func numberOfRows(forTableType tableType: TableType) -> Int {
        switch tableType {
        case .kelas1:
            kelas1Model.count
        case .kelas2:
            kelas2Model.count
        case .kelas3:
            kelas3Model.count
        case .kelas4:
            kelas4Model.count
        case .kelas5:
            kelas5Model.count
        case .kelas6:
            kelas6Model.count
        }
    }

    /// Fungsi untuk mendapatkan model kelas berdasarkan tipe tabel.
    /// - Parameter tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    /// - Returns: Array dari model kelas yang sesuai dengan tipe tabel yang diberikan.
    func kelasModelForTable(_ tableType: TableType) -> [KelasModels] {
        switch tableType {
        case .kelas1:
            kelas1Model
        case .kelas2:
            kelas2Model
        case .kelas3:
            kelas3Model
        case .kelas4:
            kelas4Model
        case .kelas5:
            kelas5Model
        case .kelas6:
            kelas6Model
        }
    }

    /// Fungsi untuk mendapatkan model kelas untuk baris tertentu dan tipe tabel tertentu.
    /// - Parameters:
    ///   - row: Indeks baris yang digunakan untuk menentukan model kelas.
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    /// - Returns: Model kelas yang sesuai dengan indeks baris dan tipe tabel yang diberikan, atau `nil` jika tidak ditemukan.
    func modelForRow(at row: Int, tableType: TableType) -> KelasModels? {
        switch tableType {
        case .kelas1:
            kelas1Model[row]
        case .kelas2:
            kelas2Model[row]
        case .kelas3:
            kelas3Model[row]
        case .kelas4:
            kelas4Model[row]
        case .kelas5:
            kelas5Model[row]
        case .kelas6:
            kelas6Model[row]
        }
    }

    /// Fungsi untuk memperbarui model kelas berdasarkan tipe tabel dan data yang dihapus.
    /// - Parameters:
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    ///   - deletedData: Data yang dihapus yang akan digunakan untuk memperbarui model kelas.
    ///   - sortDescriptor: Deskriptor pengurutan yang digunakan untuk mengurutkan model kelas setelah pembaruan.
    func updateModel(for tableType: TableType, deletedData: KelasModels, sortDescriptor: NSSortDescriptor) {
        let data = getModel(for: tableType)
        if let index = data.firstIndex(where: { $0.kelasID == deletedData.kelasID }) {
            data[index].namasiswa = deletedData.namasiswa
        }
    }

    /// Fungsi untuk menemukan semua indeks yang cocok dengan ID siswa tertentu dan memperbarui nama siswa.
    /// - Parameters:
    ///  - tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    ///  - id: ID siswa yang digunakan untuk mencari indeks.
    ///  - namaBaru: Nama baru yang akan diperbarui untuk siswa yang cocok dengan ID.
    /// - Returns: Array dari indeks yang cocok dengan ID siswa tertentu.
    func findAllIndices(for tableType: TableType, matchingID id: Int64, namaBaru: String) -> [Int] {
        let data = getModel(for: tableType)
        let indices = data.enumerated().compactMap { index, element -> Int? in
            if element.siswaID == id {
                data[index].namasiswa = namaBaru

                return index
            }
            return nil
        }
        return indices
    }

    /// Fungsi untuk memasukkan data baru ke dalam model kelas berdasarkan tipe tabel.
    /// - Parameters:
    ///   - tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    ///   - deletedData: Data yang akan dimasukkan ke dalam model kelas.
    ///   - sortDescriptor: Deskriptor pengurutan yang digunakan untuk menentukan posisi penyisipan.
    /// - Returns: Indeks tempat data baru disisipkan, atau `nil` jika data sudah ada.
    func insertData(for tableType: TableType, deletedData: KelasModels, sortDescriptor: NSSortDescriptor) -> Int? {
        var dataArray = getModel(for: tableType)

        let dataToInsert = createModel(for: tableType, from: deletedData)
        let insertionIndex = dataArray.insertionIndex(for: dataToInsert, using: sortDescriptor)
        if dataArray.contains(where: { $0.kelasID == deletedData.kelasID }) {
            // Jika data sudah ada, tidak perlu menyisipkan lagi
            return nil
        }

        if !dataArray.contains(where: { $0.kelasID == deletedData.kelasID }) {
            dataArray.insert(dataToInsert, at: insertionIndex)
        } else {
            // Jika data sudah ada, tidak perlu menyisipkan lagi
            return nil
        }

        // Memperbarui model kelas dengan data yang telah disisipkan
        setModel(dataArray, for: tableType)

        return insertionIndex
    }

    /// Fungsi untuk mendapatkan model kelas berdasarkan tipe tabel.
    /// - Parameter tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    /// - Returns: Array dari model kelas yang sesuai dengan tipe tabel yang diberikan.
    func getModel(for tableType: TableType) -> [KelasModels] {
        switch tableType {
        case .kelas1:
            kelas1Model
        case .kelas2:
            kelas2Model
        case .kelas3:
            kelas3Model
        case .kelas4:
            kelas4Model
        case .kelas5:
            kelas5Model
        case .kelas6:
            kelas6Model
        }
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
    /// - newData: Data baru yang akan digunakan untuk mengatur model kelas.
    /// - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diatur.
    func setModel(_ newData: [KelasModels], for tableType: TableType) {
        switch tableType {
        case .kelas1:
            kelas1Model = newData as! [Kelas1Model]
        case .kelas2:
            kelas2Model = newData as! [Kelas2Model]
        case .kelas3:
            kelas3Model = newData as! [Kelas3Model]
        case .kelas4:
            kelas4Model = newData as! [Kelas4Model]
        case .kelas5:
            kelas5Model = newData as! [Kelas5Model]
        case .kelas6:
            kelas6Model = newData as! [Kelas6Model]
        }
    }

    /// Fungsi untuk mengatur model kelas dengan data baru berdasarkan tipe tabel.
    /// - Parameters:
    /// - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diatur.
    /// - model: Data model kelas yang akan digunakan untuk mengatur model kelas.
    /// - Returns: Array dari model kelas yang telah diatur.
    func setModel(_ tableType: TableType, model: [KelasModels]) -> [KelasModels] {
        let modifiableModel: [KelasModels] = model
        switch tableType {
        case .kelas1:
            kelas1Model = modifiableModel as! [Kelas1Model]
        case .kelas2:
            kelas2Model = modifiableModel as! [Kelas2Model]
        case .kelas3:
            kelas3Model = modifiableModel as! [Kelas3Model]
        case .kelas4:
            kelas4Model = modifiableModel as! [Kelas4Model]
        case .kelas5:
            kelas5Model = modifiableModel as! [Kelas5Model]
        case .kelas6:
            kelas6Model = modifiableModel as! [Kelas6Model]
        }
        return modifiableModel
    }

    /// Fungsi untuk membuat model kelas berdasarkan tipe tabel dan data yang diberikan.
    /// - Parameters:
    ///  - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan dibuat.
    ///  - data: Data yang akan digunakan untuk membuat model kelas.
    /// - Returns: Model kelas yang telah dibuat berdasarkan tipe tabel dan data yang diberikan.
    func createModel(for tableType: TableType, from data: KelasModels) -> KelasModels {
        switch tableType {
        case .kelas1: Kelas1Model.create(from: data)
        case .kelas2: Kelas2Model.create(from: data)
        case .kelas3: Kelas3Model.create(from: data)
        case .kelas4: Kelas4Model.create(from: data)
        case .kelas5: Kelas5Model.create(from: data)
        case .kelas6: Kelas6Model.create(from: data)
        }
    }

    /// Fungsi untuk menghapus semua data dari model kelas.
    /// - Note: Fungsi ini akan menghapus semua data dari model kelas 1 hingga kelas 6.
    func removeAllData() {
        kelas1Model.removeAll()
        kelas2Model.removeAll()
        kelas3Model.removeAll()
        kelas4Model.removeAll()
        kelas5Model.removeAll()
        kelas6Model.removeAll()
    }

    /// Fungsi untuk menghapus data berdasarkan ID kelas dari model kelas yang ditentukan.
    /// - Parameters:
    /// - allIDs: Array dari ID kelas yang akan dihapus.
    /// - targetModel: Model kelas yang akan diperiksa untuk penghapusan.
    /// - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diperiksa.
    /// - Returns: Tuple yang berisi indeks yang dihapus, data yang dihapus, dan pasangan ID kelas dan siswa yang dihapus.
    func removeData(withIDs allIDs: [Int64], fromModel targetModel: inout [KelasModels], forTableType tableType: TableType) -> ([Int], [KelasModels], [(kelasID: Int64, siswaID: Int64)])? {
        var deletedKelasAndSiswaIDs: [(kelasID: Int64, siswaID: Int64)] = []
        var dataDihapus: [KelasModels] = []
        var indexesToRemove: [Int] = []

        // Memeriksa apakah ada data yang cocok dengan ID yang diberikan
        for (index, model) in targetModel.enumerated().reversed() {
            if allIDs.contains(model.kelasID) {
                let deletedData = KelasModels(
                    kelasID: model.kelasID,
                    siswaID: model.siswaID,
                    namasiswa: model.namasiswa,
                    mapel: model.mapel,
                    nilai: model.nilai,
                    namaguru: model.namaguru,
                    semester: model.semester,
                    tanggal: model.tanggal
                )
                deletedKelasAndSiswaIDs.append((kelasID: model.kelasID, siswaID: model.siswaID))
                dataDihapus.append(deletedData)
                indexesToRemove.append(index)

                removeData(index: index, tableType: tableType)
            }
        }
        return (indexesToRemove, dataDihapus, deletedKelasAndSiswaIDs)
    }

    /// Fungsi untuk menghapus data berdasarkan indeks dari model kelas yang ditentukan.
    /// - Parameters:
    /// - index: Indeks data yang akan dihapus.
    /// - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diperiksa.
    func removeData(index: Int, tableType: TableType) {
        switch tableType {
        case .kelas1: kelas1Model.remove(at: index)
        case .kelas2: kelas2Model.remove(at: index)
        case .kelas3: kelas3Model.remove(at: index)
        case .kelas4: kelas4Model.remove(at: index)
        case .kelas5: kelas5Model.remove(at: index)
        case .kelas6: kelas6Model.remove(at: index)
        }
    }

    /// Fungsi untuk mengurutkan model kelas berdasarkan deskriptor pengurutan yang diberikan.
    /// - Parameters:
    /// - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diurutkan.
    /// - sortDescriptor: Deskriptor pengurutan yang digunakan untuk mengurutkan model kelas.
    func sort(tableType: TableType, sortDescriptor: NSSortDescriptor?) {
        guard let sortDescriptor else { return }

        let modelToSort: [KelasModels] = switch tableType {
        case .kelas1: kelas1Model
        case .kelas2: kelas2Model
        case .kelas3: kelas3Model
        case .kelas4: kelas4Model
        case .kelas5: kelas5Model
        case .kelas6: kelas6Model
        }

        let sortedModel = sortModel(modelToSort, by: sortDescriptor)

        switch tableType {
        case .kelas1: kelas1Model = sortedModel as! [Kelas1Model]
        case .kelas2: kelas2Model = sortedModel as! [Kelas2Model]
        case .kelas3: kelas3Model = sortedModel as! [Kelas3Model]
        case .kelas4: kelas4Model = sortedModel as! [Kelas4Model]
        case .kelas5: kelas5Model = sortedModel as! [Kelas5Model]
        case .kelas6: kelas6Model = sortedModel as! [Kelas6Model]
        }
    }

    /// Fungsi untuk mengurutkan model kelas berdasarkan deskriptor pengurutan yang diberikan.
    /// - Parameters:
    /// - model: Array dari model kelas yang akan diurutkan.
    /// - sortDescriptor: Deskriptor pengurutan yang digunakan untuk mengurutkan model kelas.
    /// - Returns: Array dari model kelas yang telah diurutkan.
    func sortModel(_ model: [KelasModels], by sortDescriptor: NSSortDescriptor) -> [KelasModels] {
        model.sorted { item1, item2 -> Bool in
            switch sortDescriptor.key {
            case "namasiswa":
                if item1.namasiswa == item2.namasiswa {
                    // Jika namasiswa sama, urutkan juga berdasarkan mapel
                    return sortDescriptor.ascending ? (item1.mapel < item2.mapel || (item1.mapel == item2.mapel && item1.semester < item2.semester)) : (item1.mapel > item2.mapel || (item1.mapel == item2.mapel && item1.semester > item2.semester))
                } else {
                    // Jika namasiswa berbeda, urutkan berdasarkan namasiswa
                    return sortDescriptor.ascending ? item1.namasiswa < item2.namasiswa : item1.namasiswa > item2.namasiswa
                }
            case "mapel":
                if item1.mapel == item2.mapel {
                    return sortDescriptor.ascending ? (item1.namasiswa < item2.namasiswa || (item1.namasiswa == item2.namasiswa && item1.semester < item2.semester)) : (item1.namasiswa > item2.namasiswa || (item1.namasiswa == item2.namasiswa && item1.semester > item2.semester))
                } else {
                    return sortDescriptor.ascending ? item1.mapel < item2.mapel : item1.mapel > item2.mapel
                }
            case "nilai":
                if item1.nilai == item2.nilai {
                    return sortDescriptor.ascending ? (item1.namasiswa < item2.namasiswa || (item1.namasiswa == item2.namasiswa && item1.mapel < item2.mapel)) : (item1.namasiswa > item2.namasiswa || (item1.namasiswa == item2.namasiswa && item1.mapel > item2.mapel))
                } else {
                    return sortDescriptor.ascending ? item1.nilai < item2.nilai : item1.nilai > item2.nilai
                }
            case "semester":
                if item1.semester == item2.semester {
                    return sortDescriptor.ascending ? (item1.namasiswa < item2.namasiswa || (item1.namasiswa == item2.namasiswa && item1.mapel < item2.mapel)) : (item1.namasiswa > item2.namasiswa || (item1.namasiswa == item2.namasiswa && item1.mapel > item2.mapel))
                } else {
                    return sortDescriptor.ascending ? item1.semester < item2.semester : item1.semester > item2.semester
                }
            case "namaguru":
                if item1.namaguru == item2.namaguru {
                    return sortDescriptor.ascending ? (item1.namasiswa < item2.namasiswa || (item1.namasiswa == item2.namasiswa && item1.mapel < item2.mapel)) : (item1.namasiswa > item2.namasiswa || (item1.namasiswa == item2.namasiswa && item1.mapel > item2.mapel))
                } else {
                    return sortDescriptor.ascending ? item1.namaguru < item2.namaguru : item1.namaguru > item2.namaguru
                }
            case "tgl":
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMMM yyyy"
                guard let date1 = dateFormatter.date(from: item1.tanggal),
                      let date2 = dateFormatter.date(from: item2.tanggal)
                else {
                    return false
                }
                if date1 == date2 {
                    return sortDescriptor.ascending ? (item1.namasiswa < item2.namasiswa || (item1.namasiswa == item2.namasiswa && item1.mapel < item2.mapel)) : (item1.namasiswa > item2.namasiswa || (item1.namasiswa == item2.namasiswa && item1.mapel > item2.mapel))
                } else {
                    return sortDescriptor.ascending ? date1 < date2 : date1 > date2
                }
            default:
                return false
            }
        }
    }

    /// Fungsi untuk memperbarui model kelas berdasarkan kolom yang diedit.
    /// - Parameters:
    /// - columnIdentifier: Identifier kolom yang diedit.
    /// - rowIndex: Indeks baris yang diedit.
    /// - newValue: Nilai baru yang dimasukkan ke dalam kolom.
    /// - modelArray: Array dari model kelas yang akan diperbarui.
    /// - tableView: Tabel yang digunakan untuk menampilkan data kelas.
    /// - kelasId: ID kelas yang digunakan untuk memperbarui data di database.
    /// - Note: Fungsi ini akan memperbarui model kelas sesuai dengan kolom yang diedit dan mengirimkan notifikasi untuk memperbarui tampilan tabel.
    func updateKelasModel(columnIdentifier: String, rowIndex: Int, newValue: String, modelArray: [KelasModels], tableView: NSTableView, kelasId: Int64) {
        let nilaiBaru = newValue.capitalizedAndTrimmed()
        switch columnIdentifier {
        case "mapel":
            if rowIndex < modelArray.count {
                modelArray[rowIndex].mapel = nilaiBaru
            }
        case "nilai":
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
        case "semester":
            if rowIndex < modelArray.count {
                modelArray[rowIndex].semester = nilaiBaru
            }
        case "namaguru":
            if rowIndex < modelArray.count {
                modelArray[rowIndex].namaguru = nilaiBaru
            }
        default:
            break
        }
    }

    /// Fungsi untuk memperbarui model kelas dan database berdasarkan kolom yang diedit.
    /// - Parameters:
    /// - columnIdentifier: Identifier kolom yang diedit.
    /// - rowIndex: Indeks baris yang diedit.
    /// - newValue: Nilai baru yang dimasukkan ke dalam kolom.
    /// - oldValue: Nilai lama sebelum diedit, digunakan untuk membuat undo.
    /// - modelArray: Array dari model kelas yang akan diperbarui.
    /// - table: Tabel yang digunakan untuk menyimpan data kelas di database.
    /// - tableView: Tabel yang digunakan untuk menampilkan data kelas.
    /// - kelasId: ID kelas yang digunakan untuk memperbarui data di database.
    /// - undo: Boolean untuk menentukan apakah ini adalah operasi undo (default adalah false).
    func updateModelAndDatabase(columnIdentifier: String, rowIndex: Int, newValue: String, oldValue: String, modelArray: [KelasModels], table: Table, tableView: String, kelasId: Int64, undo: Bool = false) {
        let nilaiBaru = newValue.capitalizedAndTrimmed()
        switch columnIdentifier {
        case "mapel":
            if rowIndex < modelArray.count {
                modelArray[rowIndex].mapel = nilaiBaru
                dbController.updateDataInKelas(kelasID: modelArray[rowIndex].kelasID, mapelValue: nilaiBaru, nilaiValue: modelArray[rowIndex].nilai, namaguruValue: modelArray[rowIndex].namaguru, semesterValue: modelArray[rowIndex].semester, table: table)
            }
        case "nilai":
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
        case "semester":
            if rowIndex < modelArray.count {
                modelArray[rowIndex].semester = nilaiBaru
                dbController.updateDataInKelas(kelasID: modelArray[rowIndex].kelasID, mapelValue: modelArray[rowIndex].mapel, nilaiValue: modelArray[rowIndex].nilai, namaguruValue: modelArray[rowIndex].namaguru, semesterValue: nilaiBaru, table: table)
            }
        case "namaguru":
            if rowIndex < modelArray.count {
                modelArray[rowIndex].namaguru = nilaiBaru
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

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "EditDataSiswaKelas"), object: nil, userInfo: ["columnIdentifier": columnIdentifier, "tableView": tableView, "newValue": newValue, "kelasId": kelasId])

        if columnIdentifier == "namaguru" {
            let userInfo: [String: Any] = [
                "columnIdentifier": columnIdentifier,
                "tableView": tableView,
                "newValue": newValue,
                "guruLama": modelArray[rowIndex].namaguru,
                "mapel": modelArray[rowIndex].mapel,
                "kelasId": modelArray[rowIndex].kelasID,
            ]
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "EditNamaGuruKelas"), object: nil, userInfo: userInfo)
        }
    }

    /// Fungsi untuk mendapatkan nilai lama dari kolom yang diedit.
    /// - Parameters:
    /// - tableType: Tipe tabel yang digunakan untuk menentukan model kelas.
    /// - rowIndex: Indeks baris yang diedit.
    /// - columnIdentifier: Identifier kolom yang diedit.
    /// - modelArray: Array dari model kelas yang akan diperiksa.
    /// - table: Tabel yang digunakan untuk menyimpan data kelas di database.
    /// - Returns: Nilai lama dari kolom yang diedit, atau string kosong jika tidak ditemukan.
    /// - Note: Fungsi ini digunakan untuk mendapatkan nilai lama sebelum diedit, yang dapat digunakan untuk operasi undo.
    func getOldValueForColumn(tableType: TableType, rowIndex: Int, columnIdentifier: String, modelArray: [KelasModels], table: Table) -> String {
        switch columnIdentifier {
        case "mapel":
            modelArray[rowIndex].mapel
        case "nilai":
            String(modelArray[rowIndex].nilai)
        case "semester":
            modelArray[rowIndex].semester
        case "namaguru":
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
    /// - searchText: Teks yang akan digunakan untuk mencari bulan.
    /// - tableType: Tipe tabel yang digunakan untuk menentukan model kelas yang akan diperiksa.
    /// - Note: Fungsi ini akan mencari data berdasarkan bulan yang diberikan dalam teks pencarian, dan memperbarui model kelas yang sesuai dengan hasil pencarian.
    func cariBulan(_ searchText: String, tableType: TableType) async {
        var sortDescriptor: NSSortDescriptor!
        switch tableType {
        case .kelas1:
            searchKelas1 = await dbController.getallKelas1()
            searchData.append(contentsOf: searchKelas1)
            searchData = searchKelas1.filter {
                // Format tanggal sesuai dengan format "dd MMMM yyyy"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMMM yyyy"
                if let date = dateFormatter.date(from: $0.tanggal) {
                    let formattedDate = dateFormatter.string(from: date)
                    return formattedDate.lowercased().contains(searchText.lowercased())
                }
                return false
            }
            sortDescriptor = getSortDescriptor(forTableIdentifier: "table1")
            // Update model kelas yang sesuai dengan hasil pencarian
            kelas1Model = searchData.map { $0 as? Kelas1Model }.compactMap { $0 }
            searchKelas1.removeAll()
            searchKelas1 = await dbController.getallKelas1()
            searchData.append(contentsOf: searchKelas1)
        case .kelas2:
            searchKelas2 = await dbController.getallKelas2()
            searchData.append(contentsOf: searchKelas2)
            searchData = searchKelas2.filter {
                // Format tanggal sesuai dengan format "dd MMMM yyyy"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMMM yyyy"
                if let date = dateFormatter.date(from: $0.tanggal) {
                    let formattedDate = dateFormatter.string(from: date)
                    return formattedDate.lowercased().contains(searchText.lowercased())
                }
                return false
            }
            sortDescriptor = getSortDescriptor(forTableIdentifier: "table2")
            // Update model kelas yang sesuai dengan hasil pencarian
            kelas2Model = searchData.map { $0 as? Kelas2Model }.compactMap { $0 }
            searchKelas2.removeAll()
            searchKelas2 = await dbController.getallKelas2()
            searchData.append(contentsOf: searchKelas2)
        case .kelas3:
            searchKelas3 = await dbController.getallKelas3()
            searchData.append(contentsOf: searchKelas3)
            searchData = searchKelas3.filter {
                // Format tanggal sesuai dengan format "dd MMMM yyyy"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMMM yyyy"
                if let date = dateFormatter.date(from: $0.tanggal) {
                    let formattedDate = dateFormatter.string(from: date)
                    return formattedDate.lowercased().contains(searchText.lowercased())
                }
                return false
            }
            sortDescriptor = getSortDescriptor(forTableIdentifier: "table3")
            // Update model kelas yang sesuai dengan hasil pencarian
            kelas3Model = searchData.map { $0 as? Kelas3Model }.compactMap { $0 }
            searchKelas3.removeAll()
            searchKelas3 = await dbController.getallKelas3()
            searchData.append(contentsOf: searchKelas3)
        case .kelas4:
            searchKelas4 = await dbController.getallKelas4()
            searchData.append(contentsOf: searchKelas4)
            searchData = searchKelas4.filter {
                // Format tanggal sesuai dengan format "dd MMMM yyyy"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMMM yyyy"
                if let date = dateFormatter.date(from: $0.tanggal) {
                    let formattedDate = dateFormatter.string(from: date)
                    return formattedDate.lowercased().contains(searchText.lowercased())
                }
                return false
            }
            sortDescriptor = getSortDescriptor(forTableIdentifier: "table4")
            // Update model kelas yang sesuai dengan hasil pencarian
            kelas4Model = searchData.map { $0 as? Kelas4Model }.compactMap { $0 }
            searchKelas4.removeAll()
            searchKelas4 = await dbController.getallKelas4()
            searchData.append(contentsOf: searchKelas4)
        case .kelas5:
            searchKelas5 = await dbController.getallKelas5()
            searchData.append(contentsOf: searchKelas5)
            searchData = searchKelas5.filter {
                // Format tanggal sesuai dengan format "dd MMMM yyyy"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMMM yyyy"
                if let date = dateFormatter.date(from: $0.tanggal) {
                    let formattedDate = dateFormatter.string(from: date)
                    return formattedDate.lowercased().contains(searchText.lowercased())
                }
                return false
            }
            sortDescriptor = getSortDescriptor(forTableIdentifier: "table5")
            // Update model kelas yang sesuai dengan hasil pencarian
            kelas5Model = searchData.map { $0 as? Kelas5Model }.compactMap { $0 }
            searchKelas5.removeAll()
            searchKelas5 = await dbController.getallKelas5()
            searchData.append(contentsOf: searchKelas5)
        case .kelas6:
            searchKelas6 = await dbController.getallKelas6()
            searchData.append(contentsOf: searchKelas6)
            searchData = searchKelas6.filter {
                // Format tanggal sesuai dengan format "dd MMMM yyyy"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMMM yyyy"
                if let date = dateFormatter.date(from: $0.tanggal) {
                    let formattedDate = dateFormatter.string(from: date)
                    return formattedDate.lowercased().contains(searchText.lowercased())
                }
                return false
            }
            sortDescriptor = getSortDescriptor(forTableIdentifier: "table6")
            // Update model kelas yang sesuai dengan hasil pencarian
            kelas6Model = searchData.map { $0 as? Kelas6Model }.compactMap { $0 }
            searchKelas6.removeAll()
            searchKelas6 = await dbController.getallKelas6()
            searchData.append(contentsOf: searchKelas6)
        }
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
                kelas1Model = await dbController.searchGenericModels(
                    query: searchText,
                    table: dbController.kelas1, // Pass the Table object
                    modelType: Kelas1Model.self // Pass the Model type
                )
            case .kelas2:
                tableIdentifierStr = "table2"
                kelas2Model = await dbController.searchGenericModels(
                    query: searchText,
                    table: dbController.kelas2,
                    modelType: Kelas2Model.self
                )
            case .kelas3:
                tableIdentifierStr = "table3"
                kelas3Model = await dbController.searchGenericModels(
                    query: searchText,
                    table: dbController.kelas3, // Ensure dbController.kelas3, etc., are defined
                    modelType: Kelas3Model.self
                )
            case .kelas4:
                tableIdentifierStr = "table4"
                kelas4Model = await dbController.searchGenericModels(
                    query: searchText,
                    table: dbController.kelas4,
                    modelType: Kelas4Model.self
                )
            case .kelas5:
                tableIdentifierStr = "table5"
                kelas5Model = await dbController.searchGenericModels(
                    query: searchText,
                    table: dbController.kelas5,
                    modelType: Kelas5Model.self
                )
            case .kelas6:
                tableIdentifierStr = "table6"
                kelas6Model = await dbController.searchGenericModels(
                    query: searchText,
                    table: dbController.kelas6,
                    modelType: Kelas6Model.self
                )
            }
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
    /// - index: Indeks model kelas yang akan dihapus.
    /// - id: ID kelas yang akan dihapus.
    /// - Returns: Indeks yang dihapus jika berhasil, atau `nil` jika tidak ditemukan.
    /// - Note: Fungsi ini akan menghapus model kelas berdasarkan indeks dan ID kelas yang diberikan, dan mengembalikan indeks yang dihapus jika berhasil.
    /// Jika tidak ditemukan, akan mengembalikan `nil`.
    func deleteNotif(_ index: Int, id: Int64) -> Int? {
        // Pastikan indeks berada dalam rentang yang valid
        guard index >= 0, index < 6 else { return nil }
        switch index {
        case 0:
            guard let kelasIDIndex = kelas1Model.firstIndex(where: { $0.kelasID == id }) else { return nil }
            kelas1Model.remove(at: kelasIDIndex)
            return kelasIDIndex
        case 1:
            guard let kelasIDIndex = kelas2Model.firstIndex(where: { $0.kelasID == id }) else { return nil }
            kelas2Model.remove(at: kelasIDIndex)
            return kelasIDIndex
        case 2:
            guard let kelasIDIndex = kelas3Model.firstIndex(where: { $0.kelasID == id }) else { return nil }
            kelas3Model.remove(at: kelasIDIndex)
            return kelasIDIndex
        case 3:
            guard let kelasIDIndex = kelas4Model.firstIndex(where: { $0.kelasID == id }) else { return nil }
            kelas4Model.remove(at: kelasIDIndex)
            return kelasIDIndex
        case 4:
            guard let kelasIDIndex = kelas5Model.firstIndex(where: { $0.kelasID == id }) else { return nil }
            kelas5Model.remove(at: kelasIDIndex)
            return kelasIDIndex
        case 5:
            guard let kelasIDIndex = kelas6Model.firstIndex(where: { $0.kelasID == id }) else { return nil }
            kelas6Model.remove(at: kelasIDIndex)
            return kelasIDIndex
        default:
            return nil
        }
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

        operationQueue.addOperation { [weak self] in
            guard let self else { return }
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
            NotificationCenter.default.post(name: .undoKelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": allIDs])
        } else {
            undoManager.registerUndo(withTarget: viewController) { [weak viewController] _ in
                (viewController as? KelasVC)?.redoHapusData(tableType: tableType, table: table)
            }
            NotificationCenter.default.post(name: .undoKelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": allIDs, "hapusData": true])
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
        // Pastikan bahwa deletedData.data tidak kosong
        guard !deletedData.data.isEmpty else {
            print("Tidak ada data yang dihapus untuk dipulihkan.")
            return
        }
        // Pastikan bahwa kita memiliki tabel yang sesuai untuk tipe tabel yang diberikan
        guard let lastDeletedTable = SingletonData.dbTable(forTableType: tableType) else { return }
        table.beginUpdates()
        var lastIndex: [Int] = []
        var allIDs: [Int64] = []

        // Iterasi melalui data yang dihapus dan masukkan kembali ke dalam tabel.
        // Menggunakan enumerated() untuk mendapatkan indeks dan data.
        // Menggunakan reversed() untuk memasukkan data dari belakang ke depan.
        // Ini penting untuk memastikan bahwa indeks tetap konsisten saat kita memasukkan data baru
        // karena kita memasukkan data baru di awal tabel
        // sehingga indeks yang lebih tinggi tidak berubah saat kita memasukkan data baru
        // Ini juga memastikan bahwa data yang lebih baru muncul di atas data yang lebih lama.
        // Ini penting untuk memastikan bahwa data yang lebih baru muncul di atas data yang lebih lama
        // sehingga pengguna dapat melihat data yang baru saja dipulihkan dengan mudah.
        for (_, data) in deletedData.data.enumerated().reversed() {
            guard let insertionIndex = insertData(for: tableType, deletedData: data, sortDescriptor: sortDescriptor) else { return }
            updateDataArray(tableType, dataToInsert: data)
            table.insertRows(at: IndexSet(integer: insertionIndex), withAnimation: .slideDown)
            lastIndex.append(insertionIndex)
            allIDs.append(data.kelasID)
        }

        table.endUpdates()
        table.selectRowIndexes(IndexSet(lastIndex), byExtendingSelection: false)

        if let maxIndex = lastIndex.max() {
            table.scrollRowToVisible(maxIndex)
        }

        kelasID.append(allIDs)

        if !onlyDataKelasAktif {
            undoManager.registerUndo(withTarget: viewController) { [weak viewController] _ in
                (viewController as? KelasVC)?.redoHapus(table: table, tableType: tableType)
            }
            SingletonData.deletedKelasID.append((table: lastDeletedTable, kelasID: allIDs))
            NotificationCenter.default.post(name: .undoKelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": allIDs])
            SingletonData.deletedKelasAndSiswaIDs.removeAll { kelasSiswaPairs in
                kelasSiswaPairs.contains { pair in
                    allIDs.contains(pair.kelasID)
                }
            }
        } else {
            undoManager.registerUndo(withTarget: viewController) { [weak viewController] _ in
                (viewController as? KelasVC)?.redoHapusData(tableType: tableType, table: table)
            }
            NotificationCenter.default.post(name: .undoKelasDihapus, object: self, userInfo: ["tableType": tableType, "deletedKelasIDs": allIDs, "hapusData": true])
        }
    }
}
