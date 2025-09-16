# Transaksi Baru

View controller untuk menambahkan data transaksi administrasi baru ke dalam sistem.

## Overview

``CatatTransaksi`` menangani input data transaksi keuangan melalui form yang mencakup jenis transaksi, jumlah, kategori, acara, keperluan, dan tanggal.

## UI Components

### Text Fields
- ``CatatTransaksi/jumlah`` - Input jumlah transaksi
- ``CatatTransaksi/keperluan`` - Input keperluan transaksi
- ``CatatTransaksi/kategori`` - Input kategori transaksi
- ``CatatTransaksi/acara`` - Input acara terkait transaksi

### Selection Controls
- ``CatatTransaksi/pilihjTransaksi`` - Popup button untuk memilih jenis transaksi
- ``CatatTransaksi/tanggal`` - Date picker untuk memilih tanggal transaksi
- ``CatatTransaksi/tandaiButton`` - Tombol untuk menandai transaksi

### Buttons
- ``CatatTransaksi/catat`` - Tombol untuk menyimpan transaksi
- ``CatatTransaksi/close(_:)`` - Implementasi untuk menutup view

## Data Management

### Transaction Processing

``CatatTransaksi/tambahTransaksi(_:)``

Memproses penambahan data transaksi baru dengan memanggil ``DataManager/addData(jenis:dari:jumlah:kategori:acara:keperluan:tanggal:bulan:tahun:tanda:)``.

### Duplicate Checking
```swift
existingData.contains { entity in ... }
```
Memeriksa duplikasi data sebelum menambahkan transaksi baru.

## UI Management

### Visual Effects
```swift
NSVisualEffectView
```
Menambahkan efek visual belakang window ketika ditampilkan sebagai sheet.

### Text Formatting
- ``CatatTransaksi/kapitalkan(_:)`` - Mengkapitalisasi teks
- ``CatatTransaksi/hurufBesar(_:)`` - Mengubah teks menjadi huruf besar

### Text Suggestions
Menggunakan ``SuggestionManager`` untuk menampilkan saran input berdasarkan:
- ``ReusableFunc/kategori``
- ``ReusableFunc/acara``
- ``ReusableFunc/keperluan``

## Validation

### Input Validation
Memvalidasi bahwa:
- Jenis transaksi telah dipilih
- Jumlah transaksi tidak nol
- Minimal satu keterangan transaksi diisi (kategori, acara, atau keperluan)

### Duplicate Validation
Memeriksa apakah data transaksi yang sama sudah ada di database sebelum menyimpan.

## Notification Handling

### Data Changed
```swift
NotificationCenter.default.post(name: DataManager.dataDidChangeNotification, object: nil, userInfo: ["newItem": id])
```
Mengirim notifikasi ketika data transaksi berhasil ditambahkan.

### View Dismissal
```swift
NotificationCenter.default.post(name: .popUpDismissedTV, object: nil)
```
Mengirim notifikasi ketika view controller ditutup.

## Lifecycle Management

### View Lifecycle
- ``CatatTransaksi/viewDidLoad()`` - Setup awal delegate text field dan efek visual
- ``CatatTransaksi/viewDidAppear()`` - Mengambil data existing untuk pengecekan duplikat
- ``CatatTransaksi/viewDidDisappear()`` - Mengirim notifikasi penutupan

## Usage Example

```swift
// Menampilkan view untuk menambah transaksi
let vc = CatatTransaksi()
vc.sheetWindow = true
presentAsSheet(vc)
```

## Related Types

### Entity
Model data yang merepresentasikan transaksi dalam Core Data.

## Alert Management

### Validation Alerts
Menampilkan alert ketika:
- Jenis transaksi belum dipilih
- Jumlah transaksi kosong
- Keterangan transaksi kosong
- Data duplikat ditemukan

## Data Formatting

### Text Formatting
```swift
stringValue.capitalizedAndTrimmed()
```
Memformat teks dengan kapitalisasi dan penghapusan whitespace berlebih.

### Date Processing
```swift
Calendar.current.component(.month, from: tanggalTransaksi)
Calendar.current.component(.year, from: tanggalTransaksi)
```
Mengekstrak bulan dan tahun dari tanggal transaksi untuk penyimpanan.
