# Administrasi
Tampilan representatif untuk pengelolaan data administrasi menggunakan `NSCollectionView`.

## Overview
Mode tampilan:
- Grup. Pengelompokan data dengan kriteria acara, kategori, atau keperluan.
- Non-Grup. Representasi data secara utuh.

Foundation:
- NSUndoManager
- CoreData
- Entity

### Menambah data:
``TransaksiView`` tidak menambahkan data langsung ke database. Penambahan data dilakukan di ``CatatTransaksi`` yang mengirim notifikasi ``DataManager/dataDidChangeNotification`` kemudian dihandle di ``TransaksiView/dataDitambah(_:)``. Undo/Redo berada di ``TransaksiView/undoAddItem(_:)`` dan ``TransaksiView/redoAddItem(_:)``

### Mengedit data:
``TransaksiView`` tidak memperbarui data langsung ke database. Pembaruan di database diimplementasikan di ``EditTransaksi`` yang mengirim notifikasi ``DataManager/dataDieditNotif`` kemudian di handle di ``TransaksiView/reloadEditedItems(_:)``. Implementasi Undo/Redo berada dalam satu implementasi di ``TransaksiView/undoEdit(_:)``.

### Menghapus Data:
- Daftar transaksi secara otomatis menghapus data dari `CoreData` saat dihapus dari `CollectionView`.
    - **Hapus Data:** ``TransaksiView/deleteSelectedItems(_:section:)`` → simpan *snapshot* → hapus dari Core Data dan CollectionView → registrasi undoManager dengan *snaphsot* melalui parameter di ``TransaksiView/undoHapus(_:)``.
    - **Undo Hapus Data:** ``TransaksiView/undoHapus(_:)`` → mengembalikan snapsot dari parameter ke Core Data dan CollectionView → registrasi undoManager untuk redo dengan *snaphsot* melalui parameter di ``TransaksiView/redoHapus(_:)``.
    - **Redo Hapus Data:** ``TransaksiView/redoHapus(_:)`` → simpan *snapshot* → hapus data dari Core Data dan CollectionView → registrasi undoManager dengan *snaphsot* melalui parameter di ``TransaksiView/undoHapus(_:)``.



## Topics

### Add-On
- <doc:Grafik-Administrasi>

### Tampilan Utama
- ``TransaksiView``

### Pengelola Database
- ``DataSDI/DataManager``

### UI Item
- ``CollectionViewItem``

### Model Data
- ``Entity``
- ``UniqueString``

### Layout
- ``DataSDI/CustomFlowLayout``
- ``DataSDI/HeaderView``
- ``DataSDI/CustomHeaderLayoutAttributes``

### Konfigurasi Toolbar
- ``DataSDI/TransaksiView/setupToolbar()``
- ``DataSDI/TransaksiView/updateToolbarGroupMenu(_:)``

### Menu
- ``DataSDI/TransaksiView/updateMenu()``
- ``DataSDI/TransaksiView/updateItemMenu()``
- ``DataSDI/TransaksiView/buatGroupMenu()``
- ``DataSDI/TransaksiView/updateToolbarGroupMenu(_:)``

### Memperbarui Menu Bar
- ``DataSDI/TransaksiView/updateUndoRedo()``
- ``DataSDI/TransaksiView/updateMenuItem(_:)``

### Menambahkan Data
- ``DataSDI/CatatTransaksi``
- ``DataSDI/TransaksiView/dataDitambah(_:)``
- ``DataSDI/TransaksiView/insertSingleItem(_:)``
- ``DataSDI/TransaksiView/undoAddItem(_:)``
- ``DataSDI/TransaksiView/redoAddItem(_:)``

### Menghapus Data
- ``DataSDI/TransaksiView/hapus(_:)``
- ``DataSDI/TransaksiView/undoHapus(_:)``
- ``DataSDI/TransaksiView/redoHapus(_:)``

### Mengedit Data
- ``DataSDI/EditTransaksi``
- ``DataSDI/TransaksiView/edit(_:)``
- ``DataSDI/TransaksiView/reloadEditedItems(_:)``
- ``DataSDI/TransaksiView/undoEdit(_:)``
- ``DataSDI/TransaksiView/updateItem(ids:prevData:)``

### Memberikan Tanda
- ``DataSDI/TransaksiView/tandaiTransaksi(_:)``
- ``DataSDI/TransaksiView/undoMark(_:snapshot:)``

### Mencari Data
- ``DataSDI/TransaksiView/cariData()``
- ``DataSDI/TransaksiView/applyFilters()``
- ``DataSDI/TransaksiView/filterData(withType:)``
- ``DataSDI/TransaksiView/filterAcaraChanged(_:)``
- ``DataSDI/TransaksiView/filterKategoriChanged(_:)``
- ``DataSDI/TransaksiView/filterKeperluanChanged(_:)``
- ``DataSDI/TransaksiView/procSearchFieldInput(sender:)``
- ``DataSDI/TransaksiView/search(_:)``

### Mengurutkan Data
- ``DataSDI/TransaksiView/urutkanDipilih()``
- ``DataSDI/TransaksiView/sortPopUpValueChanged(_:)``
- ``DataSDI/TransaksiView/sortGroupedData(_:)``

### Logika Urutan Data
- ``DataSDI/TransaksiView/insertionIndex(for:)``
- ``DataSDI/TransaksiView/insertionIndex(for:in:)``
- ``DataSDI/TransaksiView/getSortingCriteria(for:)``
- ``DataSDI/TransaksiView/compareElements(_:_:criteria:)``

### Jumlah Transaksi
- ``JumlahTransaksi``
- ``JumlahTransaksiRowView``

### Ringkasan Data
- ``AdminChart``
- ``AdminLineChartView``
- ``AdminChartViewModel``
- ``ChartDataPoint``
- ``ChartPeriod``
- ``TooltipView``

### Structures
- ``EntitySnapshot``

### Enumerations
- ``JenisTransaksi``
