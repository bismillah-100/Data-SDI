//
//  Notification.swift
//  Data SDI
//
//  Created by Bismillah on 01/12/23.
//

import Foundation

extension Notification.Name {
    // MARK: - SISWAVIEWCONTROLLER

    /// Notifikasi yang diposting ketika data siswa dihapus di ``SiswaViewController``
    ///
    /// Gunakan notification ini untuk menyinkronkan data di berbagai bagian aplikasi
    /// setelah terjadi penghapusan siswa.
    static let siswaDihapus = Notification.Name("SiswaDihapus")
    /// Notifikasi yang diposting ketika data siswa diurungkan dihapus di ``SiswaViewController``
    static let undoSiswaDihapus = Notification.Name("UndoSiswaDihapus")

    // MARK: - DETAILSISWACONTROLLER

    /// Notifikasi yang diposting ketika data siswa di ``DetailSiswaController`` dihapus.
    static let findDeletedData = NSNotification.Name("FindDeletedData")
    /// Notifikasi yang diposting ketika pembaruan data di ``DetailSiswaController`` telah disimpan.
    static let dataSaved = NSNotification.Name("DataSaved")
    /// Notifikasi yang posting ketika data dimasukkan ke tabel ``DetailSiswaController``.
    static let updateRedoInDetilSiswa = NSNotification.Name("UpdateRedoInDetilSiswa")

    // MARK: - KELASVC

    /// Notifikasi yang diposting ketika data dihapus di ``KelasVC``..
    static let kelasDihapus = NSNotification.Name("KelasDihapus")
    /// Notifikasi yang diposting ketika menjalankan `redo paste` dari ``KelasVC``.
    static let undoKelasDihapus = NSNotification.Name("UndoKelasDihapus")

    /// Notifikasi yang diposting ketika data di ``KelasVC`` diperbarui.
    static let updateDataKelas = Notification.Name("UpdateDataSiswaDiKelas")

    // MARK: KELASVIEWMODEL

    /// Notifikasi yang diposting ketika nama guru di kelas diperbarui.
    static let editNamaGuruKelas = NSNotification.Name("EditNamaGuruKelas")
    /// Notifikasi yang diposting ketika data kelas diperbarui.
    static let editDataSiswaKelas = NSNotification.Name("EditDataSiswaKelas")

    // MARK: - MENAMBAHKAN DATA KELAS

    /// Notifikasi yang dikirim ketika menambahkan data ke tabel database kelas.
    /// Notifikasi ini digunakan untuk menambahkan data ke  tabel ``DetailSiswaController``..
    static let updateTableNotificationDetilSiswa = NSNotification.Name("UpdateTableNotificationDetilSiswa")

    static let addDetilSiswaUITertutup = Notification.Name("AddDetilSiswaUITertutup")

    /// Notifikasi ini dikirim ketika nama guru di daftar guru diperbarui. ``DatabaseController/updateKolomGuru(_:kolom:baru:)``.
    static let updateGuruMapel = NSNotification.Name("updateGuruMapel")

    /// Notifikasi ini dikirim ketika tugas guru diperbarui dengan mapel berbeda.
    static let updateTugasMapel = NSNotification.Name("updateTugasMapel")

    /// Notification yang diposting ketika data siswa diedit atau diperbarui.
    ///
    /// Gunakan notification ini untuk memperbarui tampilan atau data terkait siswa
    /// yang telah dimodifikasi.
    static let dataSiswaDiEdit = NSNotification.Name("dataSiswaDiEdit")

    static let windowControllerClose = Notification.Name("WindowControllerclose")
    static let popupDismissed = Notification.Name("popupDismissed")
    static let popupDismissedKelas = Notification.Name("popupDismissedKelas")
    static let saveData = Notification.Name("simpanSemua")
    static let hapusCacheFotoKelasAktif = Notification.Name("cacheFotoKelasAktifDihapus")

    // dari SiswaView ke KelasVC
    static let dataSiswaDiEditDiSiswaView = NSNotification.Name("dataSiswaDiEditDiSiswaView")

    // MARK: - JUMLAHSISWA

