//
//  JumlahSiswa.swift
//  Data Manager
//
//  Created by Bismillah on 19/11/23.
//

import Cocoa

class JumlahSiswa: NSViewController {
    let dbController = DatabaseController.shared
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var filterJumlah: NSTextField!
    @IBOutlet weak var visualEffect: NSVisualEffectView!
    @IBOutlet weak var stackHeaderTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var stackBox: NSBox!
    private var isDataLoaded: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        stackBox.boxType = .custom
        stackBox.contentViewMargins = .zero
        self.filterJumlah.alphaValue = 0.6
        visualEffect.material = .headerView
        stackBox.borderColor = .gridColor
        stackBox.fillColor = .gridColor
        
        // Do view setup here.
        NotificationCenter.default.addObserver(self, selector: #selector(saveData(_:)), name: .saveData, object: nil)
    }
//    @objc func tabBarDidHide(_ notification: Notification) {
//        guard let window = self.view.window,
//           let tabGroup = window.tabGroup,
//           !tabGroup.isTabBarVisible else {
//            return
//        }
//        DispatchQueue.main.async { [unowned self] in
//            guard stackHeaderTopConstraint.constant != 35 else {return}
//            stackHeaderTopConstraint.constant = 35
//            scrollView.contentInsets.top = 79
//            scrollView.layoutSubtreeIfNeeded()
//            labelStack.layoutSubtreeIfNeeded()
//        }
//    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard !isDataLoaded else { return }
        
