# Siswa

Tampilan tabel untuk pengelolaan data guru menggunakan `NSTableView`.

## Overview

Tampilan siswa memiliki dua tampilan: Grup dan non-grup.
Grup menggunakan NSTableView dengan cell ``GroupTableCellView``, sedangkan non-group menggunakan cell ``CustomTableCellView`` dengan kustomisasi NSDatePicker untuk kolom tahun daftar dan tanggal berhenti.
- Mode Grup dan non-Grup menggunakan class ``EditableTableView`` yang dikelola dalam satu outlet tableView dalam satu class ``SiswaViewController``.
- Data siswa menggunakan kerangka data ``ModelSiswa`` yang dikelola oleh viewModel ``SiswaViewModel``.

## Topics

### Tampilan Utama
- ``SiswaViewController``

### Tampilan Model
- ``SiswaViewModel``

### Model Data
- ``ModelSiswa``

### Array Undo
- ``SingletonData/deletedSiswaArray``
- ``SingletonData/deletedSiswasArray``
- ``SingletonData/undoAddSiswaArray``
- ``SingletonData/redoPastedSiswaArray``
- ``SingletonData/deletedStudentIDs``
- ``SiswaViewController/pastedSiswasArray``
- ``SiswaViewController/redoDeletedSiswaArray``
- ``SiswaViewController/urungsiswaBaruArray``
- ``SiswaViewController/ulangsiswaBaruArray``

### Menambahkan Data
- ``AddDataViewController``
- ``SiswaViewController/addSiswa(_:)``
- ``SiswaViewController/addSiswaNewWindow(_:)``
- ``SiswaViewController/handleDataDidChangeNotification(_:)``
- ``SiswaViewController/urungSiswaBaru(_:)``
- ``SiswaViewController/ulangSiswaBaru(_:)``
- ``SiswaViewController/paste(_:)``
- ``SiswaViewController/undoPaste(_:)``
- ``SiswaViewController/redoPaste(_:)``

### Menghapus Data
- ``SiswaViewController/deleteDataClicked(_:)``
- ``SiswaViewController/deleteSelectedRowsAction(_:)``
- ``SiswaViewController/undoDeleteMultipleData(_:)``
- ``SiswaViewController/redoDeleteMultipleData(_:)``

### Mengedit Data
- ``DataSDI/EditData``
- ``SiswaViewController/edit(_:)``
- ``SiswaViewController/updateDataInBackground(selectedRowIndexes:)``
- ``SiswaViewController/undoEditSiswa(_:)``
- ``SiswaViewController/ubahStatus(_:)``
- ``SiswaViewController/updateKelasDipilih(_:)``

### Mencari dan Mengganti Data pada Kolom
- ``DataSDI/CariDanGanti``
- ``SiswaViewController/findAndReplace(_:)``

### Menu Bar
- ``SiswaViewController/updateUndoRedo(_:)``
- ``SiswaViewController/updateMenuItem(_:)``

### Menu (Toolbar)
- ``SiswaViewController/updateMenu(_:)``

### Menu (Kolom)
- ``SiswaViewController/toggleColumnVisibility(_:)``
- ``SiswaViewController/updateHeaderMenuOrder()``

### Konteks Menu (Klik Kanan)
- ``SiswaViewController/updateMenu(_:)``
- ``SiswaViewController/updateTableMenu(_:)``

### Konteks Menu Perubahan Kelas
- ``TagControl``
- ``SiswaViewController/createCustomMenu()``
- ``SiswaViewController/createCustomMenu2()``
- ``SiswaViewController/tagMenuItem``
- ``SiswaViewController/tagMenuItem2``
- ``SiswaViewController/tagClick(_:)``

### Mengurutkan Data
- ``SortDescriptorWrapper``
- ``DataSDI/SiswaViewModel/sortSiswa(by:isBerhenti:)``
- ``DataSDI/SiswaViewModel/sortGroupSiswa(by:)``
- ``DataSDI/Swift/Array/insertionIndex(for:using:)-2g3nq``


### Dekorasi Tabel
- ``CustomRowView``
- ``GroupTableCellView``
- ``CustomTableCellView``

### Dekorasi Kolom Tabel
- ``MyHeaderCell``
- ``CustomTableHeaderView``

### Mengedit Tanggal
- ``InternalDatePicker``
- ``ExpandingDatePicker``
- ``ExpandingDatePickerPanel``
- ``ExpandingDatePickerPanelController``
- ``ExpandingDatePickerPanelBackdropView``

### Drag & Drop
- ``FilePromiseProvider``
- ``SiswaViewController/dragSourceIsFromOurTable(draggingInfo:)``
- ``SiswaViewController/undoDragFoto(_:image:)``
- ``SiswaViewController/redoDragFoto(_:image:)``

### QuickLook
- ``SharedQuickLook``
- ``SiswaViewController/showQuickLook(_:)``

### Ekspor Data
- ``SiswaViewController/exportToPDF(_:)``
- ``SiswaViewController/exportToExcel(_:)``

### Jumlah Siswa
- ``JumlahSiswa``
- ``MonthlyData``

### Tampilan Rincian Siswa
- ``DataSDI/DetilWindow``
- ``DataSDI/DetailSiswaController``

### Protokol
- ``DetilWindowDelegate``

### Structures
- ``FotoSiswa``

### Enumerations
- ``KelasAktif``
- ``ModelSiswaKey``
- ``TableViewMode``
- ``StatusSiswa``
