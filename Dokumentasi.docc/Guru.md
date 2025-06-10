# Guru

Tampilan tabel untuk pengelolaan data guru menggunakan `NSOutlineView`.

## Overview

Foundation:
- NSUndoManager
- ``DataSDI/GuruModel``
- ``DataSDI/MapelModel``

## Topics

### Tampilan Utama
- ``GuruViewController``
- ``EditableOutlineView``

### Pengelola Database
- ``DataSDI/DatabaseController``
- ``DataSDI/DatabaseManager``

### Model Data
- ``DataSDI/GuruModel``
- ``DataSDI/MapelModel``

### Array Undo
- ``DataSDI/SingletonData/undoAddGuru``
- ``DataSDI/SingletonData/deletedGuru``
- ``DataSDI/GuruViewController/undoHapus``
- ``DataSDI/GuruViewController/redoHapus``

### Menambahkan Data
- ``DataSDI/GuruViewController/addGuru(_:)``
- ``DataSDI/GuruViewController/undoTambah(data:)``
- ``DataSDI/GuruViewController/redoTambah(groupedDeletedData:)``
- ``DataSDI/GuruViewController/simpanGuru(_:)``

### Menghapus Data
- ``DataSDI/GuruViewController/deleteData(_:)``
- ``DataSDI/GuruViewController/hapusSerentak(_:)``
- ``DataSDI/GuruViewController/hapusRow(_:idToDelete:)``
- ``DataSDI/GuruViewController/confirmDelete(idsToDelete:)``
- ``DataSDI/GuruViewController/undoHapus(groupedDeletedData:)``
- ``DataSDI/GuruViewController/redoHapus(data:)``

### Mengedit Data
- ``DataSDI/GuruViewController/edit(_:)``
- ``DataSDI/GuruViewController/simpanEditedGuru(_:)``
- ``DataSDI/GuruViewController/undoEdit(guru:)``

### Menu
- ``DataSDI/GuruViewController/menuNeedsUpdate(_:)``
- ``DataSDI/GuruViewController/buatMenuItem()``
- ``DataSDI/GuruViewController/updateTableMenu(_:)``
- ``DataSDI/GuruViewController/updateToolbarMenu(_:)``

### Menu Bar
- ``GuruViewController/updateUndoRedo(_:)``
- ``SiswaViewController/updateMenuItem(_:)``

### Mengurutkan Data
- ``DataSDI/Swift/Array/insertionIndex(for:using:)-3foab``

### Prediksi Ketik
- ``DataSDI/ReusableFunc/namaguru``
- ``DataSDI/ReusableFunc/alamat``
- ``DataSDI/ReusableFunc/mapel``
- ``DataSDI/ReusableFunc/jabatan``

### Struktur Guru
- ``Struktur``