    static let jumlahSiswa = NSNotification.Name("tglBerhentiProcessed")

    // MARK: - TRANSAKSI VIEW

    static let popUpDismissedTV = NSNotification.Name("popUpDismissedKeTV")
    static let perubahanData = NSNotification.Name("perubahanData")
    static let didAssignUUID = Notification.Name("didAssignUUID")

    // MARK: - WINDOW

    // MARK: - SISWAVIEWMODEL

    static let undoActionNotification = Notification.Name("undoActionNotification")
    static let updateEditSiswa = Notification.Name("editedDataSiswa")

    // MARK: - UPDATE FOTO DI TOOLBAR

    static let bisaUndo = Notification.Name("bisaUndo")

    // MARK: - KELASAKTIF DAN STATUS BERUBAH

    /// Notifikasi ini dikirim ketika pendaftaran (enrollment) aktif seorang siswa berubah.
    /// `userInfo` akan berisi ["siswaID": Int64].
    static let didChangeStudentEnrollment = Notification.Name("didChangeStudentEnrollment")

    // MARK: - PENAMBAHAN DATA BARU KE DATABASE DAN TABLEVIEW
}

/// Protokol yang mendefinisikan payload untuk notification system.
///
/// Terapkan protokol ini untuk membuat payload notification yang type-safe
/// dan mudah dikonsumsi oleh observer.
protocol NotificationPayload {
    /// Membuat instance payload dari dictionary userInfo NotificationCenter.
    ///
    /// - Parameter userInfo: Dictionary yang berisi data payload dari notification
    /// - Returns: Instance payload jika semua data required tersedia, nil jika tidak
    init?(userInfo: [AnyHashable: Any])
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// Menambahkan observer untuk notification dengan payload type-safe.
    ///
    /// Method ini menyediakan cara yang lebih aman untuk mendengarkan notification
    /// dengan automatic payload parsing dan filtering.
    ///
    /// - Parameters:
    ///   - name: Nama notification yang ingin didengarkan
    ///   - obj: Object yang dikaitkan dengan notification (optional)
    ///   - queue: OperationQueue untuk eksekusi block (optional, default main queue)
    ///   - filter: Closure untuk memfilter payload tertentu (optional)
    ///   - block: Block yang dieksekusi ketika notification diterima
    /// - Returns: Token observer yang dapat digunakan untuk remove observer
    ///
    /// /// ### Contoh Penggunaan
    ///
    /// #### 1. Basic Usage
    /// ```swift
    /// // Definisikan payload type-safe
    /// struct NilaiKelasNotif: NotificationPayload {
    ///     let id: Int64
    ///     let nilai: Int
    ///
    ///     init?(userInfo: [AnyHashable : Any]) {
    ///         guard let id = userInfo["id"] as? Int64 else { return nil }
    ///         guard let nilai = userInfo["nilai"] as? [Int] else { return nil }
    ///         self.id = id
    ///         self.nilai = nilai
    ///     }
    /// }
    ///
    /// // Menambahkan observer
    /// let token = NotificationCenter.default.addObserver(
    ///     forName: .nilaiDidUpdate,
    ///     using: { (payload: NilaiKelasNotif) in
    ///         print("id:", payload.id, "Nilai baru:", payload.nilai)
    ///     }
    /// )
    /// ```
    ///
    /// #### 2. Dengan Filter
    /// ```swift
    /// let token = NotificationCenter.default.addObserver(
    ///     forName: .nilaiDidUpdate,
    ///     filter: { (payload: NilaiKelasNotif) in
    ///         payload.id == some.id
    ///     },
    ///     using: { payload in
    ///         print("Nilai baru:", payload.nilai)
    ///     }
    /// )
    /// ```
    @discardableResult
    func addObserver<P: NotificationPayload>(
        forName name: Notification.Name,
        object obj: Any? = nil,
        queue: OperationQueue? = nil,
        filter: ((P) -> Bool)? = nil,
        using block: @escaping (P) -> Void
    ) -> NSObjectProtocol {
        addObserver(forName: name, object: obj, queue: queue) { notification in
            // Parse payload dari userInfo
            guard let payload = P(userInfo: notification.userInfo ?? [:]) else {
                print("Warning: Failed to parse payload for notification \(name.rawValue)")
                return
            }

            // Apply filter jika provided
            if let filter, !filter(payload) {
                return
            }

            // Eksekusi block dengan payload
            block(payload)
        }
    }
}

