# Edit Transaksi

View controller untuk mengedit data transaksi administrasi dalam sistem.

## Overview

``EditTransaksi`` menangani pengeditan data transaksi keuangan, termasuk pemasukan dan pengeluaran, dengan dukungan untuk pengeditan multiple entities.

## UI Components

### Text Fields
- ``EditTransaksi/jumlah`` - Input jumlah transaksi
- ``EditTransaksi/keperluan`` - Input keperluan transaksi
- ``EditTransaksi/kategori`` - Input kategori transaksi
- ``EditTransaksi/acara`` - Input acara terkait transaksi

### Buttons
- ``EditTransaksi/catat`` - Tombol untuk menyimpan perubahan
- ``EditTransaksi/tutup`` - Tombol untuk menutup view
- ``EditTransaksi/ubahTransaksi`` - Tombol untuk mengaktifkan edit jenis transaksi
- ``EditTransaksi/tandai``, ``EditTransaksi/biarkanTanda``, ``EditTransaksi/hapusTanda`` - Tombol untuk mengelola tanda transaksi

### Selection Controls
- ``EditTransaksi/transaksi`` - Popup button untuk memilih jenis transaksi

## Data Management

### Entity Management

``EditTransaksi/editedEntities``

Array yang menyimpan entitas transaksi yang akan diedit.

### Transaction Processing

``EditTransaksi/simpanButtonClicked(_:)``

Memproses penyimpanan perubahan data transaksi dengan memanggil ``DataManager/editData(entity:jenis:dari:jumlah:kategori:acara:keperluan:tanggal:bulan:tahun:tanda:)``.

## UI Management

### Multi-Edit Handling

``EditTransaksi/resetKapital(_:)``

Mengatur placeholder text untuk mode pengeditan multiple entities.

### Transaction Type Toggle

``EditTransaksi/beralihTransaksi(_:)``

Mengaktifkan/menonaktifkan edit jenis transaksi.

## Text Formatting

### Capitalization Options
- ``EditTransaksi/kapitalkan(_:)`` - Mengkapitalisasi teks
- ``EditTransaksi/hurufBesar(_:)`` - Mengubah teks menjadi huruf besar

### Text Suggestions
Menggunakan ``SuggestionManager`` untuk menampilkan saran input berdasarkan:
- ``ReusableFunc/kategori``
- ``ReusableFunc/acara``
- ``ReusableFunc/keperluan``

## Notification Handling

### View Dismissal
```swift
NotificationCenter.default.post(name: .popUpDismissedTV, object: nil)
```
Mengirim notifikasi ketika view controller ditutup.

### Data Updated
```swift
NotificationCenter.default.post(name: DataManager.dataDieditNotif, object: nil, userInfo: notif)
```
Mengirim notifikasi ketika data transaksi berhasil diperbarui.

## Lifecycle Management

### View Lifecycle
- ``EditTransaksi/viewDidLoad()`` - Setup awal
- ``EditTransaksi/viewWillAppear()`` - Mengatur efek visual
- ``EditTransaksi/viewDidAppear()`` - Setup delegate dan suggestion manager
- ``EditTransaksi/viewDidDisappear()`` - Mengirim notifikasi penutupan

## Usage Example

```swift
// Menampilkan view untuk mengedit transaksi
let vc = EditTransaksi()
vc.editedEntities = selectedTransactions
presentAsSheet(vc)
```

## Related Types

### Entity
Model data yang merepresentasikan transaksi dalam Core Data.

### EntitySnapshot
Snapshot untuk backup data sebelum dilakukan perubahan.

## Data Validation

### Text Formatting

``ReusableFunc/teksFormat(_:oldValue:hurufBesar:kapital:allowEmpty:)``

Memvalidasi dan memformat input teks dengan opsi huruf besar dan kapitalisasi.

### Number Formatting
Menggunakan `NumberFormatter` untuk memformat nilai jumlah transaksi.

## Alert Management

### No Changes Alert
```swift
ReusableFunc.showAlert(title: "Data tidak dibuah", message: "Tidak ada perubahan yang disimpan")
```
Menampilkan alert ketika tidak ada perubahan data yang disimpan.

## Backup System

### Entity Backup
```swift
ReusableFunc.createBackup(for:)
```
Membuat backup snapshot dari entitas sebelum dilakukan perubahan.
