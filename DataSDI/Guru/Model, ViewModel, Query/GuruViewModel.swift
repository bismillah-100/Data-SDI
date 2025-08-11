//
//  GuruViewModel.swift
//  Data SDI
//
//  Created by MacBook on 09/07/25.
//

import Foundation
import Combine

typealias GuruWithUpdate = (guru: GuruModel, update: UpdatePenugasanGuru)
typealias GuruInsertDict = [MapelModel: [(guru: GuruModel, index: Int)]]

/// Pengelola data guru, struktur dan tugas. Menggunakan combine untuk publish
/// event pembaruan.
class GuruViewModel {
    /// Membuat singleton ``GuruViewModel``.
    static let shared = GuruViewModel()
    /// Instansi ``DatabaseController``
    let dbController = DatabaseController.shared

    /// Properti untuk menyimpan data guru yang diambil dari database.
    private(set) var guru: [GuruModel] = []

    /// Properti kamus untuk menyusun data mapel sebagai kata kunci dan
    /// daftar guru sebagai isi dari mapel. Keduanya disimpan sebagai
    /// ``MapelModel``.
    private(set) var daftarMapel: [MapelModel] = []

    private(set) var strukturDict: [StrukturGuruDictionary] = []

    /// Publisher event granular untuk insert/delete/update penugasan guru.
    let tugasGuruEvent = PassthroughSubject<PenugasanGuruEvent, Never>()

    /// Publisher event granular untuk insert/delete/update guru.
    let guruEvent = PassthroughSubject<GuruEvent, Never>()

    /// Publisher event granular untuk insert/delete/update jabatan guru.
    let strukturEvent = PassthroughSubject<StrukturEvent, Never>()

    /// undoManager untuk tugas Guru.
    var myUndoManager: UndoManager = .init()

    /// undoManager untuk Guru.
    var guruUndoManager: UndoManager = .init()

    /// SortDesriptor yang digunakan di tableView mapel.
    var sortDescriptor: NSSortDescriptor?

    /// SortDescriptor yang digunakan di tableView guru.
    var guruSortDescriptor: NSSortDescriptor! = NSSortDescriptor(key: "NamaGuru", ascending: true)

    /// Properti untuk menyimpan filter status penugasan.
    var filterTugas: StatusSiswa? {
        get {
            guard UserDefaults.standard.object(forKey: "FilterTugasGuru") != nil else {
                return nil
            }
            let ud = UserDefaults.standard.integer(forKey: "FilterTugasGuru")
            return StatusSiswa(rawValue: ud)
        }
        set {
            if let value = newValue {
                UserDefaults.standard.setValue(value.rawValue, forKey: "FilterTugasGuru")
            } else {
                UserDefaults.standard.removeObject(forKey: "FilterTugasGuru")
            }
            tugasGuruEvent.send(.reloadData)
        }
    }

    private var cancellables = Set<AnyCancellable>()

