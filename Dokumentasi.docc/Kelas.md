# Kelas

Tampilan tabel untuk pengelolaan data kelas menggunakan `NSTableView`.

## Overview

Menggunakan ``DataSDI/KelasModels`` sebagai kerangka data dan ``DataSDI/KelasViewModel`` untuk mengelola data.
- **NSUndoManager**: Mendukung fungsionalitas undo/redo.
- **SQLite.Swift**: Digunakan sebagai lapisan interaksi dengan database.
- **`KelasTableManager`**: Mengelola *delegate* dan *data source* untuk `NSTabView` dan `NSTableView`, serta mengirimkan event seleksi dan pengeditan melalui protokol ``TableSelectionDelegate``.

* Menggunakan enam (6) `NSTableView` untuk kemudahan akses *state* yang melibatkan Undo/Redo. 

### Event Sistem

| Mekanisme         | Digunakan Untuk                                                                                                      | Alasan Pemilihan                                                                                                                                                  |
|-------------------|----------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Combine**       | - Perubahan status siswa (naik/turun kelas, aktif/nonaktif) <br> - Pembaruan nama guru                              | - ViewModel guru sudah memakai Combine untuk *streaming* pembaruan ke tabel guru <br> - Mendukung fitur Combine (operator, sink, dll.) yang mempermudah debugging dan *event chaining* <br> - Cocok untuk event yang sifatnya **kontinu** dan **stateful** |
| **NotificationCenter** | - Penghapusan/undo penghapusan siswa <br> - Pembaruan nama siswa <br> - Sinkronisasi nilai antara Kelas Aktif dan Rincian Siswa | - Skenario relatif sederhana, tidak memerlukan *pipeline* kompleks <br> - Minim overhead, mudah di-*fire* dari berbagai modul <br> - Cocok untuk event **diskrit** dan **satu arah** |


### Menambahkan data
`ViewController` Kelas Aktif ``KelasVC`` tidak mengimplementasikan metode penambahan data baru ke database. Penambahan data ke database diimplementasikan di ``AddDetaildiKelas`` dengan menggunakan closure ``AddDetaildiKelas/onSimpanClick`` yang diterima di KelasVC untuk diinsert ke tabel dengan implementasi ``KelasVC/updateTableMenu(table:tipeTabel:menu:)``.
``AddDetaildiKelas`` → simpan ke database → closure ``AddDetaildiKelas/onSimpanClick`` → ``KelasVC/updateTableMenu(table:tipeTabel:menu:)`` untuk update viewModel dan UI → undo stack dan registrasi undo.

> Selengkapnya bisa dilihat di <doc:Nilai-Kelas>

### Mengedit data
Pengeditan data diimplementasikan melalui protokol `NSTextFieldDelegate` melalui ``KelasTableManager`` untuk update database dan viewModel, kemudian mengirim notifikasi `.updateDataKelas` jika pengeditan di ``KelasVC`` dan `.editDataSiswa` jika pengeditan di ``DetailSiswaController``. Setelanya, delegate ``TableSelectionDelegate/didEndEditing(_:originalModel:)`` diteruskan ke KelasVC dengan informasi data lama untuk Undo/Redo stack dan registrasi undoManager.

---

### Siswa Berpindah Kelas

Bagian ini menjelaskan bagaimana `KelasVC` menangani perpindahan kelas siswa menggunakan *event* dari `SiswaViewModel` melalui framework **Combine**.

- **Alur Perpindahan Kelas**:
    - **Promosi Siswa**: Event ``NaikKelasEvent/kelasBerubah(_:fromKelas:)`` memicu ``KelasVC/siswaDidPromote(_:fromKelas:)``. Data siswa dihapus dari tabel kelas asal, disalin ke ``KelasViewModel/siswaNaikArray``, dan UI diperbarui secara atomik.
    - **Pembatalan Promosi (Undo)**: Event ``NaikKelasEvent/undoUbahKelas(_:toKelas:status:)`` memicu ``KelasVC/undoSiswaDidPromote(_:toKelas:status:)``. Data siswa dikembalikan dari `siswaNaikArray` ke tabel asal dan baris disisipkan kembali.

