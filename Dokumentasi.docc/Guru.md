# Guru

Tampilan tabel untuk pengelolaan data guru menggunakan `NSTableView`.

## Overview
Menggunakan `NSTableView`. Data dikelola ``DataSDI/GuruViewModel`` dan perubahan diteruskan melalui event `Combine`.

Foundation:
- NSUndoManager
- ``DataSDI/GuruModel``
- ``DataSDI/GuruEvent``
- ``DataSDI/GuruColumns``

## Topics

### Tampilan Utama
- ``DataSDI/GuruVC``

### Database
- ``DatabaseController``
- ``GuruColumns``

### View Model
- ``DataSDI/GuruViewModel``

### Event Combine
- ``GuruVC/setupCombine()``
- ``GuruViewModel/guruEvent``

### Model Data
- ``GuruModel``

### Menambahkan Data
- ``GuruVC/tambahGuru(_:)``
- ``DataSDI/GuruVC/bukaJendelaAddTugas(_:opsi:)``

### Memperbarui Data
- ``DataSDI/GuruVC/editGuru(_:)``
- ``DataSDI/GuruVC/bukaJendelaAddTugas(_:opsi:)``

### Menghapus Data
- ``DataSDI/GuruVC/hapusGuru(_:)``

### Array Undo
- ``DataSDI/SingletonData/deletedGuru``

### Menu
- ``DataSDI/GuruVC/updateTableMenu(_:)``
- ``DataSDI/GuruVC/updateToolbarMenu(_:)``
- ``DataSDI/GuruVC/buatMenuItem()``

### Prediksi Ketik
- ``DataSDI/ReusableFunc/namaguru``
- ``DataSDI/ReusableFunc/alamat``

### Mengurutkan Data
- ``DataSDI/Swift/Array/insertionIndex(for:using:)-3foab``

### Struktur Guru
- ``DataSDI/Struktur``

### Enumerations
- ``GuruEvent``

### Structures
- ``StrukturGuruDictionary``