    /// Initializer private ``GuruViewModel``. Untuk menjaga supaya
    /// tidak dibuat init ulang.
    private init() {
        guruEvent
            .receive(on: DispatchQueue.global(qos: .background))
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case let .updatedNama(update: guru):
                    self.updateNama(guru)
                default: break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - STRUKTUR

    /// Membentuk struktur guru berdasarkan tahun ajaran tertentu.
    /// - Parameter tahunAjaran: Tahun ajaran yang ingin difilter (opsional). Jika nil, akan mengambil semua guru.
    /// - Note: Fungsi ini akan mengelompokkan guru berdasarkan atribut `struktural`. Jika atribut tersebut nil, maka akan menggunakan tanda "-".
    ///         Setiap guru hanya akan muncul satu kali dalam setiap kelompok struktural (tidak ada duplikasi berdasarkan `idGuru`).
    ///         Hasil akhir akan disimpan dalam `strukturDict` dalam bentuk array, di mana setiap elemen berisi nama struktural dan daftar guru yang sudah diurutkan berdasarkan nama.
    /// - Important: Fungsi ini berjalan secara asynchronous.
    func buildStrukturGuru(_ tahunAjaran: String? = nil) async {
        let allRelevantGuru = await dbController.getGuruByTahunAjaran(tahunAjaran: tahunAjaran)
        var groupedGuru: [String: [GuruModel]] = [:]

        for guru in allRelevantGuru {
            // Gunakan nama struktural, atau "Tidak Ada Jabatan" jika nil
            let strukturalKey = guru.struktural ?? "-"

            // Tambahkan guru ke array yang sesuai dengan kunci struktural
            if var guruListForStruktur = groupedGuru[strukturalKey] {
                // Pastikan tidak ada duplikasi guru dalam satu struktural
                if !guruListForStruktur.contains(where: { $0.idGuru == guru.idGuru }) {
                    guruListForStruktur.append(guru)
                    groupedGuru[strukturalKey] = guruListForStruktur
                }
            } else {
                groupedGuru[strukturalKey] = [guru]
            }
        }

        // Konversi dictionary ke array StrukturGuruDictionary
        // Anda mungkin ingin mengurutkan berdasarkan nama struktural atau kriteria lain
        strukturDict = groupedGuru.map { struktural, guruList in
            // Sort guruList secara opsional, misalnya berdasarkan nama guru
            let sortedGuruList = guruList.sorted { $0.namaGuru.localizedCaseInsensitiveCompare($1.namaGuru) == .orderedAscending }
            return .init(struktural: struktural, guruList: sortedGuruList)
        }
    }

    /// Menghapus elemen struktur pada indeks tertentu dari guru yang dipilih.
    /// - Parameters:
    ///   - strukturIndex: Indeks struktur yang akan dihapus.
    ///   - guruIndex: Indeks guru yang strukturnya akan diubah.
    /// - Returns: `true` jika penghapusan berhasil, `false` jika gagal.
    func removeStruktur(_ strukturIndex: Int, guruIndex: Int) -> Bool {
        guard strukturIndex < strukturDict.count else { return false }

        let struktur = strukturDict[strukturIndex]
        guard guruIndex < struktur.guruList.count else { return false }

        struktur.guruList.remove(at: guruIndex)

        if struktur.guruList.isEmpty {
            strukturDict.remove(at: strukturIndex)
            return true // menandakan grup juga dihapus
        } else {
            strukturDict[strukturIndex] = struktur
            return false
        }
    }

    /// Menyisipkan data guru ke dalam struktur pada indeks tertentu.
    /// - Parameters:
    ///   - strukturIndex: Indeks struktur tempat data guru akan disisipkan.
    ///   - guru: Objek `GuruModel` yang akan disisipkan.
    /// - Returns: Nilai integer opsional yang menunjukkan hasil penyisipan, atau `nil` jika gagal.
    func insertStruktur(_ strukturIndex: Int, guru: GuruModel) -> Int? {
        let struktur = strukturDict[strukturIndex]
        let insertIndex = struktur.guruList.firstIndex(where: {
            $0.namaGuru.localizedCaseInsensitiveCompare(guru.namaGuru) == .orderedDescending
        }) ?? struktur.guruList.count
        if !struktur.guruList.contains(where: { $0.idGuru == guru.idGuru }) {
            struktur.guruList.insert(guru, at: insertIndex)
            strukturDict[strukturIndex] = struktur
            return insertIndex
        }
        return nil
    }

    /// Menambahkan objek `GuruModel` ke dalam struktur data `strukturDict` sebagai grup baru berdasarkan properti `struktural`.
    /// - Parameter guru: Objek `GuruModel` yang akan dimasukkan.
    /// - Returns: Tuple berisi indeks grup struktur (`strukturIndex`) dan indeks guru di dalam grup tersebut (`guruIndex`), atau `nil` jika gagal.
    func insertGuruInStruktur(_ guru: GuruModel) -> (strukturIndex: Int, guruIndex: Int)? {
        let key = guru.struktural ?? "Tidak Ada Jabatan"
        let newGroup = StrukturGuruDictionary(struktural: key, guruList: [guru])
        strukturDict.append(newGroup)
        return (strukturDict.count - 1, 0)
    }

    // MARK: - GURU

    /// Fungsi untuk menjalankan query database ``DatabaseController/getGuru(statusTugas:searchQuery:semester:tahunAjaran:guruVC:)`` dan menyimpan
    /// hasilnya ke ``guru`` jika ``guru`` masih kosong.
    /// - Parameter forceLoad: Opsi untuk tetap menjalankan query database bahkan ketika ``guru`` sudah
    /// menyimpan setidaknya satu daftar guru. Ini biasanya digunakan untuk memuat ulang data dan tampilan
    /// pada kondisi tertentu yang mengharuskan data diquery ulang dari database.
    func queryDataGuru(statusTugas: StatusSiswa? = nil, query: String? = nil, semester: String? = nil, tahunAjaran: String? = nil, forceLoad: Bool = false) async {
        guard guru.isEmpty || forceLoad else { return }
        if let statusTugas {
            guru = await dbController.getGuru(statusTugas: statusTugas, searchQuery: query, semester: semester, tahunAjaran: tahunAjaran, guruVC: true)
        } else if let query {
            guru = await dbController.getGuru(searchQuery: query, guruVC: true)
        } else {
            guru = await dbController.getGuru(guruVC: true)
        }
    }

    /// Menghapus data guru pada indeks tertentu dari daftar guru.
    ///
    /// - Parameter index: Indeks dari data guru yang akan dihapus dari array `guru`.
    func removeGuru(at index: Int) {
        guru.remove(at: index)
    }

    /// Fungsi untuk menambahkan guru pada urutan yang sesuai index.
    ///
    /// - Parameters:
    ///   - newData: Data guru baru yang akan disisipkan.
    ///   - index: Indeks posisi di mana data guru baru akan dimasukkan ke dalam array.
    func insertGuru(_ newData: GuruModel, at index: Int) {
        guru.insert(newData, at: index)
    }

    /// Fungsi untuk membersihkan data ``guru``.
    func removeAllGuruData() {
        guru.removeAll()
    }

    /// Memperbarui data guru dalam array `guru` berdasarkan data baru yang diberikan.
    ///
    /// Fungsi ini melakukan pembaruan pada elemen-elemen yang sudah ada di array `guru`
    /// dengan data dari `newData`. Untuk setiap item:
    /// - Jika ditemukan perbedaan pada kolom `namaGuru` atau `alamatGuru`, maka akan dilakukan update ke database.
    /// - Item lama dihapus dari array, lalu item baru dimasukkan kembali pada posisi yang sesuai dengan sort descriptor.
    /// - Jika posisi item berubah, maka dicatat sebagai pergerakan (move); jika tidak, dicatat sebagai pembaruan (update).
    ///
    /// Setelah semua perubahan diterapkan, fungsi akan mengirimkan event batch yang berisi daftar indeks yang diperbarui
    /// dan pasangan indeks asal dan tujuan untuk item yang berpindah posisi.
    ///
    /// Jika `registerUndo` bernilai `true`, fungsi juga akan mendaftarkan aksi undo untuk membatalkan perubahan.
    ///
    /// - Parameter newData: Array `GuruModel` berisi data guru yang akan diperbarui.
    /// - Parameter registerUndo: Menentukan apakah aksi undo perlu didaftarkan (default: `true`).
    func updateGuruu(_ newData: [GuruModel], registerUndo: Bool = true) {
        // Ensure a sort descriptor is provided, otherwise exit as sorting logic depends on it.
        guard let guruSortDescriptor else {
            print("Error: guruSortDescriptor is not set. Cannot update guru array.")
            return
        }

        // Arrays to collect indices for batch move and update events
        var movedFromIndices: [Int] = [] // Stores original indices of moved items
        var movedToIndices: [Int] = [] // Stores new indices of moved items
        var updatedIndices: [Int] = [] // Simpan indeks yang akan diperbarui

        var oldData: [GuruModel] = [] // Simpan data untuk undo

        // To correctly find original indices and simulate array changes for insertionIndex,
        // we need to track the current state of the array as items are "virtually" removed and inserted.
        // A mapping of idGuru to its current index can help, or we can work directly on the `guru` array
        // and adjust for shifts. For simplicity and correctness with `firstIndex(where:)`,
        // we'll proceed by directly modifying `guru` and carefully tracking indices.

        // It's crucial to understand that `firstIndex(where:)` will find the index
        // in the *current* state of `guru`. When an item is removed, subsequent items shift.
        // To accurately track original `from` indices for a batch `move` event,
        // we need to store the index *before* any removals for the current iteration.

        // A better approach for complex updates (mix of moves, updates, inserts, removes)
        // often involves calculating a diff between the old and new states.
        // However, based on your current `updateGuruu` logic, which assumes `newData`
        // are updates to *existing* items (remove then insert), we'll adapt that.

        // To handle potential index shifts when removing items, we need to iterate
        // `newData` and find their *current* positions in `guru` before modifying `guru`.
        // A common pattern is to process items in `newData` and then apply changes.

        // Let's refine the loop to correctly track original indices for moves.
        // We'll iterate `newData`, find existing items, remove them, determine new positions,
        // and then re-insert.

        for data in newData {
            // Find the current index of the item in the `guru` array based on its ID.
            // We use the *current* `guru` array here to get the actual index for removal.
            guard let oldIndexInCurrentGuru = guru.firstIndex(where: { $0.idGuru == data.idGuru }) else {
                // If the item doesn't exist in the current `guru` array, it means it's a new item
                // or an item that was somehow removed previously.
                // Based on your original logic, we skip it if not found.
                // For a full "update" function, you might want to `insertGuru` here.
                continue
            }
            let oldGuru = guru[oldIndexInCurrentGuru]

            // Simpan untuk undo/redo
            oldData.append(oldGuru)

            // Update data di database
            if data.namaGuru != oldGuru.namaGuru {
                dbController.updateKolomGuru(
                    data.idGuru,
                    kolom: "nama_guru",
                    baru: data.namaGuru
                )
                guruEvent.send(.updatedNama(update: data))
            }

            if data.alamatGuru != oldGuru.alamatGuru {
                dbController.updateKolomGuru(
                    data.idGuru,
                    kolom: "alamat_guru",
                    baru: data.alamatGuru ?? ""
                )
            }

            // Store the original index before removal for the `from` part of the move event.
            // This is the index in the `guru` array *before* this specific item is removed.
            let originalFromIndex = oldIndexInCurrentGuru

            // Remove the item from the actual `guru` array.
            // This will cause subsequent items to shift their indices.
            removeGuru(at: oldIndexInCurrentGuru)

            // Determine the correct insertion index for the updated `data` within the *modified* `guru` array.
            // `insertionIndex` is called on the `guru` array which now has one less element.
            let newInsertionIndex = guru.insertionIndex(for: data, using: guruSortDescriptor)

            // Insert the updated `data` into the actual `guru` array at its new sorted position.
            insertGuru(data, at: newInsertionIndex)

            // Now, compare the original position with the new position to determine if it was a move or an in-place update.
            if originalFromIndex != newInsertionIndex {
                // If the item's position has changed, record both the original and new indices.
                movedFromIndices.append(originalFromIndex)
                movedToIndices.append(newInsertionIndex)
            } else {
                // Send a single `update` event if any items were updated in place.
                updatedIndices.append(newInsertionIndex)
            }
        }

        // After processing all items in `newData`, send the batch events.

        guruEvent.send(
            .moveAndUpdate(
                // Send a single `update` event if any items were updated in place.
                updates: updatedIndices,
                // Send a single `move` event if any items were moved.
                moves: zip(movedFromIndices, movedToIndices).map { ($0, $1) }
            )
        )
        strukturEvent.send(.updated(newData))
        guard registerUndo else { return }
        guruUndoManager.registerUndo(withTarget: self) { target in
            target.updateGuruu(oldData)
        }
    }

    /// Menyisipkan satu atau beberapa data `GuruModel` ke dalam daftar guru.
    /// - Parameters:
    ///   - newData: Array dari `GuruModel` yang akan disisipkan.
    ///   - registerUndo: Menentukan apakah aksi ini harus didaftarkan ke undo manager (default: true).
    ///
    /// Fungsi ini akan:
    /// 1. Menentukan indeks penyisipan untuk setiap data guru baru berdasarkan `guruSortDescriptor`.
    /// 2. Menyisipkan data guru pada indeks yang sesuai.
    /// 3. Menghapus ID guru dari daftar `deletedGuru` jika ada.
    /// 4. Mengirim event penyisipan ke `guruEvent`.
    /// 5. Jika `registerUndo` bernilai true, mendaftarkan aksi undo untuk menghapus data yang baru disisipkan.
    func insertGuruu(_ newData: [GuruModel], registerUndo: Bool = true) {
        guard let guruSortDescriptor else { return }
        var indexesToInsert = [Int]()
        for data in newData {
            let insertionIndex = guru.insertionIndex(for: data, using: guruSortDescriptor)
            insertGuru(data, at: insertionIndex)
            indexesToInsert.append(insertionIndex)
            if let indexUndo = SingletonData.deletedGuru.firstIndex(where: { $0 == data.idGuru }) {
                SingletonData.deletedGuru.remove(at: indexUndo)
            }
        }
        guruEvent.send(.insert(at: indexesToInsert))
        guard registerUndo else { return }
        guruUndoManager.registerUndo(withTarget: self) { target in
            target.removeGuruu(newData)
        }
    }

    /// Menghapus data guru dari daftar `guru`.
    ///
    /// - Parameter newData: Array berisi objek `GuruModel` yang akan dihapus.
    /// - Parameter registerUndo: Menentukan apakah aksi penghapusan akan didaftarkan ke undo manager (default: `true`).
    ///
    /// Fungsi ini akan:
    /// 1. Mengecek apakah setiap guru pada `newData` masih digunakan sebagai foreign key di tabel lain.
    ///    Jika masih digunakan, guru tersebut tidak akan dihapus dan akan ditampilkan pesan peringatan.
    /// 2. Menghapus guru dari daftar jika tidak sedang digunakan.
    /// 3. Menyimpan data guru yang dihapus untuk keperluan undo.
    /// 4. Mengirim event penghapusan ke `guruEvent`.
    /// 5. Jika ada guru yang tidak bisa dihapus karena masih bertugas, akan menampilkan pesan peringatan.
    ///
    /// - Note: Fungsi ini juga akan menambahkan id guru yang dihapus ke dalam `SingletonData.deletedGuru`.
    func removeGuruu(_ newData: [GuruModel], registerUndo: Bool = true) {
        var oldData = [GuruModel]()
        var indexesToDelete = [Int]()
        var guruBelumDiHapus = false
        for data in newData {
            // 🔍 1️⃣ Cek FK
            if dbController.isGuruMasihDipakai(idGuruValue: data.idGuru) {
                guruBelumDiHapus = true
                continue // Lewati, jangan hapus
            }
            guard let index = guru.firstIndex(where: { $0.idGuru == data.idGuru }) else { continue }
            oldData.append(guru[index])
            removeGuru(at: index)
            indexesToDelete.append(index)
            SingletonData.deletedGuru.insert(data.idGuru)
        }

        guruEvent.send(.remove(at: indexesToDelete))
        if !oldData.isEmpty, registerUndo {
            guruUndoManager.registerUndo(withTarget: self) { target in
                target.insertGuruu(oldData)
            }
        }

        if guruBelumDiHapus {
            ReusableFunc.showProgressWindow(3,
                                            pesan: "Guru masih bertugas, tidak dapat menghapus.",
                                            image: ReusableFunc.trashSlashFill!)
        }
    }

    /// Mengurutkan array `guru` berdasarkan kriteria yang diberikan oleh `sortDescriptor`.
    ///
    /// - Parameter sortDescriptor: Objek `NSSortDescriptor` yang menentukan properti dan urutan pengurutan.
    /// - Note: Fungsi ini menggunakan metode pembanding `compare(to:using:)` pada objek guru untuk menentukan urutan.
    func urutkanGuru(_ sortDescriptor: NSSortDescriptor) {
        guru.sort {
            $0.compare(to: $1, using: sortDescriptor) == .orderedAscending
        }
    }

    // MARK: - PENUGASAN GURU

    /// Memperbarui nama guru pada daftarMapel berdasarkan idGuru yang sesuai.
    /// - Parameter guru: Model guru yang berisi idGuru dan namaGuru terbaru.
    ///
    /// Fungsi ini akan mencari guru dengan idGuru yang sama pada setiap guruList di daftarMapel.
    /// Jika ditemukan, namaGuru pada guru tersebut akan diperbarui.
    /// Setelah pembaruan, fungsi akan mengirimkan event `.updateNama` melalui tugasGuruEvent
    /// dengan parentMapel dan index guru yang diperbarui.
    func updateNama(_ guru: GuruModel) {
        for indices in daftarMapel.indices {
            for (i, oldGuru) in daftarMapel[indices].guruList.enumerated() {
                guard oldGuru.idGuru == guru.idGuru else { continue }

                daftarMapel[indices].guruList[i].namaGuru = guru.namaGuru
                tugasGuruEvent.send(.updateNama(parentMapel: daftarMapel[indices], index: i))
            }
        }
    }

    /// Fungsi untuk menjalankan query database ``DatabaseController/getGuru(statusTugas:searchQuery:semester:tahunAjaran:guruVC:)``
    /// dan membuat dictonary untuk ``daftarMapel``. Jika ``guru`` masih kosong dan forceLoad bernilai `false`.
    /// - Parameters:
    ///   - statusTugas: Status penugasan guru pada mapel dan kelas.
    ///   - query: Opsional, untuk memfilter guru dan penugasan dengan query.
    ///   - semester: Opsional, untuk memfilter penugasan sesuai dengan semester.
    ///   - tahunAjaran: Opsional, untuk memfilter penugasan guru sesuai dengan tahun ajaran.
    ///   - forceLoad: Opsi untuk tetap merefresh daftar ``guru`` dan menjalankan penyusunan ulang dictionary meskipun
    ///   ``guru`` sudah diisi sebelumnya. Default = false (tidak menjalankan query database) jika ``guru`` menyimpan
    ///   setidaknya satu daftar guru. Ini biasanya digunakan untuk memuat ulang data dan tampilan
    ///   pada kondisi tertentu yang mengharuskan data diquery ulang dari database.
    func buatKamusMapel(statusTugas: StatusSiswa? = nil, query: String? = nil, semester: String? = nil, tahunAjaran: String? = nil, forceLoad: Bool = false) async {
        guard guru.isEmpty || forceLoad else { return }
        // Refresh data dari database secara asinkron
        let guru = await dbController.getGuru(statusTugas: statusTugas, searchQuery: query, semester: semester, tahunAjaran: tahunAjaran)

        // Bersihkan data yang ada
        daftarMapel.removeAll()

        // Kelompokkan data guru berdasarkan mapel
        var mapelDict: [String: [GuruModel]] = [:]
        for guru in guru {
            mapelDict[guru.mapel ?? "", default: []].append(guru)
        }

        // Reset dan isi ulang daftarMapel berdasarkan mapelDict
        daftarMapel.removeAll()
        for (mapel, guruList) in mapelDict {
            let mapelModel = MapelModel(id: UUID(), namaMapel: mapel, guruList: guruList)
            daftarMapel.append(mapelModel)
        }
    }

    /// Memperbarui data guru dengan perubahan properti dan penugasan ke MapelModel yang sesuai.
    ///
    /// Mendukung perpindahan guru antar MapelModel jika namaMapel berubah.
    /// Penghapusan MapelModel juga dilakukan jika guru terakhir dihapus.
    /// Semua perubahan memicu event UI dan dapat di-undo.
    ///
    /// - Parameter newData: Array tuple berisi GuruModel hasil edit dan data UpdatePenugasanGuru.
    ///
    /// - Note:
    ///   Fungsi ini memecah pembaruan menjadi dua fase:
    ///   1) Penghapusan guru lama dari posisi lama.
    ///   2) Penyisipan guru ke MapelModel baru (jika pindah).
    ///   Undo manager akan mendaftarkan aksi undo dengan data snapshot sebelumnya.
    @discardableResult
    func updateGuru(newData: [GuruWithUpdate]) async -> [GuruWithUpdate] {
        guard let guruSort = sortDescriptor else { return [] }

        // 1) Phase 1: Gather all removals
        var removedGurus: [MapelModel: [Int]] = [:]
        var removedMapelIndices: [Int] = []
        var updatedIndices: [(parentMapel: MapelModel?, index: Int)] = [] // Stores indices of items updated in place
        var oldData: [GuruModel] = []
        var oldPenugasan: [UpdatePenugasanGuru] = []

        var updateStrukturGuru = [(oldGuru: GuruModel, updatedGuru: GuruModel)]()

        func getIdAndMapel(guru: GuruModel) async -> (idMapel: Int64?, idJabatan: Int64?) {
            async let mapelID = IdsCacheManager.shared.mapelID(for: guru.mapel ?? "")
            async let jabatanID = IdsCacheManager.shared.jabatanID(for: guru.struktural ?? "")

            let (idMapel, idJabatan) = await (mapelID, jabatanID)
            return (idMapel: idMapel, idJabatan: idJabatan)
        }

        func updateDatabase(_ guru: GuruModel, idJabatan: Int64, idMapel: Int64) async {
            // Siapkan string tanggal
            let tglMulaiStr = guru.tglMulai
            let tglBerhentiStr = guru.tglSelesai
            let statusStr = guru.statusTugas

            await dbController.updatePenugasanGuru(
                idPenugasan: guru.idTugas,
                idJabatan: idJabatan,
                idMapel: idMapel,
                tanggalMulai: tglMulaiStr,
                tanggalBerhenti: tglBerhentiStr,
                statusTugas: statusStr
            )
        }

        @Sendable
        func updateStruktur(_ oldGuru: GuruModel, updatedGuru: GuruModel) {
            if oldGuru.struktural != updatedGuru.struktural {
                strukturEvent.send(.moved(oldGuru: oldGuru, updatedGuru: updatedGuru))
            } else if oldGuru.namaGuru != updatedGuru.namaGuru {
                strukturEvent.send(.updated([updatedGuru]))
            }
        }

        for guruData in newData {
            let edited = guruData.0
            let penugasan = guruData.1

            // find old parent & index
            guard let oldParent = daftarMapel.first(
                where: { $0.guruList.contains { $0.idTugas == edited.idTugas } }
            ),
                let idx = oldParent.guruList.firstIndex(
                    where: { $0.idTugas == edited.idTugas }
                )
            else {
                if let oldTugas = await dbController.fetchPenugasan(byID: edited.idTugas), oldTugas.status == "Selesai" {
                    let oldGuruModel = edited.copy()
                    oldGuruModel.statusTugas = .selesai
                    oldGuruModel.tglMulai = oldTugas.tanggalMulai
                    oldGuruModel.tglSelesai = oldTugas.tanggalSelesai
                    oldGuruModel.mapel = await dbController.fetchNamaMapelById(oldTugas.idMapel)

                    oldPenugasan.append(UpdatePenugasanGuru(idJabatan: oldTugas.idJabatan, idMapel: oldTugas.idMapel))
                    // Simpan untuk undo
                    oldData.append(oldGuruModel)
                    await updateDatabase(edited, idJabatan: penugasan.idJabatan, idMapel: penugasan.idMapel)
                    if edited.statusTugas == .selesai {
                        await MainActor.run {
                            ReusableFunc.showProgressWindow(2, pesan: "Data diperbarui untuk guru yang selesai bertugas.")
                        }
                    }

                    let oldStruktur = await IdsCacheManager.shared.namaJabatan(for: oldTugas.idJabatan)
                    if oldGuruModel.struktural != oldStruktur {
                        updateStrukturGuru.append((oldGuru: oldGuruModel, updatedGuru: edited))
                    }
                }
                continue
            }

            // Ambil model dan snapshot namaMapel lama
            let guru = oldParent.guruList[idx]
            let guruToStruktur = oldParent.guruList[idx].copy()
            let (oldMapelID, oldJabatanID) = await getIdAndMapel(guru: guru)
            if let oldMapelID, let oldJabatanID {
                oldPenugasan.append(UpdatePenugasanGuru(idJabatan: oldJabatanID, idMapel: oldMapelID))
            }
            await updateDatabase(edited, idJabatan: penugasan.idJabatan, idMapel: penugasan.idMapel)

            // Simpan untuk undo
            oldData.append(guru.copy())

            // newStatus == .berhenti + filter == "Aktif" → remove ——————
            if edited.statusTugas == .selesai, filterTugas == .aktif {
                oldParent.guruList.remove(at: idx)
                removedGurus[oldParent, default: []].append(idx)

                // kalau parent kini kosong, hapus juga
                if oldParent.guruList.isEmpty,
                   let parentIdx = daftarMapel.firstIndex(where: { $0 === oldParent })
                {
                    daftarMapel.remove(at: parentIdx)
                    removedMapelIndices.append(parentIdx)
                }
                continue
            }

            let oldMapel = guru.mapel

            // Update properti guru
            guru.namaGuru = edited.namaGuru
            guru.alamatGuru = edited.alamatGuru
            guru.tahunaktif = edited.tahunaktif
            guru.mapel = edited.mapel
            guru.struktural = edited.struktural
            guru.statusTugas = edited.statusTugas
            guru.kelas = edited.kelas
            guru.tglMulai = edited.tglMulai
            guru.tglSelesai = edited.tglSelesai

            // CASE A: masih di parent yang sama
            if oldMapel == edited.mapel {
                updatedIndices.append((parentMapel: oldParent, index: idx))
            } else {
                // CASE B: pindah parent → gunakan remove+insert composite
                // remove from model
                oldParent.guruList.remove(at: idx)
                removedGurus[oldParent, default: []].append(idx)

                // if parent is now empty, remove parent too
                if oldParent.guruList.isEmpty,
                   let parentIdx = daftarMapel.firstIndex(where: { $0 === oldParent })
                {
                    daftarMapel.remove(at: parentIdx)
                    removedMapelIndices.append(parentIdx)
                }
            }
            updateStrukturGuru.append((oldGuru: guruToStruktur, updatedGuru: edited))
        }

        // 2) Phase 2: Gather all insertions (grouped by namaMapel)

        let filteredGuru: [GuruWithUpdate]
        if let filter = filterTugas {
            // hanya yang status==filterTugas
            filteredGuru = newData.filter {
                $0.guru.statusTugas == filter
            }
        } else {
            // filterTugas == nil → ambil semua, termasuk .aktif, .berhenti, .selesai
            filteredGuru = newData
        }

        // 2) Group by mapel
        let groupedByMapel = Dictionary(
            grouping: filteredGuru,
            by: { $0.guru.mapel ?? "" }
        )

        var insertedMapelIndices: [Int] = []
        var insertedGuruIndices: GuruInsertDict = [:]

        for (mapelName, guruList) in groupedByMapel {
            // find or create parent
            let parent: MapelModel
            var parentIdx: Int?

            if let existing = daftarMapel.first(where: { $0.namaMapel == mapelName }) {
                parent = existing
            } else {
                parent = .init(id: UUID(), namaMapel: mapelName, guruList: [])
                let mapelSort = NSSortDescriptor(key: "Mapel", ascending: guruSort.ascending)
                parentIdx = daftarMapel.insertionIndex(for: parent, using: mapelSort)
                daftarMapel.insert(parent, at: parentIdx!)
                insertedMapelIndices.append(parentIdx!)
            }

            // insert each guru if it isn’t already present
            for guruData in guruList {
                let edited = guruData.guru
                if parent.guruList.contains(where: { $0.idTugas == edited.idTugas }) {
                    continue
                }

                // create a fresh GuruModel so outlineView sees a new item
                let newGuru = GuruModel(
                    idGuru: edited.idGuru,
                    idTugas: edited.idTugas,
                    nama: edited.namaGuru,
                    alamat: edited.alamatGuru,
                    tahunaktif: edited.tahunaktif,
                    mapel: edited.mapel,
                    struktural: edited.struktural,
                    statusTugas: edited.statusTugas,
                    kelas: edited.kelas,
                    tglMulai: edited.tglMulai,
                    tglSelesai: edited.tglSelesai
                )

                let insertIdx = parent.guruList.insertionIndex(
                    for: newGuru,
                    using: guruSort
                )
                parent.guruList.insert(newGuru, at: insertIdx)
                insertedGuruIndices[parent, default: []].append((guru: newGuru, index: insertIdx))
            }
        }

        // 3) Fire UI event for update
        tugasGuruEvent.send(.updated(items: updatedIndices))

        // 3) Fire UI events in two clear batches
        tugasGuruEvent.send(.guruAndMapelRemoved(
            gurus: removedGurus,
            mapelIndices: removedMapelIndices,
            fallbackItem: nil
        ))
        tugasGuruEvent.send(.guruAndMapelInserted(
            mapelIndices: insertedMapelIndices,
            guruu: insertedGuruIndices
        ))

        // Zip lagi untuk rollback
        let dataToRestore: [GuruWithUpdate] = zip(oldData, oldPenugasan)
            .map { guru, penugasan in (guru: guru, update: penugasan) }

        // Kirim event ke struktur guru menggunakan thread lain
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now()) { [updateStrukturGuru] in
            for (old, new) in updateStrukturGuru {
                updateStruktur(old, updatedGuru: new)
            }
        }

        // Register undo di viewController
        return dataToRestore
    }

//    /// Memperbarui data penugasan guru di database dan memperbarui model di memori.
//    ///
//    /// Untuk setiap id guru yang diberikan, fungsi ini:
//    /// - Mengambil data guru lama.
//    /// - Membuat GuruModel baru dengan mapel, jabatan, status, dan tanggal yang diperbarui.
//    /// - Memanggil query `updatePenugasanGuru` ke database.
//    /// - Memperbarui daftarMapel dengan GuruModel yang baru.
//    ///
//    /// - Parameters:
//    ///   - ids: Array ID tugas guru yang akan diperbarui.
//    ///   - namaMapel: Nama mata pelajaran baru.
//    ///   - jabatanID: ID jabatan guru yang baru.
//    ///   - statusTugas: Status aktif atau selesai.
//    ///   - tanggalMulai: Tanggal mulai penugasan baru.
//    ///   - tanggalSelesai: Tanggal selesai penugasan (opsional).
//    ///
//    /// - Note:
//    ///   Data guru lama disimpan untuk kebutuhan undo di luar fungsi ini jika diperlukan.
//    func updatePenugasanGuru(ids: [Int64], namaMapel: String, jabatanID: Int, statusTugas: Bool, tanggalMulai: Date, tanggalSelesai: Date?) async {
//        let status: StatusSiswa = statusTugas ? .aktif : .selesai
//        var hasil: [(GuruModel, UpdatePenugasanGuru)] = []
//        var oldData: [GuruModel] = []
//
//        for id in ids {
//            guard let lama = daftarMapel.flatMap({ $0.guruList }).first(where: { $0.idTugas == id })
//            else { continue }
//
//            oldData.append(lama)
//
//            let tglMulai = ReusableFunc.buatFormatTanggal(tanggalMulai)!
//            let tglBerhenti = tanggalSelesai != nil ? ReusableFunc.buatFormatTanggal(tanggalSelesai!) : nil
//            let idMapelBaru = await IdsCacheManager.shared.mapelID(for: namaMapel)
//
//            let baru = GuruModel(
//                idGuru: lama.idGuru,
//                idTugas: lama.idTugas,
//                nama: lama.namaGuru,
//                alamat: lama.alamatGuru,
//                tahunaktif: lama.tahunaktif,
//                mapel: namaMapel,
//                struktural: lama.struktural,
//                statusTugas: status,
//                kelas: lama.kelas,
//                tglMulai: lama.tglMulai,
//                tglSelesai: tglBerhenti
//            )
//
//            let update = UpdatePenugasanGuru(
//                idJabatan: Int64(jabatanID),
//                idMapel: idMapelBaru!
//            )
//
//            hasil.append((guru: baru, update: update))
//
//            await dbController.updatePenugasanGuru(
//                idPenugasan: lama.idTugas,
//                idJabatan: Int64(jabatanID),
//                idMapel: idMapelBaru,
//                tanggalMulai: tglMulai,
//                tanggalBerhenti: tglBerhenti,
//                statusTugas: status
//            )
//        }
//
//        // Simpan ke model utama
//        for item in hasil {
//            // 1) Cari MapelModel yang punya guru ini
//            if let parentIndex = daftarMapel.firstIndex(where: {
//                $0.guruList.contains(where: { $0.idTugas == item.0.idTugas })
//            }) {
//                // 2) Cari index guru di dalam parent mapel
//                if let guruIndex = daftarMapel[parentIndex].guruList.firstIndex(where: {
//                    $0.idTugas == item.0.idTugas
//                }) {
//                    // 3) Update guru di dalam parent mapel
//                    daftarMapel[parentIndex].guruList[guruIndex] = item.0
//                }
//            }
//        }
//    }

