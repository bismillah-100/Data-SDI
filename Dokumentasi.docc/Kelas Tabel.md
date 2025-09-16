# KelasTabel

KelasTableManager adalah kelas yang mengelola tampilan dan interaksi tabel untuk data kelas. Kelas ini bertindak sebagai data source dan delegate untuk NSTableView, serta menangani editing teks `NSTextFieldDelegate` dan delegate `NSTabView`.

## Overview
KelasTableManager mengimplementasikan protokol `NSTabViewDelegate`, `NSTextFieldDelegate`, `NSTableViewDelegate` dan `NSTableViewDataSource`. Protokol tersebut dari kelas ini diteruskan melalui protokol ``TableSelectionDelegate`` ke `NSViewController` yang menggunakan.

- Inisialisasi:
```Swift
class ViewController: TableSelectionDelegate {
    var tableViewManager = TableViewManager!
    var tabView: NSTabView = .init()
    var tables: [NSTableView] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        tableViewManager = .init(siswaID: siswaID, tabView: tabView, tableViews: tables, selectionDelegate: self)
    }
}
```

### Protokol
* **NSTableViewDataSource & NSTableViewDelegate*
* **NSTabViewDelegate*
* **NSTextFieldDelegate*

- Dengan mematuhi protokol NSTableViewDataSource dan NSTableViewDelegate, ``KelasTableManager`` dapat menggunakan fungsi-fungsi yang disediakan. Beberapa fungsi dari protokol tableView diteruskan melalui protokol ``TableSelectionDelegate``.
    - ``KelasTableManager/tableViewSelectionDidChange(_:)`` meneruskan protokol ``TableSelectionDelegate/didSelectRow(_:at:)`` ke `viewController` yang menggunakannya.

- ``KelasTableManager`` juga mematuhi protokol NSTabViewDelegate dan menggunakan implementasi yang disediakan protokol tersebut.
    - ``KelasTableManager/tabView(_:didSelect:)`` meneruskan protokol ``TableSelectionDelegate/didSelectTabView(_:at:)`` ke `viewController` yang menggunakannya.

- ``KelasTableManager`` juga mematuhi protokol NSTextFieldDelegate dan menggunakan implementasi yang disediakan protokol tersebut.
    - ``KelasTableManager/controlTextDidEndEditing(_:)`` meneruskan protokol ``TableSelectionDelegate/didEndEditing(_:originalModel:)`` ke `viewController` yang menggunakannya.

### Notifikasi
- KelasTableManager membuat `observer` untuk perubahan nilai kelas melalui `NotificationCenter` dengan nama `.editDataKelas`.
    - selector: ``KelasTableManager/updateDataKelas(_:)``
    - perilaku: Memperbarui kolom nilai sesuai dengan data baru dari notifikas.
    - userInfo: Notifikasi membawa informasi dengan model ``NilaiKelasNotif``.

## Topics

### Instantiate
- ``KelasTableManager/init(siswaID:tabView:tableViews:selectionDelegate:arsip:)``

### Instance
- ``KelasTableManager/viewModel``

### NSView
- ``KelasTableManager/tables``
- ``KelasTableManager/tabView``

### Variabel
- ``KelasTableManager/arsip``
- ``KelasTableManager/activeTableType``
- ``KelasTableManager/activeTableView``
- ``KelasTableManager/selectedIDs``

### Metode Bantu
- ``KelasTableManager/tableType(_:)``
- ``KelasTableManager/toggleColumnVisibility(_:)``
- ``KelasTableManager/getTableView(for:)``
- ``KelasTableManager/createLabelForActiveTable()``
- ``KelasTableManager/createStringForActiveTable()``

### Protokol
- ``TableSelectionDelegate``
