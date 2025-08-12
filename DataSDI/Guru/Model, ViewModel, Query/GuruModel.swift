//
//  GuruModel.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 19/10/23.
//

import Foundation
import SQLite

/// `GuruModel` adalah kelas yang merepresentasikan data seorang guru.
///
/// Kelas ini mengimplementasikan protokol `Comparable` dan `Equatable`, memungkinkan
/// instance `GuruModel` untuk dibandingkan dan dicek kesetaraannya.
///
/// - Properti:
///   - `idGuru`: `Int64` yang unik untuk setiap guru. Digunakan dalam perbandingan dan kesetaraan.
///   - `namaGuru`: Nama lengkap guru.
///   - `alamatGuru`: Alamat tempat tinggal guru.
///   - `tahunaktif`: Tahun di mana guru aktif mengajar.
///   - `mapel`: Mata pelajaran yang diajar oleh guru.
///   - `struktural`: Posisi struktural atau jabatan guru (misalnya, "Kepala Sekolah", "Guru Kelas").
///   - `menuNeedsUpdate`: Sebuah flag `Bool` yang bisa digunakan untuk menandakan apakah UI terkait guru perlu diperbarui.
///
/// - Catatan:
///   Implementasi `Comparable` dan `Equatable` mempertimbangkan *semua* properti yang didefinisikan.
///   Metode `copy()` menyediakan cara untuk membuat salinan *deep copy* dari instance `GuruModel`.
class GuruModel: Comparable, Equatable, Hashable {
    /// Inisialisasi `GuruModel` dari satu baris result raw‑SQL.
    /// - Parameter row: Array binding hasil `stmt`, dengan urutan kolom:
    ///   0: id_guru, 1: nama_guru, 2: alamat_guru,
    ///   3: nama_jabatan, 4: nama_mapel,
    ///   5: tahun_ajaran, 6: tingkat_kelas, 7: nama_kelas, 8: semester,
    ///   9: id_penugasan, 10: status_penugasan,
    ///   11: tanggal_mulai_efektif, 12: tanggal_selesai_efektif
    convenience init?(from row: [Binding?]) {
        guard row.count >= 13 else { return nil }
        // Ambil ID dan ID tugas dari konstruktor utama
        let idGuru = row[0] as? Int64 ?? -1
        let idTugas = row[9] as? Int64 ?? -1
        self.init(idGuru: idGuru, idTugas: idTugas)

        // Set properti dasar
        namaGuru = StringInterner.shared.intern(row[1] as? String ?? "")
        alamatGuru = row[2] as? String // bisa nil

        // Hanya untuk tampilan guruVC = false
        struktural = StringInterner.shared.intern(row[3] as? String ?? "")
        mapel = row[4] as? String ?? ""
        tahunaktif = StringInterner.shared.intern(row[5] as? String ?? "")

        // Gabungkan kelas + semester
        let tingkat = row[6] as? String ?? ""
        let namaKls = row[7] as? String ?? ""
        let sem = row[8] as? String ?? ""
        kelas = "\(tingkat) \(namaKls) – Semester \(sem)"

        // Status & tanggal penugasan
        if let statusInt = row[10] as? Int {
            statusTugas = StatusSiswa(rawValue: statusInt) ?? .aktif
        } else if let statusInt64 = row[10] as? Int64 {
            statusTugas = StatusSiswa(rawValue: Int(statusInt64)) ?? .aktif
        } else {
            statusTugas = .aktif
        }
        tglMulai = row[11] as? String ?? ""
        tglSelesai = row[12] as? String // bisa nil
    }

    convenience init?(fromGuruOnlyRow row: [Binding?]) {
        guard row.count >= 3 else { return nil }
        let idGuru = row[0] as? Int64 ?? 0
        self.init(idGuru: idGuru, idTugas: -1)

        namaGuru = StringInterner.shared.intern(row[1] as? String ?? "")
        alamatGuru = row[2] as? String
    }

    // MARK: - Properti

    /// ID unik guru di database
    let idGuru: Int64
    /// ID unik penugasan guru
    let idTugas: Int64
    /// Nama guru
    var namaGuru: String = ""
    /// Alamat guru
    var alamatGuru: String?
    /// Tahun aktif guru
    var tahunaktif: String?
    /// Mata pelajaran guru
    var mapel: String?
    /// Jabatan guru
    var struktural: String?
    /// Status tugas guru.
    var statusTugas: StatusSiswa = .aktif
    /// Kelas tempat guru mengajar
    var kelas: String?
    /// Tanggal mulai tugas guru
    var tglMulai: String?
    /// Tanggal selesai tugas guru
    var tglSelesai: String?

