//
//  KelasTableManager.swift
//  Data SDI
//
//  Created by MacBook on 26/08/25.
//

import Cocoa

/**
 Kelas KelasTableManager mengelola tampilan tabel untuk menampilkan data kelas,
 menangani baik presentasi data maupun interaksi pengguna.

 Kelas ini mengimplementasikan protokol NSTableViewDelegate, NSTableViewDataSource
 NSTabViewDelegate, dan NSTextFieldDelegate.
 */
class KelasTableManager: NSObject {
    /// String identifikasi unik untuk tabel berdasarkan jenis tabel aktif dan konteks
    var tableIdentifierStr: String {
        let tingkatKelas = createStringForActiveTable()
        let tableIdentifierStr = if arsip {
            "KelasHistoris-SortDescriptor"
        } else if siswaID == nil {
            "SortDescriptor_" + tingkatKelas
        } else {
            "SortDescriptorSiswa_" + tingkatKelas
        }
        return tableIdentifierStr
    }

    // MARK: - Properti Let

    /// Instance view model bersama untuk mengakses data kelas
    let viewModel: KelasViewModel = .shared

    /// Array tampilan tabel yang dikelola oleh pengontrol ini
    let tables: [NSTableView]

    /// Array tuple berisi tampilan tabel dan jenis yang sesuai
    var tableInfo: [(table: NSTableView, type: TableType)] = .init()

    // MARK: - PROPERTI VARIABEL

    /// Flag yang menunjukkan apakah data arsip sedang ditampilkan
    var arsip: Bool = false

    /// ID siswa opsional untuk penyaringan data
    var siswaID: Int64?

    /// Delegate untuk menangani peristiwa pemilihan tabel
    weak var selectionDelegate: TableSelectionDelegate?

    /// Tampilan tab sebagai wadah untuk beberapa tampilan tabel
    weak var tabView: NSTabView!

    /// Jenis tabel yang sedang aktif
    var activeTableType: TableType = .kelas1

    /// Tampilan tabel yang sedang aktif
    var activeTableView: NSTableView?

    /// Set ID baris yang dipilih untuk mempertahankan status pemilihan
    var selectedIDs: Set<Int64> = []

    /// Dictionary untuk melacak apakah setiap TableType membutuhkan reload
    var needsReloadForTableType: [TableType: Bool] = [:]
    /// Dictionary untuk menyimpan iD `Int64` baris yang perlu di-reload per TableType
    var pendingReloadRows: [TableType: Set<Int64>] = [:]

    /**
     Menginisialisasi instance KelasTableManager baru

     - Parameter:
       - siswaID: ID siswa opsional untuk penyaringan data
       - tabView: Tampilan tab wadah untuk beberapa tabel
       - tableViews: Array tampilan tabel yang akan dikelola
       - selectionDelegate: Delegate untuk peristiwa pemilihan
       - arsip: Flag yang menunjukkan tampilan data arsip

     - Returns: Instance KelasTableManager yang diinisialisasi
     */
    init(siswaID: Int64? = nil, tabView: NSTabView? = nil, tableViews: [NSTableView], selectionDelegate: TableSelectionDelegate? = nil, arsip: Bool = false) {
        self.siswaID = siswaID
        tables = tableViews
        self.tabView = tabView
        self.selectionDelegate = selectionDelegate
        self.arsip = arsip
        super.init()
        for (i, table) in tables.enumerated() {
            guard let type = TableType(rawValue: i) else { continue }
            tableInfo.append((table, type))
        }
        tabView?.delegate = self

        setupNotification()
    }

    private func setupNotification() {
        guard !arsip else { return }

        NotificationCenter.default.addObserver(
            forName: .updateDataKelas,
            queue: ReusableFunc.operationQueue,
            filter: siswaID != nil ? { [weak self] in $0.idSiswa == self?.siswaID } : nil
        ) { [weak self] (payload: NilaiKelasNotif) in
            self?.updateDataKelas(payload)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(updateTugasMapelNotification(_:)), name: .updateTugasMapel, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(updateNamaGuruNotification(_:)), name: .updateGuruMapel, object: nil)
    }
}
