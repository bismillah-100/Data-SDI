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
    let dbController: DatabaseController = .shared

    /// Jumlah row di dalam data
    var numberOfRows: Int { dataSource.numberOfRows }

    /// Data Source untuk mode ``TableViewMode/plain``
    private var plainData: PlainSiswaData = .init()

    /// Data Source untuk mode ``TableViewMode/grouped``
    private var groupedData: GroupedSiswaData = .init()

    /// Data Source sesuai ``mode`` yang akan dikelola.
    ///
    /// - ``TableViewMode/plain`` = ``PlainSiswaData``
    /// - ``TableViewMode/grouped`` = ``GroupedSiswaData``
    var dataSource: SiswaDataSource {
        mode == .grouped ? groupedData : plainData
    }

    /// Properti ``TableViewMode`` yang menyimpan presentasi antara ``PlainSiswaData`` dan ``GroupedSiswaData``.
    private(set) var mode: TableViewMode = .plain

    /// Publisher ketika siswa berubah status atau kelas.
    let kelasEvent: PassthroughSubject<NaikKelasEvent, Never> = .init()

    /**
     Inisialisasi ``SiswaViewModel``.

     Inisialisasi ini mendapat ``mode`` dari `UserDefaults`.
     */
    private init() {
        if let savedMode = UserDefaults.standard.value(forKey: "tableViewMode") as? Int,
           let mode = TableViewMode(rawValue: savedMode)
        {
            setMode(mode)
        }
    }

    // MARK: - SISWADATA related View

    /// Mengatur mode tampilan tabel (`TableViewMode`) untuk `SiswaViewModel`.
    ///
    /// Fungsi ini akan:
    /// - Memperbarui properti `mode` sesuai nilai yang diberikan.
    /// - Menyimpan pilihan mode ke `UserDefaults` dengan key `"tableViewMode"`,
    ///   sehingga preferensi mode akan tetap tersimpan untuk sesi berikutnya.
    ///
    /// - Parameter mode: Nilai `TableViewMode` yang menentukan apakah data ditampilkan
    ///   dalam mode datar (`.plain`) atau terkelompok (`.grouped`).
    func setMode(_ mode: TableViewMode) {
        self.mode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "tableViewMode")
    }

    /// Mengambil data siswa dari database secara asinkron
    /// dengan menjalankan protokol ``SiswaDataSource/fetchSiswa()``.
    func fetchSiswaData() async {
        await dataSource.fetchSiswa()
    }

    /**
         Mencari siswa berdasarkan filter yang diberikan.

         Fungsi ini menjalankan protokol ``SiswaDataSource/cariSiswa(_:)``.

         - Parameter filter: String yang digunakan sebagai filter pencarian.
     */
    func cariSiswa(_ filter: String) async {
        await dataSource.cariSiswa(filter)
    }

    /**
     Menghapus siswa pada indeks tertentu dari ``dataSource``.

     Fungsi ini menjalankan protokol ``SiswaDataSource/remove(at:)``

     - Parameter index: Indeks siswa yang akan dihapus dalam daftar ``dataSource``.
     */
    @inline(__always)
    func removeSiswa(at index: Int) {
        dataSource.remove(at: index)
    }

    /// Fungsi ini bertujuan untuk menambahkan siswa ke ``dataSource`` dengan cara mengambilnya dari database
    /// ``DatabaseController/getSiswa(idValue:)`` sesuai dengan parameter `id`.
    ///
    /// Fungsi ini menjalankan protokol ``SiswaDataSource/insert(_:comparator:)``.
    /// - Parameters:
    ///   - id: ID unik siswa yang akan di fetch dari database.
    ///   - comparator: Perbandingan dua objek untuk penempatan yang sesuai dengan urutan data.
    /// - Returns: Int `index` penempatan pada `dataSource`.
    @inline(__always)
    func insertHiddenSiswa(_ id: Int64, comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool) -> Int {
        let siswa = dbController.getSiswa(idValue: id)
        return dataSource.insert(siswa, comparator: comparator)
    }

    /**
     Memperbarui data siswa pada indeks tertentu.

     Fungsi ini memperbarui data siswa baik di sumber data di array yang telah difilter  sesuai ``dataSource``.

     - Parameter siswa: Objek ``ModelSiswa`` yang berisi data siswa yang telah diperbarui.

     */
    @discardableResult @inline(__always)
    func updateSiswa(_ siswa: ModelSiswa) -> Int? {
        dataSource.update(siswa: siswa)
    }

    /**
         Memperbarui data siswa dan mengirim notifikasi ke KelasVC dan DetailSiswaViewController.

         Fungsi ini melakukan serangkaian operasi, termasuk mengirim notifikasi berdasarkan perubahan data siswa,
         memperbarui database dengan data siswa yang baru, dan mengirim notifikasi setelah pembaruan database.

         - Parameter id: ID unik siswa yang akan diperbarui (Int64).
         - Parameter dataLama: ModelSiswa yang berisi data siswa sebelum pembaruan.
         - Parameter baru: ModelSiswa yang berisi data siswa yang telah diperbarui.

         **Logika Utama:**

         **Pembaruan Database:**
         - Membandingkan setiap properti di `dataLama` dan `baru`.
         - Jika ada perbedaan, kolom yang sesuai di database akan diperbarui menggunakan `dbController`.
         - Properti yang diperbarui meliputi: nama, alamat, tanggal lahir, tahun daftar, nama wali, NIS, jenis kelamin, status, kelas saat ini, tanggal berhenti, foto, NISN, ayah, ibu, dan nomor telepon.

         **Notifikasi yang Dikirim:**
         - `.tanggalBerhentiBerubah`: Dikirim ketika ``ModelSiswa/tahundaftar`` atau ``ModelSiswa/tanggalberhenti`` berubah.
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
    }

    /**
         Menyaring data siswa berdasarkan status berhenti dan melakukan pengurutan. Fungsi ini menjalankan protokol ``SiswaDataSource/filterSiswaBerhenti(_:comparator:)``

         Fungsi ini menyaring data siswa berdasarkan status "berhenti". Jika `isBerhentiHidden` bernilai `true`,
         maka fungsi akan mencari index siswa yang memiliki status "berhenti" dari ``dataSource`` yang sudah ada.
         Jika `isBerhentiHidden` bernilai `false`, fungsi akan mengambil data siswa terbaru dari database,
         mengurutkannya, dan kemudian mencari index siswa yang memiliki status "berhenti".

         - Parameter isBerhentiHidden: Boolean yang menentukan apakah siswa dengan status "berhenti" disembunyikan atau tidak.
                                       Jika `true`, pencarian dilakukan pada ``dataSource`` yang sudah ada.
                                       Jika `false`, data siswa diambil dari database dan diurutkan terlebih dahulu.
         - Parameter sortDescriptor:  Objek `SortDescriptorWrapper` yang digunakan untuk mengurutkan data siswa.
         - Returns: Array berisi index dari siswa yang memiliki status "berhenti".
     */
    @inline(__always)
    func filterSiswaBerhenti(_ isBerhentiHidden: Bool, sortDescriptor: SortDescriptorWrapper) async -> [Int] {
        guard let comparator = ModelSiswa.comparator(from: sortDescriptor.asNSSortDescriptor) else { return [] }
        return await dataSource.filterSiswaBerhenti(isBerhentiHidden, comparator: comparator)
    }

    /**
         Menyaring data siswa berdasarkan status kelulusan dan mengembalikan indeks siswa yang lulus.

         Fungsi ini menjalankan protokol ``SiswaDataSource/filterSiswaLulus(_:comparator:)``.

         - Parameter tampilkanLulus: Boolean yang menentukan apakah akan menampilkan hanya siswa yang lulus atau tidak. Jika `false`, fungsi akan mengembalikan indeks siswa yang lulus dari ``dataSource``. Jika `true`, fungsi akan mengambil data siswa terbaru dari database, mengurutkannya, dan kemudian mengembalikan indeks siswa yang lulus.
         - Parameter sortDesc: Deskriptor pengurutan yang digunakan untuk mengurutkan data siswa jika `tampilkanLulus` adalah `true`.
         - Returns: Array berisi indeks dari siswa yang lulus. Jika tidak ada siswa yang lulus, array akan kosong.
     */
    @inline(__always)
    func filterSiswaLulus(_ tampilkanLulus: Bool, sortDesc: SortDescriptorWrapper) async -> [Int] {
        guard let comparator = ModelSiswa.comparator(from: sortDesc.asNSSortDescriptor) else { return [] }
        return await dataSource.filterSiswaLulus(tampilkanLulus, comparator: comparator)
    }

    /**
         Mengambil nilai lama untuk kolom tertentu dari data siswa.

         Fungsi ini mengambil nilai dari properti tertentu dari objek ``dataSource``
         berdasarkan `columnIdentifier` yang diberikan.

         - Parameter rowIndex: Indeks baris dalam array `data`. Opsional, defaultnya adalah `nil`.
         - Parameter columnIdentifier: String yang mengidentifikasi kolom yang nilainya akan diambil.

         - Returns: String yang mewakili nilai lama untuk kolom yang ditentukan. Mengembalikan string kosong jika `columnIdentifier` tidak cocok dengan kasus yang diketahui.
     */
    func getOldValueForColumn(rowIndex: Int, columnIdentifier: SiswaColumn) -> (id: Int64?, oldValue: String) {
        guard let s = dataSource.siswa(at: rowIndex) else { return (nil, "") }

        let value: String
        switch columnIdentifier {
        case .nama: value = s.nama
        case .alamat: value = s.alamat
        case .ttl: value = s.ttl
        case .namawali: value = s.namawali
        case .nis: value = s.nis
        case .nisn: value = s.nisn
        case .ayah: value = s.ayah
        case .ibu: value = s.ibu
        case .jeniskelamin: value = s.jeniskelamin.description
        case .status: value = s.status.description
        case .tlv: value = s.tlv
        case .tahundaftar: value = s.tahundaftar
        case .tanggalberhenti: value = s.tanggalberhenti
        default: return (nil, "")
        }

        return (s.id, value)
    }

    /**
     Memperbarui model data siswa dan database berdasarkan pengidentifikasi kolom yang diberikan.

     - Parameter id: ID unik siswa yang akan diperbarui.
     - Parameter columnIdentifier: Pengidentifikasi kolom yang akan diperbarui (misalnya, "Nama", "Alamat", dll.).
     - Parameter rowIndex: Indeks baris siswa dalam array ``dataSource``.
     - Parameter newValue: Nilai baru untuk kolom yang ditentukan.

     Fungsi ini melakukan hal berikut:
     1. Menjalankan protokol ``SiswaDataSource/updateModelAndDatabase(id:columnIdentifier:rowIndex:newValue:)``.
     2. Menambahkan saran pengetikan ``DatabaseController/catatSuggestions(data:)``.
     3. Menambahkan saran pengetikan dengan model ``AutoCompletion`` ke array yang digunakan ``SuggestionManager``.
     4. Memposting pemberitahuan `.tanggalBerhentiBerubah` jika `columnIdentifier` merupakan salah satu dari `.status, .tanggalberhenti, .jeniskelamin, .tahundaftar, atau .ttl`.
     */
    func updateModelAndDatabase(id: Int64, columnIdentifier: SiswaColumn, rowIndex: Int? = nil, newValue: String) {
        dataSource.updateModelAndDatabase(
            id: id,
            columnIdentifier: columnIdentifier,
            rowIndex: rowIndex,
            newValue: newValue
        )

        // 3. Opsional: autocomplete, suggestion, notifikasi spesifik
        DatabaseController.shared.catatSuggestions(data: [columnIdentifier: newValue])
        switch columnIdentifier {
        case .nama:
            addAutocomplete(newValue, to: &ReusableFunc.namasiswa)
        case .alamat:
            addAutocomplete(newValue, to: &ReusableFunc.alamat)
        case .ttl:
            addAutocomplete(newValue, to: &ReusableFunc.ttl)
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        case .namawali:
            addAutocomplete(newValue, to: &ReusableFunc.namawali)
        case .nis:
            addAutocomplete(newValue, to: &ReusableFunc.nis)
        case .nisn:
            addAutocomplete(newValue, to: &ReusableFunc.nisn)
        case .ayah:
            addAutocomplete(newValue, to: &ReusableFunc.namaAyah)
        case .ibu:
            addAutocomplete(newValue, to: &ReusableFunc.namaIbu)
        case .status, .tanggalberhenti, .jeniskelamin, .tahundaftar:
            NotificationCenter.default.post(name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        case .tlv:
            addAutocomplete(newValue, to: &ReusableFunc.tlvString)
        default: break
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

    /// Memasukkan ``ModelSiswa`` ke dalam ``dataSource``.
    ///
    /// Fungsi ini menggunakan protokol ``SiswaDataSource/insert(_:comparator:)``
    ///
    /// - Parameters:
    ///   - data: Objek ``ModelSiswa`` yang akan dimasukkan.
    ///   - comparator: Sebuah closure yang digunakan untuk menentukan posisi terurut yang benar
    ///     untuk data siswa baru.
    /// - Returns: Enum ``UpdateData`` yang berisi informasi tentang penyisipan.
    @inline(__always)
    func insertSiswa(
        _ siswa: ModelSiswa,
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool
    ) -> UpdateData {
        let index = dataSource.insert(siswa, comparator: comparator)
        return .insert(index: index, selectRow: true, extendSelection: true)
    }

    /// Fungsi untuk mendapatkan data dari ``dataSource`` dalam bentuk `array` datar.
    ///
    /// Fungsi ini menjalankan protokol ``SiswaDataSource/currentFlatData()``.
    /// - Returns: Array ``ModelSiswa``.
    func flattenedData() -> [ModelSiswa] {
        dataSource.currentFlatData()
    }

    /// Fungsi ini menjalankan protokol ``SiswaDataSource/indexSiswa(for:)`` untuk
    /// mendapatkan index siswa di dalam ``dataSource`` sesuai dengan id uniknya.
    /// - Parameter id: ``ModelSiswa/id`` yang akan digunakan untuk mencari indeks.
    /// - Returns: Int Indeks data siswa sesuai `id` di dalam ``dataSource``.
    @inline(__always)
    func getIndexForSiswa(_ id: Int64) -> Int? {
        dataSource.indexSiswa(for: id)
    }

    /// Mendapatkan objek ``ModelSiswa`` sesuai di dalam ``dataSource``
    /// sesuai dengan row (tempat indeks objek di `dataSource`) dengan cara
    /// menjalankan protokol ``SiswaDataSource/siswa(at:)``.
    /// - Parameter row: Indeks objek di dalam ``dataSource``.
    /// - Returns: Objek ``ModelSiswa`` yang ada di ``dataSource`` sesuai lokasi `row`.
    @inline(__always)
    func siswa(at row: Int) -> ModelSiswa? {
        dataSource.siswa(at: row)
    }

    /// Mendapatkan objek array dari ``dataSource`` dengan cara
    /// menjalankan protokol ``SiswaDataSource/siswa(in:)``.
    /// - Parameter selectedRows: IndexSet kumpulan indeks yang akan digunakan
    /// untuk mencari siswa di ``dataSource`` sesuai dengan nomor indeks.
    /// - Returns: Array ``ModelSiswa`` yang berada di urutan sesuai parameter
    /// `selectedRows`.
    @inline(__always)
    func getSiswas(for selectedRows: IndexSet) -> [ModelSiswa] {
        dataSource.siswa(in: selectedRows)
    }

    /// Merelokasi (memindahkan) data siswa ke posisi yang benar dalam model data.
    ///
    /// Fungsi ini bertindak sebagai dispatcher, mengarahkan pemanggilan ke protokol ``SiswaDataSource/relocateSiswa(_:comparator:columnIndex:)``
    /// dan mengembalikan objek ``UpdateData`` untuk memperbarui UI.
    ///
    /// - Parameters:
    ///   - siswa: Objek ``ModelSiswa`` yang akan direlokasi.
    ///   - comparator: Sebuah closure yang digunakan untuk membandingkan dua
    ///     siswa untuk menentukan posisi pengurutan yang benar.
    ///   - columnIndex: Indeks kolom opsional untuk pembaruan UI yang lebih spesifik.
    /// - Returns: Sebuah objek ``UpdateData`` yang berisi detail pembaruan yang diperlukan
    ///   untuk UI, atau `nil` jika siswa tidak ditemukan.
    @inline(__always)
    func relocateSiswa(
        _ siswa: ModelSiswa,
        comparator: @escaping (ModelSiswa, ModelSiswa) -> Bool,
        columnIndex: Int? = nil
    ) -> UpdateData? {
        dataSource.relocateSiswa(siswa, comparator: comparator, columnIndex: columnIndex)
    }

    /// Menghapus siswa dari ``dataSource``.
    ///
    /// Fungsi ini menjalankan ``SiswaDataSource/removeSiswa(_:)`` untuk mencari
    /// siswa berdasarkan ID dan menghapusnya dari ``dataSource`` yang sesuai dan
    /// mengembalikan objek ``UpdateData`` yang merepresentasikan tindakan penghapusan
    /// untuk diperbarui di UI.
    ///
    /// - Parameters:
    ///   - siswa: Objek ``ModelSiswa`` yang akan dihapus.
    /// - Returns: Tuple. **Indeks** baris absolut siswa yang dihapus dalam tabel dan objek ``UpdateData``
    ///   yang merepresentasikan tindakan penghapusan di UI.
    ///   Mengembalikan `nil` jika siswa tidak ditemukan dalam model.
    @inline(__always)
    func removeSiswa(_ siswa: ModelSiswa) -> (index: Int, update: UpdateData)? {
        dataSource.removeSiswa(siswa)
    }

    /**
         Mengurutkan data siswa berdasarkan deskriptor pengurutan yang diberikan.

         Fungsi ini mengurutkan data sesuai dengan ``dataSource`` dengan menjalankan protokol ``SiswaDataSource/sort(by:)``.

         - Parameter sortDescriptor: Objek `SortDescriptorWrapper` yang berisi kunci dan urutan pengurutan (menaik atau menurun).

         - Catatan:
             Fungsi ini menggunakan metode bantu `compareStrings` dan `compareDates` untuk melakukan perbandingan string dan tanggal, masing-masing.
             Jika konversi tanggal gagal, fungsi ini akan mengembalikan `false`, yang dapat memengaruhi urutan pengurutan.
     */
    @inline(__always)
    func sortSiswa(by sortDescriptor: NSSortDescriptor) {
        guard let comparator = ModelSiswa.comparator(from: sortDescriptor) else { return }
        dataSource.sort(by: comparator)
    }

    /**
     Mengambil ID siswa berdasarkan indeks baris.

     Fungsi ini mencari ID siswa berdasarkan indeks baris yang diberikan dalam tampilan yang dikelompokkan.
     Ini mengiterasi melalui setiap kelompok siswa dan memeriksa apakah indeks baris yang diberikan berada dalam rentang kelompok tersebut.
     Jika ditemukan, ia menghitung indeks siswa relatif dalam kelompok dan mengembalikan ID siswa tersebut.

     - Parameter row: Indeks baris dalam tampilan yang dikelompokkan.
     - Returns: ID siswa (Int64) jika ditemukan dalam indeks baris yang diberikan; jika tidak, mengembalikan -1.
     */
    @inline(__always)
    func getSiswaId(row: Int) -> Int64? {
        guard let id = dataSource.siswa(at: row)?.id else { return nil }
        return id
    }
}

extension SiswaViewModel {
    /**
         Melakukan operasi 'undo' pada in-line editing siswa.

         Fungsi ini membalikkan perubahan terakhir yang dilakukan pada data siswa sesuai ``dataSource``.
         Operasi 'undo' dicatat menggunakan `UndoManager` untuk memungkinkan operasi 'redo'.  Fungsi ini menjalankan protokol ``SiswaDataSource/redoAction(originalModel:)``

         - Parameter originalModel: Objek `DataAsli` yang berisi informasi tentang perubahan yang akan dibatalkan,
                                   termasuk ID siswa, pengidentifikasi kolom, nilai baru, dan nilai lama.
     */
    func undoAction(originalModel: DataAsli) {
        dataSource.undoAction(originalModel: originalModel)
        SiswaViewModel.siswaUndoManager.registerUndo(withTarget: self, handler: { targetSelf in
            targetSelf.redoAction(originalModel: originalModel)
        })
    }

    /**
     Fungsi ini membalikkan perubahan undo terakhir pada in-line editing siswa sesuai ``dataSource``,
     serta mendaftarkan aksi undo yang sesuai menggunakan `UndoManager`. Fungsi ini menjalankan protokol ``SiswaDataSource/redoAction(originalModel:)``

     - Parameter originalModel: Model `DataAsli` yang berisi informasi tentang perubahan yang akan di-redo, termasuk ID, pengidentifikasi kolom, nilai baru, dan nilai lama.
     */
    func redoAction(originalModel: DataAsli) {
        dataSource.redoAction(originalModel: originalModel)
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
            if let matchedSiswaData = dataSource.siswa(for: snapshotSiswa.id) {
                oldData.append(matchedSiswaData)
                updateDataSiswa(snapshotSiswa.id, dataLama: matchedSiswaData, baru: snapshotSiswa)
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

extension SiswaViewModel {
    /// Dispatcher yang menjalankan func ``GroupedSiswaData/getRowInfoFor(row:)``.
    func getRowInfoForRow(_ row: Int) -> (isGroupRow: Bool, sectionIndex: Int, rowIndexInSection: Int) {
        guard let groupedSource = dataSource as? GroupedSiswaData else { return (false, -1, -1) }
        return groupedSource.getRowInfoFor(row: row)
    }
}

/**
    Struktur pembungkus untuk `NSSortDescriptor` agar sesuai dengan protokol `Sendable`.

    Struktur ini merangkum properti kunci dan urutan menaik dari sebuah `NSSortDescriptor`,
    memungkinkannya untuk dilewatkan dengan aman antar thread.

    - Note: Digunakan untuk membungkus `NSSortDescriptor` agar sesuai dengan protokol `Sendable`.
 */
struct SortDescriptorWrapper: Sendable {
    /// Nama `SortDescriptorWrapper`.
    let key: String
    /// Status `ascending` dari `SortDescriptorWrapper`.
    let ascending: Bool

    /// Konversi ``SortDescriptorWrapper`` menjadi `NSSortDescriptor`.
    var asNSSortDescriptor: NSSortDescriptor {
        NSSortDescriptor(key: key, ascending: ascending)
    }

    /// Konversi `NSSortDescriptor` menjadi ``SortDescriptorWrapper``.
    /// - Parameter descriptor: `NSSortDescriptor` yang dikonversi.
    /// - Returns: ``SortDescriptorWrapper`` dari `NSSortDescriptor`.
    static func from(_ descriptor: NSSortDescriptor) -> SortDescriptorWrapper {
        SortDescriptorWrapper(key: descriptor.key ?? "", ascending: descriptor.ascending)
    }
}