- **Metode Terkait**:
    - ``KelasVC/setupCombine()``: Mengatur *subscriber* dengan penundaan 100ms untuk memastikan UI siap menerima pembaruan.
    - ``KelasVC/siswaDidPromote(_:fromKelas:)``: Menangani proses promosi.
    - ``KelasVC/undoSiswaDidPromote(_:toKelas:status:)``: Menangani proses pembatalan promosi.

- **Contoh Event**:
```swift
// Saat siswa naik kelas:
SiswaViewModel.shared.kelasEvent.send(.kelasBerubah(id: siswa.id, fromKelas: siswa.kelas))

// Saat undo naik kelas:
SiswaViewModel.shared.kelasEvent.send(.undoUbahKelas(id: siswa.id, toKelas: siswa.kelas, status: .aktif))
```

### Menerima Notifikasi

Notifikasi ini digunakan untuk memperbarui tabel dengan data terbaru yang diperbarui di tempat lain.

- Kelas Aktif merespon perubahan data siswa melalui `NotificationCenter`:
    - **Siswa dihapus:** `.siswaDihapus` → selector: ``KelasVC/handleSiswaDihapusNotification(_:)``.
    - **Siswa dihapus-undo:** `.undoSiswaDihapus` → selector: ``KelasVC/handleUndoSiswaDihapusNotification(_:)``.
    - **Nama Siswa diperbarui:** `.dataSiswaDiEditDiSiswaView` → selector: ``KelasTableManager/handleNamaSiswaDiedit(_:)``.
- Kelas Aktif juga merespon perubahan data kelas dari ``DetailSiswaController`` melalui `NotificationCenter`: 
    - **Nilai dihapus:** `.findDeletedData` → selector: ``KelasTableManager/updateDeletion(_:)``.
    - **Nilai dihapus-undo:** `.updateRedoInDetilSiswa` → selector: ``KelasTableManager/handleUndoKelasDihapusNotification(_:)``.
    - **Nilai diperbarui:** `.updateDataKelas` → selector: ``KelasTableManager/updateDataKelas(_:)``.
- Kelas Aktif juga merespon perubahan data guru melalui `NotificationCenter`:
    - **Nama/Mapel Guru diperbarui:** `.updateGuruMapel` → selector: ``KelasTableManager/updateTugasMapelNotification(_:)``.

### Undo/Redo Flow

Kelas Aktif mengimplementasikan Undo/Redo dengan menggunakan properti **stack** untuk menyimpan *snapshot*.  
Penggunaan stack ini hanya untuk:
- **Undo Hapus**
- **Redo Tambah Data**
- **Redo Paste**

Untuk **Undo/Redo pembaruan data**, digunakan parameter pada fungsi seperti:
- ``KelasVC/undoAction(originalModel:)``
- ``KelasVC/redoAction(originalModel:)``

---

#### Tambah/Paste Data
1. ``AddDetaildiKelas``  
2. → closure ``AddDetaildiKelas/onSimpanClick``  
3. → ``KelasVC/updateTable(_:tambahData:)``  
4. → Simpan *snapshot* data baru ke ``KelasVC/pastedNilaiID``  
5. → Pembaruan tableView & viewModel  
6. → Registrasi `undoManager` untuk Undo

- **Undo Tambah/Paste**  
  ``KelasVC/undoPaste(table:tableType:)`` → update tableView & viewModel → simpan snapshot ke ``SingletonData/pastedData`` → registrasi **Redo** untuk menambah kembali ke tableView & viewModel.

- **Redo Tambah/Paste**  
  ``KelasVC/redoPaste(tableType:table:)`` → update tableView & viewModel → hapus snapshot di ``SingletonData/pastedData`` → registrasi **Undo** untuk menghapus lagi dari tableView & viewModel.

---

