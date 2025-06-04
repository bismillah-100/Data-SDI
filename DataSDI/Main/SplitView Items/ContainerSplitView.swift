//
//  ContainerSplitView.swift
//  Data SDI
//
//  Created by Admin on 15/04/25.
//

import Cocoa

class ContainerSplitView: NSViewController, SidebarDelegate {   
    weak var delegate: SidebarDelegate?
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        // Mengatur nilai default pada saat inisialisasi
        UserDefaults.standard.register(defaults: ["SelectedSidebarItemIndex": 14])
        selectedSidebarItemIndex = UserDefaults.standard.integer(forKey: "SelectedSidebarItemIndex")
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    required init?(coder: NSCoder) {
        // Mengatur nilai default pada saat inisialisasi
        UserDefaults.standard.register(defaults: ["SelectedSidebarItemIndex": 14])
        selectedSidebarItemIndex = UserDefaults.standard.integer(forKey: "SelectedSidebarItemIndex")
        
        super.init(coder: coder)
    }
    
    /* Print Menu Item
     memuat menu item print yang berada di Toolbar.
     */
    @IBOutlet weak var printMenu: NSMenu!
    
    @IBOutlet weak var printerMenuItem: NSMenuItem!
    @IBOutlet weak var excelMenuItem: NSMenuItem!
    @IBOutlet weak var csvMenuItem: NSMenuItem!
    @IBOutlet weak var pdfMenuItem: NSMenuItem!
    @IBOutlet weak var separatorMenuItem: NSMenuItem!
    
    let eksporMenuItem = NSMenuItem()
    let headerPrintMenuItem = NSMenuItem()
    
    var firstOpen: Bool = true
    
    lazy var kelasVC: KelasVC = {
        // XIB diload manual di class KelasVC, tidak perlu menggunakan nibName bundle.
        return KelasVC()
    }()
    lazy var saldoView: JumlahTransaksi = {
        let viewController = JumlahTransaksi(nibName: "JumlahTransaksi", bundle: nil)
        return viewController
    }()
    lazy var statistikView: Stats = {
        let viewController = Stats(nibName: "ChartKelas", bundle: nil)
        return viewController
    }()
    lazy var jumlahSiswa: JumlahSiswa = {
        let viewController = JumlahSiswa(nibName: "JumlahSiswa", bundle: nil)
        return viewController
    }()
    lazy var struktur: Struktur = {
        let viewController = Struktur(nibName: "Struktur", bundle: nil)
        return viewController
    }()
    lazy var inventaris: InventoryView = {
        let viewController = InventoryView(nibName: "InventoryView", bundle: nil)
        return viewController
    }()
    // Gunakan lazy var untuk view controller
    lazy var siswaViewController: SiswaViewController = {
        let viewController = SiswaViewController(nibName: "SiswaViewController", bundle: nil)
        return viewController
    }()
    
    lazy var guruViewController: GuruViewController = {
        let viewController = GuruViewController(nibName: "GuruViewController", bundle: nil)
        return viewController
    }()
    lazy var transaksiView: TransaksiView = {
        let viewController = TransaksiView(nibName: "TransaksiView", bundle: nil)
        return viewController
    }()
    
