//
//  Stats.swift
//  Data Manager
//
//  Created by Bismillah on 08/11/23.
//

import Cocoa
import SwiftUI

/// ViewController untuk menampilkan statistik nilai siswa per kelas
/// dan semester dalam bentuk grafik pie dan bar chart.
/// Juga menyediakan opsi untuk menyimpan grafik sebagai gambar.
/// Dapat digunakan sebagai sheet window atau view biasa.
class Stats: NSViewController {
    // MARK: - Properties

    /// Outlet untuk elemen UI Pie Chart.
    @IBOutlet weak var stats: NSView!
    /// OUtlet untuk tombol tutup.
    @IBOutlet weak var tutup: NSButton!
    /// Outlet untuk elemen UI Pie Chart untuk semester 2.
    @IBOutlet weak var stats2: NSView!
    /// Outlet untuk elemen UI Bar Chart.
    @IBOutlet weak var barstats: NSView!
    /// Outlet untuk pilihan menu popup.
    @IBOutlet weak var pilihan: NSPopUpButton!
    /// Outlet untuk garis vertikal.
    @IBOutlet weak var verline: NSBox!
    /// Outlet untuk nama kategori yang dipilih dari popup ``pilihan``.
    @IBOutlet weak var kategoriTextField: NSTextField!
    /// Outlet constraint bagian atas untuk tombol ``tutup``.
    @IBOutlet weak var tutupTpConstraint: NSLayoutConstraint! // default 12

    /// Outlet cell menu popup ``pilihan``.
    @IBOutlet weak var pilihanCell: NSPopUpButtonCell!
    /// Outlet menu popup di bawah ``stats``.
    @IBOutlet weak var pilihanSmstr1: NSPopUpButton!
    /// Outlet menu popup di bawah ``stats2``.
    @IBOutlet weak var pilihanSmstr2: NSPopUpButton!
    /// Outlet untuk menu popup yang menampilkan semua nilai kelas.
    @IBOutlet weak var semuaNilai: NSPopUpButton!
    /// Outlet untuk menu item "..." pada menu popup.
    @IBOutlet weak var moreItem: NSMenuItem!

    /// Outlet progress indicator.
    @IBOutlet weak var progressInd: NSProgressIndicator!

    /// Menandakan apakah ``Stats`` ditampilkan sebagai sheet window.
    var sheetWindow: Bool = false

    /// Variabel untuk menyimpan semester yang dipilih untuk pie chart semester 1.
    var selectedSemester1: String?
    /// Variabel untuk menyimpan semester yang dipilih untuk pie chart semester 2.
    var selectedSemester2: String?

    /// ViewModel Chart Kelas
    let viewModel: ChartKelasViewModel = .shared

    /// Outlet textField tahun ajaran.
    @IBOutlet weak var tahunAjaranTextField1: NSTextField!
    /// Outlet textField tahun ajaran.
    @IBOutlet weak var tahunAjaranTextField2: NSTextField!

    /// Properti untuk menyimpan Tahun Ajaran.
    var tahunAjaran: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        if let ve = view as? NSVisualEffectView {
            ve.blendingMode = .behindWindow
            ve.material = .windowBackground
            ve.state = .followsWindowActiveState
        }
        tahunAjaranTextField1.refusesFirstResponder = true
        tahunAjaranTextField2.refusesFirstResponder = true
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if !tahunAjaran.isEmpty {
            tahunAjaranTextField1.stringValue = ReusableFunc.selectComponentString(tahunAjaran, separator: "/", selectPart: 0)
            tahunAjaranTextField2.stringValue = ReusableFunc.selectComponentString(tahunAjaran, separator: "/", selectPart: 1)
        }
        tahunAjaranTextField1.delegate = self
        tahunAjaranTextField2.delegate = self
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        tahunAjaranTextField1.delegate = nil
        tahunAjaranTextField2.delegate = nil
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        for view in stats.subviews {
            view.removeFromSuperview()
        }
        for view in stats2.subviews {
            view.removeFromSuperview()
        }
        for view in barstats.subviews {
            view.removeFromSuperview()
        }
        if sheetWindow {
            sheetWindow = false
        }

