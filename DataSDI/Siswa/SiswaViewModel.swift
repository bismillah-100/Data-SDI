//
//  SiswaViewModel.swift
//  Data SDI
//
//  Created by Bismillah on 21/09/24.
//
import Foundation
import AppKit

class SiswaViewModel {
    static var siswaUndoManager: UndoManager = UndoManager()
    private var dbController: DatabaseController!
    
    private(set) lazy var filteredSiswaData: [ModelSiswa] = []
    private(set) lazy var groupedSiswa: [[ModelSiswa]] = [[], [], [], [], [], [], [], []]
    private var imageCache = NSCache<NSString, NSImage>()
    
    private let operationQueue = OperationQueue()
    var isGrouped: Bool = false
    
    //// **  Dependency Injection
    init(dbController: DatabaseController) {
        self.dbController = dbController
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .userInitiated
    }
    // MARK: - SISWADATA related View
    func fetchSiswaData() async {
        filteredSiswaData = await Task(priority: .userInitiated) {
            return await self.dbController.getSiswa(isGrouped)
        }.value
    }

    /// Fungsi untuk memfilter siswa yang belum dihapus
    func filterDeletedSiswa(sortDescriptor: SortDescriptorWrapper, group: Bool, filterBerhenti: Bool) async {
        await Task { [weak self] in
            guard let self = self else { return }
            if group { await self.getGroupSiswa() }
        }.value
    }

    func cariSiswa(_ filter: String) async {
        filteredSiswaData = await dbController.searchSiswa(query: filter)
    }
    
    /// CRUD
    func removeSiswa(at index: Int) {
        let siswaToRemove = filteredSiswaData[index]
        
        // Hapus dari database
        
        // Hapus dari siswaData dan filteredSiswaData
        if let siswaIndex = filteredSiswaData.firstIndex(where: { $0.id == siswaToRemove.id }) {
            removeImageReferenceToDisk(for: filteredSiswaData[siswaIndex])
            filteredSiswaData.remove(at: siswaIndex)
        }
        
    }
    /// CRUD
    func insertSiswa(_ siswa: ModelSiswa, at index: Int) {
        // Tambahkan ke database
        
        // Tambahkan ke siswaData dan filteredSiswaData pada posisi yang sesuai
        filteredSiswaData.insert(siswa, at: index)
        saveImageReferenceToDisk(for: siswa)
    }
    /// CRUD
    func updateSiswa(_ siswa: ModelSiswa, at index: Int) {
        let siswaToUpdate = filteredSiswaData[index]
        
        // Update di database
        
        // Update di siswaData dan filteredSiswaData
        if let siswaIndex = filteredSiswaData.firstIndex(where: { $0.id == siswaToUpdate.id }) {
            filteredSiswaData[siswaIndex] = siswa
        }
        saveImageReferenceToDisk(for: siswa)
    }
    
