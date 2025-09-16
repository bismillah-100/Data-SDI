# Cari & Ganti

View controller untuk menangani operasi pencarian dan penggantian teks dalam data.

## Overview

``CariDanGanti`` menyediakan antarmuka untuk melakukan operasi find-and-replace pada kolom data tertentu, dengan dukungan untuk dua mode operasi: mengganti teks dan menambahkan teks.

## UI Components

### Selection Controls
- ``CariDanGanti/popUpColumn`` - Popup button untuk memilih kolom data
- ``CariDanGanti/popUpOption`` - Popup button untuk memilih mode operasi (ganti teks/tambah teks)
- ``CariDanGanti/popUpAddText`` - Popup button untuk memilih posisi penambahan teks

### Text Fields
- ``CariDanGanti/findTextField`` - Input untuk teks yang akan dicari
- ``CariDanGanti/replaceTextField`` - Input untuk teks pengganti

### Labels
- ``CariDanGanti/exampleLabel`` - Label yang menampilkan contoh hasil operasi
- ``CariDanGanti/findLabel`` - Label "Temukan"
- ``CariDanGanti/replaceLabel`` - Label "Ganti dengan"

### Buttons
- ``CariDanGanti/tmblSimpan`` - Tombol "Ubah data"
- ``CariDanGanti/cancelButtonClicked(_:)`` - Tombol "Tutup"

## Data Management

### Data Properties
- ``CariDanGanti/objectData`` - Data yang akan diedit
- ``CariDanGanti/columns`` - Daftar kolom yang dapat diedit
- ``CariDanGanti/selectedColumn`` - Kolom yang dipilih untuk operasi

### Closure Handlers
- ``CariDanGanti/onUpdate`` - Closure untuk mengembalikan data yang telah diedit
- ``CariDanGanti/onClose`` - Closure untuk menangani penutupan view

## UI Management

### Dynamic UI Configuration
```swift
``CariDanGanti/handlePopUpOption(_:)``
```
Mengubah tampilan UI berdasarkan mode operasi yang dipilih (ganti teks atau tambah teks).

### Example Display
```swift
``CariDanGanti/updateContoh()``
```
Memperbarui label contoh berdasarkan input dan opsi yang dipilih.

### Column Population
```swift
``CariDanGanti/isiPopUpColumn()``
```
Mengisi popup column dengan nama kolom yang tersedia.

## Operation Modes

### Replace Mode
- Mencari teks tertentu dan menggantinya dengan teks baru
- Menampilkan kedua field "Temukan" dan "Ganti dengan"

### Add Mode
- Menambahkan teks di awal atau akhir nilai yang ada
- Hanya menampilkan field "Temukan"
- Menggunakan ``CariDanGanti/popUpAddText`` untuk memilih posisi penambahan

## Data Processing

### Batch Processing
```swift
``CariDanGanti/updateButtonClicked(_:)``
```
Memproses semua data yang dipilih dengan operasi yang ditentukan.

### Text Operations
- `String.replacingOccurrences(of:with:)` - Untuk operasi ganti teks
- Concatenation - Untuk operasi tambah teks

## User Preferences

### Persistent Settings
Menyimpan preferensi pengguna ke `UserDefaults`:
- Kolom yang dipilih
- Mode operasi
- Posisi penambahan teks

## Lifecycle Management

### View Lifecycle
- ``CariDanGanti/viewDidLoad()`` - Setup awal dan registrasi defaults
- ``CariDanGanti/viewDidAppear()`` - Setup delegate dan pemulihan preferences
- ``CariDanGanti/viewWillDisappear()`` - Memanggil closure onClose

## Usage Example

```swift
// Menampilkan view untuk operasi find-and-replace
let vc = CariDanGanti.instantiate()
vc.objectData = dataToEdit
vc.columns = availableColumns
vc.onUpdate = { updatedData, column in
    // Handle updated data
}
presentAsSheet(vc)
```

## Validation

### Input Validation
```swift
controlTextDidChange(_:)
```
Mengaktifkan/menonaktifkan tombol simpan berdasarkan apakah field pencarian diisi.

## Notification Handling

### Text Changes
Menggunakan `NSTextFieldDelegate` untuk melacak perubahan teks dan memperbarui contoh secara real-time.

## Factory Method

### Instantiation
```swift
``CariDanGanti/instantiate()``
```
Method statis untuk membuat instance dari XIB.