/// Payload notification untuk event penghapusan siswa.
///
/// Struct ini menyampaikan informasi tentang siswa mana yang dihapus dan dari kelas mana.
/// Digunakan untuk menyinkronkan data di berbagai bagian aplikasi setelah penghapusan.
///
/// ## Contoh Penggunaan:
/// ```swift
/// // Mengirim notification
/// NotifSiswaDihapus.sendNotif(siswa)
///
/// // Mendengarkan notification
/// NotificationCenter.default.addObserver(forName: .siswaDihapus) { (payload: NotifSiswaDihapus) in
///     // Handle deletion
/// }
/// ```
struct NotifSiswaDihapus: NotificationPayload {
    /// Sebuah array berisi ID unik dari siswa yang telah dihapus.
    ///
    /// Setiap elemen dalam array ini adalah `Int64` yang merepresentasikan
    /// ID database atau kunci unik serupa untuk seorang siswa.
    var deletedStudentIDs: [Int64]

    /// Nama atau pengenal kelas tempat siswa dihapus.
    ///
    /// String ini memberikan konteks untuk penghapusan, menunjukkan
    /// siswa yang terpengaruh berasal dari kelas mana.
    var kelasSekarang: String

    /// Mengkonversi payload menjadi dictionary untuk NotificationCenter.
    ///
    /// - Returns: Dictionary yang berisi semua data payload dengan keys yang sesuai
    var asUserInfo: [AnyHashable: Any] {
        [
            "deletedStudentIDs": deletedStudentIDs,
            "kelasSekarang": kelasSekarang,
        ]
    }

    /// Membuat instance payload dari dictionary userInfo NotificationCenter.
    ///
    /// - Parameter userInfo: Dictionary userInfo dari notification
    /// - Returns: Instance NotifSiswaDihapus jika data valid, nil jika tidak
    init?(userInfo: [AnyHashable: Any]) {
        guard let deletedStudentIDs = userInfo["deletedStudentIDs"] as? [Int64],
              let kelasSekarang = userInfo["kelasSekarang"] as? String
        else {
            print("Error: Invalid userInfo for NotifSiswaDihapus")
            return nil
        }

        self.deletedStudentIDs = deletedStudentIDs
        self.kelasSekarang = kelasSekarang
    }

    /// Membuat instance payload langsung dengan data yang diperlukan.
    ///
    /// - Parameters:
    ///   - deletedStudentIDs: Array ID siswa yang dihapus
    ///   - kelasSekarang: Nama kelas tempat penghapusan terjadi
    init(deletedStudentIDs: [Int64], kelasSekarang: String) {
        self.deletedStudentIDs = deletedStudentIDs
        self.kelasSekarang = kelasSekarang
    }

    /// Mengirim notification untuk penghapusan satu siswa.
    ///
    /// Convenience method untuk mengirim notification penghapusan dengan data dari ModelSiswa.
    ///
    /// - Parameter siswa: ModelSiswa yang dihapus
    /// - Parameter notificationName: Nama notifikasi. default: `.siswaDihapus`.
    static func sendNotif(_ siswa: ModelSiswa, notificationName: Notification.Name = .siswaDihapus) {
        let payload = NotifSiswaDihapus(
            deletedStudentIDs: [siswa.id],
            kelasSekarang: siswa.tingkatKelasAktif.rawValue
        )
        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: payload.asUserInfo
        )
    }
}

/// Payload notification untuk event pengeditan data siswa.
///
/// Struct ini menyampaikan informasi tentang siswa yang diedit, termasuk
/// ID siswa, kelas, dan nama yang diperbarui. Menggunakan protokol
/// ``NotificationPayload``untuk memfasilitasi konversi data ke dan
/// dari format `userInfo` yang digunakan oleh `NotificationCenter`.
struct NotifSiswaDiedit: NotificationPayload {
    /// ID unik dari siswa yang datanya diedit.
    var updateStudentID: Int64

