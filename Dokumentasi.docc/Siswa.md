# Siswa

Tampilan tabel untuk pengelolaan data guru menggunakan `NSTableView`.

## Overview

Modul ini menampilkan data siswa dalam dua mode: **Grup** dan **non-Grup**. Keduanya dikelola oleh `SiswaViewController` menggunakan `EditableTableView`. Perpindahan mode diatur oleh `TableViewMode`.

| Mode | Kelas Cell | Fitur |
| :--- | :--- | :--- |
| **Grup** | ``GroupTableCellView`` | *Sticky header*, *sectioning* |
| **Non-Grup** | ``NamaSiswaCellView`` | Nama Siswa dan Ikon kelas |

Data siswa dikelola oleh ``SiswaViewModel``. Menggunakan ``ModelSiswa`` sebagai model data.

---

## Fungsionalitas Tabel

### Tampilan Tabel
- **`headerView`**: Menggunakan ``CustomTableHeaderView`` untuk membuat salinan *header* tabel yang memberikan efek *sticky header* saat menggulir dalam mode Grup.
- **`headerCellView`**: Menggunakan ``GroupTableCellView`` untuk menampilkan dekorasi *header* tabel, seperti format teks, indikator urutan kolom, dan *padding* kustom.
- **`rowView`**: Menggunakan ``CustomRowView`` untuk mengatur tampilan baris tabel dalam mode Grup.

---

## Manajemen Data

### Menambahkan Data
Penambahan data siswa diinisiasi dari ``AddDataViewController``. Setelah data disimpan ke *database*, ``SiswaViewController`` menerima notifikasi `.siswaBaru`. Notifikasi ini akan memicu ``SiswaViewController/handleDataDidChangeNotification(_:)`` untuk memperbarui tabel dengan menyisipkan baris baru dan mendaftarkan aksi tersebut ke *Undo/Redo stack*.

-  ``AddDataViewController`` atau ``SiswaViewController/pasteClicked(_:)`` (untuk paste) → notifikasi `.siswaBaru` (selain paste) → ``SiswaViewController/handleDataDidChangeNotification(_:)`` → `tableView` insertRow(at:withAnimation:) → Undo/Redo stack. 

### Mengedit Data
Pengeditan data dapat dilakukan melalui dua cara:

1.  **Pengeditan In-line**: Melalui *cell* tabel, dikelola oleh ``OverlayEditorManagerDelegate``. Perubahan terbaru langsung disimpan ke *database* melalui ``SiswaViewModel/updateModelAndDatabase(id:columnIdentifier:rowIndex:newValue:)``, dan tabel diperbarui secara langsung. Aksi ini dicatat ke *Undo/Redo stack* melalui parameter ``SiswaViewModel/undoAction(originalModel:)`` dan ``SiswaViewModel/redoAction(originalModel:)``.

2.  **Pengeditan Massal**: Aksi pengeditan berganda dari ``EditData`` atau sumber lain akan mengirim notifikasi `.editDataSiswa`. Notifikasi ini memicu ``SiswaViewController/receivedNotification(_:)`` untuk memperbarui `SiswaViewModel` dan *database* sebelum dicatat ke *Undo/Redo stack* melalui parameter ``SiswaViewModel/undoEditSiswa(_:registerUndo:)``.

- ``EditData`` → ``OverlayEditorManagerDelegate`` (editing inline) / ``SiswaViewController/receivedNotification(_:)`` (multipel editing) → notifikasi `.editDataSiswa` (multipel editing) → update ke database → update ke ``SiswaViewModel`` → Undo/Redo stack.

3. **Pengeditan Tanggal:** Pengeditan tanggal masuk/berhenti siswa tidak menggunakan ``OverlayEditorManager``. Sebagai gantinya, `NSTableCellView` yang dikustomisasi akan menampilkan ``ExpandingDatePicker``. Setelah pengeditan selesai, notifikasi `.tanggalBerhentiBerubah` dikirim untuk memperbarui data tableView di ``JumlahSiswa``. Implementasi *Undo/Redo* untuk aksi ini sama dengan pengeditan *cell* pada umumnya.

