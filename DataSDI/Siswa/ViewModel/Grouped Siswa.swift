//
//  Grouped Siswa.swift
//  Data SDI
//
//  Created by MacBook on 20/09/25.
//

import Foundation

/// `GroupedSiswaData`
///
/// Mengimplementasikan protokol ``SiswaDataSource`` untuk menyimpan dan mengelola data siswa
/// dalam bentuk **kelompok (grouped)**, yaitu array 2 dimensi (`[[ModelSiswa]]`).
/// Setiap grup dapat merepresentasikan kategori tertentu (misalnya kelas, tingkat, atau status).
///
/// `GroupedSiswaData` menyediakan fungsi untuk:
/// - Mengambil data dalam bentuk datar (flat) atau terkelompok.
/// - Mencari, memfilter, menambah, menghapus, dan memindahkan siswa.
/// - Mengelola pembaruan data di memori dan sinkronisasi dengan database.
/// - Mendukung operasi undo/redo.
/// - Menghitung indeks absolut siswa dalam tampilan tabel yang memiliki baris grup.
///
/// Struktur data:
/// - `groups`: Array dari array ``ModelSiswa``, di mana setiap elemen mewakili satu grup.
/// - Baris grup (header) dihitung dalam `numberOfRows` sebagai tambahan 1 baris per grup.

class GroupedSiswaData: SiswaDataSource {
    /// Menyimpan data siswa dari database dalam bentuk array 2 dimensi, setiap sub-array adalah satu grup.
    var groups: [[ModelSiswa]] = Array(repeating: [], count: 8)

    /// Mengembalikan jumlah total baris, termasuk baris header grup.
    var numberOfRows: Int { groups.reduce(0) { $0 + $1.count + 1 } }

    /// Array yang menyimpan index baris awal dari setiap section dalam tabel.
    ///
    /// Setiap elemen dalam array ini merepresentasikan index baris pertama (header grup)
    /// dari section yang bersesuaian. Index array adalah section index, dan nilainya
    /// adalah row index dari baris pertama section tersebut.
    ///
    /// - Note: Array ini di-generate oleh ``buildIndexMap()`` dan harus diperbarui
    ///         setiap kali struktur data `groups` berubah.
    ///
    /// ## Example
    /// ```swift
    /// // Jika tabel memiliki struktur:
    /// // Section 0: 3 baris (row 0-2)
    /// // Section 1: 2 baris (row 3-4)
    /// // Section 2: 4 baris (row 5-8)
    ///
    /// sectionStartRows = [0, 3, 5]
    /// // Section 0 dimulai di row 0
    /// // Section 1 dimulai di row 3
    /// // Section 2 dimulai di row 5
    /// ```
    ///
    /// - Important: Hanya dapat dimodifikasi dari dalam class (private set),
    ///              untuk menjaga konsistensi dengan `rowToSectionMap`.
    private(set) var sectionStartRows: [Int] = []

    /// Array yang memetakan setiap baris tabel ke index section yang memilikinya.
    ///
    /// Setiap elemen dalam array ini merepresentasikan section index dari baris yang bersesuaian.
    /// Index array adalah row index, dan nilainya adalah section index tempat baris tersebut berada.
    /// Ini memungkinkan pencarian O(1) untuk mengetahui section mana yang memiliki baris tertentu.
    ///
    /// - Note: Array ini di-generate oleh ``buildIndexMap()`` dan harus diperbarui
    ///         setiap kali struktur data `groups` berubah.
    ///
    /// ## Example
    /// ```swift
    /// // Jika tabel memiliki struktur:
    /// // Section 0: 3 baris (header + 2 data)
    /// // Section 1: 2 baris (header + 1 data)
    /// // Section 2: 4 baris (header + 3 data)
    ///
    /// rowToSectionMap = [0, 0, 0, 1, 1, 2, 2, 2, 2]
    /// // Row 0, 1, 2 → Section 0
    /// // Row 3, 4    → Section 1
    /// // Row 5-8     → Section 2
    ///
    /// // Penggunaan:
    /// let row = 5
    /// let section = rowToSectionMap[row]  // 2 (Section 2)
    /// ```
    ///
    /// - Important: Hanya dapat dimodifikasi dari dalam class (private set),
    ///              untuk menjaga konsistensi dengan `sectionStartRows`.
    ///
    /// - Complexity: Lookup adalah O(1), build adalah O(n) dimana n adalah total rows.
    private(set) var rowToSectionMap: [Int] = []