        tableView.delegate = self
        tableView.dataSource = self
        for columnInfo in tableView.tableColumns {
            guard let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(columnInfo.identifier.rawValue)) else {
                continue
            }
            let customHeaderCell = NSTableHeaderCell()
            customHeaderCell.title = columnInfo.title
            column.headerCell = customHeaderCell
        }
        Task { @MainActor [weak self] in
            guard let self = self else {return}
            if SingletonData.monthliData.isEmpty {
                self.filterJumlah.stringValue = "Memuat..."
                self.progressIndicator.isHidden = false
                self.progressIndicator.startAnimation(self)
                self.tableView.delegate = self
                self.tableView.dataSource = self
                if let savedRowHeight = UserDefaults.standard.value(forKey: "JumlahSiswaTableHeight") as? CGFloat {
                    self.tableView.rowHeight = savedRowHeight
                }
                Task.detached() { [weak self] in
                    await self?.reloadData()
                }
            } else {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3 // Durasi animasi
                    context.allowsImplicitAnimation = true
                    
                    self.progressIndicator.stopAnimation(nil)
                    self.progressIndicator.isHidden = true
                    self.labelStack.layoutSubtreeIfNeeded()
                    self.updateFilterJumlah()
                } completionHandler: {
                    self.isDataLoaded = true
                }
            }
        }
    }
    var toolbarMenu = NSMenu()
    override func viewDidAppear() {
        super.viewDidAppear()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateMenuItem(self)
            self.view.window?.makeFirstResponder(self.tableView)
            if let window = self.view.window, let group = window.tabGroup {
                if !group.isTabBarVisible {
                    DispatchQueue.main.asyncAfter(deadline: .now()) { [unowned self] in
                        stackHeaderTopConstraint.constant = 35
                        scrollView.contentInsets.top = 79
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now()) { [unowned self] in
                        stackHeaderTopConstraint.constant = 60
                        scrollView.contentInsets.top = 104
                    }
                }
            }
        }
        let menu = buatItemMenu()
        toolbarMenu = buatItemMenu()
        menu.delegate = self
        tableView.menu = menu
        setupToolbar()
        tableView.allowsMultipleSelection = true
        tableView.allowsTypeSelect = true
        // NotificationCenter.default.addObserver(self, selector: #selector(tabBarDidHide(_:)), name: .windowTabDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(procDataDidChange), name: .jumlahSiswa, object: nil)
    }
    @objc func saveData(_ notification: Notification) {
        
    }
    override func viewDidDisappear() {
        super.viewDidDisappear()
    }

    //MARK: -DATA
    
    @IBOutlet weak var labelStack: NSStackView!
    
    @IBAction func muatUlang(_ sender: Any) {
        Task { [weak self] in
            guard let self = self else {return}
            // Mulai progress indicator
            self.progressIndicator.isHidden = false
            self.progressIndicator.startAnimation(self)
            
            await self.reloadData()
        }
    }
    func reloadData() async {
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            self.filterJumlah.stringValue = "Memuat..."
            self.progressIndicator.isHidden = false
            self.progressIndicator.startAnimation(nil)
            if self.tableView.numberOfRows != 0 {
                self.tableView.removeRows(at: IndexSet(integersIn: 0..<self.tableView.numberOfRows), withAnimation: .effectFade)
            }
        }
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Bagian berat — dijalankan di background thread
        await self.bacaDataBulanan()
        
        // Masukkan data ke TableView
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            
            self.tableView.beginUpdates()
            for (index, _) in SingletonData.monthliData.enumerated().sorted(by: { $0.element.year < $1.element.year }) {
                self.tableView.insertRows(at: IndexSet([index]), withAnimation: .slideDown)
            }
            self.tableView.endUpdates()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.allowsImplicitAnimation = true
                
                self.progressIndicator.stopAnimation(nil)
                self.progressIndicator.isHidden = true
                self.labelStack.layoutSubtreeIfNeeded()
                self.updateFilterJumlah()
            } completionHandler: {
                self.isDataLoaded = true
            }
        }
    }

    
    @objc func procDataDidChange() {
        DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
            guard let self = self else {return}
            self.tableView.reloadData()
        }
    }
    
    private func bacaDataBulanan() async {
        SingletonData.monthliData = await self.dbController.getDataForTableView()
    }
    //MARK: -UI
    @IBAction func segmentedControlValueChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            decreaseSize(sender)
        case 1:
            increaseSize(sender)
        default:
            break
        }
    }
    @IBAction func increaseSize(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup({ context in
            // Implementasi untuk memperbesar ukuran NSTableView
            // Contoh: tambahkan 10 ke tinggi baris
            context.duration = 0.2
            tableView.rowHeight += 10
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<tableView.numberOfRows))
          
        }, completionHandler: {
            self.saveRowHeight()
        })
    }
    
    @IBAction func decreaseSize(_ sender: Any?) {
        // Implementasi untuk memperkecil ukuran NSTableView
        // Contoh: kurangkan 10 dari tinggi baris, dengan batas minimum
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            tableView.rowHeight = max(tableView.rowHeight - 5, 16)
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<tableView.numberOfRows))
        }, completionHandler: {
            self.saveRowHeight()
        })
    }
    func saveRowHeight() {
        UserDefaults.standard.setValue(tableView.rowHeight, forKey: "JumlahSiswaTableHeight")
    }
    // Helper function to calculate the difference between two arrays
