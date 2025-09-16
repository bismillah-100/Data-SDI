# Siswa Baru

View controller yang bertanggung jawab untuk menambahkan data siswa baru ke dalam sistem.

---

## Overview

``AddDataViewController`` menyediakan formulir komprehensif untuk input data dan mendukung fitur *drag-and-drop* untuk foto siswa.

Tampilan ini diinstansiasi melalui ``AppDelegate/createPopover(forPopover:)`` dan dibuka melalui ``AppDelegate/showInputSiswaBaru()``. State tampilan ini disimpan di ``AppDelegate/popoverAddSiswa``, memastikan hanya satu instance yang aktif.

---

## Antarmuka Pengguna (UI)

### Input Formulir

Formulir ini mencakup berbagai *text fields* dan kontrol pemilihan untuk data siswa:

* **Data Pribadi:**
    * ``AddDataViewController/namaSiswa``: Nama lengkap siswa.
    * ``AddDataViewController/alamatTextField``: Alamat tempat tinggal.
    * ``AddDataViewController/ttlTextField``: Tempat dan tanggal lahir.
    * ``AddDataViewController/jenisPopUp``: Pilihan jenis kelamin.
    * ``AddDataViewController/pilihTanggal``: *Date picker* untuk tanggal pendaftaran.
* **Data Orang Tua/Wali:**
    * ``AddDataViewController/namawaliTextField``: Nama wali.
    * ``AddDataViewController/ayah``: Nama ayah.
    * ``AddDataViewController/ibu``: Nama ibu.
    * ``AddDataViewController/tlv``: Nomor telepon.
* **Data Akademik:**
    * ``AddDataViewController/NIS``: Nomor Induk Siswa.
    * ``AddDataViewController/NISN``: Nomor Induk Siswa Nasional.
    * ``AddDataViewController/popUpButton``: Pilihan kelas aktif.

### Penanganan Foto

Fitur penanganan foto didukung oleh:
* ``AddDataViewController/imageView``: Area tampilan foto yang mendukung *drag-and-drop* menggunakan ``XSDragImageView``.
* ``AddDataViewController/showImageView``: Tombol untuk menampilkan atau menyembunyikan area foto.
* ``AddDataViewController/pilihFoto``: Tombol untuk memilih foto dari disk melalui `NSOpenPanel`.
* ``AddDataViewController/pilihFoto(_:)``: Implementasi untuk membuka `NSOpenPanel`.

---

## Logika & Operasi

### Manajemen Data
* **Penyimpanan Data:** Data siswa baru disimpan ke database dengan memanggil `insertSiswaKeDatabase()`, yang kemudian menggunakan ``DatabaseController/catatSiswa(_:)``.
* **Penambahan Kelas:** Siswa ditambahkan ke kelas yang dipilih dengan ``DatabaseController/naikkanSiswa(_:intoKelasId:tingkatBaru:tahunAjaran:semester:tanggalNaik:statusEnrollment:)``.
* **Identifikasi Kelas:** ID kelas diperoleh atau dibuat menggunakan ``DatabaseController/insertOrGetKelasID(nama:tingkat:tahunAjaran:semester:)``.

### Manajemen UI dan Lifecycle
* **Penyesuaian Tampilan:** Metode ``AddDataViewController/updateStackViewSize(_:anchorRect:)`` secara dinamis menyesuaikan ukuran tampilan.
* **Manajemen Teks:** Metode seperti ``AddDataViewController/kapitalkan(_:)`` dan ``AddDataViewController/hurufBesar(_:)`` digunakan untuk memformat input teks, sementara `resetForm(_:)` mengembalikan form ke kondisi awal.
* **Lifecycle View:**
    * `viewDidLoad()`: Pengaturan awal dan delegate *text field*.
    * `viewWillAppear()`: Menyesuaikan visibilitas foto.
    * `viewDidAppear()`: Mengatur fokus jendela.
    * `viewWillDisappear()`: Mengirim notifikasi penutupan.

---

## Notifikasi dan Komunikasi

``AddDataViewController`` berkomunikasi dengan bagian lain dari aplikasi melalui `NotificationCenter`.

* **Notifikasi Siswa Baru:** Mengirim notifikasi ``DatabaseController/siswaBaru`` setelah data siswa berhasil disimpan.
* **Notifikasi Penutupan Popup:** Mengirim notifikasi khusus berdasarkan `SourceViewController` saat tampilan ditutup.

### Dependensi dan Tipe Terkait
* ``SiswaDefaultData``: `tuple` yang merepresentasikan data default siswa.
* ``ModelSiswa``: Model data yang merepresentasikan entitas siswa.
* `SourceViewController`: `enum` privat yang mengelola sumber tampilan untuk penanganan notifikasi yang sesuai.

---

## Penggunaan

```swift
// Menampilkan view untuk menambah siswa baru
let vc = AddDataViewController()
vc.sourceViewController = .siswaViewController
presentAsSheet(vc)
``` 

## Proses Ekspor dan Kompresi

* **Kompresi Gambar:** Gambar yang dipilih dikompresi menjadi 50% kualitasnya sebelum disimpan ke database menggunakan `selectedImage?.compressImage(quality: 0.5)`.
* **Saran Teks:** ``SuggestionManager`` digunakan untuk menyediakan saran otomatis pada beberapa *text field* seperti nama, alamat, dan nomor kontak.
