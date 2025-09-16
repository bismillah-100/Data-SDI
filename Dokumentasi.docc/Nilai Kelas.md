# Nilai Kelas

View controller yang menangani logika penambahan data nilai untuk kelas dan siswa tertentu.

## Overview

``AddDetaildiKelas`` menyediakan antarmuka lengkap untuk memasukkan data mata pelajaran, nilai, informasi guru, dan detail akademik lainnya.

## Fitur Utama

- Input dan pengelolaan data nilai siswa
- Integrasi dengan operasi database
- Validasi form dinamis dan auto-completion
- Manajemen semester dan tahun ajaran
- Pelacakan penugasan guru dengan caching
- Notifikasi badge real-time untuk jumlah data

## Properti Utama

### Elemen UI
- ``AddDetaildiKelas/titleText`` - Label judul tampilan
- ``AddDetaildiKelas/mapelTextField`` - Field teks untuk input mata pelajaran
- ``AddDetaildiKelas/nilaiTextField`` - Field teks untuk input nilai
- ``AddDetaildiKelas/guruMapel`` - Field teks untuk input nama guru
- ``AddDetaildiKelas/namaPopUpButton`` - Popup button untuk pemilihan siswa
- ``AddDetaildiKelas/smstrPopUpButton`` - Popup button untuk pemilihan semester
- ``AddDetaildiKelas/kelasPopUpButton`` - Popup button untuk pemilihan kelas
- ``AddDetaildiKelas/ok`` - Tombol untuk mencatat data ke memori
- ``AddDetaildiKelas/simpan`` - Tombol untuk menyimpan data ke database

### Manajemen Data
- ``AddDetaildiKelas/dataArray`` - Array penyimpanan data kelas dengan indeks
- ``AddDetaildiKelas/tableDataArray`` - Array penyimpanan data tabel dengan ID
- `penugasanCache` - Cache private untuk penugasan guru
- ``AddDetaildiKelas/dbController`` - Instance controller database

## Metode Utama

### Inisialisasi dan Setup
- ``AddDetaildiKelas/loadView()`` - Menyiapkan hierarki tampilan
- ``AddDetaildiKelas/viewDidLoad()`` - Melakukan setup awal
- ``AddDetaildiKelas/viewDidAppear()`` - Menangani logika presentasi tampilan
- ``AddDetaildiKelas/viewWillDisappear()`` - Menangani logika penutupan tampilan

### Penanganan Data
- **Alur Kerja Memproses Input:**
    - ``AddDetaildiKelas/okButtonClicked(_:)``
        1. **Validasi Input**: Memeriksa kelengkapan data tahun ajaran dan kesesuaian jumlah mata pelajaran, nilai, dan guru
        2. **Parsing Data**: Memisahkan input teks menjadi array menggunakan koma sebagai pemisah
        3. **Pembentukan Kunci Cache**: Membuat kunci unik untuk setiap kombinasi guru-mapel-bagian-semester-tahun ajaran
        4. **Pemeriksaan Cache**: Menentukan apakah data penugasan sudah ada di cache atau perlu dibuat baru
        5. **Penampilan Sheet ``AddTeacherRoles``**: Jika ada guru yang belum memiliki penugasan, tampilkan sheet untuk memilih jabatan
        6. **Menambahkan data ke tugas guru**: ``GuruViewModel/insertTugas(groupedDeletedData:registerUndo:)``
        7. **Menambahkan data ke daftar guru**: ``GuruViewModel/insertGuruu(_:registerUndo:)``

- Interaksi dengan DatabaseController:
```swift
// Mendapatkan ID kelas
let kelasID = await dbController.insertOrGetKelasID(
    nama: bagianKelasName,
    tingkat: tingkat,
    tahunAjaran: tahunAjaran,
    semester: semester
)

// Mendapatkan ID mata pelajaran
let mapelID = await IdsCacheManager.shared.mapelID(for: mapel)

// Mendapatkan ID guru
let guruID = await dbController.insertOrGetGuruID(nama: guru)

// Membuat/mendapatkan ID penugasan
let penugasanID = await dbController.insertOrGetPenugasanID(
    guruID: guruID,
    mapelID: mapelID,
    kelasID: kelasID,
    jabatanID: jabatanID,
    tanggalMulai: tanggalString
)
```

- Pembukaan Sheet AddTeacherRoles:
```swift
// Ketika ada guru yang belum memiliki penugasan
let addTeacherRoles = AddTeacherRoles(nibName: "AddTeacherRoles", bundle: nil)
addTeacherRoles.loadGuruData(daftarGuru: daftarSheet)

addTeacherRoles.onJabatanSelected = { [weak self] result in
    // Handle hasil pemilihan jabatan
    let dataUntukUpdate: DataNilaiSiswa = (...)
    Task {
        // Akses private `updateDatabase`
        await self?.updateDatabase(data: dataUntukUpdate)
    }
}

self.presentAsSheet(addTeacherRoles)
```

- **Alur Kerja Menyimpan Data:**
    - ``AddDetaildiKelas/simpan(_:)``
        1. **Validasi Final**: Memastikan ada data yang akan disimpan
        2. **Pemanggilan Closure**: Memanggil closure `onSimpanClick` dengan data yang telah dikumpulkan
        3. **Notifikasi**: Mengirim notifikasi untuk update UI di kelas induk
        4. **Reset Form**: Mengembalikan form ke keadaan awal

- Interaksi dengan Sistem:
```swift
// Memanggil closure handler dengan data yang terkumpul
onSimpanClick?(dataArray, true, false, true)

// Mengirim notifikasi ke observer
NotificationCenter.default.post(
    name: .updateTableNotificationDetilSiswa, 
    object: nil, 
    userInfo: ["data": dataArray]
)
```

