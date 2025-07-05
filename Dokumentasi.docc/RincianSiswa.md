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
- ``KelasModels``
- ``KelasPrint``

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
- ``DetailSiswaController/hapus(_:)``
- ``DetailSiswaController/hapusKlik(tableType:table:clickedRow:)``
- ``DetailSiswaController/hapusPilih(tableType:table:selectedIndexes:)``
- ``DetailSiswaController/undoHapus(tableType:table:)``
- ``DetailSiswaController/redoHapus(table:tableType:)``

### Mengurutkan Data
- ``DataSDI/Swift/Array/insertionIndex(for:using:)-mm8h``
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

### Structures
- ``WindowData``

### Enumerations
- ``KelasAktif``
- ``TableType``