//    private func diff(old: Int, new: Int) -> [IndexPath] {
//        guard old != nil || new != nil else {return [IndexPath()]}
//        let added = (old..<new).map { IndexPath(item: $0, section: 0) }
//        let deleted = (new..<old).map { IndexPath(item: $0, section: 0) }
//        return added + deleted
//    }
    private func updateFilterJumlah() {
        let jumlahSiswaAktif = dbController.countSiswaByStatus(statusFilter: "Aktif")
        let jumlahSiswaLulus = dbController.countSiswaByStatus(statusFilter: "Lulus")
        let jumlahSiswaBerhenti = dbController.countSiswaByStatus(statusFilter: "Berhenti")
        let jumlahSiswa = dbController.countAllSiswa()
        
        // Gabungkan hasil menjadi satu string dan set ke NSTextField
        let resultString = "Aktif: \(jumlahSiswaAktif) | Lulus: \(jumlahSiswaLulus) | Berhenti: \(jumlahSiswaBerhenti) | Semua Siswa: \(jumlahSiswa)"
        filterJumlah.animator().stringValue = resultString
    }
    
    private func setupToolbar() {
        if let toolbar = self.view.window?.toolbar {
            
            // Search Field Toolbar Item
            if let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }),
               let searchField = searchFieldToolbarItem.view as? NSSearchField {
                searchField.placeholderAttributedString = nil
                searchField.placeholderString = "Jumlah Siswa"
                searchField.isEnabled = false
            }
            
            // Zoom Toolbar Item
            if let zoomToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Tabel" }),
               let zoom = zoomToolbarItem.view as? NSSegmentedControl {
                zoom.isEnabled = true
                zoom.target = self
                zoom.action = #selector(segmentedControlValueChanged(_:))
            }
            
            // Kalkulasi Toolbar Item
            if let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }),
               let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton {
                kalkulasiNilai.isEnabled = false
            }
            
            // Hapus Toolbar Item
            if let hapusToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Hapus" }),
               let hapus = hapusToolbarItem.view as? NSButton {
                hapus.isEnabled = false
            }
            
            // Edit Toolbar Item
            if let editToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Edit" }),
               let edit = editToolbarItem.view as? NSButton {
                edit.isEnabled = false
            }
            
            // Tambah Toolbar Item
            if let tambahToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "tambah" }),
               let tambah = tambahToolbarItem.view as? NSButton {
                tambah.isEnabled = false
            }
            
            // Add Toolbar Item
            if let addToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "add" }),
               let add = addToolbarItem.view as? NSButton {
                add.isEnabled = false
            }
            
            // PopUp Menu Toolbar Item
            if let popUpMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "popUpMenu" }),
               let popUpButton = popUpMenuToolbarItem.view as? NSPopUpButton {
                popUpButton.menu = toolbarMenu
                toolbarMenu.delegate = self
            }
        }
    }
    deinit {
        filterJumlah.removeFromSuperview()
        progressIndicator.removeFromSuperview()
        tableView.removeFromSuperview()
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseController.siswaBaru, object: nil)
        NotificationCenter.default.removeObserver(self, name: .editButtonClicked, object: nil)
        NotificationCenter.default.removeObserver(self, name: .deleteButtonClicked, object: nil)
        DistributedNotificationCenter.default().removeObserver(self, name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
    }
}
extension JumlahSiswa: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return SingletonData.monthliData.count
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = "JumlahSiswaCell"
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: self) as? NSTableCellView else {
            return NSTableCellView()
        }
        let monthlyData = SingletonData.monthliData[row]

        switch tableColumn?.identifier.rawValue {
        case "Tahun":
            cell.textField?.stringValue = "\(monthlyData.year)"
        case "Januari":
            cell.textField?.stringValue = monthlyData.januari
        case "Februari":
            cell.textField?.stringValue = monthlyData.februari
        case "Maret":
            cell.textField?.stringValue = monthlyData.maret
        case "April":
            cell.textField?.stringValue = monthlyData.april
        case "Mei":
            cell.textField?.stringValue = monthlyData.mei
        case "Juni":
            cell.textField?.stringValue = monthlyData.juni
        case "Juli":
            cell.textField?.stringValue = monthlyData.juli
        case "Agustus":
            cell.textField?.stringValue = monthlyData.agustus
        case "September":
            cell.textField?.stringValue = monthlyData.september
        case "Oktober":
            cell.textField?.stringValue = monthlyData.oktober
        case "November":
            cell.textField?.stringValue = monthlyData.november
        case "Desember":
            cell.textField?.stringValue = monthlyData.desember

        default:
            break
        }
        return cell
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        NSApp.sendAction(#selector(JumlahSiswa.updateMenuItem(_:)), to: nil, from: self)
    }
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return tableView.rowHeight
    }
    func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        return false
    }
    @objc func updateMenuItem(_ sender: Any?) {
        if let mainMenu = NSApp.mainMenu,
            let editMenuItem = mainMenu.item(withTitle: "Edit"),
            let editMenu = editMenuItem.submenu,
            let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" }) {
            let selectedRows = tableView.selectedRowIndexes
            guard selectedRows.count > 0 else {
                copyMenuItem.target = nil
                copyMenuItem.action = nil
                copyMenuItem.isEnabled = false
                return
            }
            copyMenuItem.target = self
            copyMenuItem.action = #selector(copyAllColumnsRows(_:))
            copyMenuItem.isEnabled = selectedRows.count > 0
        }
    }
}

