# Rincian Siswa

Representasi siswa tertentu dengan tampilan data yang komprehensif.

## Overview

Menggunakan ``DataSDI/KelasModels`` sebagai kerangka data dan ``DataSDI/KelasViewModel`` untuk mengelola data yang akan dipresentasikan ke dalam ViewController ``DetailSiswaController`` dan ditampilkan sebagai jendela baru untuk setiap siswa. Jendela Rincian Siswa dikelola oleh ``DetilWindow``.
- Rincian lengkap siswa seperti NIS/NISN dll. menggunakan kerangka data dari ``DataSDI/ModelSiswa``
- Menggunakan NSTabView untuk memuat 6 Kelas.
- Ada beberapa tampilan pendukung untuk merepresentasikan beberapa data seperti Foto, Rincian Lengkap, dan Grafis Nilai di Setiap Kelas untuk Semester 1 dan 2.

## Topics

### Jendela
- ``DetilWindow``

### Model Data
- ``KelasModel``
- ``KelasModels``
- ``Kelas1Model``
- ``Kelas2Model``
- ``Kelas3Model``
- ``Kelas4Model``
- ``Kelas5Model``
- ``Kelas6Model``
- ``KelasPrint``
- ``Kelas1Print``
- ``Kelas2Print``
- ``Kelas3Print``
- ``Kelas4Print``
- ``Kelas5Print``
- ``Kelas6Print``

### View Model
- ``KelasViewModel``

### Tampilan Utama
- ``DetailSiswaController``

### NSTabView
- ``TabContentView``

### Tampilan Tabel
- ``DataSDI/EditableTableView``

### Menambahkan Data
- ``AddDetilSiswaUI``
- ``DetailSiswaController/paste(_:)``
- ``DetailSiswaController/validateAndAddData(tableView:forTableType:withPastedData:)``
- ``DetailSiswaController/tambahSiswaButtonClicked(_:)``
- ``DetailSiswaController/undoPaste(table:tableType:)``
- ``DetailSiswaController/redoPaste(tableType:table:)``

### Mengedit Data
- <doc:TableEditing>
- ``DetailSiswaController/undoAction(originalModel:)``
- ``DetailSiswaController/redoAction(originalModel:)``

### Menghapus Data
- ``DetailSiswaController/deleteMenuItemPress(_:)``
- ``DetailSiswaController/deleteMenuItemClicked(_:)``
- ``DetailSiswaController/undoHapus(tableType:table:)``
- ``DetailSiswaController/redoHapus(table:tableType:)``

### Mengurutkan Data
- ``DataSDI/Swift/Array/insertionIndex(for:using:)-1aqar``
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
- ``StatistikMurid``
- ``StudentCombinedChartView``

### Tampilan Pendukung
- ``PratinjauFoto``
- ``CenteringClipView``

### Protokol
- ``DetilWindowDelegate``
- ``WindowWillCloseDetailSiswa``

### Structures
- ``FotoSiswa``
- ``WindowData``

### Enumerations
- ``KelasAktif``
- ``TableType``