    /// Mengambil seluruh data siswa dalam bentuk array datar (flat).
    ///
    /// - Returns: Array `ModelSiswa` hasil penggabungan semua ``groups``.
    func currentFlatData() -> [ModelSiswa] {
        groups.flatMap { $0 }
    }

    /// Mencari siswa berdasarkan kata kunci dan mengelompokkan hasilnya.
    ///
    /// - Parameter filter: Kata kunci pencarian.
    /// - Note: Proses dilakukan secara asinkron ``DatabaseController/searchSiswa(query:)``
    /// dan hasilnya dikelompokkan ulang dalam array dua dimensi (2D) ``groups``.
    func cariSiswa(_ filter: String) async {
        let filteredSiswaData = await DatabaseController.shared.searchSiswa(query: filter)
        await getGroupSiswa(flatData: filteredSiswaData)
    }

    /// Memfilter siswa yang berstatus berhenti.
    ///
    /// - Parameters:
    ///   - isBerhentiHidden: Jika `true`, hanya mengembalikan indeks siswa berhenti dari data saat ini.
    ///     Jika `false`, data akan diambil ulang, diurutkan, dan dikelompokkan ulang.
    ///   - comparator: Closure pembanding untuk pengurutan.
    /// - Returns: Array indeks absolut siswa yang berstatus berhenti.
    func filterSiswaBerhenti(
        _ isBerhentiHidden: Bool,
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool
    ) async -> [Int] {
        if isBerhentiHidden {
            // Gunakan data grouped saat ini tanpa refetch
            return calculateAbsoluteRowIndices { $0.status == .berhenti }
        } else {
            // Refetch, sort, dan regroup untuk data terbaru
            await fetchSiswa()
            sort(by: comparator)

            return calculateAbsoluteRowIndices { $0.status == .berhenti }
        }
    }

    /// Memfilter siswa yang berstatus lulus.
    ///
    /// - Parameters:
    ///   - tampilkanLulus: Jika `false`, hanya mengembalikan indeks siswa lulus dari data saat ini.
    ///     Jika `true`, data akan diambil ulang, diurutkan, dan dikelompokkan ulang.
    ///   - comparator: Closure pembanding untuk pengurutan.
    /// - Returns: Array indeks absolut siswa yang berstatus lulus.
    func filterSiswaLulus(
        _ tampilkanLulus: Bool,
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool
    ) async -> [Int] {
        if !tampilkanLulus {
            // Gunakan data grouped saat ini tanpa refetch
            return calculateAbsoluteRowIndices { $0.status == .lulus }
        } else {
            // Refetch, sort, dan regroup untuk data terbaru
            await fetchSiswa()
            sort(by: comparator)

            return calculateAbsoluteRowIndices { $0.status == .lulus }
        }
    }

    /// Mengembalikan data siswa ke nilai sebelumnya (undo).
    ///
    /// Fungsi ini menjalankan ``updateModelAndDatabase(id:columnIdentifier:rowIndex:newValue:)``
    /// untuk memperbarui model dan database.
    ///
    /// - Parameter originalModel: Data asli sebelum perubahan.
    func undoAction(originalModel: DataAsli) {
        let (id, column, oldValue, _) = DataAsli.extract(originalModel: originalModel)

        guard let rowIndexToUpdate = indexSiswa(for: id) else {
            updateModelAndDatabase(id: id, columnIdentifier: column, rowIndex: nil, newValue: oldValue)
            UndoActionNotification.sendNotif(id, columnIdentifier: column)
            return
        }
        updateModelAndDatabase(id: id, columnIdentifier: column, rowIndex: rowIndexToUpdate, newValue: oldValue)
    }