> **Catatan Desain**: ``OverlayEditorManager`` dibuat untuk pengeditan in-line karena mendukung interaksi teks panjang yang dapat digulir, sedangkan pengeditan tanggal menggunakan ``ExpandingDatePicker`` untuk memastikan integritas format dan logika validasi tanggal.

---

### Menghapus Data

- Data yang dihapus dari daftar siswa disimpan di ``SingletonData/deletedSiswasArray`` untuk dihapus di database nanti ketika aplikasi akan ditutup.
    - Hapus Data: ``SiswaViewController/hapus(_:selectedRows:)`` → simpan snapshot ke `deletedSiswasArray`  → pembaruan viewModel dan tableView → registrasi `undoManager` ``SiswaViewController/undoDeleteMultipleData(_:)``.
    - Undo Hapus Data: ``SiswaViewController/undoDeleteMultipleData(_:)`` → pembaruan viewModel dan tableView → hapus *snapshot* terakhir → registrasi `undoManager` untuk redo.
    - Redo Hapus Data: ``SiswaViewController/redoDeleteMultipleData(_:)`` → simpan *snapshot* ke `deletedSiswasArray` → pembaruan viewModel dan tableView → registrasi `undoManager` untuk redo.

> **Undo/Redo stack pembaruan edit** dijalankan dari parameter func:
>   - **Pengeditan In-Line:** ``SiswaViewModel/undoEditSiswa(_:registerUndo:)``.
>   - **Pengeditan Massal:** ``SiswaViewModel/undoAction(originalModel:)`` dan ``SiswaViewModel/redoAction(originalModel:)``.
> **Undo/Redo stack hapus/tambah/paste disimpan di ``SingletonData``:**
>   - **Stack Hapus:** ``SingletonData/deletedSiswasArray``.
>   - **Stack Tambah-Undo:** ``SingletonData/undoAddSiswaArray``.
>   - **Stack Paste-Undo:** ``SingletonData/redoPastedSiswaArray``.


> **Catatan Snapshot**
> 
> Sumber snapshot dapat dilihat pada daftar **Topics** di bawah.
> 
> Snapshot digunakan untuk operasi **hapus**, **tambah**, dan **paste** karena:
> - Data yang dihapus dari tableView **tidak langsung** dihapus dari database.
> - Data sementara disimpan di dalam _array_ sebagai cadangan.
> - Cadangan ini berfungsi untuk:
>   - *Restore* data ke tableView saat operasi Undo.
>   - Menghapus permanen dari database ketika aplikasi akan ditutup.

## Topics

### Sumber Data
- <doc:Siswa-View-Model>
- <doc:Flat-Data-Siswa>
- <doc:Grup-Data-Siswa>

### Tampilan Utama
- ``SiswaViewController``

### Tampilan Model
- ``SiswaViewModel``

### Model Data
- ``ModelSiswa``

### Array Undo
- ``SingletonData/deletedSiswaArray``
- ``SingletonData/deletedSiswasArray``
- ``SingletonData/undoAddSiswaArray``
- ``SingletonData/redoPastedSiswaArray``
- ``SingletonData/deletedStudentIDs``
- ``SiswaViewController/pastedSiswasArray``
- ``SiswaViewController/redoDeletedSiswaArray``
- ``SiswaViewController/urungsiswaBaruArray``
- ``SiswaViewController/ulangsiswaBaruArray``

### Menambahkan Data
- ``AddDataViewController``
- ``SiswaViewController/addSiswa(_:)``
- ``SiswaViewController/addSiswaNewWindow(_:)``
- ``SiswaViewController/handleDataDidChangeNotification(_:)``
- ``SiswaViewController/urungSiswaBaru(_:)``
- ``SiswaViewController/ulangSiswaBaru(_:)``
- ``SiswaViewController/paste(_:)``
- ``SiswaViewController/undoPaste(_:)``
- ``SiswaViewController/redoPaste(_:)``

