# Kelas

Tampilan tabel untuk pengelolaan data kelas menggunakan `NSTableView`.

## Overview

Menggunakan ``DataSDI/KelasModels`` sebagai kerangka data dan ``DataSDI/KelasViewModel`` untuk mengelola data.
- Menggunakan NSTabView untuk memuat 6 Kelas.
- NSUndoManager
- SQLite.Swift

## Topics

### Tampilan Utama
- ``KelasVC``

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
- ``SingletonData/deletedKelasID``
- ``SingletonData/deletedDataArray``
- ``SingletonData/deletedDataKelas``
- ``SingletonData/deletedKelasAndSiswaIDs``
- ``SingletonData/dataArray``
- ``SingletonData/undoStack``
- ``SingletonData/pastedData``
- ``SingletonData/siswaNaikArray``

### Menambahkan Data
- ``AddDetaildiKelas``
- ``KelasVC/addData(_:)``
- ``KelasVC/updateTable(_:tambahData:)``
- ``KelasVC/insertRow(forIndex:withData:)``
- ``KelasVC/paste(_:)``
- ``KelasVC/undoPaste(table:tableType:)``
- ``KelasVC/redoPaste(tableType:table:)``

### Mengedit Data
- <doc:TableEditing>
- ``EditMapel``
- ``MapelEditView``
- ``KelasVC/undoAction(originalModel:)``
- ``KelasVC/redoAction(originalModel:)``
- ``KelasVC/handleNamaSiswaDiedit(_:)``
- ``KelasVC/updateNamaGuruNotification(_:)``

### Menghapus Data
- ``KelasVC/hapus(_:)``
- ``KelasVC/hapusKlik(tableType:table:clickedRow:)``
- ``KelasVC/hapusPilih(tableType:table:selectedIndexes:)``
- ``KelasVC/undoHapus(tableType:table:)``
- ``KelasVC/redoHapus(table:tableType:)``

### Mengurutkan Data
- ``DataSDI/Swift/Array/insertionIndex(for:using:)-mm8h``
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

### Enumerations
- ``KelasAktif``
- ``KelasColumn``
- ``TableType``
