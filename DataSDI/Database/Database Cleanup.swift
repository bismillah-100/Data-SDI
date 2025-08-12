//
//  Database Orphaned.swift
//  Data SDI
//
//  Created by MacBook on 25/07/25.
//

import Foundation

extension DatabaseController {
    func tabelNoRelationCleanup() async {
        tabelMapelCleanup()
        tablePenugasanGuruCleanup()
        tabelKelasCleanup()
        tabelSiswaKelasCleanup()
    }

    private func tabelKelasCleanup() {
        guard UserDefaults.standard.bool(forKey: "bersihkanTabelKelas") else { return }
        // SQL untuk menghapus kelas yang tidak punya relasi di siswa_kelas
        let deleteKelasOrphanSQL = """
        DELETE FROM kelas
        WHERE idKelas NOT IN (
            SELECT DISTINCT id_kelas FROM siswa_kelas
        );
        """

        do {
            try db.execute(deleteKelasOrphanSQL)
        } catch {
            #if DEBUG
                print("Gagal menghapus orphan kelas: \(error)")
            #endif
        }
    }

    private func tabelSiswaKelasCleanup() {
        guard UserDefaults.standard.bool(forKey: "bersihkanTabelSiswaKelas") else { return }
        let deleteSiswaKelasOrphanSQL = """
        DELETE FROM siswa_kelas
        WHERE id_siswa NOT IN (
            SELECT DISTINCT id FROM siswa
        );
        """

        do {
            try db.execute(deleteSiswaKelasOrphanSQL)
            #if DEBUG
                print("Orphan kelas berhasil dihapus")
            #endif
        } catch {
            #if DEBUG
                print("Gagal menghapus orphan kelas: \(error)")
            #endif
        }
    }

    private func tabelMapelCleanup() {
        guard UserDefaults.standard.bool(forKey: "bersihkanTabelMapel") else { return }
        do {
            db.busyTimeout = 5.0
            db.busyHandler { tries in tries < 3 }

            // Hapus mapel yang tidak direferensikan di penugasan
            let sql = """
                DELETE FROM mapel
                WHERE id_mapel NOT IN (
                    SELECT DISTINCT id_mapel
                    FROM penugasan_guru_mapel_kelas
                );
            """
            try db.execute(sql)

            #if DEBUG
                print("Orphan mapel dibersihkan.")
            #endif

        } catch {
            #if DEBUG
                print("Gagal pembersihan orphan mapel: \(error)")
            #endif
        }
    }

    private func tablePenugasanGuruCleanup() {
        guard UserDefaults.standard.bool(forKey: "bersihkanTabelTugas") else { return }
        do {
            // Opsional: pakai serialized mode
            db.busyTimeout = 5.0
            db.busyHandler { tries in
                tries < 3
            }

            // Eksekusi raw SQL DELETE orphan
            let sql = """
                DELETE FROM penugasan_guru_mapel_kelas
                WHERE id_penugasan NOT IN (
                    SELECT DISTINCT id_penugasan_guru_mapel_kelas
                    FROM nilai_siswa_mapel
                );
            """
            try db.execute(sql)

            #if DEBUG
                print("Orphan penugasan guru dibersihkan (koneksi baru).")
            #endif
        } catch {
            #if DEBUG
                print("Gagal pembersihan penugasan orphan: \(error)")
            #endif
        }
    }
}