    // MARK: - Inisialisasi

    /// Menginisialisasi instance `GuruModel` kosong dengan nilai default.
    init(idGuru: Int64, idTugas: Int64) {
        self.idGuru = idGuru
        self.idTugas = idTugas
    }

    /// Menginisialisasi instance `GuruModel` dengan detail yang diberikan.
    ///
    /// - Parameters:
    ///   - idGuru: ID unik guru.
    ///   - nama: Nama lengkap guru.
    ///   - alamat: Alamat guru.
    ///   - tahunaktif: Tahun aktif guru.
    ///   - mapel: Mata pelajaran yang diajar.
    ///   - struktural: Posisi struktural guru.
    init(idGuru: Int64, idTugas: Int64? = nil, nama: String, alamat: String? = nil, tahunaktif: String? = nil, mapel: String? = nil, struktural: String? = nil, statusTugas: StatusSiswa? = nil, kelas: String? = nil, tglMulai: String? = nil, tglSelesai: String? = nil) {
        self.idGuru = idGuru
        if let idTugas {
            self.idTugas = idTugas
        } else {
            self.idTugas = -1
        }
        namaGuru = StringInterner.shared.intern(nama)
        if let alamat {
            alamatGuru = alamat
        }
        if let tahunaktif {
            self.tahunaktif = tahunaktif
        }
        if let mapel {
            self.mapel = StringInterner.shared.intern(mapel)
        }
        if let struktural {
            self.struktural = StringInterner.shared.intern(struktural)
        }
        if let statusTugas {
            self.statusTugas = statusTugas
        }
        if let kelas {
            self.kelas = StringInterner.shared.intern(kelas)
        }
        if let tglMulai {
            self.tglMulai = tglMulai
        }
        if let tglSelesai {
            self.tglSelesai = tglSelesai
        }
    }

    // --- Metode Protokol Hashable (Implisit dari Equatable) ---
    /// Metode ini menyediakan cara untuk membuat nilai hash dari objek ``GuruModel``
    /// berdasarkan ``idGuru`` dan ``idTugas``. Ini penting saat
    /// menggunakan ``GuruModel`` dalam koleksi seperti `Set` atau sebagai kunci dalam `Dictionary`.
    func hash(into hasher: inout Hasher) {
        hasher.combine(idGuru)
        hasher.combine(idTugas)
    }

    // MARK: - Implementasi Protokol Comparable

    /// Mengimplementasikan operator "kurang dari" (`<`) untuk `GuruModel`.
    ///
    /// Dua `GuruModel` dianggap "kurang dari" jika semua properti (`idGuru`, `namaGuru`,
    /// `alamatGuru`, `mapel`, `tahunaktif`, `struktural`) dari `lhs` secara leksikografis
    /// atau numerik kurang dari `rhs`.
    ///
    /// - Parameters:
    ///   - lhs: `GuruModel` di sisi kiri operator.
    ///   - rhs: `GuruModel` di sisi kanan operator.
    /// - Returns: `true` jika `lhs` dianggap "kurang dari" `rhs` berdasarkan perbandingan semua properti.
    static func < (lhs: GuruModel, rhs: GuruModel) -> Bool {
        lhs.idGuru < rhs.idGuru &&
            lhs.idTugas < rhs.idTugas &&
            lhs.namaGuru < rhs.namaGuru &&
            (lhs.alamatGuru ?? "") < (rhs.alamatGuru ?? "") &&
            (lhs.mapel ?? "") < (rhs.mapel ?? "") &&
            (lhs.tahunaktif ?? "") < (rhs.tahunaktif ?? "") &&
            (lhs.struktural ?? "") < (rhs.struktural ?? "") &&
            lhs.statusTugas < rhs.statusTugas &&
            (lhs.kelas ?? "") < (rhs.kelas ?? "") &&
            (lhs.tglMulai ?? "") < (rhs.tglMulai ?? "") &&
            (lhs.tglSelesai ?? "") < (rhs.tglSelesai ?? "")
    }

    // MARK: - Implementasi Protokol Equatable

    /// Mengimplementasikan operator kesetaraan (`==`) untuk `GuruModel`.
    ///
    /// Dua `GuruModel` dianggap sama jika *semua* properti (``idGuru`` dan ``idTugas``) mereka sama.
    ///
    /// - Parameters:
    ///   - lhs: `GuruModel` di sisi kiri operator.
    ///   - rhs: `GuruModel` di sisi kanan operator.
    /// - Returns: `true` jika kedua guru memiliki nilai properti yang sama, `false` jika sebaliknya.
    static func == (lhs: GuruModel, rhs: GuruModel) -> Bool {
        lhs.idGuru == rhs.idGuru &&
            lhs.idTugas == rhs.idTugas
    }

