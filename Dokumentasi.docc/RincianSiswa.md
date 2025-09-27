# Rincian Siswa

Representasi siswa tertentu dengan tampilan data yang komprehensif.

## Overview

Menggunakan ``DataSDI/KelasModels`` sebagai kerangka data dan ``DataSDI/KelasViewModel`` untuk mengelola data yang akan dipresentasikan ke dalam ViewController ``DetailSiswaController`` dan ditampilkan sebagai jendela baru untuk setiap siswa. Jendela Rincian Siswa dikelola oleh ``DetilWindow``.
- Rincian lengkap siswa seperti NIS/NISN dll. menggunakan kerangka data dari ``DataSDI/ModelSiswa``
- Menggunakan NSTabView untuk memuat 6 Kelas.
- Ada beberapa tampilan pendukung untuk merepresentasikan beberapa data seperti Foto, Rincian Lengkap, dan Grafis Nilai di Setiap Kelas untuk Semester 1 dan 2.

* TabView dan TableView Delegate dan DataSource dikelola di ``DataSDI/KelasTableManager`` dengan protokol ``DataSDI/TableSelectionDelegate``.

* Menggunakan enam (6) `NSTableView` untuk kemudahan akses *state* yang melibatkan Undo/Redo.

### Menambahkan Data:
- Rincian Siswa tidak mengimplementasikan insert data baru ke database. Penambahan data baru melalui *closure* dari ``AddDetaildiKelas``:
    - ``AddDetaildiKelas`` → simpan ke database → closure ``AddDetaildiKelas/onSimpanClick`` → ``DetailSiswaController/updateTable(_:tambahData:undoIsHandled:aktif:)`` untuk update viewModel dan UI.

### Mengedit Data:
Pengeditan data diimplementasikan melalui protokol `NSTextFieldDelegate` melalui ``KelasTableManager`` untuk update database dan viewModel, kemudian mengirim notifikasi `.updateDataKelas` jika pengeditan di ``KelasVC`` dan `.editDataSiswa` jika pengeditan di ``DetailSiswaController``. Setelanya, delegate ``TableSelectionDelegate/didEndEditing(_:originalModel:)`` diteruskan ke KelasVC dengan informasi data lama untuk Undo/Redo stack dan registrasi undoManager.

### Menerima Event Combine
Combine ini digunakan diimplementasikan untuk perubahan kelas aktif dan status siswa dari ``SiswaViewController``. Event merupakan enum ``NaikKelasEvent``.  Dijalankan di *background thread* untuk fetch dari database dan di *main thread* untuk update tabel.

- Pembaruan status siswa:
    - ``NaikKelasEvent/aktifkanSiswa(_:kelas:)`` → selector: ``DetailSiswaController/aktifkanSiswa(_:kelas:)``. Mengubah status data di setiap baris tabel menjadi `aktif`.
    - ``NaikKelasEvent/nonaktifkanSiswa(_:kelas:)`` → selector: ``DetailSiswaController/undoAktifkanSiswa(_:kelas:)`` Mengubah status data di setiap baris tabel menjadi `aktif == false`.

- Pembaruan kelas siswa:
    - ``NaikKelasEvent/kelasBerubah(_:fromKelas:)`` → selector: ``DetailSiswaController/siswaDidPromote(_:fromKelas:)``.
    - ``NaikKelasEvent/undoUbahKelas(_:toKelas:status:)`` → selector: ``DetailSiswaController/undoSiswaDidPromote(_:toKelas:status:)``.


### Menerima Notifikasi

Notifikasi ini digunakan untuk memperbarui tabel dengan data terbaru yang diperbarui di tempat lain.

- Rincian siswa merespon perubahan terhadap data siswa melalui `NotificationCenter`:
    - **Siswa dihapus:** `.siswaDihapus` → selector: ``DetailSiswaController/handleSiswaDihapusNotification(_:)``.
    - **Siswa dihapus-undo:** `.undoSiswaDihapus` → selector: ``DetailSiswaController/handleUndoSiswaDihapusNotification(_:)``.
    - **Nama Siswa diedit:** `.dataSiswaDiEditDiSiswaView` → selector: ``DetailSiswaController/handleNamaSiswaDiedit(_:)``.

- Rincian siswa juga merespon perubahan data kelas melalui `NotificationCenter`:
    - **Nilai dihapus:** `.kelasDihapus` → selector: ``KelasTableManager/updateDeletion(_:)``.
    - **Nilai dihapus-undo:** `.undoKelasDihapus` → selector: ``KelasTableManager/handleUndoKelasDihapusNotification(_:)``.
    - **Nilai baru:** `.updateTableNotificationDetilSiswa` → selector: ``DetailSiswaController/updateNilaiFromKelasAktif(_:)``.
    - **Nilai diperbarui:** `.updateDataKelas` → selector: ``KelasTableManager/updateDataKelas(_:)``.

- Rincian siswa juga merespon perubahan guru melalui `NotificationCenter`:
    - **Nama/Mapel Guru diperbarui:** `.updateGuruMapel` → selector: ``KelasTableManager/updateTugasMapelNotification(_:)``.

### Event Sistem
Lihat: <doc:Kelas#Siswa-Berpindah-Kelas>, <doc:Kelas#Menerima-Notifikasi>, <doc:Kelas#UndoRedo-Flow>

