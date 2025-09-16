# Tugas Guru

Tampilan tabel untuk pengelolaan tugas guru menggunakan `NSOutlineView`.

## Overview
Menggunakan `NSOutlineView`. Data dikelola ``DataSDI/GuruViewModel`` dan perubahan diteruskan melalui event `Combine`.

Foundation:
- UndoManager
- ``DataSDI/GuruModel``
- ``DataSDI/MapelModel``
- ``DataSDI/PenugasanModel``
- ``DataSDI/PenugasanGuruDefaultData``
- ``DataSDI/PenugasanGuruEvent``
- ``DataSDI/UpdatePenugasanGuru``

### Menambahkan Data
Daftar tugas guru tidak menambahkan data secara langsung ke database. Implementasi insert data ke database diimplementasikan di ``AddTugasGuruVC``. ``AddTugasGuruVC`` menjalanakan `closure` ``AddTugasGuruVC/onSimpanGuru`` yang diterima Daftar tugas guru untuk memperbarui `outlineView` dan data di `viewModel` menggunakan implementasi ``TugasMapelVC/simpanGuru(_:)`` dan ``GuruViewModel/insertTugas(groupedDeletedData:registerUndo:)``.

- **Event yang dikirim:**
    - ``PenugasanGuruEvent/guruAndMapelInserted(mapelIndices:guruu:)``
    - ``StrukturEvent/inserted(_:)``

**Undo/Redo Flow:**
1. ``TugasMapelVC/simpanGuru(_:)``.
2. → ``GuruViewModel/insertTugas(groupedDeletedData:registerUndo:)`` event tugasGuru dikirim untuk pembaruan `outlineView`.
3. → ``GuruViewModel/insertTugasGuru(_:sortDescriptor:)`` registrasi `undoManager` untuk undo insert. 
4. → ``GuruViewModel/hapusDaftarMapel(data:)`` event tugasGuru dikirim untuk pembaruan `outlineView`. registrasi `undoManager` untuk redo insert.

### Menghapus Data
Daftar tugas guru *tidak menghapus* data di database dan menyimpan data yang dihapus di ``SingletonData/deletedTugasGuru`` untuk dihapus nanti ketika aplikasi akan ditutup (setelah dialog konfirmasi). Setelah data dihapus dari `viewModel`, event `combine` dikirim untuk pembaruan ``Struktur`` dan pembaruan `outlineView`.

**Undo/Redo Flow:**
1. ``TugasMapelVC/hapusRow(_:idToDelete:)``
2. → ``GuruViewModel/hapusDaftarMapel(data:)`` event tugasGuru dikirim untuk pembaruan `outlineView`. registrasi `undoManager` untuk undo hapus.
3. → ``GuruViewModel/insertTugas(groupedDeletedData:registerUndo:)`` event tugasGuru dikirim untuk pembaruan `outlineView`.
4. → ``GuruViewModel/insertTugasGuru(_:sortDescriptor:)`` registrasi `undoManager` untuk redo hapus.

> **Catatan:**
> Tugas guru tidak dapat menghapus data yang masih digunakan di tabel database ``NilaiSiswaMapelColumns``

### Mengedit Data
Daftar tugas guru mengimplementasikan edit data melalui ``AddTugasGuruVC`` yang dikonfigurasi untuk mengedit data dengan metode `closure` ``AddTugasGuruVC/onSimpanGuru`` yang diterima di ``TugasMapelVC`` untuk pembaruan di `viewModel`. Setelah data diperbarui dari `viewModel`, event `combine` dikirim untuk pembaruan ``Struktur`` dan pembaruan `outlineView`

**Undo/Redo Flow:**
1. ``TugasMapelVC/simpanEditedGuru(_:)`` registrasi `undoManager` untuk undo edit.
2. → ``GuruViewModel/updateGuru(newData:)`` pembaruan `viewModel` dan pengiriman event `combine` untuk pembaruan ``Struktur`` dan `outlineView`.
3. → ``TugasMapelVC/undoEdit(_:currentData:)`` registrasi `undoManager` untuk redo edit.


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
- ``DataSDI/Swift/RandomAccessCollection/insertionIndex(for:using:)``

### Prediksi Ketik
- ``DataSDI/ReusableFunc/namaguru``
- ``DataSDI/ReusableFunc/alamat``
- ``DataSDI/ReusableFunc/mapel``
- ``DataSDI/ReusableFunc/jabatan``

### Structures
- ``DataSDI/PenugasanGuruMapelKelasColumns``
