//
//  Paste + Foto.swift
//  Data SDI
//
//  Created by MacBook on 18/09/25.
//

import Foundation

extension SiswaViewModel {
    /// Mem-parsing teks mentah dari clipboard menjadi array ``ModelSiswa`` dan daftar error.
    ///
    /// Fungsi ini akan:
    /// - Memisahkan baris berdasarkan newline.
    /// - Memisahkan kolom berdasarkan tab (`\t`) atau koma (`,`).
    /// - Mengisi properti ``ModelSiswa`` sesuai urutan kolom yang diberikan.
    /// - Mengabaikan kolom yang tidak memiliki setter.
    /// - Mengembalikan daftar siswa yang berhasil diparsing dan daftar error jika ada baris yang tidak valid.
    ///
    /// - Parameters:
    ///   - raw: String mentah dari clipboard.
    ///   - columnOrder: Urutan kolom (``SiswaColumn``) yang menentukan mapping data.
    /// - Returns: Tuple berisi array siswa (`siswas`) dan array pesan error (`errors`).
    func parseClipboard(_ raw: String, columnOrder: [SiswaColumn]) -> (siswas: [ModelSiswa], errors: [String]) {
        var siswaToAdd: [ModelSiswa] = []
        var errors: [String] = []

        // peta setter untuk setiap kolom. enum -> closure yang set properti.
        let setters: [SiswaColumn: (ModelSiswa, String) -> Void] = [
            .nama: { $0.nama = $1 },
            .alamat: { $0.alamat = $1 },
            .ttl: { $0.ttl = $1 },
            .namawali: { $0.namawali = $1 },
            .nis: { $0.nis = $1 },
            .nisn: { $0.nisn = $1 },
            .ayah: { $0.ayah = $1 },
            .ibu: { $0.ibu = $1 },
            .tlv: { $0.tlv = $1 },
            .tahundaftar: { $0.tahundaftar = $1 },
            .status: { $0.status = StatusSiswa.from(description: $1) ?? .aktif },
            .tanggalberhenti: { $0.tanggalberhenti = $1 },
            .jeniskelamin: { $0.jeniskelamin = JenisKelamin.from(description: $1) ?? .lakiLaki },
        ]

        let lines = raw.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let components: [String]
            if line.contains("\t") {
                components = line.components(separatedBy: "\t")
            } else if line.contains(",") {
                components = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            } else {
                errors.append("Format tidak valid: \(line)")
                continue
            }

            let siswa = ModelSiswa()
            for (i, rawValue) in components.enumerated() {
                guard i < columnOrder.count else { break } // lebih banyak field dari kolom, abaikan sisanya
                let col = columnOrder[i]
                let v = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                setters[col]?(siswa, v) // jika kolom tidak punya setter, diabaikan
            }

            siswaToAdd.append(siswa)
        }

        return (siswaToAdd, errors)
    }

    /// Menyimpan array siswa baru ke database.
    ///
    /// Fungsi ini akan:
    /// - Mengisi nilai default `tahundaftar` jika kosong.
    /// - Membuat ``SiswaDefaultData`` dari setiap ``ModelSiswa``.
    /// - Memanggil ``DatabaseController/catatSiswa(_:)`` untuk menyimpan ke database.
    /// - Mengembalikan salinan siswa yang sudah memiliki ID dari database.
    ///
    /// - Parameters:
    ///   - siswas: Array siswa yang akan dimasukkan ke database.
    ///   - foto: Data foto opsional yang akan disimpan untuk semua siswa.
    /// - Returns: Array ``ModelSiswa`` yang sudah memiliki ID dari database.
    func insertToDatabase(_ siswas: [ModelSiswa], foto: Data? = nil) -> [ModelSiswa] {
        var inserted: [ModelSiswa] = []
        for siswa in siswas {
            let tahundaftar = siswa.tahundaftar.isEmpty
                ? ReusableFunc.todayString()
                : siswa.tahundaftar

            let data: SiswaDefaultData = (
                nama: siswa.nama, alamat: siswa.alamat,
                ttl: siswa.ttl, tahundaftar: tahundaftar,
                namawali: siswa.namawali, nis: siswa.nis, nisn: siswa.nisn,
                ayah: siswa.ayah, ibu: siswa.ibu,
                jeniskelamin: siswa.jeniskelamin,
                status: siswa.status,
                tanggalberhenti: siswa.tanggalberhenti,
                tlv: siswa.tlv,
                foto: foto
            )
            if let id = dbController.catatSiswa(data),
               let copy = siswa.copy() as? ModelSiswa
            {
                copy.id = id
                inserted.append(copy)
            }
        }
        return inserted
    }

    /// Membuat entri siswa baru dari file gambar.
    ///
    /// Fungsi ini akan:
    /// - Membaca setiap file gambar dari `fileURLs`.
    /// - Mengompres gambar menjadi kualitas 0.5.
    /// - Menggunakan nama file sebagai nama siswa.
    /// - Mengisi data default lainnya.
    /// - Menyimpan ke database dan mengembalikan array siswa baru.
    ///
    /// - Parameter fileURLs: Array URL file gambar.
    /// - Returns: Array ``ModelSiswa`` yang berhasil dibuat dari file gambar.
    func pasteSiswas(from fileURLs: [URL]) -> [ModelSiswa] {
        var newSiswas: [ModelSiswa] = []
        for fileURL in fileURLs {
            if let image = NSImage(contentsOf: fileURL) {
                let compressedImageData = image.compressImage(quality: 0.5) ?? Data()
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                let currentDate = ReusableFunc.todayString()

                let data: SiswaDefaultData = (
                    nama: fileName,
                    alamat: "", ttl: "", tahundaftar: currentDate,
                    namawali: "", nis: "", nisn: "",
                    ayah: "", ibu: "",
                    jeniskelamin: .lakiLaki,
                    status: .aktif,
                    tanggalberhenti: "", tlv: "",
                    foto: compressedImageData
                )
                if let id = dbController.catatSiswa(data) {
                    let newSiswa = ModelSiswa(from: data, id: id)
                    newSiswas.append(newSiswa)
                }
            }
        }
        return newSiswas
    }

    /// Memperbarui foto siswa di database dan mengembalikan foto lama.
    ///
    /// Fungsi ini akan:
    /// - Mengompres gambar baru.
    /// - Memperbarui foto di database.
    /// - Mengembalikan foto lama jika ada.
    ///
    /// - Parameters:
    ///   - id: ID siswa yang fotonya akan diperbarui.
    ///   - newImage: Gambar baru (`NSImage`) yang akan disimpan.
    /// - Returns: Foto lama (`NSImage`) jika ada, atau `nil` jika tidak ditemukan.
    func updateFotoSiswa(id: Int64, newImage: NSImage) -> NSImage? {
        let oldData = dbController.bacaFotoSiswa(idValue: id)
        let compressed = newImage.compressImage(quality: 0.5) ?? Data()
        dbController.updateFotoInDatabase(with: compressed, idx: id)

        guard let oldImage = NSImage(data: oldData) else { return nil }
        return oldImage
    }

    /// Mengambil ID, nama, dan foto siswa berdasarkan indeks baris.
    ///
    /// - Parameter row: Indeks baris siswa.
    /// - Returns: Tuple `(id, nama, foto)` atau `nil` jika siswa tidak ditemukan.
    @inlinable
    func getIdNamaFoto(row: Int) -> (id: Int64, nama: String, foto: Data)? {
        dataSource.getIdNamaFoto(row: row)
    }
}