    /// update data siswa dan kirim notifikasi ke KelasVC dan DetailSiswaViewController
    func updateDataSiswa(_ id: Int64, dataLama: ModelSiswa, baru: ModelSiswa) {
        /* kirim notifikasi sebelum database diupdate */
        if baru.kelasSekarang == dataLama.kelasSekarang && baru.kelasSekarang != "Lulus" {
            // kelasnya sama tapi kelas baru bukan lulus.
        } else if baru.status == "Lulus" {
            dbController.editSiswaLulus(namaSiswa: baru.nama, siswaID: baru.id, kelasBerikutnya: "Lulus")
            /* */
        } else if dataLama.kelasSekarang == "Lulus" {
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [baru.id],
                "kelasSekarang": baru.kelasSekarang,
                "isDeleted": true
            ]
            NotificationCenter.default.post(name: .undoSiswaDihapus, object: nil, userInfo: userInfo)
        } else if baru.kelasSekarang == "" {
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [baru.id],
                "kelasSekarang": dataLama.kelasSekarang,
                "isDeleted": true
            ]
            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
        } else {
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [baru.id],
                "kelasSekarang": baru.kelasSekarang,
                "isDeleted": true
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
        if dataLama.foto != baru.foto {
            dbController.updateFotoInDatabase(with: baru.foto, idx: id)
        }
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
        if dataLama.foto != baru.foto {
            dbController.updateFotoInDatabase(with: baru.foto, idx: id)
        }
        
        
        /* kirim notifikasi setelah database diupdate */
        if baru.kelasSekarang == dataLama.kelasSekarang && baru.kelasSekarang != "Lulus" {
            // Ketika undo tidak merubah kelas sekarang dan kelas sekarang bukan Lulus
            let userInfo: [String: Any] = [
                "updateStudentIDs": baru.id,
                "kelasSekarang": baru.kelasSekarang,
                "namaSiswa": baru.nama
            ]
            NotificationCenter.default.post(name: .dataSiswaDiEditDiSiswaView, object: nil, userInfo: userInfo)
        } else if baru.status == "Lulus" {
            /* */
            let userInfo: [String: Any] = [
                "deletedStudentIDs": [baru.id],
                "kelasSekarang": dataLama.kelasSekarang,
                "isDeleted": true
            ]
            NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
        } else if dataLama.kelasSekarang == "Lulus" {
            // Kelas sekarang di dataLama adalah "Lulus"
        } else if baru.kelasSekarang == "" {
            // Kelas sekarang di data yang baru kosong
        } else {}
    }

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
    
    func updateModelAndDatabase(id: Int64, columnIdentifier: String, rowIndex: Int? = nil, newValue: String, oldValue: String, isGrouped: Bool? = nil, groupIndex: Int? = nil, rowInSection: Int? = nil) {
            switch columnIdentifier {
            case "Nama":
                dbController.updateKolomNama(id, value: newValue)
                if UserDefaults.standard.bool(forKey: "sembunyikanSiswaBerhenti") || !UserDefaults.standard.bool(forKey: "tampilkanSiswaLulus") {
                    if let siswa = dbController.getKelasSiswa(id) {
                        let userInfo: [String: Any] = [
                            "updateStudentIDs": id,
                            "kelasSekarang": siswa.kelas,
                            "namaSiswa": siswa.nama
                        ]
                        NotificationCenter.default.post(name: .dataSiswaDiEditDiSiswaView, object: nil, userInfo: userInfo)
                    }
                }
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    let id = groupedSiswa[groupIndex][rowInSection].id
                    groupedSiswa[groupIndex][rowInSection].nama = newValue
                    let nama = groupedSiswa[groupIndex][rowInSection].nama
                    let userInfo: [String: Any] = [
                        "updateStudentIDs": id,
                        "kelasSekarang": groupedSiswa[groupIndex][rowInSection].kelasSekarang,
                        "namaSiswa": nama
                    ]
                    NotificationCenter.default.post(name: .dataSiswaDiEditDiSiswaView, object: nil, userInfo: userInfo)
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].nama = newValue
                    let userInfo: [String: Any] = [
                        "updateStudentIDs": filteredSiswaData[rowIndex].id,
                        "kelasSekarang": filteredSiswaData[rowIndex].kelasSekarang,
                        "namaSiswa": filteredSiswaData[rowIndex].nama
                    ]
                    NotificationCenter.default.post(name: .dataSiswaDiEditDiSiswaView, object: nil, userInfo: userInfo)
                }
            case "Alamat":
                dbController.updateKolomAlamat(id, value: newValue)
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    groupedSiswa[groupIndex][rowInSection].alamat = newValue
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].alamat = newValue
                }
            case "T.T.L":
                dbController.updateKolomTglLahir(id, value: newValue)
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    groupedSiswa[groupIndex][rowInSection].ttl = newValue
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].ttl = newValue
                }
                NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
            case "Tahun Daftar":
                dbController.updateKolomTahunDaftar(id, value: newValue)
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    groupedSiswa[groupIndex][rowInSection].tahundaftar = newValue
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].tahundaftar = newValue
                }
                NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)

            case "Nama Wali":
                dbController.updateKolomWali(id, value: newValue)
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    groupedSiswa[groupIndex][rowInSection].namawali = newValue
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].namawali = newValue
                }
            case "NIS":
                dbController.updateKolomNIS(id, value: newValue)
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    groupedSiswa[groupIndex][rowInSection].nis = newValue
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].nis = newValue
                }
            case "NISN":
                dbController.updateKolomNISN(id, value: newValue)
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    groupedSiswa[groupIndex][rowInSection].nisn = newValue
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].nisn = newValue
                }
            case "Ayah":
                dbController.updateKolomAyah(id, value: newValue)
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    groupedSiswa[groupIndex][rowInSection].ayah = newValue
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].ayah = newValue
                }
            case "Ibu":
                dbController.updateKolomIbu(id, value: newValue)
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    groupedSiswa[groupIndex][rowInSection].ibu = newValue
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].ibu = newValue
                    dbController.updateKolomIbu(filteredSiswaData[rowIndex].id, value: newValue)
                }
            case "Jenis Kelamin":
                dbController.updateKolomKelamin(id, value: newValue)
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    groupedSiswa[groupIndex][rowInSection].jeniskelamin = newValue
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].jeniskelamin = newValue
                }
            case "Status":
                dbController.updateStatusSiswa(idSiswa: id, newStatus: newValue)
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    groupedSiswa[groupIndex][rowInSection].status = newValue
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].status = newValue
                }
            case "Tgl. Lulus":
                dbController.updateTglBerhenti(kunci: id, editTglBerhenti: newValue)
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    groupedSiswa[groupIndex][rowInSection].tanggalberhenti = newValue
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].tanggalberhenti = newValue
                }
                NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
            case "Nomor Telepon":
                dbController.updateKolomTlv(id, value: newValue)
                if isGrouped == true, let groupIndex = groupIndex, let rowInSection = rowInSection {
                    groupedSiswa[groupIndex][rowInSection].tlv = newValue
                }
                else if isGrouped == nil, let rowIndex = rowIndex, rowIndex < filteredSiswaData.count {
                    filteredSiswaData[rowIndex].tlv = newValue
                }
            default:
                break
            }
        if let rowIndex = rowIndex {
            NotificationCenter.default.post(name: .undoActionNotification, object: nil, userInfo: [
                "id": id,
                "rowIndex": rowIndex,
                "columnIdentifier": columnIdentifier,
                "newValue": oldValue
            ])
        } else if isGrouped == true, let gi = groupIndex, let ris = rowInSection {
            NotificationCenter.default.post(name: .undoActionNotification, object: nil, userInfo: [
                "id": id,
                "groupIndex": gi,
                "rowInSection": ris,
                "columnIdentifier": columnIdentifier,
                "newValue": oldValue,
                "isGrouped": true
            ])
        }
    }

    
    //MARK: - Image Cache
    public func setImageCache(_ image: NSImage, key: NSString) {
        imageCache.setObject(image, forKey: key)
    }
    public func getImageCache(_ key: NSString) -> NSImage? {
        guard let cache = imageCache.object(forKey: key) else { return nil }
        return cache
    }
    public func getImageForKelas(bordered: Bool = false, kelasSekarang: String, completion: @escaping (NSImage?) -> Void) {
        // Cache key hanya berdasarkan kelasSekarang dan bordered
        let cacheKey = NSString(string: "\(kelasSekarang)\(bordered ? " Bordered" : "")")
        
        // Cek apakah gambar sudah ada di cache memori
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            completion(cachedImage)
            return
        }

        // Buat BlockOperation untuk menghindari penggunaan DispatchQueue langsung
        let imageFetchOperation = BlockOperation { [weak self] in
            guard let self = self else { return }
            
            // Tentukan nama gambar berdasarkan kelas
            let kelasImageName = self.determineImageName(for: kelasSekarang)
            let finalImageName = bordered ? "\(kelasImageName) Bordered" : kelasImageName
            
            // Dapatkan gambar berdasarkan nama
            guard let image = NSImage(named: finalImageName) else {
                DispatchQueue.main.async(qos: .userInteractive) {
                    completion(nil)
                }
                return
            }
            
            // Simpan gambar ke cache memori
            if self.imageCache.object(forKey: cacheKey) == nil {
                self.imageCache.setObject(image, forKey: cacheKey)
                
            }
            
            // Kembali ke main thread untuk menyelesaikan operasi dan memanggil completion
            DispatchQueue.main.async(qos: .userInteractive) {
                completion(image)
            }
        }
        
        // Tambahkan operasi ke OperationQueue
        operationQueue.addOperation(imageFetchOperation)
    }

    /// Fungsi untuk memuat referensi gambar dari UserDefaults
    func loadImageReferenceFromDisk(for siswa: ModelSiswa, completion: @escaping (String?) -> Void) {
        let imageFetchOperation = BlockOperation {
            let imageName = UserDefaults.standard.string(forKey: "\(siswa.id)_kelasImage")
            
            // Kembali ke main thread untuk mengembalikan hasil
            DispatchQueue.main.async(qos: .userInteractive) {
                completion(imageName)
            }
        }
        operationQueue.addOperation(imageFetchOperation)
    }

    /// Fungsi untuk menentukan nama gambar berdasarkan kelas siswa
    func determineImageName(for kelasSekarang: String) -> String {
        switch kelasSekarang {
        case "Kelas 1": return "Kelas 1"
        case "Kelas 2": return "Kelas 2"
        case "Kelas 3": return "Kelas 3"
        case "Kelas 4": return "Kelas 4"
        case "Kelas 5": return "Kelas 5"
        case "Kelas 6": return "Kelas 6"
        case "Lulus": return "lulus"
        default: return "No Data"
        }
    }

    /// Fungsi untuk menyimpan referensi gambar ke UserDefaults
    func saveImageReferenceToDisk(for siswa: ModelSiswa) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let kelasImageName = self?.determineImageName(for: siswa.kelasSekarang)
            UserDefaults.standard.set(kelasImageName, forKey: "\(siswa.id)_kelasImage")
        }
    }
    func removeImageReferenceToDisk(for siswa: ModelSiswa) {
        DispatchQueue.global(qos: .utility).async {
            UserDefaults.standard.removeObject(forKey: "\(siswa.id)_kelasImage")
        }
    }
    
    // MARK: - GroupedSiswa related View
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
                    else if siswa.kelasSekarang.isEmpty && siswa.status.lowercased() != "lulus" {
                        return (7, siswa)
                    }
                    else {
                        // Bersihkan string, menghilangkan kata "Kelas "
                        let cleanedString = siswa.kelasSekarang.replacingOccurrences(of: "Kelas ", with: "")
                        
                        // Konversi string ke bilangan bulat
                        if let kelasIndex = Int(cleanedString), kelasIndex >= 1 && kelasIndex <= 6 {
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

    func updateGroupSiswa(_ siswa: ModelSiswa, groupIndex: Int, index: Int) {
        while groupedSiswa.count <= groupIndex {
            groupedSiswa.append([])
        }
        let safeIndex = min(index, groupedSiswa[groupIndex].count - 1)
        if safeIndex >= 0 {
            groupedSiswa[groupIndex][safeIndex] = siswa
            saveImageReferenceToDisk(for: siswa)
        } else {
            groupedSiswa[groupIndex].insert(siswa, at: 0)
            saveImageReferenceToDisk(for: siswa)
        }
    }
    func removeGroupSiswa(groupIndex: Int, index: Int) {
        guard groupIndex < groupedSiswa.count, index < groupedSiswa[groupIndex].count else {
            
            return
        }
        removeImageReferenceToDisk(for: groupedSiswa[groupIndex][index])
        groupedSiswa[groupIndex].remove(at: index)
    }
    func insertGroupSiswa(_ siswa: ModelSiswa, groupIndex: Int, index: Int) {
        // Tambahkan grup kosong jika perlu
        while groupedSiswa.count <= groupIndex {
            groupedSiswa.append([])
        }
        // Pastikan index tidak melebihi jumlah siswa
        if index <= groupedSiswa[groupIndex].count {
            if !groupedSiswa[groupIndex].contains(where: {$0.id == siswa.id}) {
                groupedSiswa[groupIndex].insert(siswa, at: index)
                saveImageReferenceToDisk(for: siswa)
            }
        }
    }
    func findSiswaInGroups(id: Int64) -> (Int, Int)? {
        for (groupIndex, group) in groupedSiswa.enumerated() {
            if let rowIndex = group.firstIndex(where: { $0.id == id }) {
                return (groupIndex, rowIndex)
            }
        }
        return nil
    }
    func getAbsoluteRowIndex(groupIndex: Int, rowIndex: Int) -> Int {
        var absoluteRowIndex = 0
        for i in 0..<groupIndex {
            absoluteRowIndex += groupedSiswa[i].count + 1 // +1 for header
        }
        return absoluteRowIndex + rowIndex + 1 // +1 for header
    }
    func sortSiswa(by sortDescriptor: SortDescriptorWrapper, isBerhenti: Bool) async {
        filteredSiswaData.sort { (item1, item2) -> Bool in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd MMMM yyyy"
            
            // Metode bantu untuk membandingkan dua string atau dua tanggal
            func compareStrings(_ string1: String, _ string2: String, ascending: Bool) -> Bool {
                if ascending {
                    return string1 < string2
                } else {
                    return string1 > string2
                }
            }
            
            func compareDates(_ date1: Date, _ date2: Date, ascending: Bool) -> Bool {
                if ascending {
                    return date1 < date2
                } else {
                    return date1 > date2
                }
            }
            
            switch sortDescriptor.key {
            case "nama":
                return sortDescriptor.ascending ? item1.nama < item2.nama : item1.nama > item2.nama
            case "alamat":
                if item1.alamat == item2.alamat {
                    return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                } else {
                    return compareStrings(item1.alamat, item2.alamat, ascending: sortDescriptor.ascending)
                }
            case "ttl":
                if item1.ttl == item2.ttl {
                    return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                } else {
                    return compareStrings(item1.ttl, item2.ttl, ascending: sortDescriptor.ascending)
                }
            case "tahundaftar":
                if let date1 = dateFormatter.date(from: item1.tahundaftar),
                   let date2 = dateFormatter.date(from: item2.tahundaftar) {
                    if date1 == date2 {
                        return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                    } else {
                        return compareDates(date1, date2, ascending: sortDescriptor.ascending)
                    }
                } else {
                    return false
                }
            case "namawali":
                if item1.namawali == item2.namawali {
                    return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                } else {
                    return compareStrings(item1.namawali, item2.namawali, ascending: sortDescriptor.ascending)
                }
            case "nis":
                if item1.nis == item2.nis {
                    return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                } else {
                    return compareStrings(item1.nis, item2.nis, ascending: sortDescriptor.ascending)
                }
            case "jeniskelamin":
                if item1.jeniskelamin == item2.jeniskelamin {
                    return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                } else {
                    return compareStrings(item1.jeniskelamin, item2.jeniskelamin, ascending: sortDescriptor.ascending)
                }
            case "status":
                if item1.status == item2.status {
                    return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                } else {
                    return compareStrings(item1.status, item2.status, ascending: sortDescriptor.ascending)
                }
            case "ayahkandung":
                if item1.ayah == item2.ayah {
                    return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                } else {
                    return compareStrings(item1.ayah, item2.ayah, ascending: sortDescriptor.ascending)
                }
            case "ibukandung":
                if item1.ibu == item2.ibu {
                    return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                } else {
                    return compareStrings(item1.ibu, item2.ibu, ascending: sortDescriptor.ascending)
                }
            case "nisn":
                if item1.nisn == item2.nisn {
                    return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                } else {
                    return compareStrings(item1.nisn, item2.nisn, ascending: sortDescriptor.ascending)
                }
            case "tlv":
                if item1.tlv == item2.tlv {
                    return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                } else {
                    return compareStrings(item1.tlv, item2.tlv, ascending: sortDescriptor.ascending)
                }
            case "tanggalberhenti":
                if let date1 = dateFormatter.date(from: item1.tanggalberhenti),
                   let date2 = dateFormatter.date(from: item2.tanggalberhenti) {
                    if date1 == date2 {
                        return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                    } else {
                        return compareDates(date1, date2, ascending: sortDescriptor.ascending)
                    }
                } else {
                    return false
                }
            default:
                return true
            }
        }
    }

    func getSiswaIdInGroupedMode(row: Int) -> Int64 {
        for (groupIndex, siswaGroup) in groupedSiswa.enumerated() {
            let absoluteRowIndex = getAbsoluteRowIndex(groupIndex: groupIndex, rowIndex: 0)
            let endRowIndex = absoluteRowIndex + siswaGroup.count
            if row >= absoluteRowIndex && row < endRowIndex {
                let siswaIndex = row - absoluteRowIndex
                return siswaGroup[siswaIndex].id
            }
        }
        return -1 //// nilai default negatif jika tidak ditemukan
    }
    // Fungsi untuk mengurutkan berdasarkan sort descriptor
    func sortGroupSiswa(by sortDescriptor: SortDescriptorWrapper) async {
        let sortedGroupedSiswa = groupedSiswa.map { group in
            group.sorted { (item1, item2) -> Bool in
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMMM yyyy"
                
                // Metode bantu untuk membandingkan dua string atau dua tanggal
                func compareStrings(_ string1: String, _ string2: String, ascending: Bool) -> Bool {
                    if ascending {
                        return string1 < string2
                    } else {
                        return string1 > string2
                    }
                }
                
                func compareDates(_ date1: Date, _ date2: Date, ascending: Bool) -> Bool {
                    if ascending {
                        return date1 < date2
                    } else {
                        return date1 > date2
                    }
                }
                
                switch sortDescriptor.key {
                case "nama":
                    return sortDescriptor.ascending ? item1.nama < item2.nama : item1.nama > item2.nama
                case "alamat":
                    if item1.alamat == item2.alamat {
                        return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                    } else {
                        return compareStrings(item1.alamat, item2.alamat, ascending: sortDescriptor.ascending)
                    }
                case "ttl":
                    if item1.ttl == item2.ttl {
                        return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                    } else {
                        return compareStrings(item1.ttl, item2.ttl, ascending: sortDescriptor.ascending)
                    }
                case "tahundaftar":
                    if let date1 = dateFormatter.date(from: item1.tahundaftar),
                       let date2 = dateFormatter.date(from: item2.tahundaftar) {
                        if date1 == date2 {
                            return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                        } else {
                            return compareDates(date1, date2, ascending: sortDescriptor.ascending)
                        }
                    } else {
                        return false
                    }
                case "namawali":
                    if item1.namawali == item2.namawali {
                        return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                    } else {
                        return compareStrings(item1.namawali, item2.namawali, ascending: sortDescriptor.ascending)
                    }
                case "nis":
                    if item1.nis == item2.nis {
                        return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                    } else {
                        return compareStrings(item1.nis, item2.nis, ascending: sortDescriptor.ascending)
                    }
                case "ayahkandung":
                    if item1.ayah == item2.ayah {
                        return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                    } else {
                        return compareStrings(item1.ayah, item2.ayah, ascending: sortDescriptor.ascending)
                    }
                case "ibukandung":
                    if item1.ibu == item2.ibu {
                        return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                    } else {
                        return compareStrings(item1.ibu, item2.ibu, ascending: sortDescriptor.ascending)
                    }
                case "nisn":
                    if item1.nisn == item2.nisn {
                        return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                    } else {
                        return compareStrings(item1.nisn, item2.nisn, ascending: sortDescriptor.ascending)
                    }
                case "tlv":
                    if item1.tlv == item2.tlv {
                        return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                    } else {
                        return compareStrings(item1.tlv, item2.tlv, ascending: sortDescriptor.ascending)
                    }
                case "jeniskelamin":
                    if item1.jeniskelamin == item2.jeniskelamin {
                        return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                    } else {
                        return compareStrings(item1.jeniskelamin, item2.jeniskelamin, ascending: sortDescriptor.ascending)
                    }
                case "status":
                    if item1.status == item2.status {
                        return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                    } else {
                        return compareStrings(item1.status, item2.status, ascending: sortDescriptor.ascending)
                    }
                case "tanggalberhenti":
                    if let date1 = dateFormatter.date(from: item1.tanggalberhenti),
                       let date2 = dateFormatter.date(from: item2.tanggalberhenti) {
                        if date1 == date2 {
                            return compareStrings(item1.nama, item2.nama, ascending: sortDescriptor.ascending)
                        } else {
                            return compareDates(date1, date2, ascending: sortDescriptor.ascending)
                        }
                    } else {
                        return false
                    }
                default:
                    return true
                }
            }
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
    func undoAction(originalModel: DataAsli) {
        if isGrouped == true {
            guard let siswa = findSiswaInGroups(id: originalModel.ID) else {
                updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, newValue: originalModel.oldValue, oldValue: originalModel.newValue)
                
                NotificationCenter.default.post(name: .undoActionNotification, object: nil, userInfo: [
                    "id": originalModel.ID,
                    "columnIdentifier": originalModel.columnIdentifier
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
        }
        else if !isGrouped {
            // Cari indeks di model berdasarkan ID
            guard let rowIndexToUpdate = filteredSiswaData.firstIndex(where: { $0.id == originalModel.ID }) else {
                updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, newValue: originalModel.oldValue, oldValue: originalModel.newValue)
                NotificationCenter.default.post(name: .undoActionNotification, object: nil, userInfo: [
                    "id": originalModel.ID,
                    "columnIdentifier": originalModel.columnIdentifier
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
    func redoAction(originalModel: DataAsli) {
        if isGrouped == true {
            guard let siswa = findSiswaInGroups(id: originalModel.ID) else {
                updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, newValue: originalModel.newValue, oldValue: originalModel.oldValue)
                NotificationCenter.default.post(name: .undoActionNotification, object: nil, userInfo: [
                    "id": originalModel.ID,
                    "columnIdentifier": originalModel.columnIdentifier
                ])
                SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
                    self.undoAction(originalModel: originalModel)
                })
                return
            }
            updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, newValue: originalModel.newValue, oldValue: originalModel.oldValue, isGrouped: true, groupIndex: siswa.0, rowInSection: siswa.1)
        }
        else if !isGrouped {
            // Cari indeks di model berdasarkan ID
            guard let rowIndexToUpdate = filteredSiswaData.firstIndex(where: { $0.id == originalModel.ID }) else {
                updateModelAndDatabase(id: originalModel.ID, columnIdentifier: originalModel.columnIdentifier, newValue: originalModel.newValue, oldValue: originalModel.oldValue)

                NotificationCenter.default.post(name: .undoActionNotification, object: nil, userInfo: [
                    "id": originalModel.ID,
                    "columnIdentifier": originalModel.columnIdentifier
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
            guard let self = self else { return }
            self.undoEditSiswa(oldData)
        }
    }
}

struct SortDescriptorWrapper: Sendable {
    let key: String
    let ascending: Bool

//    func toNSSortDescriptor() -> NSSortDescriptor {
//        NSSortDescriptor(key: key, ascending: ascending)
//    }
    static func from(_ descriptor: NSSortDescriptor) -> SortDescriptorWrapper {
        SortDescriptorWrapper(key: descriptor.key ?? "", ascending: descriptor.ascending)
    }
}
