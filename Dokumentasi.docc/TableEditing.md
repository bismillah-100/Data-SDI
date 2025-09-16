# Edit Data Tabel

OverlayEditorManager bertindak sebagai manajer editor di setiap data tabel.

## Overview

Editor ini muncul saat pengguna menekan Enter atau Tab di sel terakhir yang dipilih, atau saat pengguna klik kedua pada sel kolom tertentu setelah sel dipilih. Implementasi ini digunakan di ``EditableTableView`` dan ``EditableOutlineView``.

Editor ini menggunakan `NSTextView` dan `NSTableView` untuk fungsi berikut:
- **`NSTextView`** dapat menyesuaikan lebar dan tinggi secara dinamis sesuai dengan jumlah teks.
- **`NSTableView`** digunakan untuk menampilkan saran (autocompletion) saat pengguna mengetik.

- Inisialisasi:
```swift
@IBOutlet weak var tableView: EditableTableView!
var editorManager = OverlayEditorManager!

override func viewDidLoad() {
    super.viewDidLoad()
    tableView.dataSource = self
    tableView.delegate = self
    editorManager = .init(tableView: tableView, containingWindow: window)
    editorManager.dataSource = self
    editorManager.delegate = self
    tableView.editAction = { row, column in
        editorManager.startEditing(row: row, column: column)
    }
}
```

- Memanggil overlay manual:
```swift
@IBOutlet weak var tableView: EditableTableView!
var editorManager: OverlayEditorManager!

override func viewDidLoad() {
    super.viewDidLoad()
    // editorManager dan tableView harus sudah diinisialisasi
    tableView.doubleAction = #selector(tableViewDoubleAction(_:))
}

@objc func tableViewDoubleAction(_ sender: Any?) {
    let row = tableView.clickedRow
    let column = tableView.clickedColumn
    editorManager.startEditing(row: row, column: column)
}
```

- Note: `NSTableView` harus menggunakan class ``EditableTableView`` dan `NSOutlineView` harus menggunakan ``EditableOutlineView``.

## Topics

### Tampilan
- ``EditingViewController``
- ``PanelAutocompleteTextView``

### Manajer Editor
- ``DataSDI/OverlayEditorManager``

### Manajer Prediksi
- ``SuggestionCacheManager``

### Protokol
- ``EditableViewType``
- ``DataSDI/OverlayEditorManagerDataSource``
- ``DataSDI/OverlayEditorManagerDelegate``

### Enumerations
- ``GrowthDirection``