    // MARK: - Metode Lainnya

    /// Membuat salinan (deep copy) baru dari instance `GuruModel` saat ini.
    ///
    /// Ini sangat berguna ketika Anda perlu memodifikasi objek `GuruModel` tanpa
    /// memengaruhi instance aslinya, karena `GuruModel` adalah *reference type* (kelas).
    ///
    /// - Returns: Instance `GuruModel` baru dengan nilai properti yang sama dengan instance saat ini.
    func copy() -> GuruModel {
        let newCopy = GuruModel(idGuru: idGuru, idTugas: idTugas)
        newCopy.namaGuru = namaGuru
        newCopy.alamatGuru = alamatGuru
        newCopy.tahunaktif = tahunaktif
        newCopy.mapel = mapel
        newCopy.struktural = struktural
        newCopy.statusTugas = statusTugas
        newCopy.kelas = kelas
        newCopy.tglMulai = tglMulai
        newCopy.tglSelesai = tglSelesai
        return newCopy
    }
}

extension GuruModel {
    /// Membandingkan objek `GuruModel` ini dengan objek lain menggunakan kunci dan urutan dari `NSSortDescriptor`.
    ///
    /// - Parameter other: Objek `GuruModel` lain yang akan dibandingkan.
    /// - Parameter sortDescriptor: `NSSortDescriptor` yang menentukan kunci pengurutan dan arah ascending/descending.
    /// - Returns: Nilai `ComparisonResult`:
    ///   - `.orderedAscending` jika objek ini harus berada sebelum objek lain.
    ///   - `.orderedDescending` jika objek ini harus berada setelah objek lain.
    ///   - `.orderedSame` jika keduanya setara dalam urutan.
    func compare(to other: GuruModel, using sortDescriptor: NSSortDescriptor) -> ComparisonResult {
        let asc = sortDescriptor.ascending
        let key = sortDescriptor.key ?? ""

        switch key {
        case "NamaGuru":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(namaGuru, other.namaGuru, asc: asc),
                ReusableFunc.cmp(alamatGuru ?? "", other.alamatGuru ?? "")
            )

        case "AlamatGuru":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(alamatGuru ?? "", other.alamatGuru ?? "", asc: asc),
                ReusableFunc.cmp(namaGuru, other.namaGuru)
            )

        case "TahunAktif":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(tahunaktif ?? "", other.tahunaktif ?? "", asc: asc),
                ReusableFunc.cmp(namaGuru, other.namaGuru)
            )

        case "Mapel":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(mapel ?? "", other.mapel ?? "", asc: asc),
                ReusableFunc.cmp(tahunaktif ?? "", other.tahunaktif ?? "")
            )

        case "Struktural":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(struktural ?? "", other.struktural ?? "", asc: asc),
                ReusableFunc.cmp(namaGuru, other.namaGuru)
            )

        case "Status":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(statusTugas, other.statusTugas, asc: asc),
                ReusableFunc.cmp(namaGuru, other.namaGuru)
            )

        case "Kelas":
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(kelas ?? "", other.kelas ?? "", asc: asc),
                ReusableFunc.cmp(namaGuru, other.namaGuru)
            )

        case "Tgl. Mulai":
            // Asumsi tglMulai adalah String yang bisa di-convert ke Date
            let dateL = ReusableFunc.dateFormatter?.date(from: tglMulai ?? "") ?? .distantPast
            let dateR = ReusableFunc.dateFormatter?.date(from: other.tglMulai ?? "") ?? .distantPast
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(dateL, dateR, asc: asc),
                ReusableFunc.cmp(namaGuru, other.namaGuru)
            )

        case "Tgl. Selesai":
            // Asumsi tglSelesai adalah String yang bisa di-convert ke Date
            let dateL = ReusableFunc.dateFormatter?.date(from: tglSelesai ?? "") ?? .distantPast
            let dateR = ReusableFunc.dateFormatter?.date(from: other.tglSelesai ?? "") ?? .distantPast
            return ReusableFunc.firstNonSame(
                ReusableFunc.cmp(dateL, dateR, asc: asc),
                ReusableFunc.cmp(namaGuru, other.namaGuru)
            )

        default:
            return .orderedSame
        }
    }
}

