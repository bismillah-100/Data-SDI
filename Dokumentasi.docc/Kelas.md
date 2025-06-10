# Kelas

Tampilan tabel untuk pengelolaan data kelas menggunakan `NSTableView`.

## Overview

Menggunakan ``DataSDI/KelasModels`` sebagai kerangka data dan ``DataSDI/KelasViewModel`` untuk mengelola data.
- Menggunakan NSTabView untuk memuat 6 Kelas.
- NSUndoManager
- SQLite.Swift
- DGCharts

## Topics

### Tampilan Utama
- ``KelasVC``

### Pengelola Database
- ``DatabaseController``

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

### Array Undo
- ``SingletonData/deletedKelasID``
- ``SingletonData/deletedDataArray``
- ``SingletonData/deletedDataKelas``
- ``SingletonData/deletedKelasAndSiswaIDs``
- ``SingletonData/dataArray``
- ``SingletonData/undoStack``
- ``SingletonData/pastedData``
- ``SingletonData/siswaNaikArray``
- ``SingletonData/siswaNaikId``

### Menambahkan Data
- ``AddDetaildiKelas``
- ``PastediKelas``
- ``KelasVC/addData(_:)``
- ``KelasVC/updateTable(_:)``
- ``KelasVC/insertRow(forIndex:withData:)``
- ``KelasVC/paste(_:)``
- ``KelasVC/undoPaste(table:tableType:)``
- ``KelasVC/redoPaste(tableType:table:)``

### Mengedit Data
- <doc:TableEditing>
- ``EditMapel``
- ``MapelEditView``
- ``KelasVC/editMapel(tableType:table:data:)``
- ``KelasVC/editMapels(tableType:table:data:)``
- ``KelasVC/undoAction(originalModel:)``
- ``KelasVC/redoAction(originalModel:)``
- ``KelasVC/undoUpdateNamaGuru(originalModel:)``

### Menghapus Data
- ``KelasVC/hapus(_:)``
- ``KelasVC/hapusKlik(tableType:table:clickedRow:)``
- ``KelasVC/hapusPilih(tableType:table:selectedIndexes:)``
- ``KelasVC/undoHapus(tableType:table:)``
- ``KelasVC/redoHapus(table:tableType:)``
- ``KelasVC/hapusDataKlik(tableType:table:clickedRow:)``
- ``KelasVC/hapusDataPilih(tableType:table:selectedIndexes:)``
- ``KelasVC/undoHapusData(tableType:table:)``
- ``KelasVC/redoHapusData(tableType:table:)``

### Mengurutkan Data
- ``DataSDI/Swift/Array/insertionIndex(for:using:)-1aqar``
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
- ``PrintKelas``
- ``KelasVC/handlePrint(_:)``

### Manajemen
- ``KelasVC/activeTable()``

### Ringkasan Data
- ``Stats``
- ``TeksCuplikan``
- ``NilaiKelas``
- ``StatistikKelas``
- ``StatistikViewController``
- ``KelasVC/showScrollView(_:)``

### Protokol
- ``KelasVCDelegate``
- ``DetilWindowDelegate``

### Enumerations
- ``KelasAktif``
- ``KelasModelsColumnIdentifier``
- ``TableType``