    /// Melakukan operasi untuk tindakan penghapusan data guru dan mapel.
    ///
    /// Fungsi ini menghapus data di `NSOutlineView` dan model data
    /// terkait, sambil mempertahankan urutan pengurutan yang benar. Ini juga mengatur ulang status undo/redo dan menghapus ID guru dari daftar yang dihapus secara permanen.
    ///
    /// - Parameter data: Sebuah `Dictionary` yang berisi data `GuruModel`
    ///                                 yang dihapus, dikelompokkan berdasarkan nama Mapel-nya.
    ///                                 Kunci dictionary adalah `namaMapel` (String), dan nilai
    ///                                 adalah array `GuruModel` yang dihapus dari Mapel tersebut.
    func hapusDaftarMapel(data: [String: [GuruModel]]) {
        var fallbackItem: Any?
        var guruRemovalIndices: [MapelModel: [Int]] = [:]
        var mapelsToDelete: Set<MapelModel> = [] // Gunakan Set agar tidak duplikat
        var tugasBelumDihapus = false
        var oldData = [String: [GuruModel]]()

        // --- TAHAP 1: Hapus semua GURU dan CATAT mapel yang menjadi kosong ---
        for (namaMapel, guruList) in data {
            if let parentItem = daftarMapel.first(where: { $0.namaMapel == namaMapel }) {
                for guru in guruList {
                    if dbController.isTugasMasihDipakai(idTugas: guru.idTugas) {
                        tugasBelumDihapus = true
                        continue
                    }
                    if let guruIndex = parentItem.guruList.firstIndex(where: { $0.idTugas == guru.idTugas }),
                       let mapelIndex = daftarMapel.firstIndex(where: { $0.id == parentItem.id })
                    {
                        // Cari guru selanjutnya di mapel yang sama
                        if guruIndex + 1 < daftarMapel[mapelIndex].guruList.count {
                            fallbackItem = daftarMapel[mapelIndex].guruList[guruIndex + 1]

                            // Fallback: guru pertama di mapel selanjutnya
                        } else if mapelIndex + 1 < daftarMapel.count,
                                  let nextGuru = daftarMapel[mapelIndex + 1].guruList.first
                        {
                            fallbackItem = nextGuru
                        }

                        // Hapus guru dari listnya
                        parentItem.guruList.remove(at: guruIndex)

                        // Simpan ID ke singletondata untuk penghapusan di database.
                        SingletonData.deletedTugasGuru.insert(guru.idTugas)

                        guruRemovalIndices[parentItem, default: []].append(guruIndex)

                        oldData[parentItem.namaMapel, default: []].append(guru)

                        // JANGAN HAPUS MAPEL DI SINI. Cukup tandai saja.
                        if parentItem.guruList.isEmpty {
                            mapelsToDelete.insert(parentItem)
                        }
                    }
                }
            }
        }

        // --- TAHAP 2: Hapus semua MAPEL yang kosong dari data source ---
        var mapelRemovalIndices: [Int] = []

        // Urutkan mapel yang akan dihapus berdasarkan indeksnya (dari terbesar ke terkecil)
        let sortedMapelsToDelete = mapelsToDelete.compactMap { mapel -> (MapelModel, Int)? in
            if let index = daftarMapel.firstIndex(where: { $0.id == mapel.id }) {
                return (mapel, index)
            }
            return nil
        }.sorted { $0.1 > $1.1 }

        for (mapel, index) in sortedMapelsToDelete {
            // Atur fallback jika mapel dihapus
            insertFallbackMapel(idMapel: mapel.id)
            // Hapus dari data source utama
            daftarMapel.remove(at: index)
            mapelRemovalIndices.append(index)
        }

        func insertFallbackMapel(idMapel: UUID) {
            if let index = daftarMapel.firstIndex(where: { $0.id == idMapel }),
               index + 1 < daftarMapel.count,
               let nextGuru = daftarMapel[index + 1].guruList.first
            {
                fallbackItem = nextGuru
            }
        }
        // Kirim event ke view dengan data yang sudah benar
        tugasGuruEvent.send(.guruAndMapelRemoved(gurus: guruRemovalIndices, mapelIndices: mapelRemovalIndices, fallbackItem: fallbackItem))

        if !oldData.isEmpty {
            // --- Fase Daftar Undo ---
            myUndoManager.registerUndo(withTarget: self) { model in
                model.undoHapus(groupedDeletedData: oldData)
            }
            myUndoManager.setActionName("Undo Hapus Guru/Mapel")
        }

        if tugasBelumDihapus {
            ReusableFunc.showProgressWindow(3,
                                            pesan: "Tugas mapel digunakan nilai kelas, tidak dapat dihapus.",
                                            image: ReusableFunc.trashSlashFill!)
        }

        // Publish data ke event struktur.
        let hapusStrukturGuru = data.flatMap { (_, value: [GuruModel]) in
            value
        }
        strukturEvent.send(.deleted(hapusStrukturGuru))
    }