### Undo/Redo Flow
Rincian siswa mengimplementasikan Undo/Redo dengan menggunakan properti **stack** untuk menyimpan *snapshot*.
Penggunaan stack ini hanya untuk:
- **Undo Hapus**
- **Redo Tambah Data**
- **Redo Paste**

Untuk **Undo/Redo pembaruan data**, digunakan parameter pada fungsi seperti:
- ``DetailSiswaController/undoAction(originalModel:)``
- ``DetailSiswaController/redoAction(originalModel:)``

---

#### Tambah/Paste Data
1. ``AddDetaildiKelas``  
2. → closure ``AddDetaildiKelas/onSimpanClick``  
3. → ``DetailSiswaController/updateTable(_:tambahData:undoIsHandled:aktif:)``  
4. → Simpan *snapshot* data baru ke ``DetailSiswaController/pastedNilaiID``  
5. → Pembaruan tableView & viewModel  
6. → Registrasi `undoManager` untuk Undo

- **Undo Tambah/Paste**  
  ``KelasVC/undoPaste(table:tableType:)`` → update tableView & viewModel → simpan snapshot ke ``DetailSiswaController/pastedNilaiID`` → registrasi **Redo** untuk menambah kembali ke tableView & viewModel.

- **Redo Tambah/Paste**  
  ``KelasVC/redoPaste(tableType:table:)`` → update tableView & viewModel → hapus snapshot di ``DetailSiswaController/pastedNilaiID`` → registrasi **Undo** untuk menghapus lagi dari tableView & viewModel.

---

#### Hapus Data
1. ``DetailSiswaController/hapus(_:)``  
2. ``KelasTableManager/hapusModelTabel(tableType:tableView:allIDs:deletedDataArray:undoManager:undoTarget:undoHandler:)``
3. → Simpan *snapshot* sebelum dihapus ke:  
   - ``DetailSiswaController/deletedDataArray``  
   - ``SingletonData/deletedKelasAndSiswaIDs``  
4. → Hapus dari viewModel  
5. → Pembaruan tableView
6. → Registrasi `undoManager`

- **Undo Hapus**  
  Mengembalikan data ke tableView & viewModel → menghapus data di *snapshot* → registrasi **Redo Hapus**.

- **Redo Hapus**  
  Sama seperti Hapus Data, menggunakan implementasi ``DetailSiswaController/redoHapus(table:tableType:)``.

> **Catatan Snapshot**
> 
> Sumber snapshot dapat dilihat pada daftar **Topics** di bawah.
> 
> Snapshot digunakan untuk operasi **hapus**, **tambah**, dan **paste** karena:
> - Data yang dihapus dari tableView **tidak langsung** dihapus dari database.
> - Data sementara disimpan di dalam _array_ sebagai cadangan.
> - Cadangan ini berfungsi untuk:
>   - *Restore* data ke tableView saat operasi Undo.
>   - Menghapus permanen dari database ketika jendela rincian siswa akan ditutup.

## Topics

### Add-On
- <doc:Pratinjau-Foto>

### Jendela
- ``DetilWindow``

### Model Data
- ``KelasModels``
- ``KelasPrint``

### View Model
- ``KelasViewModel``

### Tampilan Utama
- ``DetailSiswaController``
- ``KelasTableManager``

### Menambahkan Data
- ``DetailSiswaController/paste(_:)``
- ``DetailSiswaController/tambahSiswaButtonClicked(_:)``
- ``DetailSiswaController/undoPaste(table:tableType:)``
- ``DetailSiswaController/redoPaste(tableType:table:)``

### Mengedit Data
- ``DetailSiswaController/undoAction(originalModel:)``
- ``DetailSiswaController/redoAction(originalModel:)``

### Menghapus Data
- ``DetailSiswaController/hapus(_:)``
- ``DetailSiswaController/hapusPilih(tableType:table:selectedIndexes:)``
- ``DetailSiswaController/undoHapus(tableType:table:)``
- ``DetailSiswaController/redoHapus(table:tableType:)``

### Mengurutkan Data
- ``DataSDI/Swift/RandomAccessCollection/insertionIndex(for:using:)``
- ``KelasViewModel/sortModel(_:by:)``
- ``KelasViewModel/sort(tableType:sortDescriptor:)``
- ``KelasViewModel/getSortDescriptor(forTableIdentifier:)``

### Menu
- ``DetailSiswaController/createContextMenu(tableView:)``
- ``DetailSiswaController/updateItemMenus(_:)``

### Ekspor Data
- ``DetailSiswaController/exportToPDF(_:)``
- ``DetailSiswaController/exportToExcel(_:)``

### Print Data
- ``DetailSiswaController/handlePrint(_:)``
- ``DetailSiswaController/printPDFDocument(at:)``
- ``DetailSiswaController/generatePDFForPrint(header:siswaData:namaFile:window:sheetWindow:pythonPath:)``

### Ringkasan Data
- ``ChartKelasViewModel``
- ``KelasChartModel``
- ``SiswaChart``
- ``StudentCombinedChartView``

### Tampilan Pendukung
- ``PratinjauFoto``
- ``CenteringClipView``

### Protokol
- ``DetilWindowDelegate``
- ``WindowWillCloseDetailSiswa``
- ``DataSDI/TableSelectionDelegate``

### Structures
- ``WindowData``
- ``DeleteNilaiResult``

### Enumerations
- ``KelasAktif``
- ``TableType``
