# Guru

Tampilan tabel untuk pengelolaan data guru menggunakan `NSTableView`.

## Overview
Menggunakan `NSTableView`. Data dikelola ``DataSDI/GuruViewModel`` dan perubahan diteruskan melalui event `Combine`.

Foundation:
- NSUndoManager
- ``DataSDI/GuruModel``
- ``DataSDI/GuruEvent``
- ``DataSDI/GuruColumns``

Penambahan/pembaruan data hanya diterima melalui event `Combine` di dalam ``GuruViewModel/guruEvent``.
Pembaruan nama guru akan dikirim ke event ``GuruViewModel/tugasGuruEvent`` dan ``GuruViewModel/strukturEvent`` dan dikirim melalui `NotificationCenter` dengan nama `.updateGuruMapel` untuk diterima di ``KelasVC`` dan ``DetailSiswaController``.

### Menambahkan Data
Daftar guru tidak menambahkan data ke database sejarah langsung. Tetapi dengan cara menjalankan implementasi yang disediakan ``AddTugasGuruVC``. ``AddTugasGuruVC`` menggunakan *closure* ``AddTugasGuruVC/onSimpanGuru`` untuk meneruskan pembaruan ke daftar guru. Setelah *closure* diterima daftar guru menggunakan implementasi dari ``GuruViewModel/insertGuruu(_:registerUndo:)`` untuk menambahkan data ke model data dan mengirim *event combine* ``GuruEvent/insert(at:)``.
**Undo/Redo Flow:**
``AddTugasGuruVC`` → ``GuruViewModel/insertGuruu(_:registerUndo:)`` → ``GuruViewModel/removeGuruu(_:registerUndo:)``

### Mengedit Data
1. **In-Line Editing:** Menggunakan ``OverlayEditorManager`` dan protokol ``OverlayEditorManagerDelegate`` dan ``OverlayEditorManagerDataSource``.
2. **Edit Massal:** Menggunakan ``AddTugasGuruVC`` yang dikonfigurasi untuk mengedit data guru.
- Pengeditan guru mengirim event ke ``GuruEvent/moveAndUpdate(updates:moves:)`` dan ``GuruEvent/insert(at:)``.
- Pengeditan nama guru mengirim notifikas `.updatedGuruMapel`.

**Undo/Redo Flow:**
``GuruViewModel/updateGuruu(_:registerUndo:)`` (Undo + Redo).

### Menghapus Data
Daftar guru **tidak menghapus** data yang dihapus di database dan menyimpannya yang dihapus ke *snapshot* ``SingletonData/deletedGuru`` untuk dihapus nanti ketika aplikasi ditutup (setelah dialog konfirmasi).

**Undo/Redo Flow:**
1. ``GuruVC/hapusGuru(_:)``
2. → ``GuruViewModel/removeGuruu(_:registerUndo:)`` simpan *snapshot* ke ``SingletonData/deletedGuru``registrasi undoManager.
3. → ``GuruViewModel/insertGuruu(_:registerUndo:)`` hapus *snapshot* di ``SingletonData/deletedGuru`` registrasi undoManager.

> **Catatan:**
> Daftar guru tidak dapat menghapus data guru yang masih digunakan di tabel database ``PenugasanGuruMapelKelasColumns``.


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
- ``DataSDI/Swift/RandomAccessCollection/insertionIndex(for:using:)``

### Struktur Guru
- ``DataSDI/Struktur``

### Enumerations
- ``GuruEvent``

### Structures
- ``StrukturGuruDictionary``