    /// Nama atau pengenal kelas tempat siswa berada.
    var kelasSekarang: String

    /// Nama siswa yang telah diperbarui.
    var namaSiswa: String

    /// Mengkonversi payload menjadi dictionary untuk NotificationCenter.
    var asUserInfo: [AnyHashable: Any] {
        [
            "updateStudentID": updateStudentID,
            "kelasSekarang": kelasSekarang,
            "namaSiswa": namaSiswa,
        ]
    }

    /// Membuat instance payload dari dictionary userInfo NotificationCenter.
    ///
    /// - Parameter userInfo: Dictionary userInfo dari notification
    /// - Returns: Instance NotifSiswaDiedit jika data valid, nil jika tidak
    init?(userInfo: [AnyHashable: Any]) {
        guard let updateStudentID = userInfo["updateStudentID"] as? Int64,
              let kelasSekarang = userInfo["kelasSekarang"] as? String,
              let namaSiswa = userInfo["namaSiswa"] as? String
        else {
            print("Error: Invalid userInfo for NotifSiswaDiedit")
            return nil
        }

        self.updateStudentID = updateStudentID
        self.kelasSekarang = kelasSekarang
        self.namaSiswa = namaSiswa
    }

    /// Membuat instance payload langsung dengan data yang diperlukan.
    ///
    /// - Parameters:
    ///   - updateStudentID: ID siswa yang diedit
    ///   - kelasSekarang: Nama kelas siswa
    ///   - namaSiswa: Nama baru siswa
    init(updateStudentID: Int64, kelasSekarang: String, namaSiswa: String) {
        self.updateStudentID = updateStudentID
        self.kelasSekarang = kelasSekarang
        self.namaSiswa = namaSiswa
    }

    /// Mengirim notification untuk pengeditan data siswa.
    ///
    /// - Parameter updatedSiswa: ModelSiswa yang datanya telah diperbarui
    static func sendNotif(_ updatedSiswa: ModelSiswa) {
        let payload = NotifSiswaDiedit(
            updateStudentID: updatedSiswa.id,
            kelasSekarang: updatedSiswa.tingkatKelasAktif.rawValue,
            namaSiswa: updatedSiswa.nama
        )
        NotificationCenter.default.post(
            name: .dataSiswaDiEditDiSiswaView,
            object: nil,
            userInfo: payload.asUserInfo
        )
    }
}

/// Payload untuk notifikasi tindakan `undo` pengeditan data siswa.
///
/// `UndoActionNotification` merangkum semua informasi yang diperlukan untuk
/// mengembalikan perubahan data siswa, seperti ID siswa yang terpengaruh,
/// kolom yang diubah, dan posisi barisnya di tabel. `struct` ini mengadopsi
/// protokol ``NotificationPayload`` untuk memfasilitasi konversi data ke dan
/// dari format `userInfo` yang digunakan oleh `NotificationCenter`.
struct UndoActionNotification: NotificationPayload {
    /// ID unik dari siswa yang tindakan 'undo'-nya akan diproses.
    var id: Int64

    /// Indeks grup tempat siswa berada dalam mode tampilan berkelompok.
    ///
    /// Nilai ini bersifat opsional (`nil`) jika mode tampilan tabel bukan berkelompok.
    var groupIndex: Int?

    /// Indeks baris siswa di dalam grup atau bagiannya.
    ///
    /// Nilai ini bersifat opsional (`nil`) jika tidak diperlukan untuk mengidentifikasi baris.
    var rowIndex: Int?

    /// Pengidentifikasi kolom dari data siswa yang diubah.
    ///
    /// Digunakan untuk menentukan kolom mana yang perlu diperbarui di UI.
    var columnIdentifier: SiswaColumn

    /// Nilai baru yang akan diterapkan pada data siswa setelah tindakan 'undo'.
    ///
    /// Nilai ini bersifat opsional (`nil`) jika 'undo' tidak melibatkan
    /// pembaruan nilai spesifik.
    var newValue: String?

