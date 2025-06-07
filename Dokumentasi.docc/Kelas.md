# Kelas

Ringkasan fitur dan tampilan yang berhubungan dengan manajemen data kelas.

## Overview

Modul ini mencakup fitur untuk menampilkan, menambah, mengedit, dan menghapus data kelas, serta elemen tampilan pendukung seperti header dan cuplikan kelas.

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
- ``Kelas1Print``
- ``Kelas2Print``
- ``Kelas3Print``
- ``Kelas4Print``
- ``Kelas5Print``
- ``Kelas6Print``
- ``KelasPrint``

### View Model
- ``KelasViewModel``

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
- ``EditMapel``
- ``MapelEditView``
- ``OverlayEditorManager``
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

### Menu
- ``KelasVC/menuNeedsUpdate(_:)``
- ``KelasVC/buatMenuItem()``
- ``KelasVC/updateTableMenu(table:tipeTabel:menu:)``
- ``KelasVC/updateToolbarMenu(table:tipeTabel:menu:)``

### Manajemen
- ``KelasVC/activeTable()``

### Ringkasan Data
- ``NilaiKelas``
- ``StatistikMurid``
- ``StatistikKelas``
- ``KelasVC/showScrollView(_:)``
