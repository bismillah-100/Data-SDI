//
//  ContainerSplitView.swift
//  Data SDI
//
//  Created by Admin on 15/04/25.
//

import Cocoa

/// `ContainerSplitView` adalah kelas yang mengelola tampilan utama aplikasi Data SDI.
/// Kelas ini merupakan subclass dari `NSViewController` dan mengimplementasikan protokol `SidebarDelegate` untuk menangani pemilihan item di sidebar.
class ContainerSplitView: NSViewController, SidebarDelegate {
    /// Protokol untuk menangani pemilihan item di sidebar
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
      * memuat menu item print yang berada di Toolbar.
     */
    @IBOutlet weak var printMenu: NSMenu!
    /// Menu item untuk ekspor data ke berbagai format file.
    @IBOutlet weak var printerMenuItem: NSMenuItem!
    /// Menu item untuk ekspor data ke file Excel.
    @IBOutlet weak var excelMenuItem: NSMenuItem!
    /// Menu item untuk ekspor data ke file CSV.
    @IBOutlet weak var csvMenuItem: NSMenuItem!
    /// Menu item untuk ekspor data ke file PDF.
    @IBOutlet weak var pdfMenuItem: NSMenuItem!
    /// Menu item untuk pemisah di menu ekspor.
    @IBOutlet weak var separatorMenuItem: NSMenuItem!

    /// Menu Item untuk ekspor data ke file.
    let eksporMenuItem = NSMenuItem()

    /// Menu item untuk header di menu ekspor.
    let headerPrintMenuItem = NSMenuItem()

    /// Properti untuk menyimpan apakah ini adalah pembukaan pertama kali
    var firstOpen: Bool = true

    /// Properti ``KelasVC`` untuk mengakses kelas view controller yang berisi tab view untuk kelas.
    lazy var kelasVC: KelasVC = // XIB diload manual di class KelasVC, tidak perlu menggunakan nibName bundle.
        .init()

    /// Properti untuk ``JumlahTransaksi`` yang menampilkan jumlah saldo.
    lazy var saldoView: JumlahTransaksi = {
        let viewController = JumlahTransaksi(nibName: "JumlahTransaksi", bundle: nil)
        return viewController
    }()

    /// Properti untuk ``Stats`` yang menampilkan statistik kelas.
    lazy var statistikView: Stats = {
        let viewController = Stats(nibName: "ChartKelas", bundle: nil)
        return viewController
    }()

    /// Properti untuk ``JumlahSiswa`` yang menampilkan jumlah siswa.
    lazy var jumlahSiswa: JumlahSiswa = {
        let viewController = JumlahSiswa(nibName: "JumlahSiswa", bundle: nil)
        return viewController
    }()

    /// Properti untuk ``Struktur`` yang menampilkan struktur guru.
    lazy var struktur: Struktur = {
        let viewController = Struktur(nibName: "Struktur", bundle: nil)
        return viewController
    }()

    /// Properti untuk ``InventoryView`` yang menampilkan inventaris.
    lazy var inventaris: InventoryView = {
        let viewController = InventoryView(nibName: "InventoryView", bundle: nil)
        return viewController
    }()

    /// Properti untuk ``SiswaViewController`` yang menampilkan data siswa.
    /// Menggunakan lazy var untuk memastikan view controller hanya dibuat saat dibutuhkan.
    /// Ini juga menghindari masalah dengan inisialisasi yang mungkin terjadi jika view controller dibuat sebelum storyboard dimuat.
    lazy var siswaViewController: SiswaViewController = {
        let viewController = SiswaViewController(nibName: "SiswaViewController", bundle: nil)
        return viewController
    }()

    /// Properti untuk ``GuruViewController`` yang menampilkan data guru.
    lazy var guruViewController: GuruViewController = {
        let viewController = GuruViewController(nibName: "GuruViewController", bundle: nil)
        return viewController
    }()

    /// Properti untuk ``TransaksiView`` yang menampilkan transaksi.
    lazy var transaksiView: TransaksiView = {
        let viewController = TransaksiView(nibName: "TransaksiView", bundle: nil)
        return viewController
    }()

