# Rincian Siswa

Representasi siswa tertentu dengan tampilan data yang komprehensif.

## Overview

Menggunakan ``DataSDI/KelasModels`` sebagai kerangka data dan ``DataSDI/KelasViewModel`` untuk mengelola data yang akan dipresentasikan ke dalam ViewController ``DetailSiswaController`` dan ditampilkan sebagai jendela baru untuk setiap siswa. Jendela Rincian Siswa dikelola oleh ``DetilWindow``.
- Rincian lengkap siswa seperti NIS/NISN dll. menggunakan kerangka data dari ``DataSDI/ModelSiswa``
- Menggunakan NSTabView untuk menampung 6 Kelas.
- Ada beberapa tampilan pendukung untuk merepresentasikan beberapa data seperti Foto, Rincian Lengkap, dan Grafis Nilai di Setiap Kelas untuk Semester 1 dan 2.

## Topics

### Jendela
- ``DetilWindow``

### Model Data
- ``DataSDI/KelasModels``

### Model Tampilan
- ``KelasViewModel``

### Tampilan Utama
- ``DetailSiswaController``

### NSTabView
- ``DataSDI/TabContentView``

### Tampilan Tabel
- ``DataSDI/EditableTableView``

### Mengedit Data Tabel
- <doc:TableEditing>

### Tampilan Pendukung
- ``DataSDI/PratinjauFoto``
- ``StatistikMurid``

### Menambahkan Data
- ``DataSDI/AddDetilSiswaUI``

### Ekspor Data
- ``DataSDI/DetailSiswaController/exportToPDF(_:)``
- ``DataSDI/DetailSiswaController/exportToExcel(_:)``

### Print PDF Data
- ``DataSDI/DetailSiswaController/printPDFDocument(at:)``
- ``DataSDI/DetailSiswaController/generatePDFForPrint(header:siswaData:namaFile:window:sheetWindow:pythonPath:)``