    /// Memasukkan data guru yang terkelompok berdasarkan nama mata pelajaran ke dalam daftarMapel.
    /// Jika MapelModel belum ada, maka akan dibuat MapelModel baru dan disisipkan pada posisi yang sesuai.
    /// Jika sudah ada, data guru akan disisipkan ke guruList pada MapelModel tersebut.
    ///
    /// - Parameters:
    ///   - groupedData: Dictionary dengan key berupa namaMapel (nama mata pelajaran) dan value berupa array GuruModel.
    ///   - sortDescriptor: Penentu urutan penyisipan guru dalam guruList dan daftarMapel.
    ///
    /// - Returns: `insertedMapelIndices` merupakan Indeks MapelModel yang berhasil disisipkan ke daftarMapel dan `insertedGuruIndices` merupakan Dictionary berisi MapelModel sebagai key dan array indeks guru yang disisipkan sebagai value.
    ///
    /// - Note:
    ///   Fungsi ini memanfaatkan UndoManager untuk membatalkan perubahan secara serentak,
    ///   memastikan tidak terjadi duplikasi guru di guruList, dan menggunakan safeInsertionIndex
    ///   agar posisi penyisipan sesuai urutan sortDescriptor.
    @discardableResult
    func insertGroupedDeletedData(_ groupedData: [String: [GuruModel]], sortDescriptor: NSSortDescriptor, registerUndo: Bool = true) -> (insertedMapelIndices: [Int], insertedGuruIndices: GuruInsertDict) {
        var insertedMapelIndices: [Int] = []
        var insertedGuruIndices: GuruInsertDict = [:]

        for (namaMapel, guruList) in groupedData {
            let targetMapel: MapelModel
            var mapelIndex: Int?

            if let existing = daftarMapel.first(where: { $0.namaMapel == namaMapel }) {
                targetMapel = existing
            } else {
                targetMapel = MapelModel(id: UUID(), namaMapel: namaMapel, guruList: [])
                let sortMapel = NSSortDescriptor(key: "Mapel", ascending: sortDescriptor.ascending)
                mapelIndex = daftarMapel.insertionIndex(for: targetMapel, using: sortMapel)
                daftarMapel.insert(targetMapel, at: mapelIndex!)
                insertedMapelIndices.append(mapelIndex!)
            }

            for guru in guruList {
                if !targetMapel.guruList.contains(where: { $0.idTugas == guru.idTugas }) {
                    let insertionIndex = safeInsertionIndex(for: guru, in: targetMapel, using: sortDescriptor)
                    targetMapel.guruList.insert(guru, at: insertionIndex)
                    if let indexUndo = SingletonData.deletedTugasGuru.firstIndex(where: { $0 == guru.idTugas }) {
                        SingletonData.deletedTugasGuru.remove(at: indexUndo)
                    }
                    insertedGuruIndices[targetMapel, default: []].append((guru: guru, index: insertionIndex))
                    /// Publish event combine untuk pembaruan struktur
                    strukturEvent.send(.inserted(guru))
                }
            }
        }
        if registerUndo {
            // ✅ Daftarkan UNDO → panggil balik hapusSerentak
            myUndoManager.registerUndo(withTarget: self) { targetSelf in
                targetSelf.hapusDaftarMapel(data: groupedData)
            }
            myUndoManager.setActionName("Undo Insert Guru/Mapel")
        }
        return (insertedMapelIndices, insertedGuruIndices)
    }