    var printKelas: PrintKelas?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        guard firstOpen else {return}
        DispatchQueue.main.asyncAfter(deadline: .now()) { [unowned self] in
            self.didSelectSidebarItem(index: selectedSidebarItemIndex)
        }
        if let toolbar = self.view.window?.toolbar {
            if let printMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "PrintMenu" }),
               let printKelasMenu = printMenuToolbarItem.view as? NSPopUpButton {
                printKelasMenu.isEnabled = true
                printKelasMenu.target = self
                printKelasMenu.menu = printMenu
            }
        }

        
        headerPrintMenuItem.identifier = NSUserInterfaceItemIdentifier("printMenuItem")
        eksporMenuItem.identifier = NSUserInterfaceItemIdentifier("eksporMenuItem")
        
        let headerPrintMenu = NSView()
        headerPrintMenu.frame = NSRect(x: 0, y: 0, width: 150, height: 20)

        let textFieldHeaderPrint = NSTextField()
        textFieldHeaderPrint.stringValue = "Cetak ke Printer"
        textFieldHeaderPrint.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        textFieldHeaderPrint.textColor = .secondaryLabelColor
        textFieldHeaderPrint.drawsBackground = false
        textFieldHeaderPrint.isBordered = false
        textFieldHeaderPrint.isEditable = false
        headerPrintMenu.addSubview(textFieldHeaderPrint)
        textFieldHeaderPrint.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textFieldHeaderPrint.leadingAnchor.constraint(equalTo: headerPrintMenu.leadingAnchor, constant: 14),
            textFieldHeaderPrint.trailingAnchor.constraint(equalTo: headerPrintMenu.trailingAnchor, constant: 0),
            textFieldHeaderPrint.centerYAnchor.constraint(equalTo: headerPrintMenu.centerYAnchor)
        ])
        headerPrintMenuItem.view = headerPrintMenu
        
        if !printMenu.items.contains(headerPrintMenuItem) {
            printMenu.insertItem(headerPrintMenuItem, at: 1)
        }
        
        let eksporView = NSView()
        eksporView.frame = NSRect(x: 0, y: 0, width: 150, height: 20)
        
        let textFieldEkspor = NSTextField()
        
        textFieldEkspor.stringValue = "Ekspor ke File"
        textFieldEkspor.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        textFieldEkspor.textColor = .secondaryLabelColor
        textFieldEkspor.drawsBackground = false
        textFieldEkspor.isBordered = false
        textFieldEkspor.isEditable = false
        
        eksporView.addSubview(textFieldEkspor)
        
        textFieldEkspor.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textFieldEkspor.leadingAnchor.constraint(equalTo: eksporView.leadingAnchor, constant: 14),
            textFieldEkspor.trailingAnchor.constraint(equalTo: eksporView.trailingAnchor, constant: 0),
            textFieldEkspor.centerYAnchor.constraint(equalTo: eksporView.centerYAnchor)
        ])
        
        
        eksporMenuItem.view = eksporView
    }
    
    var currentContentController: NSViewController?
    
    // Fungsi untuk menentukan frame yang akan digunakan child view controller
    func frameForContentController() -> NSRect {
        // Misalnya, gunakan seluruh bounds dari container view
        return self.view.bounds
    }
    
    // Fungsi untuk menampilkan child view controller
    func displayContentController(_ content: NSViewController) {
        // Tambahkan sebagai child view controller
        addChild(content)
        
        // Pastikan view dari content sudah diakses (ini akan memicu loadView jika belum termuat)
        let contentView = content.view
        
        // Atur frame dari content view agar sesuai dengan container
        contentView.frame = frameForContentController()
        
        // Tambahkan content view ke container (self.view dalam contoh ini)
        view.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: self.view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])

        // Simpan referensinya jika diperlukan di kemudian hari
        self.currentContentController = content
    }
    
    // Fungsi untuk menyembunyikan (menghapus) child view controller
    func hideContentController(_ content: NSViewController) {
        // Hapus content view dari container view
        content.view.removeFromSuperview()
        
        // Hapus child view controller dari hirarki
        content.removeFromParent()
        
        if currentContentController === content {
            currentContentController = nil
        }
    }
    
    var selectedSidebarItemIndex: Int {
        didSet {
            UserDefaults.standard.set(selectedSidebarItemIndex, forKey: "SelectedSidebarItemIndex")
        }
    }
    
    func didSelectSidebarItem(index: Int) {
        selectedSidebarItemIndex = index
        if index == 1 {
            self.view.window?.title = "Data Siswa"
            showViewController(siswaViewController)
        } else if index == 2 {
            self.view.window?.title = "Data Guru"
            showViewController(guruViewController)
        } else if index >= 3 && index <= 8 {
            showViewController(kelasVC)
            kelasVC.tabView.selectTabViewItem(at: index - 3)
            self.view.window?.title = "Kelas \(index - 2)"
            csvMenuItem.title = "\"Kelas \(index - 2)\" ke File CSV"
            excelMenuItem.title = "\"Kelas \(index - 2)\" ke File Excel"
            pdfMenuItem.title = "\"Kelas \(index - 2)\" ke File PDF"
        } else if index == 9 {
            self.view.window?.title = "Transaksi"
            showViewController(transaksiView)
            self.transaksiView.perbaruiData()
            AppDelegate.shared.groupMenuItem.isEnabled = true
        } else if index == 10 {
            showViewController(transaksiView)
            transaksiView.jenis = "Pemasukan"
            self.view.window?.title = "Pemasukan"
            DispatchQueue.main.async {
                self.handleTransaksiFilterSelection(index: index)
            }
        } else if index == 11 {
            showViewController(transaksiView)
            transaksiView.jenis = "Pengeluaran"
            self.view.window?.title = "Pengeluaran"
            DispatchQueue.main.async {
                self.handleTransaksiFilterSelection(index: index)
            }
        } else if index == 12 {
            showViewController(transaksiView)
            transaksiView.jenis = "Lainnya"
            self.view.window?.title = "Lainnya"
            DispatchQueue.main.async {
                self.handleTransaksiFilterSelection(index: index)
            }
        } else if index == 13 {
            self.view.window?.title = "Jumlah Saldo"
            showViewController(saldoView)
        } else if index == 14 {
            self.view.window?.title = "Nilai Kelas Aktif"
            showViewController(statistikView)
        } else if index == 15 {
            self.view.window?.title = "Jumlah Siswa"
            showViewController(jumlahSiswa)
        } else if index == 16 {
            self.view.window?.title = "Struktur Guru"
            showViewController(struktur)
        } else if index == 17 {
            self.view.window?.title = "Inventaris"
            showViewController(inventaris)
        }
    }
    func handleTransaksiFilterSelection(index: Int) {
        switch index {
        case 10:
            transaksiView.filterData(withType: "Pemasukan")
            //transaksiView.jenisDidChange(newJenis: "Pemasukan")
        case 11:
            transaksiView.filterData(withType: "Pengeluaran")
            //transaksiView.jenisDidChange(newJenis: "Pengeluaran")
        case 12:
            transaksiView.filterData(withType: "Lainnya")
            //transaksiView.jenisDidChange(newJenis: "Lainnya")
        default:
            transaksiView.resetData()
        }
    }
    func didSelectKelasItem(index: Int) {
        // Implementasi logika untuk menyesuaikan tampilan di NSSplitViewController
        // Berdasarkan pemilihan kelas di sidebar (index)
        if index >= 1 && index <= 6 {
            kelasVC.tabView.selectTabViewItem(at: index - 1)
            showViewController(kelasVC)
        }
    }
    
    func showViewController(_ viewController: NSViewController) {
        // Pastikan jika sudah ada childViewController sebelumnya dan berbeda, maka dihapus dahulu
        if let current = currentContentController, current != viewController {
            hideContentController(current)
        }
        
        // Jika viewController belum ada di hirarki, tambahkan saja
        if !children.contains(viewController) {
            displayContentController(viewController)
            currentContentController = viewController
        }
        
        if viewController is SiswaViewController {
            if let index = printMenu.items.firstIndex(of: separatorMenuItem), printMenu.items.first(where: {$0.identifier?.rawValue == "eksporMenuItem"}) == nil {
                printMenu.insertItem(eksporMenuItem, at: index + 1)
            }
            csvMenuItem.isHidden = true
            excelMenuItem.isHidden = false
            excelMenuItem.title = "\"Data Siswa\" ke File Excel"
            pdfMenuItem.isHidden = false
            pdfMenuItem.title = "\"Data Siswa\" ke File PDF"
        } else if viewController is KelasVC {
            if let index = printMenu.items.firstIndex(of: separatorMenuItem), printMenu.items.first(where: {$0.identifier?.rawValue == "eksporMenuItem"}) == nil {
                printMenu.insertItem(eksporMenuItem, at: index + 1)
            }
            csvMenuItem.isHidden = false
            excelMenuItem.isHidden = false
            pdfMenuItem.isHidden = false
        } else {
            csvMenuItem.isHidden = true
            excelMenuItem.isHidden = true
            pdfMenuItem.isHidden = true
            if printMenu.items.first(where: {$0.identifier?.rawValue == "eksporMenuItem"}) != nil {
                printMenu.removeItem(eksporMenuItem)
            }
        }
        
        if viewController is KelasVC {
            guard let toolbar = self.view.window?.toolbar else {return}
            guard let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }) else { return }
            guard let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton else {return}
            kalkulasiNilai.isEnabled = true
        } else {
            guard let toolbar = self.view.window?.toolbar else {return}
            guard let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }) else { return }
            guard let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton else {return}
            kalkulasiNilai.isEnabled = false
        }
    }

    @IBAction func prnt1(_ sender: Any) {
        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas?.loadView()
        printKelas?.prnt1()
    }
    @IBAction func prntkls2(_ sender: Any) {
        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas?.loadView()
        printKelas?.printkls2()
    }
    @IBAction func prntkls3(_ sender: Any) {
        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas?.loadView()
        printKelas?.printkls3()
    }
    @IBAction func prntkls4(_ sender: Any) {
        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas?.loadView()
        printKelas?.printkls4()    }
    @IBAction func prntkls5(_ sender: Any) {
        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas?.loadView()
        printKelas?.printkls5()    }
    @IBAction func prntkls6(_ sender: Any) {
        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas?.loadView()
        printKelas?.printkls6()
    }
    @IBAction func printText(_ sender: Any) {
        if let kelas = currentContentController as? KelasVC {
            kelas.printText()
        } else {
            ReusableFunc.showAlert(title: "Kelas Aktif Belum Siap", message: "")
        }
    }
    @IBAction func CSVButton(_ sender: Any) {
        // Ganti cara mendapatkan referensi ke KelasVC
        if let activeTable = kelasVC.activeTable() {
            kelasVC.exportToCSV(activeTable)
        }
    }
    @IBAction func xlxsButton(_ sender: NSMenuItem) {
        if let kelasVC = currentContentController as? KelasVC {
            kelasVC.exportToExcel(sender)
        } else if let siswaViewController = currentContentController as? SiswaViewController {
            siswaViewController.exportToExcel(sender)
        }
    }
    @IBAction func PDFButton(_ sender: NSMenuItem) {
        if let kelasVC = currentContentController as? KelasVC {
            kelasVC.exportToPDF(sender)
        } else if let siswaViewController = currentContentController as? SiswaViewController {
            siswaViewController.exportToPDF(sender)
        }
    }
}