        if let wc = NSApp.mainWindow?.windowController as? WindowController {
            // SwiftUI Chart Kelas
            wc.statistikToolbar.isEnabled = true
        }

        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .windowControllerClose, object: nil)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        muatUlang(self)

        if sheetWindow {
            // Jika Stats ditampilkan sebagai sheet window
            tutup.isHidden = false
            pilihan.isHidden = false
            moreItem.image = ReusableFunc.largeActionImage
            pilihanCell.arrowPosition = .noArrow
            pilihan.menu?.delegate = self
        } else {
            tutup.isHidden = true
            pilihan.isHidden = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            view.window?.makeFirstResponder(view)
        }

        tahunAjaranTextField1.refusesFirstResponder = false
        tahunAjaranTextField2.refusesFirstResponder = false

        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: .windowControllerClose, object: nil)

        if !sheetWindow { setupToolbar() }
    }

    // MARK: - Chart Methods

    /// Memuat ulang data dan memperbarui grafik.
    /// - Parameter sender: `Any` yang memicu aksi ini, tombol "Muat Ulang".
    @IBAction func muatUlang(_: Any) {
        progressInd.startAnimation(nil)
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            await viewModel.updateData(tahunAjaran)
            await updateUI()
        }
    }

    /// Memperbarui antarmuka pengguna dengan memilih semester default,
    /// membuat grafik pie untuk semester 1 dan 2, serta mengonfigurasi bar chart.
    func updateUI() async {
        selectedSemester1 = "Semester 1"
        selectedSemester2 = "Semester 2"

        await viewModel.makeData(["Semester 1", "Semester 2"])

        pilihanSmstr1.selectItem(withTitle: "Semester 1")
        pilihanSmstr2.selectItem(withTitle: "Semester 2")
        populateSemesterPopUpButton()
        pilihanSmstr1.selectItem(withTitle: "Semester 1")
        pilihanSmstr2.selectItem(withTitle: "Semester 2")

        async let lineMark1: () = createPieChart()
        async let lineMark2: () = createPieChartSemester2()

        _ = await (lineMark1, lineMark2)

        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        await MainActor.run { [weak self] in
            guard let self else { return }
            displayBarChart()
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        await MainActor.run { [weak self] in
            guard let self else { return }
            progressInd.stopAnimation(nil)
        }
    }

    // MARK: - Actions

    /// Fungsi yang dipanggil ketika menu popup untuk semester 1 dipilih.
    /// Mengupdate data dan grafik sesuai dengan semester yang dipilih.
    ///
    /// - Parameter sender: `NSPopUpButton` yang memicu aksi ini.
    @IBAction func pilihanSemester1(_ sender: NSPopUpButton) {
        guard let selectedTitle = sender.selectedItem?.title, selectedTitle != selectedSemester1 else { return }
        selectedSemester1 = selectedTitle
        Task { [weak self] in
            await self?.createPieChart()
        }
    }

    /// Fungsi yang dipanggil ketika menu popup untuk semester 2 dipilih.
    /// Mengupdate data dan grafik sesuai dengan semester yang dipilih.
    ///
    /// - Parameter sender: `NSPopUpButton` yang memicu aksi ini
    @IBAction func pilihanSemester2(_ sender: NSPopUpButton) {
        guard let selectedTitle = sender.selectedItem?.title, selectedTitle != selectedSemester2 else { return }
        selectedSemester2 = selectedTitle
        Task { [weak self] in
            await self?.createPieChartSemester2()
        }
    }

    /// Fungsi untuk mengisi popup menu ``pilihanSmstr1`` dan ``pilihanSmstr2`` dengan semester yang tersedia.
    func populateSemesterPopUpButton() {
        let kelasDataArrays: [[KelasModels]] = TableType.allCases.map { type in
            viewModel.kelasByType[type] ?? []
        }

        // Filter dan gabungkan semester yang tidak kosong
        let allSemesters: Set<String> = Set(kelasDataArrays.flatMap { $0.map(\.semester).filter { !$0.isEmpty } })

        let sortedSemesters = allSemesters.sorted { viewModel.semesterOrder($0, $1) }
        let formattedSemesters = sortedSemesters.map { viewModel.formatSemesterName($0) }

        if formattedSemesters.isEmpty {
            // Tambahkan pesan placeholder jika tidak ada data
            semuaNilai.addItem(withTitle: "Semua Kategori & Semester")
            let semuaSemester = semuaNilai.item(withTitle: "Semua Kategori & Semester")
            semuaSemester?.state = .on
            pilihanSmstr1.removeAllItems()
            pilihanSmstr1.addItem(withTitle: "Tdk. ada data")
            pilihanSmstr1.isEnabled = false
            pilihanSmstr2.removeAllItems()
            pilihanSmstr2.addItem(withTitle: "Tdk. ada data")
            pilihanSmstr2.isEnabled = false
        } else {
            semuaNilai.addItem(withTitle: "Semua Kategori & Semester")
            semuaNilai.addItems(withTitles: formattedSemesters)
            semuaNilai.selectItem(withTitle: "Semua Kategori & Semester")
            semuaNilai.selectItem(withTitle: "Semester 1")
            semuaNilai.selectItem(withTitle: "Semester 2")
            let semester1 = semuaNilai.item(withTitle: "Semester 1")
            let semester2 = semuaNilai.item(withTitle: "Semester 2")
            semester1?.state = .on
            semester2?.state = .on
            // Update pilihanSmstr1
            pilihanSmstr1.removeAllItems()
            pilihanSmstr1.addItems(withTitles: formattedSemesters)
            pilihanSmstr1.isEnabled = true
            // Update pilihanSmstr2
            pilihanSmstr2.removeAllItems()
            pilihanSmstr2.addItems(withTitles: formattedSemesters)
            pilihanSmstr2.isEnabled = true
            kategoriTextField.stringValue = "Nilai rata-rata Semester 1 & 2"
        }
    }

    /// Fungsi untuk menampilkan bar chart dengan data yang telah diisi.
    /// Menggunakan thread background untuk membuat dataset dan menambahkan entri ke bar chart.
    /// - Note: Pastikan untuk memanggil fungsi ini setelah dataEntries diisi.
    func displayBarChart() {
        barstats.subviews.removeAll()
        guard let container = barstats else { return }
        // Create an instance of our SwiftUI Chart View, passing in the data
        let swiftUIChartView = StudentCombinedChartView(data: viewModel.kelasData, displayLine1: false, displayLine2: false)

        // Create the hosting view that will contain our SwiftUI view
        let hostingView = NSHostingView(rootView: swiftUIChartView)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        // Add the hosting view as a subview to our container
        container.addSubview(hostingView)

        // Create and activate constraints to make the hosting view fill the container
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
    }

    /// Fungsi untuk menampilkan pie chart pertama.
    /// Mengambil semester yang dipilih dari menu popup ``pilihanSmstr1`` dan membuat pie chart berdasarkan data kelas.
    func createPieChart() async {
        let selectedSemester = pilihanSmstr1.titleOfSelectedItem ?? "Semester 1"
        var formattedSemester = selectedSemester
        if selectedSemester.contains("Semester") {
            if let number = selectedSemester.split(separator: " ").last {
                formattedSemester = String(number)
            }
        }
        guard let container = stats else { return }

        stats.subviews.removeAll()

        let calculatedData = await viewModel.makeSemesterData(formattedSemester)

        await MainActor.run {
            // Create an instance of our SwiftUI Chart View, passing in the data
            let swiftUIChartView = StudentCombinedChartView(data: calculatedData, displayLine2: false, displayBar: false)

            // Create the hosting view that will contain our SwiftUI view
            let hostingView = NSHostingView(rootView: swiftUIChartView)

            hostingView.translatesAutoresizingMaskIntoConstraints = false
            // Add the hosting view as a subview to our container
            container.addSubview(hostingView)

            // Create and activate constraints to make the hosting view fill the container
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: container.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
        }
    }

    /// Fungsi untuk menampilkan pie chart kedua.
    /// Mengambil semester yang dipilih dari menu popup ``pilihanSmstr2`` dan membuat pie chart berdasarkan data kelas.
    func createPieChartSemester2() async {
        let selectedSemester = pilihanSmstr2.titleOfSelectedItem ?? "Semester 2"
        var formattedSemester = selectedSemester

        if selectedSemester.contains("Semester") {
            if let number = selectedSemester.split(separator: " ").last {
                formattedSemester = String(number)
            }
        }

        guard let container = stats2 else { return }

        stats2.subviews.removeAll()

        let calculatedData = await viewModel.makeSemesterData(formattedSemester)

        await MainActor.run {
            // Create an instance of our SwiftUI Chart View, passing in the data
            let swiftUIChartView = StudentCombinedChartView(data: calculatedData, displayLine2: false, displayBar: false)

            // Create the hosting view that will contain our SwiftUI view
            let hostingView = NSHostingView(rootView: swiftUIChartView)

            hostingView.translatesAutoresizingMaskIntoConstraints = false
            // Add the hosting view as a subview to our container
            container.addSubview(hostingView)

            // Create and activate constraints to make the hosting view fill the container
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: container.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
        }
    }

    /// Action tombol untuk menutup view ``Stats`` ketika ditampilkan dalam jendela sheet.
    /// - Parameter sender: Objek pemicu, dapat berupa apapun.
    @IBAction func tutupchart(_: Any) {
        if let sheetWindow = NSApplication.shared.mainWindow?.attachedSheet {
            NSApplication.shared.mainWindow?.endSheet(sheetWindow)
            sheetWindow.orderOut(nil)
        }
    }

    /// Action tombol untuk menyimpan ``barstats``.
    /// - Parameter sender: Objek pemicu, dapat berupa apapun.
    @IBAction func simpanchart(_: Any) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(pilihan.menu?.item(withTag: 3)?.title.replacingOccurrences(of: "/", with: "-") ?? "")"
        panel.beginSheetModal(for: view.window!) { [weak self] result in
            if let self, result == NSApplication.ModalResponse.OK {
                if let url = panel.url {
                    guard let imageData = ReusableFunc.createImageFromNSView(barstats, scaleFactor: 2.0) else { return }
                    do {
                        try imageData.write(to: url)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }

    /// Tombol untuk menyimpan ``stats``.
    /// - Parameter sender: Objek pemicu, dapat berupa apapun.
    @IBAction func smstr1(_: Any) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(pilihan.menu?.item(withTag: 1)?.title.replacingOccurrences(of: "/", with: "-") ?? "")"
        panel.beginSheetModal(for: view.window!) { [weak self] result in
            guard let self, result == NSApplication.ModalResponse.OK else { return }

            guard let url = panel.url else {
                #if DEBUG
                    print("Error: Save URL is nil.")
                #endif
                return
            }

            guard let imageData = ReusableFunc.createImageFromNSView(stats, scaleFactor: 4.0) else { return }

            do {
                try imageData.write(to: url)
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    /// Tombol untuk menyimpan ``stats2``.
    /// - Parameter sender: Objek pemicu, dapat berupa apapun.
    @IBAction func smstr2(_: Any) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(pilihan.menu?.item(withTag: 2)?.title.replacingOccurrences(of: "/", with: "-") ?? "")"
        panel.beginSheetModal(for: view.window!) { [weak self] result in
            if let self, result == NSApplication.ModalResponse.OK {
                if let url = panel.url {
                    guard let imageData = ReusableFunc.createImageFromNSView(stats2, scaleFactor: 4.0) else { return }

                    do {
                        try imageData.write(to: url)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }

    /// Action untuk NSPopUpButton ``semuaNilai``.
    /// - Parameter sender: Objek pemicu berupa NSPopUpButton.
    @IBAction func pilihanSemuaNilai(_ sender: NSPopUpButton) {
        view.window?.becomeFirstResponder()
        // Dapatkan menu dari NSPopUpButton
        let menu = sender.menu
        guard let items = menu?.items else { return }

        // Mendapatkan item yang dipilih
        guard let selectedItem = sender.titleOfSelectedItem else { return }

        // Ubah state item yang dipilih
        if let selectedMenuItem = items.first(where: { $0.title == selectedItem }) {
            // Toggle state item yang dipilih
            selectedMenuItem.state = (selectedMenuItem.state == .on) ? .off : .on
        }
        if selectedItem == "Semua Kategori & Semester" {
            for menuItem in items {
                menuItem.state = (menuItem.title == selectedItem) ? .on : .off
            }
        } else if selectedItem == "Semua Kategori & Semester", items.first(where: { $0.state == .on && $0.title != "Semua Kategori & Semester" }) != nil {
            // Matikan state "Semua Kategori & Semester"
            if let allSemesterItem = items.first(where: { $0.title == "Semua Kategori & Semester" }) {
                allSemesterItem.state = .off
            }
        } else {
            // Matikan state "Semua Kategori & Semester" jika kategori lain dipilih
            if selectedItem != "Semua Kategori & Semester" {
                if let allSemesterItem = items.first(where: { $0.title == "Semua Kategori & Semester" }) {
                    allSemesterItem.state = .off
                }
            }
        }
        // Ambil item yang sedang dalam keadaan aktif
        let selectedItems = items.enumerated()
            .filter { $0.offset != 0 && $0.element.state == .on } // Mengecualikan indeks 0
            .map(\.element.title)
        let selectedSemesters = items.filter { $0.state == .on }.map(\.title)

        Task { [weak self] in
            guard let self else { return }
            !selectedItems.contains("Semua Kategori & Semester") ? await viewModel.makeData(selectedSemesters) : await viewModel.makeData(["Semester 1", "Semester 2"])
            await MainActor.run {
                self.displayBarChart()
                self.updateKategoriTextField(with: selectedItems)
            }
        }
    }

    /// Memperbarui tampilan bidang teks kategori dengan item yang dipilih.
    /// Fungsi ini menggabungkan item yang dipilih menjadi sebuah string yang diformat,
    /// kemudian menetapkan string tersebut ke `kategoriTextField` setelah pengelompokan item selesai di latar belakang.
    /// Pemrosesan dilakukan secara asinkron untuk menghindari pemblokiran thread utama.
    ///
    /// - Parameter selectedItems: Sebuah array string yang berisi item-item yang dipilih oleh pengguna.
    ///                            Item-item ini akan diproses untuk membentuk string tampilan kategori.
    func updateKategoriTextField(with selectedItems: [String]) {
        var text = String()
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            // Gabungkan item yang dipilih, format sesuai kebutuhan
            text = await groupItemsByBaseName(Array(Set(selectedItems))).joined(separator: " & ")
            await MainActor.run { [weak self] in
                self?.kategoriTextField.stringValue = text
            }
        }
    }

    /// Mengelompokkan item-item string berdasarkan nama dasarnya dan menggabungkan angka-angka terkait.
    /// Misalnya, jika input adalah ["Kategori 1", "Kategori 2", "Kategori 3"],
    /// output akan menjadi ["Kategori 1 & 2 & 3"]. Ini berguna untuk menampilkan pilihan yang ringkas.
    ///
    /// - Parameter items: Sebuah array string, di mana setiap string diharapkan memiliki format
    ///                    "Nama Angka" (misalnya, "Semester 1", "Kelas 3").
    /// - Returns: Sebuah array string yang telah dikelompokkan, di mana nama dasar yang sama digabungkan
    ///            dengan angka-angka yang sesuai.
    func groupItemsByBaseName(_ items: [String]) async -> [String] {
        var grouped: [String: [String]] = [:]

        for item in items {
            // Pisahkan nama dan angka
            let components = item.split(separator: " ")
            guard let baseName = components.first else { continue }

            // Kelompokkan berdasarkan nama
            if grouped[String(baseName)] != nil {
                grouped[String(baseName)]?.append(item)
            } else {
                grouped[String(baseName)] = [item]
            }
        }

        // Gabungkan nama dengan angka
        var result: [String] = []
        for (baseName, items) in grouped {
            if items.count > 1 {
                let numbers: [String] = items.compactMap { item in
                    let components = item.split(separator: " ")
                    return components.count > 1 ? String(components.last!) : nil
                }
                let numberRange = numbers.sorted().joined(separator: " & ")
                result.append("\(baseName) \(numberRange)")
            } else {
                result.append(items.first ?? "")
            }
        }

        return result
    }

    /// Konfigurasi action dan target toolbar.
    func setupToolbar() {
        guard let wc = view.window?.windowController as? WindowController else { return }

        // SearchField
        wc.searchField.isEnabled = false
        wc.searchField.isEditable = false
        wc.searchField.delegate = nil
        wc.searchField.target = nil
        wc.searchField.placeholderString = "Statistik Nilai"

        // Tambah Data
        wc.tambahSiswa.isEnabled = false
        wc.tambahSiswa.toolTip = ""

        // Tambah nilai kelas
        wc.tambahDetaildiKelas.isEnabled = false

        // Kalkulasi nilai kelas
        wc.kalkulasiButton.isEnabled = false

        // SwiftUI Chart Kelas
        wc.statistikToolbar.isEnabled = false

        // Action Menu
        pilihan.isEnabled = true
        wc.actionPopUpButton.menu = pilihan.menu
        pilihan.menu?.delegate = self

        // Edit
        wc.tmbledit.isEnabled = false

        // Hapus
        wc.hapusToolbar.isEnabled = false
        wc.hapusToolbar.target = nil

        // Zoom Segment
        wc.segmentedControl.isEnabled = false
        wc.segmentedControl.target = nil
    }

    deinit {
        barstats.removeFromSuperview()
        stats.removeFromSuperview()
        stats2.removeFromSuperview()
        NotificationCenter.default.removeObserver(self, name: .windowControllerClose, object: nil)
    }
}

extension Stats {
    /// Notifikasi ketika ada window ditutup. Berguna ketika sheet ``Stats`` dihentikan.
    @objc func windowWillClose(_: Notification) {}
}

extension Stats: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if let saves = menu.item(at: 1) {
            saves.isEnabled = false
            saves.isHidden = false
        }
        if let save = menu.item(at: 2) {
            if let title = pilihanSmstr1.titleOfSelectedItem {
                save.title = title
                save.isHidden = false
            } else {
                save.isHidden = true
            }
        }

        if let save1 = menu.item(at: 3) {
            if let title = pilihanSmstr2.titleOfSelectedItem {
                save1.title = title
                save1.isHidden = false
            } else {
                save1.isHidden = true
            }
        }
        if let saveOpt = menu.item(at: 4) {
            saveOpt.title = "\(kategoriTextField.stringValue)"
        }
    }
}

extension Stats: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }

        if textField === tahunAjaranTextField1,
           let intValue = Int(textField.stringValue)
        {
            tahunAjaranTextField2.stringValue = String(intValue + 1)
        }

        let thnAjrn1 = tahunAjaranTextField1.stringValue
        let thnAjrn2 = tahunAjaranTextField2.stringValue

        guard thnAjrn1.allSatisfy(\.isNumber),
              thnAjrn2.allSatisfy(\.isNumber)
        else {
            ReusableFunc.showAlert(title: "Tahun ajaran harus berupa angka.", message: "")
            return
        }

        let newThnAjrn = thnAjrn1 + "/" + thnAjrn2

        if !thnAjrn1.isEmpty, !thnAjrn2.isEmpty,
           tahunAjaran != newThnAjrn
        {
            tahunAjaran = newThnAjrn
            muatUlang(obj)
        } else
        if thnAjrn1.isEmpty, thnAjrn2.isEmpty,
           !tahunAjaran.isEmpty
        {
            tahunAjaran.removeAll()
            muatUlang(obj)
        }
        view.window?.makeFirstResponder(view)
    }
}
