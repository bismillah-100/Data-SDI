# Inventaris

Ringkasan fitur dan tampilan yang berhubungan dengan manajemen data inventaris.

## Overview

Foundation:
- NSUndoManager
- SQLite.Swift

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
