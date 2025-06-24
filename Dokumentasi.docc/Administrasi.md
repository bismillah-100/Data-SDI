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

## Topics

### Tampilan Utama
- ``TransaksiView``

### Pengelola Database
- ``DataSDI/DataManager``

### UI Item
- ``CollectionViewItem``

### Model Data
- ``Entity``

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
- ``DataSDI/TransaksiView/dataDitambah()``
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
- ``DataSDI/TransaksiView/sortSectionKeys()``
- ``DataSDI/TransaksiView/sortSectionKeys(_:)``
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
- ``TransaksiType``