extension [GuruModel] {
    /// Menemukan indeks penyisipan yang tepat untuk sebuah elemen baru dalam array,
    /// mempertahankan urutan yang ditentukan oleh `NSSortDescriptor`.
    ///
    /// Fungsi ini mengiterasi elemen-elemen yang ada dan membandingkan properti kunci
    /// dari elemen yang akan disisipkan (`element`) dengan properti yang sama dari
    /// setiap item yang sudah ada (`item`). Perbandingan ini disesuaikan dengan
    /// arah pengurutan (`ascending` atau `descending`) yang ditentukan oleh `sortDescriptor`.
    /// Untuk kasus di mana properti kunci utama sama, fungsi ini menggunakan `namaGuru`
    /// sebagai kriteria pengurutan sekunder untuk memastikan pengurutan yang stabil.
    ///
    /// - Parameter element: **Elemen** baru yang akan disisipkan ke dalam array.
    /// - Parameter sortDescriptor: **`NSSortDescriptor`** yang mendefinisikan kunci (`key`)
    ///   untuk perbandingan utama dan arah pengurutan (`ascending`).
    ///
    /// - Returns: **Indeks (`Index`)** di mana `element` harus disisipkan untuk menjaga
    ///   urutan array yang benar. Jika `element` lebih besar dari semua elemen yang ada
    ///   (sesuai dengan kriteria pengurutan), maka akan mengembalikan `self.endIndex`.
    ///
    /// - Catatan:
    ///   - Fungsi ini mengasumsikan bahwa `Element` adalah tipe yang memiliki properti
    ///     `namaGuru`, `alamatGuru`, `tahunaktif`, `mapel`, dan `struktural`
    ///     yang semuanya berjenis `String`.
    ///   - Kriteria pengurutan sekunder selalu `namaGuru` ketika kunci utama sama,
    ///     kecuali ketika kunci utama adalah `namaGuru` itu sendiri, di mana `alamatGuru`
    ///     digunakan sebagai kriteria sekunder. Ini perlu dikonfirmasi apakah perilaku
    ///     ini yang diinginkan.
    func insertionIndex(for element: Element, using sortDescriptor: NSSortDescriptor) -> Index {
        firstIndex { $0.compare(to: element, using: sortDescriptor) == .orderedDescending } ?? endIndex
    }
}

// MARK: - Tabel Guru

/// Struktur `GuruColumns` digunakan untuk mendefinisikan representasi kolom-kolom pada tabel `guru` di database.
/// - `tabel`: Objek tabel `guru`.
/// - `id`: Kolom `id_guru` sebagai primary key bertipe `Int64`.
/// - `nama`: Kolom `nama_guru` bertipe `String`.
/// - `alamat`: Kolom `alamat_guru` yang dapat bernilai `null` (opsional) bertipe `String?`.
enum GuruColumns {
    /// Representasi objek tabel `guru` di *database*.
    static let tabel: Table = .init("guru")
    /// Kolom 'id_guru' pada tabel `guru`.
    static let id: Expression<Int64> = .init("id_guru")
    /// Kolom 'nama_guru' pada tabel `guru`.
    static let nama: Expression<String> = .init("nama_guru")
    /// Kolom 'alamat_guru' pada tabel `guru`, bisa bernilai null.
    static let alamat: Expression<String?> = .init("alamat_guru")
}

/// Struktur `JabatanColumns` digunakan untuk mendefinisikan kolom-kolom pada tabel `jabatan_guru` di database.
///
/// - Properti:
///   - tabel: Mendefinisikan tabel master `jabatan_guru`.
///   - id: Menyimpan ekspresi untuk kolom id unik jabatan (`id_jabatan`).
///   - nama: Menyimpan ekspresi untuk kolom nama jabatan (`nama`).
enum JabatanColumns {
    /// Tabel master jabatan guru.
    static let tabel: Table = .init("jabatan_guru")
    /// Id unik jabatan.
    static let id: Expression<Int64> = .init("id_jabatan")
    /// Nama jabatan.
    static let nama: Expression<String> = .init("nama")
}

// MARK: - GuruEvent

/// Representasi berbagai jenis perubahan atau peristiwa yang terjadi pada penugasan guru di tampilan.
///
/// Enum ini digunakan untuk memberitahu perubahan yang relevan agar UI atau data model dapat merespons secara tepat, seperti pembaruan nama, perpindahan guru, insert/hapus mapel dan guru, atau reload data penuh.
enum PenugasanGuruEvent {
    /// Menandakan bahwa nama mapel telah diperbarui.
    ///
    /// - Parameters:
    ///   - parentMapel: Mapel induk tempat nama diperbarui.
    ///   - index: Indeks dari guru dalam mapel tersebut.
    case updateNama(parentMapel: MapelModel, index: Int)

