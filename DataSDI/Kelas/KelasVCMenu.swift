//
//  KelasVCMenu.swift
//  Data SDI
//
//  Created by Bismillah on 12/12/24.
//

import Cocoa

extension KelasVC {
    /// Fungsi ini untuk membuat menu item baik di tabel atau menu di toolbar.
    /// - Returns: Objek NSMenu yang telah dibuat.
    func buatMenuItem() -> NSMenu {
        let menu = NSMenu()
        let image = NSMenuItem(title: "foto", action: nil, keyEquivalent: "")
        let actionImage = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: .none)
        let largeConf = NSImage.SymbolConfiguration(scale: .large)
        let largeActionImage = actionImage?.withSymbolConfiguration(largeConf)
        image.image = largeActionImage
        menu.addItem(image)
        let refresh = NSMenuItem(title: "Muat Ulang", action: #selector(muatUlang(_:)), keyEquivalent: "")
        refresh.target = self
        menu.addItem(refresh)
        menu.addItem(NSMenuItem.separator())
        let addData = NSMenuItem(title: "Catat Data Baru di \"\(createLabelForActiveTable())\"", action: #selector(addData(_:)), keyEquivalent: "")
        addData.identifier = NSUserInterfaceItemIdentifier("addData")
        menu.addItem(addData)
        let tempel = NSMenuItem(title: "Tempel", action: #selector(pasteWindow(_:)), keyEquivalent: "")
        tempel.identifier = NSUserInterfaceItemIdentifier("tempel")
        tempel.target = self
        // tempel.representedObject = (table, tipeTabel)
        menu.addItem(tempel)
        menu.addItem(NSMenuItem.separator())

        let editMapel = NSMenuItem(title: "Edit", action: #selector(editMapelMenu(_:)), keyEquivalent: "")
        // editMapel.representedObject = (table, tipeTabel)
        editMapel.identifier = NSUserInterfaceItemIdentifier("edit")
        menu.addItem(editMapel)
        let naikKelas = NSMenuItem(title: "Naik Kelas", action: #selector(naikKelasMenu(_:)), keyEquivalent: "")
        naikKelas.identifier = NSUserInterfaceItemIdentifier("naikkelas")
        // menuItem.representedObject = (table, tipeTabel)
        naikKelas.target = self
        menu.addItem(naikKelas)
        menu.addItem(NSMenuItem.separator())

        let copyMenuItem = NSMenuItem(title: "Salin", action: #selector(copyDataContextMenu(_:)), keyEquivalent: "")
        copyMenuItem.identifier = NSUserInterfaceItemIdentifier("salin")
        // copyMenuItem.representedObject = (table, tipeTabel)
        copyMenuItem.target = self
        menu.addItem(copyMenuItem)

        menu.addItem(NSMenuItem.separator())

        let hapus = NSMenuItem(title: "Hapus", action: #selector(hapusMenu(_:)), keyEquivalent: "")
        hapus.identifier = NSUserInterfaceItemIdentifier("hapus")
        hapus.target = self
        // hapus.representedObject = (table, tipeTabel)
        menu.addItem(hapus)

        let hapusData = NSMenuItem(title: "Hapus Data", action: #selector(hapusDataMenu(_:)), keyEquivalent: "")
        hapusData.identifier = NSUserInterfaceItemIdentifier("hapusData")
        // hapusData.representedObject = (table, tipeTabel)
        hapusData.target = self
        menu.addItem(hapusData)
        menu.addItem(NSMenuItem.separator())

        let kalkulasi = NSMenuItem(title: "Print Nilai Semester", action: #selector(printText), keyEquivalent: "")
        kalkulasi.target = self
        kalkulasi.identifier = NSUserInterfaceItemIdentifier("kalkulasi")
        menu.addItem(kalkulasi)
        menu.addItem(NSMenuItem.separator())
        let excel = NSMenuItem(title: "Ekspor Data \"\(createLabelForActiveTable())\" ke File Format CSV", action: #selector(exportButtonClicked(_:)), keyEquivalent: "")
        excel.target = self
        excel.identifier = NSUserInterfaceItemIdentifier("excel")
        // excel.representedObject = (table, tipeTabel)
        menu.addItem(excel)
        menu.addItem(NSMenuItem.separator())
        let newPDF = NSMenuItem(title: "Konversi Data \"\(createLabelForActiveTable())\" ke File PDF", action: #selector(exportToPDF(_:)), keyEquivalent: "")
        newPDF.target = self
        newPDF.identifier = NSUserInterfaceItemIdentifier("newPDF")
        // newPDF.representedObject = (table, tipeTabel)
        menu.addItem(newPDF)
        let newExcel = NSMenuItem(title: "Konversi Data \"\(createLabelForActiveTable())\" ke File Excel", action: #selector(exportToExcel(_:)), keyEquivalent: "")
        newExcel.target = self
        newExcel.identifier = NSUserInterfaceItemIdentifier("newExcel")
        // newExcel.representedObject = (table, tipeTabel)
        menu.addItem(newExcel)
        return menu
    }

    /// Memperbarui menu tabel dengan kondisi klik atau pilih di baris tertentu
    /// - Parameters:
    ///   - table: `NSTableView` yang diklik/dipilih.
    ///   - tipeTabel: Tipe tabel yang akan digunakan untuk merepresentasikan menu.
    ///   - menu: `NSMenu` yang akan diperbarui.
    func updateTableMenu(table: NSTableView, tipeTabel: TableType, menu: NSMenu) {
        let image = menu.items.first(where: { $0.title == "foto" })
        image?.isHidden = true
        image?.isEnabled = true

        let kelasModel = viewModel.kelasData[tipeTabel]!
        guard table.clickedRow >= 0, table.clickedRow < kelasModel.count else {
            for i in menu.items {
                if i.identifier?.rawValue == "excel" ||
                    i.identifier?.rawValue == "kalkulasi" ||
                    i.identifier?.rawValue == "newPDF" ||
                    i.identifier?.rawValue == "newExcel" ||
                    i.identifier?.rawValue == "addData" ||
                    i.title == "Muat Ulang" ||
                    i.title == "Tempel"
                {
                    i.isHidden = false
                    i.representedObject = (table, tipeTabel)
                }
            }
            let kelas = createLabelForActiveTable()

            if let add = menu.items.first(where: { $0.identifier?.rawValue == "addData" }) {
                add.title = "Catat Data Baru di \"\(createLabelForActiveTable())\""
            }
            if let kalkulasi = menu.items.first(where: { $0.identifier?.rawValue == "kalkulasi" }) {
                kalkulasi.title = "Print Nilai Semester"
            }
            if let excel = menu.items.first(where: { $0.identifier?.rawValue == "excel" }) {
                excel.title = "Ekspor Data \"\(kelas)\" ke File Format CSV"
            }
            if let newExcel = menu.items.first(where: { $0.identifier?.rawValue == "newExcel" }) {
                newExcel.title = "Konversi Data \"\(kelas)\" ke File Excel"
            }
            if let pdf = menu.items.first(where: { $0.identifier?.rawValue == "newPDF" }) {
                pdf.title = "Konversi Data \"\(kelas)\" ke File PDF"
            }

            if let add = menu.items.first(where: { $0.identifier?.rawValue == "addData" }) {
                add.title = "Catat Data Baru di \"\(createLabelForActiveTable())\""
            }
            if let naikKelas = menu.items.first(where: { $0.identifier?.rawValue == "naikkelas" }) {
                naikKelas.isHidden = true
            }

            if let salin = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) {
                salin.isHidden = true
            }

            if let edit = menu.items.first(where: { $0.identifier?.rawValue == "edit" }) {
                edit.isHidden = true
            }

            if let hapus = menu.items.first(where: { $0.identifier?.rawValue == "hapus" }) {
                hapus.isHidden = true
            }

            if let hapusData = menu.items.first(where: { $0.identifier?.rawValue == "hapusData" }) {
                hapusData.isHidden = true
            }

            return
        }
        let selectedKelas = kelasModel[table.clickedRow]
        var editTitle = ""
        var salinTitle = ""
        var hapusTitle = ""
        var naikTitle = ""
        var hapusDataTitle = ""
        var mapelData: [String] = []
        var processedMapels = Set<String>()
        var processedSiswas = Set<String>()
        func formatUniqueMapelNames(_ mapelNames: [String]) -> String {
            let uniqueMapelNames = Array(Set(mapelNames)).sorted() // Menghilangkan duplikasi dan mengurutkan
            guard !uniqueMapelNames.isEmpty else { return "Mapel" }

            switch uniqueMapelNames.count {
            case 1:
                return uniqueMapelNames[0]
            case 2:
                return "\(uniqueMapelNames[0]) dan \(uniqueMapelNames[1])"
            case 3:
                return "\(uniqueMapelNames[0]), \(uniqueMapelNames[1]), dan \(uniqueMapelNames[2])"
            default:
                let firstThree = uniqueMapelNames.prefix(3)
                let remainingCount = uniqueMapelNames.count - 3
                let formattedFirst = firstThree.joined(separator: ", ")
                return "\(formattedFirst), dan \(remainingCount) lainnya"
            }
        }
        // Membuat string untuk menu item berdasarkan mapel yang dipilih
        if table.selectedRowIndexes.contains(table.clickedRow), table.selectedRowIndexes.count > 1 {
            for row in table.selectedRowIndexes {
                let mapel = kelasModel[row].mapel
                let siswa = kelasModel[row].namasiswa
                // Cek apakah mapel sudah diproses sebelumnya
                if !processedMapels.contains(mapel) {
                    // Tambahkan mapel ke dalam Set
                    processedMapels.insert(mapel)

                    // Tambahkan data ke mapelData dengan mapel sebagai Set
                    mapelData.append(mapel)
                }
                if !processedSiswas.contains(siswa) {
                    processedSiswas.insert(siswa)
                }
            }
            let mapelNames = mapelData
            let formattedMapelNames = formatUniqueMapelNames(mapelNames)
            editTitle = "Edit Nama Guru \(formattedMapelNames)"
            salinTitle = "Salin \(table.selectedRowIndexes.count) Data"
            hapusTitle = "Hapus \(table.selectedRowIndexes.count) Data Siswa"
            hapusDataTitle = "Hapus \(table.selectedRowIndexes.count) Catatan dari Kelas Aktif \"\(createLabelForActiveTable())\""
            if table == table6 {
                naikTitle = "Tandai \(processedSiswas.count) Siswa sebagai \(createLabelForNextClass()) 🎓 🎉 🎊"
            } else {
                naikTitle = "Tandai \(processedSiswas.count) Siswa sebagai Naik ke \"\(createLabelForNextClass())\" 🎉"
            }
        } else {
            let mapelName = selectedKelas.mapel
            let namaSiswa = selectedKelas.namasiswa
            editTitle = "Edit Nama Guru \(mapelName) di \"\(createLabelForActiveTable())\""
            salinTitle = "Salin 1 Data \"\(namaSiswa)\""
            hapusTitle = "Hapus 1 Data \"\(namaSiswa)\""
            if table == table6 {
                naikTitle = "\"\(namaSiswa)\" \(createLabelForNextClass()) 🎓 🎉 🎊"
            } else {
                naikTitle = "\"\(namaSiswa)\" Naik ke \"\(createLabelForNextClass())\" 🎉"
            }
            hapusDataTitle = "Hapus 1 Catatan dari Kelas Aktif \"\(createLabelForActiveTable())\""
        }
        if let salin = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) {
            salin.title = salinTitle
        }

        if let edit = menu.items.first(where: { $0.identifier?.rawValue == "edit" }) {
            edit.title = editTitle
        }

        if let hapus = menu.items.first(where: { $0.identifier?.rawValue == "hapus" }) {
            hapus.title = hapusTitle
        }

        if let hapusData = menu.items.first(where: { $0.identifier?.rawValue == "hapusData" }) {
            hapusData.title = hapusDataTitle
        }

        if let naikKelas = menu.items.first(where: { $0.identifier?.rawValue == "naikkelas" }) {
            naikKelas.title = naikTitle
        }
        for i in menu.items {
            if i.identifier?.rawValue == "excel" ||
                i.identifier?.rawValue == "kalkulasi" ||
                i.identifier?.rawValue == "newPDF" ||
                i.identifier?.rawValue == "newExcel" ||
                i.identifier?.rawValue == "addData" ||
                i.title == "Muat Ulang" ||
                i.title == "Tempel" ||
                i.title == "foto"
            {
                i.isHidden = true
            } else {
                i.isHidden = false
                i.representedObject = (table, tipeTabel)
            }
        }
    }

    /// Memperbarui menu di toolbar dengan kondisi di baris yang dipilih.
    /// - Parameters:
    ///   - table: `NSTableView` yang dipilih.
    ///   - tipeTabel: Tipe tabel yang akan digunakan untuk merepresentasikan menu.
    ///   - menu: `NSMenu` yang akan diperbarui.
    func updateToolbarMenu(table: NSTableView, tipeTabel: TableType, menu: NSMenu) {
        let kelas = createLabelForActiveTable()
        let image = menu.items.first(where: { $0.title == "foto" })
        image?.isHidden = true
        image?.isEnabled = true
        if let add = menu.items.first(where: { $0.identifier?.rawValue == "addData" }) {
            add.title = "Catat Data Baru di \"\(createLabelForActiveTable())\""
        }
        if let kalkulasi = menu.items.first(where: { $0.identifier?.rawValue == "kalkulasi" }) {
            kalkulasi.title = "Print Nilai Semester"
        }
        if let excel = menu.items.first(where: { $0.identifier?.rawValue == "excel" }) {
            excel.title = "Ekspor Data \"\(kelas)\" ke File Format CSV"
        }
        if let pdf = menu.items.first(where: { $0.identifier?.rawValue == "newPDF" }) {
            pdf.title = "Konversi Data \"\(kelas)\" ke File PDF"
        }
        if let newExcel = menu.items.first(where: { $0.identifier?.rawValue == "newExcel" }) {
            newExcel.title = "Konversi Data \"\(kelas)\" ke File Excel"
        }
        guard table.numberOfSelectedRows >= 1 else {
            for i in menu.items {
                if i.identifier?.rawValue == "excel" ||
                    i.identifier?.rawValue == "kalkulasi" ||
                    i.identifier?.rawValue == "newPDF" ||
                    i.identifier?.rawValue == "newExcel" ||
                    i.identifier?.rawValue == "addData" ||
                    i.title == "Muat Ulang" ||
                    i.title == "Tempel"
                {
                    i.isHidden = false
                    i.representedObject = (table, tipeTabel)
                }
            }

            if let naikKelas = menu.items.first(where: { $0.identifier?.rawValue == "naikkelas" }) {
                naikKelas.isHidden = true
            }

            if let salin = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) {
                salin.isHidden = true
            }

            if let edit = menu.items.first(where: { $0.identifier?.rawValue == "edit" }) {
                edit.isHidden = true
            }

            if let hapus = menu.items.first(where: { $0.identifier?.rawValue == "hapus" }) {
                hapus.isHidden = true
            }

            if let hapusData = menu.items.first(where: { $0.identifier?.rawValue == "hapusData" }) {
                hapusData.isHidden = true
            }

            return
        }
        let kelasModel = viewModel.kelasData[tipeTabel]!
        let selectedKelas = kelasModel[table.selectedRow]
        var editTitle = ""
        var salinTitle = ""
        var hapusTitle = ""
        var naikTitle = ""
        var hapusDataTitle = ""
        var mapelData: [String] = []
        var processedMapels = Set<String>()
        var processedSiswas = Set<String>()
        func formatUniqueMapelNames(_ mapelNames: [String]) -> String {
            let uniqueMapelNames = Array(Set(mapelNames)).sorted() // Menghilangkan duplikasi dan mengurutkan
            guard !uniqueMapelNames.isEmpty else { return "Mapel" }

            switch uniqueMapelNames.count {
            case 1:
                return uniqueMapelNames[0]
            case 2:
                return "\(uniqueMapelNames[0]) dan \(uniqueMapelNames[1])"
            case 3:
                return "\(uniqueMapelNames[0]), \(uniqueMapelNames[1]), dan \(uniqueMapelNames[2])"
            default:
                let firstThree = uniqueMapelNames.prefix(3)
                let remainingCount = uniqueMapelNames.count - 3
                let formattedFirst = firstThree.joined(separator: ", ")
                return "\(formattedFirst), dan \(remainingCount) lainnya"
            }
        }
        // Membuat string untuk menu item berdasarkan mapel yang dipilih
        if table.selectedRowIndexes.count > 1 {
            for row in table.selectedRowIndexes {
                let mapel = kelasModel[row].mapel
                let siswa = kelasModel[row].namasiswa
                // Cek apakah mapel sudah diproses sebelumnya
                if !processedMapels.contains(mapel) {
                    // Tambahkan mapel ke dalam Set
                    processedMapels.insert(mapel)

                    // Tambahkan data ke mapelData dengan mapel sebagai Set
                    mapelData.append(mapel)
                }
                if !processedSiswas.contains(siswa) {
                    processedSiswas.insert(siswa)
                }
            }
            let mapelNames = mapelData
            let formattedMapelNames = formatUniqueMapelNames(mapelNames)
            editTitle = "Edit Nama Guru \(formattedMapelNames)"
            salinTitle = "Salin \(table.selectedRowIndexes.count) Data"
            hapusTitle = "Hapus \(table.selectedRowIndexes.count) Data Siswa"
            hapusDataTitle = "Hapus \(table.selectedRowIndexes.count) Catatan dari Kelas Aktif \"\(createLabelForActiveTable())\""
            if table == table6 {
                naikTitle = "Tandai \(processedSiswas.count) Siswa sebagai \(createLabelForNextClass()) 🎓 🎉 🎊"
            } else {
                naikTitle = "Tandai \(processedSiswas.count) Siswa sebagai Naik ke \"\(createLabelForNextClass())\" 🎉"
            }
        } else {
            let mapelName = selectedKelas.mapel
            let namaSiswa = selectedKelas.namasiswa
            editTitle = "Edit Nama Guru \(mapelName) di \"\(createLabelForActiveTable())\""
            salinTitle = "Salin 1 Data \"\(namaSiswa)\""
            hapusTitle = "Hapus 1 Data \"\(namaSiswa)\""
            if table == table6 {
                naikTitle = "\"\(namaSiswa)\" \(createLabelForNextClass()) 🎓 🎉 🎊"
            } else {
                naikTitle = "\"\(namaSiswa)\" Naik ke \"\(createLabelForNextClass())\" 🎉"
            }
            hapusDataTitle = "Hapus 1 Catatan dari Kelas Aktif \"\(createLabelForActiveTable())\""
        }
        if let salin = menu.items.first(where: { $0.identifier?.rawValue == "salin" }) {
            salin.title = salinTitle
        }

        if let edit = menu.items.first(where: { $0.identifier?.rawValue == "edit" }) {
            edit.title = editTitle
        }

        if let hapus = menu.items.first(where: { $0.identifier?.rawValue == "hapus" }) {
            hapus.title = hapusTitle
        }

        if let hapusData = menu.items.first(where: { $0.identifier?.rawValue == "hapusData" }) {
            hapusData.title = hapusDataTitle
        }

        if let naikKelas = menu.items.first(where: { $0.identifier?.rawValue == "naikkelas" }) {
            naikKelas.title = naikTitle
        }
        for i in menu.items {
            if i.title == "foto" {
                i.isHidden = true
            } else {
                i.isHidden = false
                i.representedObject = (table, tipeTabel)
            }
        }
    }
}