    /// Properti ``PrintKelas`` untuk menangani cetakan kelas.
    /// Ini akan diinisialisasi saat dibutuhkan, sehingga tidak perlu dibuat pada saat inisialisasi awal.
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
        guard firstOpen else { return }
        DispatchQueue.main.asyncAfter(deadline: .now()) { [unowned self] in
            self.didSelectSidebarItem(index: selectedSidebarItemIndex)
        }
        if let toolbar = view.window?.toolbar {
            if let printMenuToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "PrintMenu" }),
               let printKelasMenu = printMenuToolbarItem.view as? NSPopUpButton
            {
                printKelasMenu.isEnabled = true
                printKelasMenu.target = self
                printKelasMenu.menu = printMenu
            }
        }

        // Set identifier untuk headers dan ekspor menu item
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
            textFieldHeaderPrint.centerYAnchor.constraint(equalTo: headerPrintMenu.centerYAnchor),
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
            textFieldEkspor.centerYAnchor.constraint(equalTo: eksporView.centerYAnchor),
        ])

        eksporMenuItem.view = eksporView
    }

    /// Properti untuk menyimpan referensi ke child view controller yang sedang ditampilkan
    /// Ini akan digunakan untuk mengelola tampilan child view controller yang ditampilkan di dalam container view.
    /// Dengan menyimpan referensi ini, kita dapat dengan mudah mengakses dan mengelola child view controller yang sedang aktif.
    var currentContentController: NSViewController?

    /// Fungsi untuk menentukan frame yang akan digunakan child view controller
    /// Ini bisa disesuaikan dengan kebutuhan, misalnya menggunakan bounds dari container view atau ukuran tertentu.
    /// Dalam contoh ini, kita akan menggunakan seluruh bounds dari container view.
    /// - Returns: NSRect yang menentukan frame untuk child view controller.
    func frameForContentController() -> NSRect {
        // Misalnya, gunakan seluruh bounds dari container view
        view.bounds
    }

    /// Fungsi untuk menampilkan child view controller
    /// Ini akan menambahkan child view controller ke dalam hirarki view controller dan menampilkan view-nya di dalam container view.
    /// - Parameter content: NSViewController yang akan ditampilkan sebagai child view controller.
    /// - Note: Pastikan untuk mengatur frame dari content view agar sesuai dengan container view.
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
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // Simpan referensinya jika diperlukan di kemudian hari
        currentContentController = content
    }

    /// Fungsi untuk menyembunyikan (menghapus) child view controller.
    /// Ini akan menghapus view dari container view dan juga menghapus child view controller dari hirarki.
    /// - Parameter content: NSViewController yang akan disembunyikan.
    /// - Note: Pastikan untuk memeriksa apakah content view controller yang akan dihapus adalah yang sedang aktif.
    func hideContentController(_ content: NSViewController) {
        // Hapus content view dari container view
        content.view.removeFromSuperview()

        // Hapus child view controller dari hirarki
        content.removeFromParent()

        if currentContentController === content {
            currentContentController = nil
        }
    }

    /// Properti untuk menyimpan indeks item sidebar yang dipilih.
    var selectedSidebarItemIndex: Int {
        didSet {
            UserDefaults.standard.set(selectedSidebarItemIndex, forKey: "SelectedSidebarItemIndex")
        }
    }

    /// Fungsi untuk menangani pemilihan item di sidebar.
    /// Fungsi ini akan dipanggil ketika pengguna memilih item di sidebar.
    /// Ini akan memperbarui tampilan yang ditampilkan di dalam container view berdasarkan item yang dipilih.
    /// - Note: Pastikan untuk memperbarui judul window sesuai dengan item yang dipilih.
    /// - Note: Pastikan untuk memanggil fungsi ini dari sidebar delegate ketika item sidebar dipilih.
    /// - Note: Jika item yang dipilih adalah kelas, pastikan untuk memperbarui tab view di ``KelasVC`` sesuai dengan indeks yang dipilih.
    /// - Note: Pastikan untuk memperbarui judul window sesuai dengan item yang dipilih.
    /// - Parameter index: Indeks item sidebar yang dipilih.
    func didSelectSidebarItem(index: Int) {
        // Simpan indeks item sidebar yang dipilih
        selectedSidebarItemIndex = index
        if index == 1 {
            view.window?.title = "Data Siswa"
            showViewController(siswaViewController)
        } else if index == 2 {
            view.window?.title = "Data Guru"
            showViewController(guruViewController)
        } else if index >= 3, index <= 8 {
            showViewController(kelasVC)
            kelasVC.tabView.selectTabViewItem(at: index - 3)
            view.window?.title = "Kelas \(index - 2)"
            csvMenuItem.title = "\"Kelas \(index - 2)\" ke File CSV"
            excelMenuItem.title = "\"Kelas \(index - 2)\" ke File Excel"
            pdfMenuItem.title = "\"Kelas \(index - 2)\" ke File PDF"
        } else if index == 9 {
            view.window?.title = "Transaksi"
            showViewController(transaksiView)
            transaksiView.perbaruiData()
            AppDelegate.shared.groupMenuItem.isEnabled = true
        } else if index == 10 {
            showViewController(transaksiView)
            transaksiView.jenis = "Pemasukan"
            view.window?.title = "Pemasukan"
            DispatchQueue.main.async {
                self.handleTransaksiFilterSelection(index: index)
            }
        } else if index == 11 {
            showViewController(transaksiView)
            transaksiView.jenis = "Pengeluaran"
            view.window?.title = "Pengeluaran"
            DispatchQueue.main.async {
                self.handleTransaksiFilterSelection(index: index)
            }
        } else if index == 12 {
            showViewController(transaksiView)
            transaksiView.jenis = "Lainnya"
            view.window?.title = "Lainnya"
            DispatchQueue.main.async {
                self.handleTransaksiFilterSelection(index: index)
            }
        } else if index == 13 {
            view.window?.title = "Jumlah Saldo"
            showViewController(saldoView)
        } else if index == 14 {
            view.window?.title = "Nilai Kelas Aktif"
            showViewController(statistikView)
        } else if index == 15 {
            view.window?.title = "Jumlah Siswa"
            showViewController(jumlahSiswa)
        } else if index == 16 {
            view.window?.title = "Struktur Guru"
            showViewController(struktur)
        } else if index == 17 {
            view.window?.title = "Inventaris"
            showViewController(inventaris)
        }
    }

    /// Fungsi untuk menangani pemilihan filter transaksi.
    /// - Parameter index: Indeks filter yang dipilih.
    func handleTransaksiFilterSelection(index: Int) {
        switch index {
        case 10:
            transaksiView.filterData(withType: "Pemasukan")
        // transaksiView.jenisDidChange(newJenis: "Pemasukan")
        case 11:
            transaksiView.filterData(withType: "Pengeluaran")
        // transaksiView.jenisDidChange(newJenis: "Pengeluaran")
        case 12:
            transaksiView.filterData(withType: "Lainnya")
        // transaksiView.jenisDidChange(newJenis: "Lainnya")
        default:
            transaksiView.resetData()
        }
    }

    /// Fungsi untuk menangani pemilihan item kelas di sidebar.
    /// - Parameter index: Indeks item kelas yang dipilih.
    func didSelectKelasItem(index: Int) {
        // Implementasi logika untuk menyesuaikan tampilan di NSSplitViewController
        // Berdasarkan pemilihan kelas di sidebar (index)
        if index >= 1, index <= 6 {
            kelasVC.tabView.selectTabViewItem(at: index - 1)
            showViewController(kelasVC)
        }
    }

    /// Fungsi untuk menampilkan view controller yang sesuai berdasarkan item sidebar yang dipilih.
    /// - Parameter viewController: NSViewController yang akan ditampilkan.
    /// - Note: Pastikan untuk memeriksa apakah viewController sudah ada di hirarki sebelum menambahkannya.
    /// Jika viewController sudah ada di hirarki, cukup tampilkan saja.
    /// Jika viewController belum ada di hirarki, tambahkan sebagai child view controller.
    /// Jika ada child view controller yang sedang aktif, sembunyikan (hapus) sebelum menampilkan viewController baru.
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
            if let index = printMenu.items.firstIndex(of: separatorMenuItem), printMenu.items.first(where: { $0.identifier?.rawValue == "eksporMenuItem" }) == nil {
                printMenu.insertItem(eksporMenuItem, at: index + 1)
            }
            csvMenuItem.isHidden = true
            excelMenuItem.isHidden = false
            excelMenuItem.title = "\"Data Siswa\" ke File Excel"
            pdfMenuItem.isHidden = false
            pdfMenuItem.title = "\"Data Siswa\" ke File PDF"
        } else if viewController is KelasVC {
            if let index = printMenu.items.firstIndex(of: separatorMenuItem), printMenu.items.first(where: { $0.identifier?.rawValue == "eksporMenuItem" }) == nil {
                printMenu.insertItem(eksporMenuItem, at: index + 1)
            }
            csvMenuItem.isHidden = false
            excelMenuItem.isHidden = false
            pdfMenuItem.isHidden = false
        } else {
            csvMenuItem.isHidden = true
            excelMenuItem.isHidden = true
            pdfMenuItem.isHidden = true
            if printMenu.items.first(where: { $0.identifier?.rawValue == "eksporMenuItem" }) != nil {
                printMenu.removeItem(eksporMenuItem)
            }
        }

        if viewController is KelasVC {
            guard let toolbar = view.window?.toolbar else { return }
            guard let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }) else { return }
            guard let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton else { return }
            kalkulasiNilai.isEnabled = true
        } else {
            guard let toolbar = view.window?.toolbar else { return }
            guard let kalkulasiNilaToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "Kalkulasi" }) else { return }
            guard let kalkulasiNilai = kalkulasiNilaToolbarItem.view as? NSButton else { return }
            kalkulasiNilai.isEnabled = false
        }
    }

    /// Fungsi ini akan menampilkan dialog cetak untuk kelas 1.
    /// - Parameter sender: Tombol yang ditekan untuk memicu aksi ini.
    @IBAction func prnt1(_ sender: Any) {
        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas?.loadView()
        printKelas?.prnt1()
    }

    /// Fungsi ini akan menampilkan dialog cetak untuk kelas 2.
    /// - Parameter sender: Tombol yang ditekan untuk memicu aksi ini.
    @IBAction func prntkls2(_ sender: Any) {
        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas?.loadView()
        printKelas?.printkls2()
    }

    /// Fungsi ini akan menampilkan dialog cetak untuk kelas 3.
    /// - Parameter sender: Tombol yang ditekan untuk memicu aksi ini.
    @IBAction func prntkls3(_ sender: Any) {
        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas?.loadView()
        printKelas?.printkls3()
    }

    /// Fungsi ini akan menampilkan dialog cetak untuk kelas 4.
    /// - Parameter sender: Tombol yang ditekan untuk memicu aksi ini.
    @IBAction func prntkls4(_ sender: Any) {
        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas?.loadView()
        printKelas?.printkls4()
    }

    /// Fungsi ini akan menampilkan dialog cetak untuk kelas 5.
    /// - Parameter sender: Tombol yang ditekan untuk memicu aksi ini.
    @IBAction func prntkls5(_ sender: Any) {
        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas?.loadView()
        printKelas?.printkls5()
    }

    /// Fungsi ini akan menampilkan dialog cetak untuk kelas 6.
    /// - Parameter sender: Tombol yang ditekan untuk memicu aksi ini.
    @IBAction func prntkls6(_ sender: Any) {
        let storyboard = NSStoryboard(name: "PrintKelas", bundle: nil)
        if let printKelas = storyboard.instantiateController(withIdentifier: "PrintKelas") as? PrintKelas {
            self.printKelas = printKelas
        }
        printKelas?.loadView()
        printKelas?.printkls6()
    }

    /// Fungsi ini akan menampilkan dialog cetak untuk kalkulasi nilai siswa dan semester
    /// di kelas aktif yang sedang ditampilkan atau yang terakhir di tampilkan.
    /// - Parameter sender: Tombol yang ditekan untuk memicu aksi ini.
    @IBAction func printText(_ sender: Any) {
        if let kelas = currentContentController as? KelasVC {
            kelas.printText()
        } else {
            ReusableFunc.showAlert(title: "Kelas Aktif Belum Siap", message: "")
        }
    }

    /// Action untuk mengekspor data ke file CSV ``csvMenuItem``.
    /// Ini akan memanggil fungsi `exportToCSV` pada kelas view controller yang aktif.
    /// - Parameter sender: Tombol yang ditekan untuk memicu aksi ini.
    @IBAction func CSVButton(_ sender: Any) {
        // Ganti cara mendapatkan referensi ke KelasVC
        if let activeTable = kelasVC.activeTable() {
            kelasVC.exportToCSV(activeTable)
        }
    }

    /// Action untuk mengekspor data ke file Excel ``excelMenuItem``.
    /// Ini akan memanggil fungsi `exportToExcel` pada kelas view controller yang aktif.
    /// - Parameter sender: Tombol yang ditekan untuk memicu aksi ini.
    @IBAction func xlxsButton(_ sender: NSMenuItem) {
        if let kelasVC = currentContentController as? KelasVC {
            kelasVC.exportToExcel(sender)
        } else if let siswaViewController = currentContentController as? SiswaViewController {
            siswaViewController.exportToExcel(sender)
        }
    }

    /// Action untuk mengekspor data ke file PDF ``pdfMenuItem``.
    /// - Parameter sender: Tombol yang ditekan untuk memicu aksi ini.
    @IBAction func PDFButton(_ sender: NSMenuItem) {
        if let kelasVC = currentContentController as? KelasVC {
            kelasVC.exportToPDF(sender)
        } else if let siswaViewController = currentContentController as? SiswaViewController {
            siswaViewController.exportToPDF(sender)
        }
    }
}