    /// Sebuah penanda yang menunjukkan apakah tindakan 'undo' ini berkaitan
    /// dengan mode tampilan tabel berkelompok.
    var isGrouped: Bool?

    /// Mengkonversi properti `struct` ini menjadi format `userInfo` yang valid untuk `NotificationCenter`.
    var asUserInfo: [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [
            "id": id,
            "columnIdentifier": columnIdentifier,
        ]

        if let groupIndex {
            userInfo["groupIndex"] = groupIndex
        }
        if let rowIndex {
            userInfo["rowIndex"] = rowIndex
        }
        if let newValue {
            userInfo["newValue"] = newValue
        }
        if let isGrouped {
            userInfo["isGrouped"] = isGrouped
        }

        return userInfo
    }

    /// Inisialisasi `struct` dari objek `userInfo` yang diterima dari `NotificationCenter`.
    ///
    /// - Parameter userInfo: Kamus (`Dictionary`) yang berisi data notifikasi.
    /// - Returns: Sebuah instance `UndoActionNotification` atau `nil` jika data wajib tidak ditemukan.
    init?(userInfo: [AnyHashable: Any]) {
        guard let id = userInfo["id"] as? Int64,
              let columnIdentifier = userInfo["columnIdentifier"] as? SiswaColumn
        else { return nil }

        self.id = id
        self.columnIdentifier = columnIdentifier
        groupIndex = userInfo["groupIndex"] as? Int
        rowIndex = userInfo["rowIndex"] as? Int
        newValue = userInfo["newValue"] as? String
        isGrouped = userInfo["isGrouped"] as? Bool
    }

    /// Inisialisasi standar untuk membuat objek `UndoActionNotification`.
    ///
    /// - Parameters:
    ///   - id: ID siswa.
    ///   - columnIdentifier: Pengidentifikasi kolom.
    ///   - groupIndex: Indeks grup (opsional).
    ///   - rowIndex: Indeks baris (opsional).
    ///   - newValue: Nilai baru yang akan diatur (opsional).
    ///   - isGrouped: Penanda mode berkelompok (opsional).
    init(id: Int64, columnIdentifier: SiswaColumn, groupIndex: Int? = nil, rowIndex: Int? = nil, newValue: String? = nil, isGrouped: Bool? = nil) {
        self.id = id
        self.columnIdentifier = columnIdentifier
        self.groupIndex = groupIndex
        self.rowIndex = rowIndex
        self.newValue = newValue
        self.isGrouped = isGrouped
    }

    /// Sebuah metode `static` untuk mengirim notifikasi `UndoActionNotification`.
    ///
    /// Metode ini menyediakan cara yang nyaman dan terstandarisasi untuk
    /// memublikasikan notifikasi, memastikan payload dibuat dengan benar.
    ///
    /// - Parameters:
    ///   - id: ID siswa yang akan dikirim.
    ///   - columnIdentifier: Kolom yang diubah.
    ///   - groupIndex: Indeks grup siswa (opsional).
    ///   - rowIndex: Indeks baris siswa (opsional).
    ///   - newValue: Nilai yang akan ditetapkan (opsional).
    ///   - isGrouped: Penanda mode group (opsional).
    static func sendNotif(_ id: Int64, columnIdentifier: SiswaColumn, groupIndex: Int? = nil, rowIndex: Int? = nil, newValue: String? = nil, isGrouped: Bool? = nil) {
        let payload = UndoActionNotification(
            id: id,
            columnIdentifier: columnIdentifier,
            groupIndex: groupIndex,
            rowIndex: rowIndex,
            newValue: newValue,
            isGrouped: isGrouped
        )

        NotificationCenter.default.post(
            name: .undoActionNotification,
            object: nil,
            userInfo: payload.asUserInfo
        )
    }
}