    /// Mengulangi kembali perubahan data siswa (redo).
    ///
    /// Fungsi ini menjalankan ``updateModelAndDatabase(id:columnIdentifier:rowIndex:newValue:)``
    /// untuk memperbarui model dan database.
    ///
    /// - Parameter originalModel: Data asli setelah perubahan.
    func redoAction(originalModel: DataAsli) {
        let (id, column, _, newValue) = DataAsli.extract(originalModel: originalModel)

        guard let rowIndexToUpdate = indexSiswa(for: id) else {
            updateModelAndDatabase(id: id, columnIdentifier: column, rowIndex: nil, newValue: newValue)
            UndoActionNotification.sendNotif(id, columnIdentifier: column)
            return
        }
        updateModelAndDatabase(id: id, columnIdentifier: column, rowIndex: rowIndexToUpdate, newValue: newValue)
    }

    /// Mengambil ulang data siswa dari database dan mengelompokkannya
    /// dalam array dua dimensi (2D) ``groups``.
    func fetchSiswa() async {
        // Fetch dan group (wrap async di ViewModel)
        let filteredSiswaData = await DatabaseController.shared.getSiswa()
        await getGroupSiswa(flatData: filteredSiswaData)
    }

    /// Mengambil objek siswa berdasarkan indeks absolut baris.
    ///
    /// - Parameter row: Indeks absolut baris siswa.
    /// - Returns: Objek ``ModelSiswa`` jika ditemukan, atau `nil` jika baris adalah header grup atau indeks tidak valid.
    func siswa(at row: Int) -> ModelSiswa? {
        let info = getRowInfoFor(row: row)
        guard !info.isGroupRow, info.sectionIndex < groups.count,
              info.rowIndexInSection < groups[info.sectionIndex].count else { return nil }
        return groups[info.sectionIndex][info.rowIndexInSection]
    }

    /// Mengambil objek siswa berdasarkan ID unik.
    ///
    /// - Parameter id: ID siswa.
    /// - Returns: Objek ``ModelSiswa`` jika ditemukan, atau `nil` jika tidak ada yang cocok.
    func siswa(for id: Int64) -> ModelSiswa? {
        for group in groups {
            if let siswa = group.first(where: { $0.id == id }) { return siswa }
        }
        return nil
    }

    /// Mengambil indeks absolut siswa berdasarkan ID unik.
    ///
    /// Menjalankan func ``findSiswaInGroups(id:)`` untuk mendapatkan
    /// indeks grup dan indeks siswa di dalam grup dan menjalankan func
    /// ``absoluteIndex(for:rowIndex:)`` untuk nilai `return`.
    ///
    /// - Parameter id: ID siswa.
    /// - Returns: Indeks absolut siswa jika ditemukan, atau `nil` jika tidak ada yang cocok.
    @inlinable
    func indexSiswa(for id: Int64) -> Int? {
        guard let (groupIndex, rowIndex) = findSiswaInGroups(id: id) else { return nil }
        return absoluteIndex(for: groupIndex, rowIndex: rowIndex)
    }

    /// Memperbarui data siswa.
    ///
    /// Menjalankan func ``indexSiswa(for:)`` untuk mendapatkan
    /// absolut indeks yang akan digunakan sebagai nilai `return`
    /// dan menjalankan func ``getRowInfoFor(row:)``
    /// untuk mendapatkan indeks ``ModelSiswa`` yang sesuai
    /// sebelum diperbarui.
    ///
    /// - Parameter siswa: Objek ``ModelSiswa`` yang akan diperbarui.
    /// - Returns: Indeks absolut siswa yang diperbarui, atau `nil` jika siswa tidak ditemukan.
    @inlinable
    func update(siswa: ModelSiswa) -> Int? {
        guard let index = indexSiswa(for: siswa.id) else { return nil }

        let info = getRowInfoFor(row: index)
        groups[info.sectionIndex][info.rowIndexInSection] = siswa

        return index
    }

    /// Menghapus siswa berdasarkan indeks absolut baris.
    ///
    /// Menjalankan func ``getRowInfoFor(row:)`` untuk mendapatkan
    /// informasi indeks yang akan dihapus dari indeks absolut parameter `index`.
    ///
    /// - Parameter index: Indeks absolut baris siswa yang akan dihapus.
    @inlinable
    func remove(at index: Int) {
        let info = getRowInfoFor(row: index)
        guard !info.isGroupRow else { return }
        groups[info.sectionIndex].remove(at: info.rowIndexInSection)
    }

