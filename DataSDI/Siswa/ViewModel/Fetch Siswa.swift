//
//  Fetch Siswa.swift
//  Data SDI
//
//  Created by MacBook on 19/09/25.
//

import Foundation

extension SiswaViewModel {
    /// Mengambil ID siswa dari baris yang dipilih dari ``dataSource``.
    ///
    /// - Parameter selectedRowIndexes: `IndexSet` berisi indeks baris yang dipilih.
    /// - Returns: `Set<Int64>` berisi ID siswa yang sesuai dengan baris yang dipilih.
    func updateSelectedIDs(_ selectedRowIndexes: IndexSet) -> Set<Int64> {
        dataSource.siswaIDs(in: selectedRowIndexes)
    }

    /// Mengambil `IndexSet` berdasarkan kumpulan ID siswa yang dipilih dari ``dataSource``.
    ///
    /// - Parameter selectedIds: `Set<Int64>` berisi ID siswa yang dipilih.
    /// - Returns: `IndexSet` berisi indeks baris yang sesuai dengan ID siswa tersebut.
    func getIndexSetForSelection(_ selectedIds: Set<Int64>) -> IndexSet {
        dataSource.indexSet(for: selectedIds)
    }

    /// Mengambil array siswa berdasarkan kumpulan indeks baris dari ``dataSource``.
    ///
    /// - Parameter indexes: `IndexSet` berisi indeks baris siswa.
    /// - Returns: Array ``ModelSiswa`` sesuai urutan indeks yang diberikan.
    func siswa(in indexes: IndexSet) -> [ModelSiswa] {
        dataSource.siswa(in: indexes)
    }

    /// Mengambil objek siswa berdasarkan ID unik dari ``dataSource``.
    ///
    /// - Parameter id: ID siswa.
    /// - Returns: Objek ``ModelSiswa`` jika ditemukan, atau `nil` jika tidak ada yang cocok.
    func siswa(for id: Int64) -> ModelSiswa? {
        dataSource.siswa(for: id)
    }

    /// Mengambil data siswa yang telah diedit secara asinkronus dan paralel.
    ///
    /// Fungsi ini membandingkan data snapshot siswa (`snapshotSiswas`) dengan data
    /// terbaru yang ada di database. Dengan menggunakan `withTaskGroup`, fungsi ini
    /// secara efisien mengambil data setiap siswa dari database secara paralel,
    /// yang secara signifikan meningkatkan kinerja untuk daftar siswa yang besar.
    ///
    /// - Parameter snapshotSiswas: Array dari ``ModelSiswa`` yang mewakili data
    ///   siswa sebelum perubahan.
    /// - Returns: Sebuah array dari tuple, di mana setiap tuple berisi
    ///   `snapshot` (data lama) dan `databaseData` (data terbaru dari database).
    func fetchEditedSiswa(snapshotSiswas: [ModelSiswa]) async -> [(snapshot: ModelSiswa, databaseData: ModelSiswa)] {
        // Pre-fetch semua data siswa secara parallel
        let siswaResults = await withTaskGroup(of: (ModelSiswa, ModelSiswa).self) { group -> [(ModelSiswa, ModelSiswa)] in
            for snapshotSiswa in snapshotSiswas {
                group.addTask {
                    let databaseData = await self.dbController.getSiswaAsync(idValue: snapshotSiswa.id)
                    return (snapshotSiswa, databaseData)
                }
            }

            var results: [(ModelSiswa, ModelSiswa)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        return siswaResults
    }
}