    /// Melakukan operasi 'undo' (pembatalan) untuk tindakan penghapusan data guru dan mapel.
    /// Fungsi ini mengembalikan item-item yang sebelumnya dihapus ke `NSOutlineView` dan model data
    /// terkait, sambil mempertahankan urutan pengurutan yang benar. Ini juga mengatur ulang status undo/redo
    /// dan menghapus ID guru dari daftar yang dihapus secara permanen.
    ///
    /// - Parameter groupedDeletedData: Sebuah `Dictionary` yang berisi data `GuruModel`
    ///                                 yang dihapus, dikelompokkan berdasarkan nama Mapel-nya.
    ///                                 Kunci dictionary adalah `namaMapel` (String), dan nilai
    ///                                 adalah array `GuruModel` yang dihapus dari Mapel tersebut.
    func undoHapus(groupedDeletedData: [String: [GuruModel]], registerUndo: Bool = true) {
        guard let sortDescriptor else { return }
        let (insertedMapelIndices, insertedGuruIndices) = insertGroupedDeletedData(groupedDeletedData, sortDescriptor: sortDescriptor, registerUndo: registerUndo)

        tugasGuruEvent.send(.guruAndMapelInserted(mapelIndices: insertedMapelIndices, guruu: insertedGuruIndices))
    }

