//
//  TabContentView.swift
//  Data SDI
//
//  Created by Admin on 17/04/25.
//

import Cocoa

/// Kelas untuk mengelola tampilan konten tab yang berisi beberapa tabel editable.
/// Kelas ini mengimplementasikan NSView dan memuat tampilan dari file XIB.
/// Kelas ini juga menyediakan outlet untuk NSTabView dan beberapa EditableTableView.
/// Kelas ini digunakan untuk menampilkan konten yang berbeda dalam tab yang berbeda.
class TabContentView: NSView {
    /// Outlet untuk NSTabView yang mengelola tab dalam tampilan ini.
    @IBOutlet weak var tabView: NSTabView!
    /// Outlet untuk tabel pertama yang dapat diedit.
    /// Setiap EditableTableView akan menampilkan data yang berbeda sesuai dengan tab yang dipilih.
    /// Kelas EditableTableView harus sudah didefinisikan sebelumnya untuk mengelola tabel yang dapat diedit.
    ///
    /// Lihat ``EditableTableView`` untuk detail implementasi tabel yang dapat diedit.
    @IBOutlet weak var table1: EditableTableView!
    /// Outlet untuk tabel kedua yang dapat diedit.
    ///
    /// Lihat ``EditableTableView`` untuk detail implementasi tabel yang dapat diedit.
    @IBOutlet weak var table2: EditableTableView!
    /// Outlet untuk tabel ketiga yang dapat diedit.
    ///
    /// Lihat ``EditableTableView`` untuk detail implementasi tabel yang dapat diedit.
    @IBOutlet weak var table3: EditableTableView!
    /// Outlet untuk tabel keempat yang dapat diedit.
    ///
    /// Lihat ``EditableTableView`` untuk detail implementasi tabel yang dapat diedit.
    @IBOutlet weak var table4: EditableTableView!
    /// Outlet untuk tabel kelima yang dapat diedit.
    ///
    /// Lihat ``EditableTableView`` untuk detail implementasi tabel yang dapat diedit.
    @IBOutlet weak var table5: EditableTableView!
    /// Outlet untuk tabel keenam yang dapat diedit.
    ///
    /// Lihat ``EditableTableView`` untuk detail implementasi tabel yang dapat diedit.
    @IBOutlet weak var table6: EditableTableView!
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        loadFromNib()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadFromNib()
    }

    /// Memuat tampilan dari file XIB yang terkait dengan kelas ini.
    /// Metode ini akan mencari file XIB dengan nama "TabContentView" dan memuatnya ke dalam outlet yang telah didefinisikan.
    private func loadFromNib() {
        var topLevelObjects: NSArray? = nil
        Bundle.main.loadNibNamed("TabContentView", owner: self, topLevelObjects: &topLevelObjects)
    }
}
