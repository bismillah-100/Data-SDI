//
//  ModelSiswa.swift
//  DataSDI
//
//  Created by Ays on 02/06/25.
//

import Foundation

public class ModelSiswa: Comparable {
    static var currentSortDescriptor: NSSortDescriptor?
    public var id: Int64 = 0
    public var nama: String = ""
    public var alamat: String = ""
    public var ttl: String = ""
    public var tahundaftar: String = ""
    public var namawali: String = ""
    public var nis: String = ""
    public var nisn: String = ""
    public var ayah: String = ""
    public var ibu: String = ""
    public var jeniskelamin: String = ""
    public var status: String = ""
    public var kelasSekarang: String = ""
    public var tanggalberhenti: String = ""
    public var tlv: String = ""
    lazy var foto: Data = Data()
    public var index: Int = 0
    public var originalIndex: Int = 0
    public var menuDiupdate: Bool = false
    // Default initializer (implicit)
    init() {
        self.id = 0
        self.nama = ""
        self.alamat = ""
        self.ttl = ""
        self.tahundaftar = ""
        self.namawali = ""
        self.nis = ""
        self.nisn = ""
        self.ayah = ""
        self.ibu = ""
        self.jeniskelamin = ""
        self.status = ""
        self.kelasSekarang = ""
        self.tanggalberhenti = ""
        self.tlv = ""
        self.foto = Data()
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(index)
        hasher.combine(originalIndex)
        hasher.combine(nama)
    }
    public static func < (lhs: ModelSiswa, rhs: ModelSiswa) -> Bool {
        return lhs.id == rhs.id && lhs.index == rhs.index && lhs.originalIndex == rhs.originalIndex && lhs.nama == rhs.nama && lhs.alamat == rhs.alamat && lhs.kelasSekarang == rhs.kelasSekarang && lhs.ayah == rhs.ayah && lhs.ibu == rhs.ibu
    }
    public static func == (lhs: ModelSiswa, rhs: ModelSiswa) -> Bool {
        return lhs.id == rhs.id && lhs.index == rhs.index && lhs.originalIndex == rhs.originalIndex && lhs.nama == rhs.nama && lhs.alamat == rhs.alamat && lhs.kelasSekarang == rhs.kelasSekarang && lhs.ayah == rhs.ayah && lhs.ibu == rhs.ibu
    }
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "Nama": nama,
            "Alamat": alamat,
            "T.T.L": ttl,
            "Tahun Daftar": tahundaftar,
            "Nama Wali": namawali,
            "NIS": nis,
            "NISN": nisn,
            "Ayah": ayah,
            "Ibu": ibu,
            "Jenis Kelamin": jeniskelamin,
            "Status": status,
            "Kelas Sekarang": kelasSekarang,
            "Tgl. Lulus": tanggalberhenti,
            "Nomor Telepon": tlv,
            "foto": foto
        ]
    }
    static func fromDictionary(_ dictionary: [String: Any]) -> ModelSiswa {
        let siswa = ModelSiswa()
        
        siswa.id = dictionary["id"] as? Int64 ?? 0
        siswa.nama = dictionary["Nama"] as? String ?? ""
        siswa.alamat = dictionary["Alamat"] as? String ?? ""
        siswa.ttl = dictionary["T.T.L"] as? String ?? ""
        siswa.tahundaftar = dictionary["Tahun Daftar"] as? String ?? ""
        siswa.namawali = dictionary["Nama Wali"] as? String ?? ""
        siswa.nis = dictionary["NIS"] as? String ?? ""
        siswa.nisn = dictionary["NISN"] as? String ?? ""
        siswa.ayah = dictionary["Ayah"] as? String ?? ""
        siswa.ibu = dictionary["Ibu"] as? String ?? ""
        siswa.jeniskelamin = dictionary["Jenis Kelamin"] as? String ?? ""
        siswa.status = dictionary["Status"] as? String ?? ""
        siswa.kelasSekarang = dictionary["Kelas Sekarang"] as? String ?? ""
        siswa.tanggalberhenti = dictionary["Tgl. Lulus"] as? String ?? ""
        siswa.tlv = dictionary["Nomor Telepon"] as? String ?? ""
        siswa.foto = dictionary["Foto"] as? Data ?? Data()
        return siswa
    }
}

struct SiswaInput {
    let nama: String
    let alamat: String
    let ttl: String
    let nis: String
    let nisn: String
    let ayah: String
    let ibu: String
    let tlv: String
    let namawali: String
    let jeniskelamin: String
    let status: String
    let tanggalDaftar: String
    let tanggalBerhenti: String
    let kelas: String
    let selectedImageData: Data?
}

struct UpdateOption {
    var aktifkanTglDaftar: Bool
    var tglBerhentiEnabled: Bool
    var statusEnabled: Bool
    var pilihKelasSwitch: Bool
    var kelasIsEnabled: Bool
    var pilihJnsKelamin: Bool
    var kelasPilihan: String
}

struct FotoSiswa {
    var foto: Data = Data()
}
