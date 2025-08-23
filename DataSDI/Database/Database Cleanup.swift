//
//  Database CleanUp.swift
//  Data SDI
//
//  Created by MacBook on 25/07/25.
//

import Foundation

extension DatabaseController {
    // Optional: ringkas flag per tabel
    fileprivate struct CleanupFlags {
        let mapel = UserDefaults.standard.bool(forKey: "bersihkanTabelMapel")
        let tugas = UserDefaults.standard.bool(forKey: "bersihkanTabelTugas")
        let kelas = UserDefaults.standard.bool(forKey: "bersihkanTabelKelas")
        let siswaKelas = UserDefaults.standard.bool(forKey: "bersihkanTabelSiswaKelas")
        var any: Bool { mapel || tugas || kelas || siswaKelas }
    }

    // Ringkas hasil pre-read (pakai count untuk audit/preview)
    fileprivate struct NoFKEntryCounts {
        var mapel = 0
        var tugas = 0
        var kelas = 0
        var siswaKelas = 0

        var total: Int { mapel + tugas + kelas + siswaKelas }
        var isEmpty: Bool { total == 0 }
    }

    // SQL DELETE final (pakai NOT EXISTS untuk aman dari NULL)
    fileprivate enum DeleteSQL {
        static let mapel = """
        DELETE FROM mapel AS m
        WHERE NOT EXISTS (
            SELECT 1 FROM penugasan_guru_mapel_kelas AS p
            WHERE p.id_mapel = m.id_mapel
        );
        """
        static let tugas = """
        DELETE FROM penugasan_guru_mapel_kelas AS p
        WHERE NOT EXISTS (
            SELECT 1 FROM nilai_siswa_mapel AS n
            WHERE n.id_penugasan_guru_mapel_kelas = p.id_penugasan
        );
        """
        static let kelas = """
        DELETE FROM kelas AS k
        WHERE NOT EXISTS (
            SELECT 1 FROM siswa_kelas AS sk
            WHERE sk.id_kelas = k.idKelas
        );
        """
        static let siswaKelas = """
        DELETE FROM siswa_kelas AS sk
        WHERE
            -- case 1: id_siswa sudah tidak ada di tabel siswa
            NOT EXISTS (
                SELECT 1
                FROM siswa AS s
                WHERE s.id = sk.id_siswa
            )

            OR

            -- case 2: status_enrollment != 1 dan ada row lain untuk siswa yang sama dengan status_enrollment = 1,
            --         serta belum punya entri nilai di nilai_siswa_mapel
            (
                sk.status_enrollment != 1
                AND EXISTS (
                    SELECT 1
                    FROM siswa_kelas AS sk2
                    WHERE sk2.id_siswa = sk.id_siswa
                      AND sk2.status_enrollment = 1
                    LIMIT 1
                )
                AND NOT EXISTS (
                    SELECT 1
                    FROM nilai_siswa_mapel AS n
                    WHERE n.id_siswa_kelas = sk.id_siswa_kelas
                )
            );
        """
    }

    // SQL COUNT untuk pre-read (mirror dari DELETE)
    fileprivate enum CountSQL {
        static let mapel = """
        SELECT COUNT(*) FROM mapel AS m
        WHERE NOT EXISTS (
            SELECT 1 FROM penugasan_guru_mapel_kelas AS p
            WHERE p.id_mapel = m.id_mapel
        );
        """
        static let tugas = """
        SELECT COUNT(*) FROM penugasan_guru_mapel_kelas AS p
        WHERE NOT EXISTS (
            SELECT 1 FROM nilai_siswa_mapel AS n
            WHERE n.id_penugasan_guru_mapel_kelas = p.id_penugasan
        );
        """
        static let kelas = """
        SELECT COUNT(*) FROM kelas AS k
        WHERE NOT EXISTS (
            SELECT 1 FROM siswa_kelas AS sk
            WHERE sk.id_kelas = k.idKelas
        );
        """
        static let siswaKelas = """
        SELECT COUNT(*) FROM siswa_kelas AS sk
        WHERE NOT EXISTS (
            SELECT 1 FROM siswa AS s
            WHERE s.id = sk.id_siswa
        );
        """
    }

