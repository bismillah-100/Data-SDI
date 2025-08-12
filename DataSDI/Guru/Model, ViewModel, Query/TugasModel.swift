//
//  TugasModel.swift
//  Data SDI
//
//  Created by MacBook on 21/07/25.
//

import SQLite

/// Model yang merepresentasikan penugasan guru pada mata pelajaran dan kelas tertentu.
/// - Parameter id: ID penugasan.
/// - Parameter idGuru: ID guru yang diberikan penugasan.
/// - Parameter idJabatan: ID jabatan guru.
/// - Parameter idMapel: ID mata pelajaran yang diampu.
/// - Parameter idKelas: ID kelas tempat penugasan.
/// - Parameter tanggalMulai: Tanggal mulai penugasan.
/// - Parameter tanggalSelesai: Tanggal selesai penugasan (bisa bernilai null).
/// - Parameter status: Status penugasan, contoh: "Aktif".
struct PenugasanModel {
    /// Inisialisasi model dari baris database.
    /// - Parameter row: Baris database yang berisi data penugasan guru.
    init(row: Row) {
        // id = row[PenugasanGuruMapelKelasColumns.id]
        // idGuru = row[PenugasanGuruMapelKelasColumns.idGuru]
        idJabatan = row[PenugasanGuruMapelKelasColumns.idJabatan]
        idMapel = row[PenugasanGuruMapelKelasColumns.idMapel]
        // idKelas = row[PenugasanGuruMapelKelasColumns.idKelas]
        tanggalMulai = row[PenugasanGuruMapelKelasColumns.tanggalMulaiEfektif]
        tanggalSelesai = row[PenugasanGuruMapelKelasColumns.tanggalSelesaiEfektif]
        status = StatusSiswa(rawValue: row[PenugasanGuruMapelKelasColumns.statusPenugasan])?.description ?? "Aktif"
    }

    // let id: Int64
    // let idGuru: Int64
    let idJabatan: Int64
    let idMapel: Int64
    // let idKelas: Int64
    let tanggalMulai: String
    let tanggalSelesai: String?
    let status: String
}

/// Struktur untuk memperbarui penugasan guru, berisi informasi jabatan dan mata pelajaran.
/// - Parameter idJabatan: ID jabatan guru.
/// - Parameter idMapel: ID mata pelajaran yang diampu.
struct UpdatePenugasanGuru {
    var idJabatan: Int64 = 0
    var idMapel: Int64 = 0
}

// MARK: - Tabel Penugasan_Guru_Mapel_Kelas

/// Struktur `PenugasanGuruMapelKelasColumns` berfungsi sebagai representasi kolom-kolom pada tabel `penugasan_guru_mapel_kelas` di database.
///
/// Kolom-kolom yang tersedia:
/// - `tabel`: Referensi ke tabel `penugasan_guru_mapel_kelas`.
/// - `id`: Kolom 'id_penugasan', sebagai primary key.
/// - `idGuru`: Kolom 'id_guru', merujuk ke `guru.id`.
/// - `idJabatan`: Kolom 'id_jabatan', merujuk ke `jabatan.id`.
/// - `idMapel`: Kolom 'id_mapel', merujuk ke `mapel.id`.
/// - `idKelas`: Kolom 'id_kelas', merujuk ke `kelas.id`.
/// - `tanggalMulaiEfektif`: Kolom 'tanggal_mulai_efektif', menyimpan tanggal mulai penugasan.
/// - `tanggalSelesaiEfektif`: Kolom 'tanggal_selesai_efektif', menyimpan tanggal selesai penugasan (bisa bernilai null).
/// - `statusPenugasan`: Kolom 'status_penugasan', contoh: "Aktif".
enum PenugasanGuruMapelKelasColumns {
    /// Representasi objek tabel `penugasan_guru_mapel_kelas` di *database*.
    static let tabel: Table = .init("penugasan_guru_mapel_kelas")
    /// Kolom 'id_penugasan' pada tabel `penugasan_guru_mapel_kelas`.
    static let id: Expression<Int64> = .init("id_penugasan")
    /// Kolom 'id_guru' pada tabel `penugasan_guru_mapel_kelas`, merujuk ke `guru.id`.
    static let idGuru: Expression<Int64> = .init("id_guru")
    /// Kolom "id_jabatan' pada tabel `penugasan_guru_mapel_kelas`, merujuk ke `jabatan.id`.
    static let idJabatan: Expression<Int64> = .init("id_jabatan")
    /// Kolom 'id_mapel' pada tabel `penugasan_guru_mapel_kelas`, merujuk ke `mapel.id`.
    static let idMapel: Expression<Int64> = .init("id_mapel")
    /// Kolom 'id_kelas' pada tabel `penugasan_guru_mapel_kelas`, merujuk ke `kelas.id`.
    static let idKelas: Expression<Int64> = .init("id_kelas")
    /// Kolom 'tanggal_mulai_efektif' pada tabel `penugasan_guru_mapel_kelas`.
    static let tanggalMulaiEfektif: Expression<String> = .init("tanggal_mulai_efektif")
    /// Kolom 'tanggal_selesai_efektif' pada tabel `penugasan_guru_mapel_kelas`, bisa bernilai null.
    static let tanggalSelesaiEfektif: Expression<String?> = .init("tanggal_selesai_efektif")
    /// Kolom 'status_penugasan' pada tabel `penugasan_guru_mapel_kelas`, contoh: "Aktif".
    static let statusPenugasan: Expression<Int> = .init("status_penugasan")
}