/// Payload notifikasi untuk pembaruan nilai kelas.
///
/// `NilaiKelasNotif` digunakan untuk mengirimkan informasi perubahan nilai
/// pada tabel kelas tertentu, termasuk kolom yang diubah, nilai baru,
/// dan ID siswa terkait (opsional).
///
/// Struktur ini mengimplementasikan `NotificationPayload` sehingga dapat
/// diparse secara type-safe dari `userInfo` pada `Notification`.
///
/// - Properties:
///   - tableType: Jenis tabel tempat nilai berada.
///   - columnIdentifier: Kolom yang nilainya diubah.
///   - idNilai: ID unik nilai yang diubah.
///   - dataBaru: Nilai baru dalam bentuk `String`.
///   - idSiswa: ID siswa terkait (opsional).
///
/// ### Contoh Mengirim Notifikasi
/// ```swift
/// NilaiKelasNotif.sendNotif(
///     tableType: .uts,
///     columnIdentifier: .nilaiTugas,
///     idNilai: 123,
///     dataBaru: "85",
///     idSiswa: 456
/// )
/// ```
///
/// ### Contoh Menerima Notifikasi
/// ```swift
/// NotificationCenter.default.addObserver(
///     forName: .updateDataKelas,
///     using: { (payload: NilaiKelasNotif) in
///         print("Nilai baru:", payload.dataBaru, "untuk siswa:", payload.idSiswa ?? 0)
///     }
/// )
/// ```
struct NilaiKelasNotif: NotificationPayload {
    // MARK: - Properti

    /// Tipe tabel tempat data diperbarui.
    var tableType: TableType

    /// Pengenal kolom tempat data diperbarui.
    var columnIdentifier: KelasColumn

    /// ID dari objek nilai yang diperbarui.
    var idNilai: Int64

    /// Nilai string baru dari data yang diperbarui.
    var dataBaru: String

    /// ID siswa terkait (opsional, `nil` jika tidak ada).
    var idSiswa: Int64?

    /// Mengonversi properti payload menjadi kamus `[AnyHashable : Any]` yang siap untuk `NotificationCenter`.
    var asUserInfo: [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [
            "tableType": tableType,
            "columnIdentifier": columnIdentifier,
            "idNilai": idNilai,
            "dataBaru": dataBaru,
        ]

        if let idSiswa {
            userInfo["idSiswa"] = idSiswa
        }

        return userInfo
    }

    // MARK: - Inisialisasi

    /// Menginisialisasi sebuah instance `NilaiKelasNotif` dari kamus `userInfo` notifikasi.
    ///
    /// - Parameter userInfo: Kamus yang berisi data notifikasi.
    /// - Returns: Sebuah instance `NilaiKelasNotif` jika data yang diperlukan tersedia, jika tidak `nil`.
    init?(userInfo: [AnyHashable: Any]) {
        guard let tableType = userInfo["tableType"] as? TableType,
              let columnIdentifier = userInfo["columnIdentifier"] as? KelasColumn,
              let idNilai = userInfo["idNilai"] as? Int64,
              let dataBaru = userInfo["dataBaru"] as? String
        else { return nil }

        self.tableType = tableType
        self.columnIdentifier = columnIdentifier
        self.idNilai = idNilai
        self.dataBaru = dataBaru
        idSiswa = userInfo["idSiswa"] as? Int64
    }

    /// Menginisialisasi sebuah instance `NilaiKelasNotif` dengan nilai-nilai yang ditentukan.
    ///
    /// - Parameters:
    ///   - tableType: Tipe tabel yang diperbarui.
    ///   - columnIdentifier: Pengenal kolom yang diperbarui.
    ///   - idNilai: ID nilai yang diperbarui.
    ///   - dataBaru: Nilai string baru.
    ///   - idSiswa: ID siswa terkait (opsional).
    init(tableType: TableType, columnIdentifier: KelasColumn, idNilai: Int64, dataBaru: String, idSiswa: Int64? = nil) {
        self.tableType = tableType
        self.columnIdentifier = columnIdentifier
        self.idNilai = idNilai
        self.dataBaru = dataBaru
        self.idSiswa = idSiswa
    }

    // MARK: - Fungsi Statis