    // Entry point: parallel read dulu, lalu single-connection delete
    func tabelNoRelationCleanup() async {
        let flags = CleanupFlags()
        guard flags.any else { return }

        do {
            // 1) Parallel read dengan pool.read untuk pre-audit
            let counts = try await preReadNoFKEntryCounts(flags: flags)

            // Early exit kalau tidak ada yang perlu dihapus
            guard !counts.isEmpty else { return }

            // 2) Single write connection + transaksi untuk semua DELETE
            //    Pakai koneksi `db` yang tunggal
            db.busyTimeout = 5.0
            db.busyHandler { tries in tries < 3 }

            if flags.mapel, counts.mapel > 0 {
                try db.execute(DeleteSQL.mapel)
                #if DEBUG
                    print("NoFKEntry mapel dihapus: \(counts.mapel)")
                #endif
            }
            if flags.tugas, counts.tugas > 0 {
                try db.execute(DeleteSQL.tugas)
                #if DEBUG
                    print("NoFKEntry penugasan dihapus: \(counts.tugas)")
                #endif
            }
            if flags.kelas, counts.kelas > 0 {
                try db.execute(DeleteSQL.kelas)
                #if DEBUG
                    print("NoFKEntry kelas dihapus: \(counts.kelas)")
                #endif
            }
            if flags.siswaKelas, counts.siswaKelas > 0 {
                try db.execute(DeleteSQL.siswaKelas)
                #if DEBUG
                    print("NoFKEntry siswa_kelas dihapus: \(counts.siswaKelas)")
                #endif
            }

        } catch {
            #if DEBUG
                print("Gagal pembersihan penugasan orphan: \(error)")
            #endif
        }
    }

    // MARK: - Parallel pre-read dengan withTaskGroup + pool.read

    private func preReadNoFKEntryCounts(flags: CleanupFlags) async throws -> NoFKEntryCounts {
        // TaskGroup hasilkan tuple (label, count)
        let results = try await withThrowingTaskGroup(of: (String, Int).self) { group -> [(String, Int)] in
            if flags.mapel {
                group.addTask {
                    let raw = try await DatabaseManager.shared.pool.read { db in
                        try db.scalar(CountSQL.mapel) as? Int64
                    }
                    return ("mapel", Int(raw ?? 0))
                }
            }

            if flags.tugas {
                group.addTask {
                    let raw = try await DatabaseManager.shared.pool.read { db in
                        try db.scalar(CountSQL.tugas) as? Int64
                    }
                    return ("tugas", Int(raw ?? 0))
                }
            }

            if flags.kelas {
                group.addTask {
                    let raw = try await DatabaseManager.shared.pool.read { db in
                        try db.scalar(CountSQL.kelas) as? Int64
                    }
                    return ("kelas", Int(raw ?? 0))
                }
            }

            if flags.siswaKelas {
                group.addTask {
                    let raw = try await DatabaseManager.shared.pool.read { db in
                        try db.scalar(CountSQL.siswaKelas) as? Int64
                    }
                    return ("siswaKelas", Int(raw ?? 0))
                }
            }

            // Kumpulkan semua hasil
            return try await group.reduce(into: [(String, Int)]()) { acc, element in
                acc.append(element)
            }
        }
        // Gabungkan hasil ke NoFKEntryCounts
        var counts = NoFKEntryCounts()
        for (label, value) in results {
            switch label {
            case "mapel": counts.mapel = value
            case "tugas": counts.tugas = value
            case "kelas": counts.kelas = value
            case "siswaKelas": counts.siswaKelas = value
            default: break
            }
        }
        return counts
    }
}
