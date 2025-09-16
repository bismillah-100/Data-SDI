# Inventaris

Ringkasan fitur dan tampilan yang berhubungan dengan manajemen data inventaris.

## Overview

Modul ini menampilkan daftar inventaris yang dinamis menggunakan `NSTableView`. Fitur utamanya meliputi:
- **Penyesuaian Kolom**: Dukungan penambahan dan penghapusan kolom (kecuali kolom bawaan) yang disesuaikan dengan skema tabel *database*.
- **Drag & Drop**: Mendukung `Drag & Drop` file gambar (*.png, .jpg, .pdf, .ai*, dll.) langsung ke tabel.
- **Pencarian**: Fitur cari & ganti untuk mengubah data teks pada kolom tertentu.
- **Undo/Redo**: Setiap perubahan data dan kolom diregistrasi ke `NSUndoManager` untuk fungsionalitas *undo* dan *redo* yang reaktif.

> **Catatan Snapshot**
> Data yang dihapus tidak langsung dihapus dari *database*, melainkan disimpan sebagai *snapshot* sementara dalam *array* cadangan. Ini memungkinkan operasi **Undo/Redo** dan memastikan data tidak hilang saat aplikasi ditutup paksa. Data yang dihapus bisa dihapus dari database setelah konfirmasi yang muncul ketika aplikasi akan ditutup.

---

### Menambahkan Data
Data baru dapat ditambahkan melalui dua cara:

1.  **Metode Langsung**: Menambahkan baris dengan data standar yang langsung membuka editor *in-line*.
    - **Alur Undo/Redo**: ``InventoryView/addRowButtonClicked(_:)`` → ``InventoryView/undoAddRows(_:)`` → ``InventoryView/redoAddRows(_:)``
2.  **Drag & Drop**: Menjatuhkan file gambar ke tabel.
    - **Alur Undo/Redo**: ``InventoryView/handleInsertNewRows(at:fileURLs:tableView:)`` → ``InventoryView/undoAddRows(_:)`` → ``InventoryView/redoAddRows(_:)`
    - Jika file dijatuhkan pada baris yang sudah ada, gambar lama akan ditimpa. Alur *undo/redo* untuk ini adalah: ``InventoryView/handleReplaceExistingRow(at:withImageData:tableView:)`` → ``InventoryView/undoReplaceImage(_:imageData:)`` → ``InventoryView/redoReplaceImage(_:imageData:)``

### Mengelola Kolom
Anda dapat menambah, mengedit, dan menghapus kolom. Semua perubahan diregistrasi untuk *undo/redo*.
- **Menambah**: Kolom ditambahkan ke *database* dan *tableView* secara bersamaan.
    - **Alur Undo/Redo**: ``InventoryView/addColumnButtonClicked(_:)`` → ``InventoryView/undoAddColumn(_:)`` → ``InventoryView/redoAddColumn(columnName:)``
- **Mengedit**: Nama kolom dapat diubah melalui migrasi tabel di *database*.
    - **Alur Undo/Redo**: ``InventoryView/editNamaKolom(_:)`` → ``InventoryView/undoEditNamaKolom(kolomLama:kolomBaru:previousValues:)``
- **Menghapus**: Kolom tidak dihapus dari *database* secara permanen, tetapi *snapshot*nya disimpan di `SingletonData/deletedColumns` untuk *undo*.
    - **Alur Undo/Redo**: ``InventoryView/deleteColumnButtonClicked(_:)`` → ``InventoryView/undoDeleteColumn()`` → ``InventoryView/redoDeleteColumn(columnName:)``

## Topics

### Tampilan Utama
- ``InventoryView``
- ``DataSDI/EditableTableView``

### Pengelola Database
- ``DataSDI/DynamicTable``

### Model Data
- ``InventoryView/data``
- ``ImageCacheManager``

### Array Undo
- ``TableChange``
- ``SingletonData/deletedInvID``
- ``SingletonData/undoAddColumns``
- ``SingletonData/deletedColumns``
- ``SingletonData/columns``

### Menambahkan Data
- ``InventoryView/addRowButtonClicked(_:)``
- ``InventoryView/handleInsertNewRow(at:withImageData:tableView:fileName:)``
- ``InventoryView/handleInsertNewRows(at:fileURLs:tableView:)``
- ``InventoryView/undoAddRows(_:)``

### Menghapus Data
- ``InventoryView/delete(_:)``
- ``InventoryView/hapusFoto(_:)``
- ``InventoryView/undoHapus(_:)``
- ``InventoryView/undoReplaceImage(_:imageData:)``

### Mengedit Data
- ``InventoryView/edit(_:)``
- ``DataSDI/EditableTableView/editAction``
- ``DataSDI/OverlayEditorManager``
- ``DataSDI/OverlayEditorManagerDataSource``
- ``DataSDI/OverlayEditorManagerDelegate``

### Mengurutkan Data
- ``DataSDI/Swift/Array/insertionIndex(for:using:)-7s3ru``

### Menambahkan Kolom
- ``InventoryView/addColumnButtonClicked(_:)``
- ``InventoryView/addColumn(name:type:)``
- ``InventoryView/undoAddColumn(_:)``
- ``InventoryView/redoAddColumn(columnName:)``

### Menghapus Kolom
- ``InventoryView/deleteColumn(at:)``
- ``InventoryView/undoDeleteColumn()``
- ``InventoryView/redoDeleteColumn(columnName:)``

### Memperbarui Kolom
- ``InventoryView/editNamaKolom(_:)``
- ``InventoryView/editNamaKolom(_:kolomBaru:)``
- ``InventoryView/undoEditNamaKolom(kolomLama:kolomBaru:previousValues:)``

### Menu
- ``InventoryView/menuNeedsUpdate(_:)``
- ``InventoryView/buatMenuItem()``
- ``InventoryView/setupColumnMenu()``
- ``InventoryView/updateTableMenu(_:)``
- ``InventoryView/updateToolbarMenu(_:)``

### Prediksi Ketik
 ``InventoryView/loadSuggestionsFromDatabase(for:completion:)``
- ``InventoryView/getSuggestions(for:)``
- ``InventoryView/refreshSuggestions()``
- ``InventoryView/updateSuggestionsCache()``

### QuickLook
- ``SharedQuickLook``
