# Edit Siswa

View controller untuk mengedit data siswa yang sudah ada dalam sistem.

## Overview

``EditData`` menangani pengeditan data siswa melalui form yang komprehensif dan mendukung berbagai operasi termasuk pembaruan foto, perubahan status, dan pemindahan kelas.

## UI Components

### Image Handling
- ``EditData/imageView`` - Menampilkan dan mengedit foto siswa
- ``EditData/pilihFoto`` - Tombol untuk memilih foto baru
- ``EditData/hapusFoto`` - Tombol untuk menghapus foto
- ``EditData/eksporFoto`` - Tombol untuk mengekspor foto

### Text Fields
- ``EditData/namaSiswa`` - Edit nama siswa
- ``EditData/alamatSiswa`` - Edit alamat siswa
- ``EditData/ttlTextField`` - Edit tempat tanggal lahir
- ``EditData/NIS`` - Edit Nomor Induk Siswa
- ``EditData/NISN`` - Edit Nomor Induk Siswa Nasional
- ``EditData/namawaliTextField`` - Edit nama wali
- ``EditData/ayah`` - Edit nama ayah
- ``EditData/ibu`` - Edit nama ibu
- ``EditData/tlv`` - Edit nomor telepon

### Selection Controls
- ``EditData/tglDaftar`` - Date picker untuk tanggal pendaftaran
- ``EditData/tglBerhenti`` - Date picker untuk tanggal berhenti
- ``EditData/kelaminSwitch`` - Switch untuk mengaktifkan edit jenis kelamin
- ``EditData/kelasSwitch`` - Switch untuk mengaktifkan edit kelas
- ``EditData/statusSwitch`` - Switch untuk mengaktifkan edit status

### Radio Buttons
- ``EditData/kelas1Radio`` hingga ``EditData/kelas6Radio`` - Pilihan kelas
- ``EditData/lakiLakiRadio`` dan ``EditData/perempuanRadio`` - Pilihan jenis kelamin
- ``EditData/statusAktif``, ``EditData/statusBerhenti``, ``EditData/statusLulus`` - Pilihan status

## Database Operations

### Memperbarui Data Siswa
```swift
``EditData/updateSiswa(_:with:option:)``
```
Memperbarui informasi siswa berdasarkan input yang diberikan dengan opsi untuk mempertahankan nilai yang ada jika input kosong.

### Operasi Foto
```swift
dbController.updateFotoInDatabase(with:idx:undoManager:)
```
Memperbarui foto siswa dalam database dengan dukungan undo management.

### Mendapatkan Data Foto
```swift
dbController.bacaFotoSiswa(idValue:)
```
Membaca data foto siswa dari database untuk diekspor.

## UI Management

### Dynamic UI Configuration
```swift
``EditData/viewWillAppear()``
```
Mengatur tampilan UI berdasarkan jumlah siswa yang dipilih (single vs multi edit).

### Status Management
```swift
``EditData/setStatusUI(statusOn:enableTanggal:enableKelas:)``
```
Mengatur tampilan UI berdasarkan status siswa yang dipilih.

### Radio Button Management
```swift
``EditData/enableKelasRadio(_:)``
``EditData/enableStatusRadio(_:)``
```
Mengaktifkan/menonaktifkan kelompok radio button.

## Data Processing

### Input Validation
```swift
ReusableFunc.teksFormat(_:oldValue:hurufBesar:kapital:allowEmpty:)
```
Memvalidasi dan memformat input teks dengan opsi huruf besar dan kapitalisasi.

### Image Processing
```swift
imageView.selectedImage?.compressImage(quality: 0.5)
```
Mengkompresi gambar dengan kualitas 50% sebelum disimpan ke database.

## Notification Handling

### Data Updated
```swift
NotificationCenter.default.post(name: .dataSiswaDiEdit, object: nil, userInfo: userInfo)
```
Mengirim notifikasi ketika data siswa berhasil diperbarui.

### Student Removed
```swift
NotificationCenter.default.post(name: .siswaDihapus, object: nil, userInfo: userInfo)
```
Mengirim notifikasi ketika siswa dihapus dari kelas.

## Usage Example

```swift
// Menampilkan view untuk mengedit siswa
let vc = EditData()
vc.selectedSiswaList = selectedStudents
presentAsSheet(vc)
```

## Related Types

### SiswaInput
Struct yang merepresentasikan data input untuk pembaruan siswa.

### UpdateOption
Struct yang mengontrol opsi pembaruan seperti pengaktifan tanggal daftar, pemilihan jenis kelamin, dll.

### ModelSiswa
Model data yang merepresentasikan siswa.

## Lifecycle Management

### View Lifecycle
- ``EditData/viewDidLoad()`` - Setup awal delegate text field dan efek visual
- ``EditData/viewWillAppear()`` - Mengatur UI berdasarkan data siswa
- ``EditData/viewDidAppear()`` - Mereset menu items
- ``EditData/viewWillDisappear()`` - Mengirim notifikasi penutupan

### Memory Management
```swift
``EditData/deinit``
```
Mencetak log debug saat di-deallocate.

## Text Suggestions

Menggunakan ``SuggestionManager`` untuk menampilkan saran input berdasarkan:
- ``ReusableFunc/namasiswa``
- ``ReusableFunc/alamat``
- ``ReusableFunc/namaAyah``
- ``ReusableFunc/namaIbu``
- ``ReusableFunc/namawali``
- ``ReusableFunc/ttl``
- ``ReusableFunc/nis``
- ``ReusableFunc/nisn``
- ``ReusableFunc/tlvString``

## Image Export

### Ekspor Foto
```swift
``EditData/eksporFoto(_:)``
```
Mengekspor foto siswa ke file JPEG dengan nama berdasarkan nama siswa.

## Alert Management

### Konfirmasi Hapus Foto
```swift
``EditData/hapusFoto(_:)``
```
Menampilkan alert konfirmasi sebelum menghapus foto siswa.

## Text Formatting Options

### Kapitalisasi
```swift
``EditData/kapitalkan(_:)``
```
Mengkapitalisasi semua teks pada field yang ditentukan.

### Huruf Besar
```swift
``EditData/hurufBesar(_:)``
```
Mengubah teks menjadi huruf besar pada field yang ditentukan.