    /// Menandakan bahwa seorang guru telah dipindahkan dari satu lokasi ke lokasi lain, bisa antar-mapel atau di dalam mapel yang sama.
    ///
    /// - Parameters:
    ///   - at: Indeks asal guru.
    ///   - atParent: Mapel asal (bisa `nil` jika tidak ada).
    ///   - to: Indeks tujuan guru.
    ///   - toParent: Mapel tujuan (bisa `nil` jika tidak ada).
    case moved(at: Int, atParent: MapelModel?, to: Int, toParent: MapelModel?)

    /// Menandakan bahwa beberapa guru telah diperbarui, misalnya karena perubahan informasi.
    ///
    /// - Parameter items: Array berisi tuple dari mapel induk dan indeks guru yang diperbarui.
    case updated(items: [(parentMapel: MapelModel?, index: Int)])

    /// Menandakan bahwa beberapa guru dan mapel telah dihapus dari tampilan.
    ///
    /// - Parameters:
    ///   - gurus: Dictionary dengan mapel sebagai key dan array indeks guru yang dihapus.
    ///   - mapelIndices: Indeks mapel yang dihapus dari daftar.
    ///   - fallbackItem: Item cadangan (jika ada) untuk digunakan ketika data kosong, biasanya untuk menjaga kestabilan UI.
    case guruAndMapelRemoved(
        gurus: [MapelModel: [Int]],
        mapelIndices: [Int],
        fallbackItem: Any?
    )

    /// Menandakan bahwa beberapa guru dan mapel telah ditambahkan ke tampilan.
    ///
    /// - Parameters:
    ///   - mapelIndices: Indeks mapel yang baru dimasukkan.
    ///   - guruu: Dictionary dengan mapel sebagai key dan array tuple guru beserta indeks mereka dalam mapel.
    case guruAndMapelInserted(
        mapelIndices: [Int],
        guruu: [MapelModel: [(guru: GuruModel, index: Int)]]
    )

    /// Menandakan bahwa seluruh data perlu di-reload secara menyeluruh.
    ///
    /// Gunakan ini ketika perubahan terlalu besar atau kompleks untuk dijelaskan dengan `case` lain.
    case reloadData
}

/// Enum `GuruEvent` mendefinisikan berbagai peristiwa yang dapat terjadi pada model guru.
/// Peristiwa ini digunakan untuk mengelola perubahan pada data guru, seperti pembaruan
enum GuruEvent {
    /// Peristiwa ketika nama guru diperbarui.
    /// - Parameter update: Objek `GuruModel` yang telah diperbarui.
    case updatedNama(update: GuruModel)

    /// Menandakan bahwa beberapa item telah dipindahkan dan diperbarui sekaligus.
    ///
    /// Gunakan ini ketika satu batch operasi melibatkan pemindahan indeks dan juga pembaruan kontennya.
    ///
    /// - Parameters:
    ///   - updates: Indeks item yang diperbarui.
    ///   - moves: Daftar tuple yang menunjukkan pemindahan, dengan `from` sebagai indeks asal dan `to` sebagai indeks tujuan.
    case moveAndUpdate(updates: [Int], moves: [(from: Int, to: Int)])

    /// Menandakan bahwa sejumlah item baru telah disisipkan ke dalam daftar.
    ///
    /// - Parameter at: Indeks tempat item baru disisipkan.
    case insert(at: [Int])

    /// Menandakan bahwa sejumlah item telah dihapus dari daftar.
    ///
    /// - Parameter at: Indeks dari item yang dihapus.
    case remove(at: [Int])
}

// MARK: - Tabel Mapel

/// Struktur `MapelColumns` digunakan untuk merepresentasikan kolom-kolom pada tabel `mapel` di database.
///
/// - Properti `tabel`: Objek `Table` yang merepresentasikan tabel `mapel`.
/// - Properti `id`: Kolom bertipe `Int64` yang merepresentasikan `id_mapel` pada tabel.
/// - Properti `nama`: Kolom bertipe `String` yang merepresentasikan `nama_mapel` pada tabel.
enum MapelColumns {
    /// Representasi objek tabel `mapel` di *database*.
    static let tabel: Table = .init("mapel")
    /// Kolom 'id_mapel' pada tabel `mapel`.
    static let id: Expression<Int64> = .init("id_mapel")
    /// Kolom 'nama_mapel' pada tabel `mapel`.
    static let nama: Expression<String> = .init("nama_mapel")
}
