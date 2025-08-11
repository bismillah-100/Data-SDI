# Tugas Guru

Tampilan tabel untuk pengelolaan tugas guru menggunakan `NSOutlineView`.

## Overview
Menggunakan `NSOutlineView`. Data dikelola ``DataSDI/GuruViewModel`` dan perubahan diteruskan melalui event `Combine`.

Foundation:
- NSUndoManager
- ``DataSDI/GuruModel``
- ``DataSDI/MapelModel``
- ``DataSDI/PenugasanModel``
- ``DataSDI/PenugasanGuruDefaultData``
- ``DataSDI/PenugasanGuruEvent``
- ``DataSDI/UpdatePenugasanGuru``

## Topics

### Tampilan Utama
- ``TugasMapelVC``

### Cache ID
- ``IdsCacheManager``

### Pengelola Database
- ``DataSDI/DatabaseController``
- ``DataSDI/DatabaseManager``

### TypeAlias
- ``TabelTugas``
- ``GuruInsertDict``
- ``GuruWithUpdate``
- ``DataSDI/PenugasanGuruDefaultData``

### Model Data
- ``DataSDI/GuruModel``
- ``DataSDI/MapelModel``
- ``DataSDI/PenugasanModel``
- ``DataSDI/UpdatePenugasanGuru``

### Event Combine
- ``DataSDI/TugasMapelVC/setupCombine()``

### Array Undo
- ``DataSDI/SingletonData/deletedTugasGuru``

### Menambahkan Data
- ``DataSDI/TugasMapelVC/addGuru(_:)``
- ``DataSDI/TugasMapelVC/simpanGuru(_:)``

### Menghapus Data
- ``DataSDI/TugasMapelVC/deleteData(_:)``
- ``DataSDI/TugasMapelVC/hapusSerentak(_:)``
- ``DataSDI/TugasMapelVC/hapusRow(_:idToDelete:)``

### Mengedit Data
- ``DataSDI/TugasMapelVC/edit(_:)``
- ``DataSDI/TugasMapelVC/simpanEditedGuru(_:)``

### Menu
- ``DataSDI/TugasMapelVC/menuNeedsUpdate(_:)``
- ``DataSDI/TugasMapelVC/buatMenuItem()``
- ``DataSDI/TugasMapelVC/updateTableMenu(_:)``
- ``DataSDI/TugasMapelVC/updateToolbarMenu(_:)``

### Menu Bar
- ``TugasMapelVC/updateUndoRedo(_:)``
- ``SiswaViewController/updateMenuItem(_:)``

### Mengurutkan Data
- ``DataSDI/Swift/Array/insertionIndex(for:using:)-3foab``

### Prediksi Ketik
- ``DataSDI/ReusableFunc/namaguru``
- ``DataSDI/ReusableFunc/alamat``
- ``DataSDI/ReusableFunc/mapel``
- ``DataSDI/ReusableFunc/jabatan``

### Structures
- ``DataSDI/PenugasanGuruMapelKelasColumns``