#### Hapus Data
1. ``KelasVC/hapus(_:)``  
2. ``KelasTableManager/hapusModelTabel(tableType:tableView:allIDs:deletedDataArray:undoManager:undoTarget:undoHandler:)``
3. → Simpan *snapshot* sebelum dihapus ke:  
   - ``SingletonData/deletedDataArray``  
   - ``SingletonData/deletedKelasAndSiswaIDs``  
4. → Hapus dari viewModel  
5. → Pembaruan tableView
6. → Registrasi `undoManager`

- **Undo Hapus**  
  Mengembalikan data ke tableView & viewModel → menghapus data di *snapshot* → registrasi **Redo Hapus**.

- **Redo Hapus**  
  Sama seperti Hapus Data, menggunakan implementasi ``KelasVC/redoHapus(table:tableType:)``.

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

### Add-On
- <doc:Grafik-Nilai>
- <doc:Kelas-Historis>
- <doc:Rekap-Nilai>

### Tampilan Utama
- ``KelasVC``
- ``KelasTableManager``

### Pengelola Database
- ``DatabaseController``

### Model Data
- ``KelasModels``
- ``KelasPrint``
- ``ImageCacheManager``

### View Model
- ``KelasViewModel``

### TypeAlias 
- ``TabelNilai``

### Array Undo
- ``SingletonData/deletedNilaiID``
- ``SingletonData/deletedDataArray``
- ``SingletonData/deletedKelasAndSiswaIDs``
- ``SingletonData/dataArray``
- ``SingletonData/undoStack``
- ``SingletonData/pastedData``
- ``KelasViewModel/siswaNaikArray``

### Menambahkan Data
- ``AddDetaildiKelas``
- ``KelasVC/addData(_:)``
- ``KelasVC/updateTable(_:tambahData:)``
- ``KelasVC/insertRow(forIndex:withData:comparator:)``
- ``KelasVC/paste(_:)``
- ``KelasVC/undoPaste(table:tableType:)``
- ``KelasVC/redoPaste(tableType:table:)``

### Mengedit Data
- <doc:TableEditing>
- ``KelasVC/undoAction(originalModel:)``
- ``KelasVC/redoAction(originalModel:)``
- ``KelasTableManager/handleNamaSiswaDiedit(_:)``
- ``KelasTableManager/updateNamaGuruNotification(_:)``

### Menghapus Data
- ``KelasVC/hapus(_:)``
- ``KelasVC/hapusPilih(tableType:table:selectedIndexes:)``
- ``KelasVC/undoHapus(tableType:table:)``
- ``KelasVC/redoHapus(table:tableType:)``

### Mengurutkan Data
- ``DataSDI/Swift/RandomAccessCollection/insertionIndex(for:using:)``
- ``KelasViewModel/sortModel(_:by:)``
- ``KelasViewModel/sort(tableType:sortDescriptor:)``
- ``KelasViewModel/getSortDescriptor(forTableIdentifier:)``

### Menu
- ``KelasVC/menuNeedsUpdate(_:)``
- ``KelasVC/buatMenuItem()``
- ``KelasVC/updateTableMenu(table:tipeTabel:menu:)``
- ``KelasVC/updateToolbarMenu(table:tipeTabel:menu:)``

### Ekspor Data
- ``KelasVC/exportButtonClicked(_:)``
- ``KelasVC/exportToCSV(_:)``
- ``KelasVC/exportToExcel(_:)``
- ``KelasVC/exportToPDF(_:)``

### Print Data
- ``PaginatedTable``
- ``PrintKelas``
- ``KelasVC/handlePrint(_:)``

### Manajemen
- ``KelasVC/activeTable()``

### Ringkasan Data
- ``Stats``
- ``ChartKelasViewModel``
- ``KelasChartModel``
- ``StudentCombinedChartView``
- ``NilaiKelas``
- ``StatistikKelas``
- ``StatistikViewController``
- ``KelasVC/showScrollView(_:)``
- ``KelasHistoryVC``

### Protokol
- ``KelasVCDelegate``
- ``DetilWindowDelegate``
- ``TableSelectionDelegate``

### Structures
- ``DeleteNilaiResult``

### Enumerations
- ``KelasAktif``
- ``KelasColumn``
- ``TableType``