    /// Fungsi helper untuk menentukan indeks insersi yang aman
    /// Menentukan indeks penyisipan yang aman untuk objek `GuruModel` baru ke dalam daftar `guruList`
    /// dari sebuah `MapelModel`, berdasarkan `NSSortDescriptor` yang diberikan.
    /// Fungsi ini menciptakan komparator dinamis berdasarkan kunci pengurutan dan arahnya,
    /// kemudian mencari posisi yang tepat untuk menyisipkan guru baru sambil menjaga urutan.
    ///
    /// - Parameters:
    ///   - guru: Objek `GuruModel` yang akan disisipkan.
    ///   - mapel: Objek `MapelModel` di mana `guru` akan disisipkan ke dalam `guruList` miliknya.
    ///   - sortDescriptor: `NSSortDescriptor` yang mendefinisikan kriteria pengurutan
    ///                     (kunci kolom dan arah ascending/descending).
    /// - Returns: `Int` yang merupakan indeks penyisipan yang direkomendasikan. Jika `guru`
    ///            harus ditempatkan di akhir daftar, jumlah elemen dalam `guruList` akan dikembalikan.
    func safeInsertionIndex(for guru: GuruModel, in mapel: MapelModel, using sortDescriptor: NSSortDescriptor) -> Int {
        // Mendeklarasikan closure `comparator` yang akan digunakan untuk membandingkan dua objek `GuruModel`.
        // Closure ini akan ditentukan berdasarkan `sortDescriptor.key`.
        let comparator: (GuruModel, GuruModel) -> Bool

            // Menggunakan `switch` untuk menentukan logika perbandingan berdasarkan `sortDescriptor.key`.
            = switch sortDescriptor.key
        {
        case "NamaGuru":
            // Jika kunci adalah "NamaGuru", bandingkan berdasarkan properti `namaGuru`.
            // Jika ascending, `guru1.namaGuru < guru2.namaGuru`. Jika descending, `guru1.namaGuru > guru2.namaGuru`.
            { sortDescriptor.ascending ? $0.namaGuru < $1.namaGuru : $0.namaGuru > $1.namaGuru }
        case "AlamatGuru":
            // Jika kunci adalah "AlamatGuru", bandingkan berdasarkan properti `alamatGuru`.
            { sortDescriptor.ascending ? $0.alamatGuru ?? "" < $1.alamatGuru ?? "" : $0.alamatGuru ?? "" > $1.alamatGuru ?? "" }
        case "TahunAktif":
            // Jika kunci adalah "TahunAktif", bandingkan berdasarkan properti `tahunaktif`.
            { sortDescriptor.ascending ? $0.tahunaktif ?? "" < $1.tahunaktif ?? "" : $0.tahunaktif ?? "" > $1.tahunaktif ?? "" }
        case "Mapel":
            // Jika kunci adalah "Mapel", bandingkan berdasarkan properti `mapel`.
            { sortDescriptor.ascending ? $0.mapel ?? "" < $1.mapel ?? "" : $0.mapel ?? "" > $1.mapel ?? "" }
        case "Struktural":
            // Jika kunci adalah "Struktural", bandingkan berdasarkan properti `struktural`.
            { sortDescriptor.ascending ? $0.struktural ?? "" < $1.struktural ?? "" : $0.struktural ?? "" > $1.struktural ?? "" }
        case "Kelas":
            { sortDescriptor.ascending ? $0.kelas ?? "" < $1.kelas ?? "" : $0.kelas ?? "" > $1.kelas ?? ""
            }
        case "Tgl. Mulai":
            { sortDescriptor.ascending ? $0.tglMulai ?? "" < $1.tglMulai ?? "" : $0.tglMulai ?? "" > $1.tglMulai ?? "" }
        case "TglSelesai":
            { sortDescriptor.ascending ? $0.tglSelesai ?? "" < $1.tglSelesai ?? "" : $0.tglSelesai ?? "" > $1.tglSelesai ?? "" }
        default:
            // Jika kunci tidak cocok dengan kasus di atas, gunakan komparator default yang selalu mengembalikan `true`.
            // Ini berarti elemen baru akan disisipkan di awal jika tidak ada kriteria pengurutan spesifik.
            { _, _ in true }
        }

        // Mencari indeks pertama dalam `mapel.guruList` di mana `comparator` mengembalikan `true`.
        // Ini adalah posisi di mana `guru` yang baru harus disisipkan agar urutan tetap terjaga.
        // Jika tidak ada elemen yang memenuhi kondisi (yaitu, `guru` harus ditempatkan di akhir),
        // maka `firstIndex(where:)` akan mengembalikan `nil`, dan operator `??` akan
        // mengembalikan `mapel.guruList.count`, yang merupakan indeks di luar elemen terakhir
        // (posisi yang tepat untuk penambahan di akhir).
        return mapel.guruList.firstIndex(where: { comparator(guru, $0) }) ?? mapel.guruList.count
    }