extension JumlahSiswa: NSMenuDelegate {
    @objc func copyMenuItem(_ sender: NSMenuItem) {
        let selectedRows = tableView.selectedRowIndexes
        let clickedRow = tableView.clickedRow
        if selectedRows.contains(clickedRow) && clickedRow >= 0 {
            copyAllColumnsRows(sender)
        } else if !selectedRows.contains(clickedRow) && clickedRow >= 0 {
            copyAllColumns(sender)
        } else {
            copyAllColumnsRows(sender)
        }
    }
    @objc func copyAllColumns(_ sender: NSMenuItem) {
        guard tableView.numberOfRows > 0 else {return}
        let rowIndex = tableView.clickedRow
        let monthlyData = SingletonData.monthliData[rowIndex]
        
        // Gabungkan seluruh kolom menjadi satu string
        let allColumnsString = [
            "\(monthlyData.year)",
            monthlyData.januari,
            monthlyData.februari,
            monthlyData.maret,
            monthlyData.april,
            monthlyData.mei,
            monthlyData.juni,
            monthlyData.juli,
            monthlyData.agustus,
            monthlyData.september,
            monthlyData.oktober,
            monthlyData.november,
            monthlyData.desember
        ].joined(separator: "\t")  // Gunakan tab atau koma sebagai separator

        // Salin string ke clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(allColumnsString, forType: .string)
    }
    @objc func copyAllColumnsRows(_ sender: NSMenuItem) {
        guard tableView.numberOfRows > 0 else {return}
        let selectedRows = tableView.selectedRowIndexes
        
        // Gabungkan seluruh kolom dari semua row yang dipilih
        var allRowsData: [String] = []
        
        for rowIndex in selectedRows {
            let monthlyData = SingletonData.monthliData[rowIndex]
            let rowString = [
                "\(monthlyData.year)",
                monthlyData.januari,
                monthlyData.februari,
                monthlyData.maret,
                monthlyData.april,
                monthlyData.mei,
                monthlyData.juni,
                monthlyData.juli,
                monthlyData.agustus,
                monthlyData.september,
                monthlyData.oktober,
                monthlyData.november,
                monthlyData.desember
            ].joined(separator: "\t")  // Gunakan tab atau koma sebagai separator
            
            allRowsData.append(rowString)
        }
        
        // Gabungkan semua row menjadi satu string
        let allRowsString = allRowsData.joined(separator: "\n")
        
        // Salin string ke clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(allRowsString, forType: .string)
    }
    
    @objc func copyAllsRows(_ sender: NSMenuItem) {
        guard tableView.numberOfRows > 0 else {return}
        // Gabungkan seluruh kolom dari semua row yang dipilih
        var allRowsData: [String] = []
        let filterJumlahText = filterJumlah.stringValue
        allRowsData.append("Jumlah Siswa: \(filterJumlahText)\n")
        for rowIndex in 0..<tableView.numberOfRows {
            let monthlyData = SingletonData.monthliData[rowIndex]
            let rowString = [
                "\(monthlyData.year)",
                monthlyData.januari,
                monthlyData.februari,
                monthlyData.maret,
                monthlyData.april,
                monthlyData.mei,
                monthlyData.juni,
                monthlyData.juli,
                monthlyData.agustus,
                monthlyData.september,
                monthlyData.oktober,
                monthlyData.november,
                monthlyData.desember
            ].joined(separator: "\t")  // Gunakan tab atau koma sebagai separator
            
            allRowsData.append(rowString)
        }
        
        // Gabungkan semua row menjadi satu string
        let allRowsString = allRowsData.joined(separator: "\n")
        
        // Salin string ke clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(allRowsString, forType: .string)
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == toolbarMenu {
            updateToolbarMenu(toolbarMenu)
        } else {
            updateTableMenu(menu)
        }
    }
    
}