    /// Menghapus siswa berdasarkan objek siswa.
    ///
    /// Menjalankan func ``indexSiswa(for:)`` untuk mendapatkan indeks
    /// ``ModelSiswa`` yang benar dari parameter `siswa`.
    ///
    /// - Parameter siswa: Objek ``ModelSiswa`` yang akan dihapus.
    /// - Returns: Tuple berisi indeks absolut siswa yang dihapus dan ``UpdateData`` untuk pembaruan UI, atau `nil` jika siswa tidak ditemukan.
    @inlinable
    func removeSiswa(_ siswa: ModelSiswa) -> (index: Int, update: UpdateData)? {
        guard let index = indexSiswa(for: siswa.id) else { return nil }
        remove(at: index)
        return (index, UpdateData.remove(index: index))
    }

    /**
     Memasukkan siswa ke dalam grup tertentu pada indeks tertentu.

     Fungsi ini menambahkan siswa ke dalam array ``groups`` pada indeks grup dan indeks siswa yang ditentukan.
     Jika grup yang ditentukan belum ada, grup baru akan dibuat.
     Fungsi ini juga memastikan bahwa indeks siswa yang diberikan valid dan siswa tidak duplikat dalam grup.

     - Parameter siswa: Objek ``ModelSiswa`` yang akan dimasukkan.
     - Parameter comparator: Comparator perbandingan objek untuk urutan *insert*.
     - Returns: Index di yang berfungsi di tableView yang dihasilkan dari ``absoluteIndex(for:rowIndex:)``.
     */
    @discardableResult
    func insert(_ siswa: ModelSiswa, comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) -> Int {
        // Tentukan group target berdasarkan siswa (e.g., berdasarkan kelas)
        let groupIndex = getGroupIndexForStudent(siswa) ?? 7

        let index = groups[groupIndex].insertionIndex(for: siswa, using: comparator)

        // Pastikan index tidak melebihi jumlah siswa
        if index <= groups[groupIndex].count {
            if !groups[groupIndex].contains(where: { $0.id == siswa.id }) {
                groups[groupIndex].insert(siswa, at: index)
            }
        }
        return absoluteIndex(for: groupIndex, rowIndex: index)
    }