    /// Mengurutkan data model (baik `MapelModel` maupun `GuruModel`) berdasarkan
    /// `NSSortDescriptor` yang diberikan. Fungsi ini akan mengurutkan daftar utama
    /// `daftarMapel` dan kemudian mengurutkan daftar `guruList` di dalam setiap `MapelModel`
    /// sesuai dengan kunci pengurutan yang ditentukan.
    ///
    /// - Parameter sortDescriptor: `NSSortDescriptor` yang berisi kunci kolom
    ///                             dan arah pengurutan (ascending/descending).
    func sortModel(by sortDescriptor: NSSortDescriptor) {
        let indicator = sortDescriptor // Menyimpan sort descriptor untuk akses mudah.

        // --- Pengurutan MapelModel (Parent Items) ---
        // Mengurutkan `daftarMapel` (daftar utama Mapel) berdasarkan kunci pengurutan.
        daftarMapel.sort { mapel1, mapel2 -> Bool in
            switch indicator.key {
            // Saat ini, pengurutan `MapelModel` hanya didukung berdasarkan "NamaGuru"
            // yang secara implisit berarti "NamaMapel" karena ini adalah kolom di level Mapel.
            case "NamaGuru": // Menggunakan "NamaGuru" sebagai kunci untuk MapelModel (yang merujuk ke NamaMapel)
                // Mengembalikan `true` jika `mapel1` harus datang sebelum `mapel2`
                // sesuai dengan arah ascending/descending.
                return indicator.ascending ? mapel1.namaMapel < mapel2.namaMapel : mapel1.namaMapel > mapel2.namaMapel
            default:
                // Jika kunci pengurutan tidak cocok, tidak ada perubahan urutan untuk Mapel.
                return true // Atau false, tergantung pada perilaku default yang diinginkan jika kunci tidak cocok.
            }
        }

        // --- Pengurutan GuruModel (Child Items) ---
        // Iterasi melalui setiap `MapelModel` dalam `daftarMapel` untuk mengurutkan `guruList` (anak-anaknya).
        // Urutkan Guru di setiap Mapel
        for mapel in daftarMapel {
            mapel.guruList.sort {
                $0.compare(to: $1, using: sortDescriptor) == .orderedAscending
            }
        }
        self.sortDescriptor = sortDescriptor
    }

    /// Fungsi untuk membersihkan ``daftarMapel``.
    func removeAllMapelDict() {
        daftarMapel.removeAll()
    }
}