### Menghapus Data
- ``SiswaViewController/hapusMenu(_:)``
- ``SiswaViewController/hapus(_:selectedRows:)``
- ``SiswaViewController/undoDeleteMultipleData(_:)``
- ``SiswaViewController/redoDeleteMultipleData(_:)``

### Mengedit Data
- <doc:TableEditing>
- ``EditData``
- ``SiswaViewController/edit(_:)``
- ``SiswaViewController/updateDataInBackground(siswaData:updateKelas:snapshot:)``
- ``SiswaViewController/undoEditSiswa(_:)``
- ``SiswaViewController/ubahStatus(_:)``

### Mengedit Kelas
- ``UndoNaikKelasContext``
- ``SiswaViewController/updateKelasDipilih(_:selectedRowIndexes:)``
- ``SiswaViewController/ubahStatus(_:)``
- ``SiswaViewModel/undoNaikKelas(contexts:siswa:aktifkanSiswa:)``
- ``SiswaViewModel/redoNaikKelas(contexts:siswa:oldData:aktifkanSiswa:)``

### Mencari dan Mengganti Data pada Kolom
- ``DataSDI/CariDanGanti``
- ``SiswaViewController/findAndReplace(_:)``

### Menu Bar
- ``SiswaViewController/updateUndoRedo(_:)``
- ``SiswaViewController/updateMenuItem(_:)``

### Menu (Toolbar)
- ``SiswaViewController/updateMenu(_:)``

### Menu (Kolom)
- ``SiswaViewController/toggleColumnVisibility(_:)``
- ``SiswaViewController/updateHeaderMenuOrder()``

### Konteks Menu (Klik Kanan)
- ``SiswaViewController/updateTableMenu(_:)``

### Konteks Menu Perubahan Kelas
- <doc:TagControl>
- ``SiswaViewController/createCustomMenu()``
- ``SiswaViewController/createCustomMenu2()``
- ``SiswaViewController/tagMenuItem``
- ``SiswaViewController/tagMenuItem2``
- ``SiswaViewController/tagClick(_:)``

### Mengurutkan Data
- ``SortDescriptorWrapper``
- ``DataSDI/SiswaViewModel/sortSiswa(by:)``
- ``DataSDI/Swift/RandomAccessCollection/insertionIndex(for:using:)``

### Dekorasi Tabel
- ``CustomRowView``
- ``NamaSiswaCellView``
- ``GroupTableCellView``

### Dekorasi Kolom Tabel
- ``MyHeaderCell``
- ``CustomTableHeaderView``

### Mengedit Tanggal
- ``InternalDatePicker``
- ``ExpandingDatePicker``
- ``ExpandingDatePickerPanel``
- ``ExpandingDatePickerPanelController``
- ``ExpandingDatePickerPanelBackdropView``

### Drag & Drop
- ``DragImageUtility``
- ``DragComponentConfig``
- ``FilePromiseProvider``
- ``SiswaViewController/undoDragFoto(_:image:)``

### QuickLook
- ``SharedQuickLook``
- ``SiswaViewController/showQuickLook(_:)``

### Ekspor Data
- ``SiswaViewController/exportToPDF(_:)``
- ``SiswaViewController/exportToExcel(_:)``

### Jumlah Siswa
- ``JumlahSiswa``
- ``MonthlyData``

### Tampilan Rincian Siswa
- ``DataSDI/DetilWindow``
- ``DataSDI/DetailSiswaController``

### Protokol
- ``DetilWindowDelegate``
- ``KelasVCDelegate``
- ``SiswaDataSource``

### TypeAlias
- ``SiswaDefaultData``

### Structures
- ``DataAsli``

### Enumerations
- ``KelasAktif``
- ``JenisKelamin``
- ``NaikKelasEvent``
- ``StatusSiswa``
- ``SiswaColumn``
- ``TableViewMode``