    /// Memindahkan siswa ke posisi yang benar berdasarkan comparator.
    ///
    /// Menjalankan func ``indexSiswa(for:)`` untuk mendapatkan indeks
    /// ``ModelSiswa`` yang benar sesuai dengan parameter `siswa`.
    ///
    /// - Parameters:
    ///   - siswa: Objek ``ModelSiswa`` yang akan dipindahkan.
    ///   - comparator: Closure pembanding untuk menentukan posisi.
    ///   - columnIndex: Indeks kolom opsional untuk pembaruan UI.
    /// - Returns: ``UpdateData`` untuk pembaruan UI, atau `nil` jika siswa tidak ditemukan.
    func relocateSiswa(_ siswa: ModelSiswa,
                       comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool,
                       columnIndex: Int?) -> UpdateData?
    {
        guard let (groupIndex, rowIndex) = findSiswaInGroups(id: siswa.id) else {
            let newIndex = insert(siswa, comparator: comparator)
            return .insert(index: newIndex, selectRow: true, extendSelection: true)
        }

        let oldAbsoluteIndex = absoluteIndex(for: groupIndex, rowIndex: rowIndex)

        groups[groupIndex].remove(at: rowIndex)

        let newAbsoluteIndex = insert(siswa, comparator: comparator)

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

    /// Memperbarui model siswa di memori dan di database.
    ///
    /// - Parameters:
    ///   - id: ID siswa.
    ///   - columnIdentifier: Kolom yang akan diperbarui.
    ///   - rowIndex: Indeks absolut baris siswa (opsional).
    ///   - newValue: Nilai baru yang akan disimpan.
    ///
    /// - Note: Fungsi ini mengirim notifikasi ``undoAction(originalModel:)`` dengan parameter
    /// `id`, `columnIndentifier`, dan objek ``ModelSiswa``. Menjalankan ``siswa(for:)`` untuk
    /// mendapatkan objek ``ModelSiswa`` sesuai `id` nya.
    func updateModelAndDatabase(id: Int64, columnIdentifier: SiswaColumn, rowIndex: Int?, newValue: String) {
        if let kolomDB = columnIdentifier.kolomDB {
            DatabaseController.shared.updateKolomSiswa(id, kolom: kolomDB, data: newValue)
        }

        guard let rowIndex, let siswa = siswa(at: rowIndex) else {
            if let persistentSiswa = DatabaseController.shared.getKelasSiswa(id) {
                NotifSiswaDiedit.sendNotif(persistentSiswa)
            }
            return
        }

        siswa.setValue(for: columnIdentifier, newValue: newValue)

        UndoActionNotification.sendNotif(
            id, columnIdentifier: columnIdentifier, rowIndex: rowIndex,
            newValue: newValue, isGrouped: true,
            updatedSiswa: siswa
        )

        NotifSiswaDiedit.sendNotif(siswa)
    }

    /// Mengambil ID, nama, dan foto siswa berdasarkan indeks absolut baris.
    ///
    /// Menjalankan ``siswa(at:)`` untuk mendapatkan siswa di dalam urutan grup
    /// yang sesuai dengan
    /// parameter `row`.
    ///
    /// - Parameter row: Indeks absolut baris siswa.
    /// - Returns: Tuple `(id, nama, foto)` atau `nil` jika siswa tidak ditemukan.
    func getIdNamaFoto(row: Int) -> (id: Int64, nama: String, foto: Data)? {
        guard let siswa = siswa(at: row) else { return nil }
        let foto = DatabaseController.shared.bacaFotoSiswa(idValue: siswa.id)
        return (siswa.id, siswa.nama, foto)
    }

    /// Mengurutkan setiap grup siswa berdasarkan comparator.
    ///
    /// - Parameter comparator: Closure pembanding untuk pengurutan.
    @inline(__always)
    func sort(by comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) {
        let sortedGroupedSiswa = groups.map { group in
            group.sorted(by: comparator)
        }

        // Perbarui grup yang ada dengan grup yang sudah diurutkan
        for (index, sortedGroup) in sortedGroupedSiswa.enumerated() {
            groups[index] = sortedGroup
        }
    }
    
    /// Fungsi ini membersihkan array ``groups``
    /// dan cache row dan section.
    func clearData() {
        groups.removeAll()
        rowToSectionMap.removeAll()
        sectionStartRows.removeAll()
    }

    /**
     Mengelompokkan data siswa ke dalam 8 grup berdasarkan kelas dan status.

     Fungsi ini memproses daftar siswa dari flat data Array ``ModelSiswa`` dan mengelompokkannya ke dalam 8 grup berbeda.
     Pengelompokan didasarkan pada properti `kelasSekarang` dan `status` dari setiap siswa.

     - Grup 0-5: Siswa dikelompokkan berdasarkan `kelasSekarang`. Jika `kelasSekarang` adalah "Kelas 1", siswa akan masuk ke grup 0, "Kelas 2" ke grup 1, dan seterusnya hingga "Kelas 6" ke grup 5.
     - Grup 6: Siswa dengan `status` "Lulus" akan masuk ke grup ini.
     - Grup 7: Siswa yang tidak memiliki informasi `kelasSekarang` (kosong) dan `status` bukan "Lulus" akan masuk ke grup ini.

     Fungsi ini menggunakan `withTaskGroup` untuk melakukan pemrosesan secara konkuren, meningkatkan kinerja saat menangani sejumlah besar data siswa.
     Setelah pengelompokan selesai, fungsi ini memperbarui properti ``groups`` dengan hasil yang dikelompokkan.
     */
    func getGroupSiswa(flatData: [ModelSiswa]) async {
        // Inisialisasi ulang groupedSiswa dengan 8 grup kosong
        var tempGroupedSiswa = Array(repeating: [ModelSiswa](), count: 8)

        // Gunakan withTaskGroup untuk memproses setiap siswa secara konkuren
        await withTaskGroup(of: (Int, ModelSiswa)?.self) { group in
            for siswa in flatData {
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
        groups = tempGroupedSiswa
        buildIndexMap()
    }

    /// Mendapatkan informasi lengkap tentang baris: apakah group row, section index, dan row index dalam section.
    ///
    /// - Parameter row: Index baris global dalam tabel.
    ///
    /// - Returns: Tuple berisi:
    ///   - `isGroupRow`: `true` jika baris adalah header grup/section.
    ///   - `sectionIndex`: Index section tempat baris berada.
    ///   - `rowIndexInSection`: Index baris relatif dalam section (-1 jika group row).
    ///
    /// - Complexity: O(1) menggunakan pre-computed index maps.
    ///
    /// ## Example
    /// ```swift
    /// let (isGroup, section, rowInSection) = viewModel.getRowInfoFor(row: 5)
    /// // isGroup: false, section: 1, rowInSection: 2
    /// ```
    @inline(__always)
    func getRowInfoFor(row: Int) -> (isGroupRow: Bool, sectionIndex: Int, rowIndexInSection: Int) {
        guard row >= 0, row < rowToSectionMap.count else {
            return (false, 0, 0)
        }

        let sectionIndex = rowToSectionMap[row]
        let isGroup = isGroupRow(row)

        if isGroup {
            return (true, sectionIndex, -1)
        }

        let sectionStartRow = sectionStartRows[sectionIndex]
        let rowInSection = row - sectionStartRow - 1 // -1 karena row 0 adalah header

        return (false, sectionIndex, rowInSection)
    }

    /// Mengembalikan indeks grup yang sesuai siswa berdasarkan status kelulusan atau tingkat kelasnya.
    ///
    /// Fungsi ini bertindak sebagai helper untuk menentukan di mana seorang siswa harus
    /// ditempatkan dalam tampilan tabel yang dikelompokkan. Jika siswa berstatus
    /// 'lulus', fungsi akan mencari indeks grup untuk status kelulusan. Jika tidak,
    /// ia akan mencari indeks grup berdasarkan tingkat kelas aktif siswa.
    ///
    /// - Parameter siswa: Objek ``ModelSiswa`` yang mewakili siswa yang akan diperiksa.
    /// - Returns: Indeks grup (`Int`) dari siswa tersebut, atau `nil` jika grup
    ///            yang sesuai tidak ditemukan.
    @inlinable
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
        for (groupIndex, group) in groups.enumerated() {
            if let rowIndex = group.firstIndex(where: { $0.id == id }) {
                return (groupIndex, rowIndex)
            }
        }
        return nil
    }

    /// Menghitung indeks baris absolut dari array dua dimensi (2D) ``groups``.
    ///
    /// Fungsi ini menghitung posisi baris secara keseluruhan (absolut) jika semua grup
    /// dan header-nya digabung menjadi satu daftar linear.
    /// Perhitungan menambahkan jumlah baris di setiap grup sebelumnya ditambah 1 baris header per grup.
    ///
    /// - Parameters:
    ///   - groupIndex: Indeks grup di dalam array `groups`.
    ///   - rowIndex: Indeks baris di dalam grup yang ditentukan.
    /// - Returns: Indeks baris absolut dalam daftar linear.
    ///
    /// ### Contoh
    /// Misalkan kita memiliki data:
    /// ```swift
    /// let groups = [
    ///     ["Siswa A", "Siswa B"], // Grup 0 - Kelas 1
    ///     ["Siswa C"], // Grup 1 - Kelas 2
    ///     ["Siswa D", "Siswa E", "Siswa F"] // Grup 2 - Kelas 3
    /// ]
    ///
    /// absoluteIndex(for: 0, rowIndex: 0) // -> 1
    /// absoluteIndex(for: 1, rowIndex: 0) // -> 4
    /// absoluteIndex(for: 2, rowIndex: 2) // -> 9
    /// ```
    /// Pada contoh di atas:
    /// - Grup 0 memiliki header di indeks 0, sehingga baris pertama (`rowIndex = 0`) ada di indeks 1.
    /// - Grup 1 dimulai setelah 2 baris siswa + 1 header dari grup 0, sehingga baris pertamanya ada di indeks 4.
    /// - Grup 2 dimulai setelah semua baris grup 0 dan 1 beserta header-nya, sehingga baris ketiga (`rowIndex = 2`) ada di indeks 9.
    func absoluteIndex(for groupIndex: Int, rowIndex: Int) -> Int {
        var base = 0
        for i in 0 ..< groupIndex {
            base += groups[i].count + 1 // header
        }
        return base + rowIndex + 1
    }

    /**
     Menghitung indeks baris absolut di table view untuk siswa yang memenuhi kondisi filter
     dalam mode grouped (2D array `groupedSiswa`).

     - Parameter condition: Closure untuk menentukan siswa mana yang memenuhi filter (e.g., status == .berhenti).
     - Returns: Array indeks absolut (tanpa indeks header), diurutkan ascending untuk konsistensi removal.
     */
    func calculateAbsoluteRowIndices(
        condition: (ModelSiswa) -> Bool
    ) -> [Int] {
        var absoluteIndices: [Int] = []

        for (groupIndex, group) in groups.enumerated() {
            // Iterasi setiap siswa di group (skip header implisit via +1 di absoluteIndex)
            for (rowIndex, siswa) in group.enumerated() {
                if condition(siswa) {
                    let absoluteRow = absoluteIndex(for: groupIndex, rowIndex: rowIndex)
                    absoluteIndices.append(absoluteRow)
                }
            }
        }

        return absoluteIndices.sorted() // Urutkan untuk menghindari index shift saat removal
    }

    /// Mendapatkan section index dari baris flat array NSTableView.
    ///
    /// Fungsi ini menggunakan `rowToSectionMap` yang dibangun oleh `buildIndexMap()`
    /// untuk melakukan pencarian section dengan kompleksitas O(1). Setiap baris dalam
    /// tabel (termasuk header group) dipetakan ke section index yang sesuai.
    ///
    /// - Parameter row: Indeks baris dalam flat array NSTableView (0-based index)
    /// - Returns: Section index yang sesuai dengan baris tersebut, atau `nil` jika data source
    ///           bukan `GroupedSiswaData` atau parameter `row` di luar jangkauan array
    ///
    /// ## Example
    /// ```swift
    /// // Misalkan tabel memiliki struktur:
    /// // Section 0: Header + 2 items (rows 0-2)
    /// // Section 1: Header + 1 item (rows 3-4)
    /// // Section 2: Header + 3 items (rows 5-8)
    ///
    /// let sectionIndex = getSectionFor(row: 6)
    /// // Returns: 2 (row 6 berada di section 2)
    ///
    /// let invalidSection = getSectionFor(row: 999)
    /// // Returns: nil (row di luar jangkauan)
    /// ```
    ///
    /// - Precondition: ``buildIndexMap()`` harus sudah dipanggil sebelumnya
    /// - Complexity: O(1) time, O(1) space
    @inline(__always)
    func getSectionFor(row: Int) -> Int? {
        guard row >= 0, row < rowToSectionMap.count else {
            return nil // Baris di luar jangkauan
        }
        return rowToSectionMap[row]
    }

    /// Mendapatkan baris pertama dari sebuah section dalam flat array NSTableView.
    ///
    /// Fungsi ini menggunakan `sectionStartRows` yang dibangun oleh `buildIndexMap()`
    /// untuk melakukan pencarian baris awal section dengan kompleksitas O(1).
    /// Baris pertama adalah baris header dari section tersebut.
    ///
    /// - Parameter section: Section index yang akan dicari (0-based index)
    /// - Returns: Indeks baris pertama dari section tersebut, atau `nil` jika data source
    ///           bukan `GroupedSiswaData` atau parameter `section` di luar jangkauan array
    ///
    /// ## Example
    /// ```swift
    /// // Misalkan tabel memiliki struktur:
    /// // Section 0: Header + 2 items (rows 0-2)
    /// // Section 1: Header + 1 item (rows 3-4)
    /// // Section 2: Header + 3 items (rows 5-8)
    ///
    /// let firstRow = getFirstRowFor(section: 1)
    /// // Returns: 3 (section 1 dimulai dari row 3)
    ///
    /// let headerRow = getFirstRowFor(section: 2)
    /// // Returns: 5 (section 2 dimulai dari row 5 - ini adalah header row)
    ///
    /// let invalidRow = getFirstRowFor(section: 999)
    /// // Returns: nil (section di luar jangkauan)
    /// ```
    ///
    /// ## Usage Pattern
    /// ```swift
    /// // Scroll ke section tertentu
    /// if let firstRow = getFirstRowFor(section: targetSection) {
    ///     tableView.scrollRowToVisible(firstRow)
    /// }
    /// ```
    ///
    /// - Precondition: ``buildIndexMap()`` harus sudah dipanggil sebelumnya
    /// - Complexity: O(1) time, O(1) space
    /// - Important: Sebaiknya dipanggil dari main queue
    @inline(__always)
    func getFirstRowFor(section: Int) -> Int? {
        guard section >= 0, section < sectionStartRows.count else {
            return nil // Section di luar jangkauan
        }
        return sectionStartRows[section]
    }

    /// Memeriksa apakah baris tertentu merupakan baris header grup (group row).
    ///
    /// Fungsi ini menentukan apakah sebuah baris dalam tabel adalah baris pertama dari sebuah section,
    /// yang biasanya digunakan sebagai header grup untuk mengelompokkan data.
    ///
    /// - Parameter row: Index baris yang akan diperiksa (berbasis 0).
    ///
    /// - Returns: `true` jika baris tersebut adalah baris header grup (baris pertama dari section),
    ///            `false` jika bukan atau jika index di luar jangkauan.
    ///
    /// - Complexity: O(1) - Pencarian dilakukan melalui array index yang sudah di-cache.
    ///
    /// - Note: Fungsi ini menggunakan `@inline(__always)` untuk optimasi performa karena
    ///         dipanggil sangat sering selama rendering tabel.
    ///
    /// ## Example
    /// ```swift
    /// // Misalnya tabel memiliki struktur:
    /// // Section 0: Row 0 (header), Row 1, Row 2
    /// // Section 1: Row 3 (header), Row 4
    ///
    /// viewModel.isGroupRow(0)  // true  - baris pertama section 0
    /// viewModel.isGroupRow(1)  // false - baris data biasa
    /// viewModel.isGroupRow(3)  // true  - baris pertama section 1
    /// viewModel.isGroupRow(10) // false - index di luar jangkauan
    /// ```
    ///
    /// - Important: Pastikan ``buildIndexMap()`` sudah dipanggil terlebih dahulu untuk
    ///              menginisialisasi ``rowToSectionMap`` dan ``sectionStartRows``.
    @inline(__always)
    func isGroupRow(_ row: Int) -> Bool {
        guard row >= 0, row < rowToSectionMap.count else {
            return false
        }

        // Group row adalah baris pertama setiap section
        let sectionIndex = rowToSectionMap[row]
        return sectionStartRows[sectionIndex] == row
    }

    /// Membangun peta indeks untuk menghubungkan baris tabel dengan section yang sesuai.
    ///
    /// Fungsi ini membuat dua struktur data penting untuk navigasi dan pengelolaan section dalam tabel:
    ///  - sectionStartRows: Array yang menyimpan indeks baris pertama dari setiap section
    ///  - rowToSectionMap: Array yang memetakan setiap baris tabel ke section index-nya
    func buildIndexMap() {
        sectionStartRows.removeAll()
        rowToSectionMap.removeAll()

        var currentRow = 0
        for (sectionIndex, section) in groups.enumerated() {
            // 1. Simpan baris awal dari section ini
            sectionStartRows.append(currentRow)
            // 2. Petakan semua baris di section ini (termasuk header group-nya)
            // ke section index yang sama.
            let sectionRowCount = section.count + 1 // +1 untuk baris header group
            for _ in 0 ..< sectionRowCount {
                rowToSectionMap.append(sectionIndex)
            }

            currentRow += sectionRowCount
        }
    }
}