    /// Mengirim notifikasi pembaruan nilai kelas ke `NotificationCenter`.
    ///
    /// - Parameters:
    ///   - tableType: Tipe tabel yang diperbarui.
    ///   - columnIdentifier: Pengenal kolom yang diperbarui.
    ///   - idNilai: ID nilai yang diperbarui.
    ///   - dataBaru: Nilai string baru.
    ///   - idSiswa: ID siswa terkait (opsional).
    static func sendNotif(tableType: TableType, columnIdentifier: KelasColumn, idNilai: Int64, dataBaru: String, idSiswa: Int64? = nil) {
        let payload = NilaiKelasNotif(
            tableType: tableType,
            columnIdentifier: columnIdentifier,
            idNilai: idNilai,
            dataBaru: dataBaru,
            idSiswa: idSiswa
        )

        NotificationCenter.default.post(
            name: .updateDataKelas,
            object: nil,
            userInfo: payload.asUserInfo
        )
    }
}

/// Payload notifikasi untuk penghapusan nilai kelas.
///
/// `DeleteNilaiKelasNotif` digunakan untuk mengirimkan informasi penghapusan
/// satu atau lebih nilai dari tabel kelas tertentu.
///
/// - Properties:
///   - tableType: Jenis tabel tempat nilai berada.
///   - nilaiIDs: Array ID nilai yang dihapus.
///
/// ### Contoh Mengirim Notifikasi
/// ```swift
/// DeleteNilaiKelasNotif.sendNotif(
///     tableType: .uas,
///     nilaiIDs: [101, 102, 103],
///     notificationName: .deleteDataKelas
/// )
/// ```
///
/// ### Contoh Menerima Notifikasi
/// ```swift
/// NotificationCenter.default.addObserver(
///     forName: .deleteDataKelas,
///     using: { (payload: DeleteNilaiKelasNotif) in
///         print("Nilai yang dihapus:", payload.nilaiIDs)
///     }
/// )
/// ```
struct DeleteNilaiKelasNotif: NotificationPayload {
    // MARK: - Properti

    /// Tipe tabel dari mana nilai-nilai tersebut dihapus.
    var tableType: TableType

    /// Array ID dari nilai-nilai yang telah dihapus.
    var nilaiIDs: [Int64]

    /// Mengubah payload notifikasi menjadi `UserInfo` yang kompatibel dengan `NotificationCenter`.
    var asUserInfo: [AnyHashable: Any] {
        [
            "tableType": tableType,
            "nilaiIDs": nilaiIDs,
        ]
    }

    // MARK: - Inisialisasi

    /// Inisialisasi dari kamus `userInfo` notifikasi.
    ///
    /// - Parameter userInfo: Kamus yang berisi data notifikasi.
    /// - Returns: Sebuah instance `DeleteNilaiKelasNotif` jika data valid, jika tidak `nil`.
    init?(userInfo: [AnyHashable: Any]) {
        guard let tableType = userInfo["tableType"] as? TableType,
              let nilaiIDs = userInfo["nilaiIDs"] as? [Int64]
        else { return nil }

        self.tableType = tableType
        self.nilaiIDs = nilaiIDs
    }

    /// Inisialisasi dengan data yang ditentukan.
    ///
    /// - Parameters:
    ///   - tableType: Tipe tabel yang relevan.
    ///   - nilaiIDs: Array ID dari nilai-nilai yang dihapus.
    init(tableType: TableType, nilaiIDs: [Int64]) {
        self.tableType = tableType
        self.nilaiIDs = nilaiIDs
    }

    // MARK: - Fungsi Statis

    /// Mengirimkan notifikasi penghapusan nilai ke `NotificationCenter`.
    ///
    /// - Parameters:
    ///   - tableType: Tipe tabel dari mana nilai-nilai dihapus.
    ///   - nilaiIDs: Array ID dari nilai-nilai yang dihapus.
    ///   - notificationName: Nama notifikasi yang akan diposting.
    static func sendNotif(tableType: TableType, nilaiIDs: [Int64], notificationName: Notification.Name) {
        let payload = DeleteNilaiKelasNotif(
            tableType: tableType,
            nilaiIDs: nilaiIDs
        )

        NotificationCenter.default.post(name: notificationName, object: nil, userInfo: payload.asUserInfo)
    }
}