- **Alur Kerja Menutup Tampilan:**
    - ``AddDetaildiKelas/tutup(_:)``
        1. **Penghapusan Data Sementara**: Menghapus data yang telah dicatat tetapi belum disimpan
        2. **Pembersihan Cache**: Membersihkan cache penugasan yang belum disimpan
        3. **Penutupan Jendela**: Menutup jendela sesuai konteks (sheet atau window)

- Interaksi dengan DatabaseController:
```swift
// Menghapus data nilai spesifik
dbController.deleteSpecificNilai(nilaiID: id)

// Menghapus data penugasan guru
dbController.hapusTugasGuru(id.penugasanID)

// Membersihkan ID yang disimpan sementara
SingletonData.insertedID.removeAll()
```

- **Alur Kerja memperbarui model data:**
    - ``AddDetaildiKelas/updateModelData(withKelasId:siswaID:namasiswa:mapel:nilai:semester:namaguru:tanggal:tahunAjaran:)``
        1. **Pembuatan Model**: Membuat instance `KelasModels` dengan data yang diberikan
        2. **Pengecekan Duplikat**: Memastikan tidak ada duplikasi data berdasarkan ID kelas
        3. **Penyimpanan ke Array**: Menyimpan data ke array sementara untuk diproses lebih lanjut

- Implementasi:
```swift
func updateModelData(withKelasId kelasId: Int64, siswaID: Int64, namasiswa: String, 
                    mapel: String, nilai: Int64, semester: String, 
                    namaguru: String, tanggal: String, tahunAjaran: String) {
    
    let validKelasModel = KelasModels()
    // Set properti model
    validKelasModel.kelasID = kelasId
    validKelasModel.siswaID = siswaID
    // ... set other properties
    
    // Cek duplikasi sebelum menambahkan
    if !dataArray.contains(where: { $0.data.kelasID == kelasId }) {
        dataArray.append((index: selectedIndex, data: validKelasModel))
        tableDataArray.append((table: kelas, id: kelasId))
    }
}
```

- **Integrasi dengan AddTeacherRoles Sheet**
    - Ketika tombol OK ditekan dan terdapat guru yang belum memiliki penugasan, sheet AddTeacherRoles akan ditampilkan:
        1. **Penyiapan Data**: Data guru yang belum memiliki penugasan dikumpulkan
        2. **Inisialisasi Sheet**: Sheet AddTeacherRoles dibuat dan dikonfigurasi
        3. **Penanganan Hasil**: Closure `onJabatanSelected` dipanggil ketika user memilih jabatan
        4. **Pemrosesan Data**: Data yang dipilih diproses dan disimpan ke database

> Proses ini memastikan bahwa setiap guru yang ditugaskan untuk mengajar mata pelajaran tertentu memiliki jabatan yang sesuai sebelum data nilai disimpan ke database.

### Manajemen UI
- ``AddDetaildiKelas/updateItemCount()`` - Memperbarui jumlah item badge
- `updateBadgeAppearance()` - Akses private untuk memperbarui tampilan visual badge
- `setupBackgroundViews()` - Akses private untuk menyiapkan tampilan latar belakang
- `setupBadgeView()` - Akses private untuk menyiapkan tampilan badge

### Manajemen Popup
- ``AddDetaildiKelas/fillNamaPopUpButton(withTable:)`` - Mengisi dropdown nama siswa
- ``AddDetaildiKelas/updateSemesterPopUpButton()`` - Memperbarui dropdown semester
- ``AddDetaildiKelas/kelasPopUpButtonDidChange(_:)`` - Menangani perubahan pemilihan kelas

## Struktur Data

### PenugasanKey
Struct private yang digunakan untuk caching penugasan guru dengan properti hashable:
- guru: Nama guru
- mapel: Nama mata pelajaran
- bagian: Bagian kelas
- semester: Semester
- tahunAjaran: Tahun ajaran

### DataNilaiSiswa
Typealias tuple structure yang berisi semua data nilai siswa:
- mapelArray: Array mata pelajaran
- nilaiArray: Array nilai
- guruArray: Array guru
- siswaID: ID siswa
- Dan informasi akademik terkait lainnya

## Titik Integrasi

- Bekerja dengan ``KelasVC`` untuk manajemen nilai
- Menggunakan ``DatabaseController`` untuk operasi database
- Mengimplementasikan ``KategoriBaruDelegate`` untuk penanganan kategori baru
- Memanfaatkan ``SuggestionManager`` untuk auto-completion field teks

## Contoh Penggunaan

```swift
// Membuat instance
let addDetailVC = AddDetaildiKelas()

// Menyiapkan data
addDetailVC.tabKelas(index: 0) // Pilih kelas pertama
addDetailVC.fillNamaPopUpButton(withTable: "Kelas 1") // Isi dropdown nama

// Menangani input data
addDetailVC.mapelTextField.stringValue = "Matematika, Fisika"
addDetailVC.nilaiTextField.stringValue = "85, 90"
addDetailVC.guruMapel.stringValue = "Budi Santoso, Ahmad Yani"

// Menyimpan data
addDetailVC.okButtonClicked(addDetailVC.ok)
addDetailVC.simpan(addDetailVC.simpan)
```

## Catatan Penting

- Data tidak langsung disimpan ke database sampai tombol "Simpan" ditekan
- Tombol "OK" hanya menyimpan data ke memori sementara
- Cache penugasan guru meningkatkan performa untuk input berulang
- Validasi dilakukan untuk memastikan konsistensi jumlah mata pelajaran, nilai, dan guru

Kelas ini merupakan komponen penting dalam sistem manajemen nilai akademik yang terintegrasi dengan database dan antarmuka pengguna yang intuitif.
