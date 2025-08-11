//
//  NaikKelasVC.swift
//  Data SDI
//
//  Created by MacBook on 23/07/25.
//

import Cocoa

/// View controller untuk menangani fungsionalitas "Naik Kelas" pada aplikasi.
///
/// Controller ini mengelola UI untuk mempromosikan siswa ke kelas berikutnya,
/// termasuk pemilihan semester dan pengisian tahun ajaran.
/// Juga menyediakan fungsionalitas untuk menambahkan semester baru
/// serta menampilkan informasi terkait proses tersebut.
/// Controller ini menggunakan tombol pop-up untuk pemilihan semester
/// dan text field untuk memasukkan tahun ajaran.
class NaikKelasVC: NSViewController {
    /// Outlet pop-up button untuk memilih dan menambahkan semester.
    @IBOutlet weak var popUp: NSPopUpButton!
    
    /// Outlet untuk memasukkan tahun ajaran pertama.
    @IBOutlet weak var inputTahun1: NSTextField!
    
    /// Outlet untuk memasukkan tahun ajaran kedua.
    @IBOutlet weak var inputTahun2: NSTextField!
    
    /// Outlet untuk menampilkan informasi tambahan tentang proses naik kelas.
    ///
    /// Ini akan menampilkan popover dengan informasi lebih lanjut ketika diklik.
    /// Popover ini berisi informasi bahwa data nilai siswa selain tahun ajaran yang diketik
    /// akan dijadikan nilai historis dan ditampilkan di Rincian Siswa, bukan Kelas Aktif.
    @IBOutlet weak var info: NSButton!
    
    /// Outlet untuk pop-up button yang menampilkan kelas yang akan dipilih.
    ///
    /// Ini akan menampilkan daftar kelas yang tersedia untuk dipilih saat siswa naik kelas.
    /// Jika tidak ada kelas yang dipilih, nil akan dikirimkan ke callback `onSimpanKelas`.
    /// Jika kelas dipilih, nama kelas yang dipilih akan dikirimkan ke callback `onSimpanKelas`.
    /// Ini memungkinkan pengguna untuk memilih kelas yang sesuai untuk siswa yang akan naik kelas.
    @IBOutlet weak var popupKelas: NSPopUpButton!

    /// Referensi ke window controller untuk jendela kategori.
    ///
    /// Digunakan untuk mengelola jendela yang memungkinkan pengguna menambahkan kategori baru (semester).
    /// Window controller dibuat ketika pengguna memilih untuk menambahkan semester baru.
    /// Akan diatur menjadi `nil` ketika jendela ditutup atau ketika view controller didealokasikan.
    /// Hal ini memastikan jendela dikelola dengan benar dan tidak menyebabkan kebocoran memori.
    /// `kategoriWindow` digunakan untuk menampilkan jendela kategori baru untuk menambahkan semester.
    private var kategoriWindow: NSWindowController?

    /// Callback closure yang dijalankan ketika pengguna menyimpan kelas yang dipilih.
    ///
    /// Ini akan mengirimkan nama kelas yang dipilih (jika ada), tahun ajaran yang dimasukkan,
    /// dan semester yang dipilih ke fungsi yang ditentukan oleh pengguna.
    /// Jika kelas tidak dipilih, nil akan dikirimkan sebagai nama kelas.
    /// Tahun ajaran akan dikirimkan dalam format "tahun1/tahun2", dan
    /// semester akan dikirimkan sebagai string yang telah dipangkas dari awalan "Semester ".
    /// Ini memungkinkan pengguna untuk menangani logika penyimpanan kelas yang dipilih sesuai kebutuhan mereka.
    /// - Parameter kelas: Nama kelas yang dipilih, atau nil jika tidak ada kelas yang dipilih.
    /// - Parameter tahunAjaran: Tahun ajaran yang dimasukkan dalam format "tahun1/tahun2".
    /// - Parameter semester: Semester yang dipilih,
    ///   dipangkas dari awalan "Semester " jika ada.
    /// - Returns: Void
    /// - Note: Pastikan untuk menangani kasus di mana kelas tidak dipilih dengan memeriksa apakah `kelas` adalah nil.
    ///   Ini penting untuk memastikan bahwa logika penyimpanan kelas yang dipilih berfungsi dengan benar.
    ///   Jika kelas tidak dipilih,
    ///   maka fungsi yang menangani penyimpanan harus dapat menangani kasus ini dengan baik.
    ///   Misalnya, jika kelas tidak dipilih, maka data yang terkait dengan kelas tersebut
    ///   tidak akan disimpan atau diperbarui dalam sistem.
    ///   Pastikan untuk memberikan umpan balik yang sesuai kepada pengguna jika kelas tidak dipilih.
    var onSimpanKelas: ((String?, String, String) -> Void)?

    /// Callback closure yang dijalankan ketika pengguna menutup view controller.
    ///
    /// Ini akan mengirimkan sinyal bahwa pengguna telah menutup view controller,
    /// memungkinkan pengguna untuk menangani logika penutupan sesuai kebutuhan mereka.
    /// Misalnya, jika pengguna ingin membersihkan data atau memperbarui UI setelah penutupan,
    /// mereka dapat melakukannya di dalam closure ini.
    /// - Returns: Void
    /// - Note: Pastikan untuk menangani kasus di mana pengguna menutup view controller
    ///   tanpa menyimpan perubahan yang telah dibuat.
    ///   Ini penting untuk memastikan bahwa aplikasi tetap responsif dan tidak kehilangan data yang belum disimpan.
    ///   Jika pengguna menutup view controller tanpa menyimpan perubahan,
    ///   maka aplikasi harus dapat menangani kasus ini dengan baik,
    ///   misalnya dengan menampilkan pesan konfirmasi atau mengembalikan UI ke keadaan semula.
    var onClose: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        let newSemOpt = NSMenuItem(title: "Tambah...", action: #selector(openSemesterWindow(_:)), keyEquivalent: "")
        newSemOpt.target = self
        newSemOpt.representedObject = CategoryType.semester
        popUp.menu?.addItem(NSMenuItem.separator())
        popUp.menu?.addItem(newSemOpt)
        info.target = self
        info.action = #selector(showPopover(_:))
        // Do view setup here.
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        onSimpanKelas = nil
        onClose = nil
        currentPopover?.contentViewController?.view.subviews.removeAll()
        currentPopover?.contentViewController = nil
        currentPopover = nil
        kategoriWindow?.close()
        kategoriWindow = nil
    }

    /// Action yang dijalankan ketika pengguna mengklik tombol "Simpan".
    ///
    /// Ini akan memeriksa apakah tahun ajaran yang dimasukkan valid,
    /// dan jika semester yang dipilih valid.
    /// Jika semua validasi berhasil, maka akan memanggil closure `onSimpanKelas`
    /// dengan nama kelas yang dipilih (jika ada), tahun ajaran yang dimasukkan,
    /// dan semester yang dipilih.
    /// Jika tahun ajaran tidak valid, akan menampilkan alert untuk meminta pengguna melengkapi
    /// tahun ajaran yang valid.
    /// - Parameter _: Parameter ini tidak digunakan, tetapi diperlukan untuk menghubungkan aksi ke tombol.
    /// - Returns: Void
    /// - Note: Pastikan untuk menangani kasus di mana pengguna tidak memilih kelas,
    ///   sehingga `onSimpanKelas` dapat menangani kasus ini dengan baik.
    ///   Jika kelas tidak dipilih, maka `popupKelas.titleOfSelectedItem`
    ///   akan mengembalikan nil, dan fungsi `onSimpanKelas`
    ///   harus dapat menangani kasus ini dengan baik.
    ///   Misalnya, jika kelas tidak dipilih, maka data yang terkait dengan kelas tersebut
    ///   tidak akan disimpan atau diperbarui dalam sistem.
    ///   Pastikan untuk memberikan umpan balik yang sesuai kepada pengguna jika kelas tidak dipilih.
    ///   Misalnya, jika kelas tidak dipilih, maka aplikasi dapat menampilkan pesan konfirmasi
    ///   atau mengembalikan UI ke keadaan semula.
    @IBAction
    private func simpan(_: Any) {
        guard let tahunAjaran1 = inputTahun1?.stringValue,
              let tahunAjaran2 = inputTahun2?.stringValue,
              !tahunAjaran1.isEmpty || !tahunAjaran2.isEmpty
        else {
            ReusableFunc.showAlert(title: "Lengkapi tahun ajaran.", message: "Masukkan tahun ajaran yang valid.")
            return
        }

        guard let semester = popUp.titleOfSelectedItem else {
            return
        }

        let trimmedSemester = semester.hasPrefix("Semester ")
            ? semester.replacingOccurrences(of: "Semester ", with: "")
            : semester

        let tahunAjaran = inputTahun1.stringValue + "/" + inputTahun2.stringValue

        onSimpanKelas?(
            popupKelas.isHidden ? nil : popupKelas.titleOfSelectedItem!,
            tahunAjaran,
            trimmedSemester
        )
        dismiss(nil)
    }

    /// Action yang dijalankan ketika pengguna mengklik tombol "Tutup".
    ///
    /// Ini akan memanggil closure `onClose` jika ada,
    /// dan kemudian menutup view controller.
    /// Ini memungkinkan pengguna untuk menutup view controller tanpa menyimpan perubahan yang telah dibuat.
    /// - Parameter _: Parameter ini tidak digunakan, tetapi diperlukan untuk menghubungkan aksi ke tombol.
    /// - Returns: Void
    /// - Note: Pastikan untuk menangani kasus di mana pengguna menutup view controller
    ///   tanpa menyimpan perubahan yang telah dibuat.
    ///   Ini penting untuk memastikan bahwa aplikasi tetap responsif dan tidak kehilangan data yang belum disimpan.
    ///   Jika pengguna menutup view controller tanpa menyimpan perubahan,
    ///   maka aplikasi harus dapat menangani kasus ini dengan baik,
    ///   misalnya dengan menampilkan pesan konfirmasi atau mengembalikan UI ke keadaan semula.
    ///   Pastikan untuk memberikan umpan balik yang sesuai kepada pengguna jika mereka memilih
    ///   untuk menutup view controller tanpa menyimpan perubahan.
    @IBAction
    private func tutup(_ sender: Any) {
        onClose?()
        dismiss(sender)
    }

    /// Action yang dijalankan ketika pengguna memilih opsi "Tambah..." dari menu pop-up semester.
    ///
    /// Ini akan membuka jendela baru untuk menambahkan semester baru.
    /// Jendela ini memungkinkan pengguna untuk memasukkan nama semester baru yang akan ditambahkan.
    /// Jika jendela sudah ada, maka akan menampilkan jendela tersebut.
    /// Jika belum ada, maka akan membuat jendela baru dengan tipe `CategoryType.semester`.
    /// - Parameter sender: Menu item yang dipilih oleh pengguna.
    /// - Returns: Void
    /// - Note: Pastikan untuk menangani kasus di mana pengguna menutup jendela
    ///   tanpa menambahkan semester baru.
    @objc
    private func openSemesterWindow(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? CategoryType else { return }

        guard kategoriWindow == nil else {
            kategoriWindow?.window?.makeKeyAndOrderFront(sender)
            return
        }

        kategoriWindow = ReusableFunc.openNewCategoryWindow(view, viewController: self, type: context, suggestions: ReusableFunc.semester)
    }

    private var currentPopover: NSPopover?

    /// Action yang dijalankan ketika pengguna mengklik tombol informasi.
    ///
    /// Ini akan menampilkan popover dengan informasi tambahan tentang proses naik kelas.
    /// Popover ini berisi informasi bahwa data nilai siswa selain tahun ajaran yang diketik
    /// akan dijadikan nilai historis dan ditampilkan di Rincian Siswa, bukan Kelas Aktif.
    /// Popover akan ditampilkan di bawah tombol informasi.
    /// Jika popover sudah ada, maka akan menampilkannya kembali.
    /// Jika belum ada, maka akan membuat popover baru dengan konten yang telah ditentukan.
    /// - Parameter _: Parameter ini tidak digunakan, tetapi diperlukan untuk menghubungkan aksi ke tombol.
    /// - Returns: Void
    /// - Note: Pastikan untuk menangani kasus di mana popover sudah ada,
    ///   sehingga tidak membuat popover baru setiap kali tombol diklik.
    ///   Ini penting untuk menghindari kebocoran memori dan memastikan bahwa popover
    ///   hanya dibuat sekali dan ditampilkan kembali jika diperlukan.
    ///   Jika popover sudah ada, maka akan menampilkannya kembali di bawah tombol informasi.
    ///   Jika belum ada, maka akan membuat popover baru dengan konten yang telah ditentukan.
    ///   Pastikan untuk memberikan umpan balik yang sesuai kepada pengguna jika mereka mengklik tombol informasi.
    ///   Misalnya, jika popover sudah ada, maka aplikasi dapat menampilkan pesan konfirmasi
    ///   atau mengembalikan UI ke keadaan semula.
    ///   Ini penting untuk memastikan bahwa pengguna dapat memahami informasi yang diberikan
    ///   dan tidak merasa bingung dengan tampilan popover yang berulang kali muncul.
    @objc
    private func showPopover(_: Any) {
        if let currentPopover {
            currentPopover.show(relativeTo: info.bounds, of: info, preferredEdge: .maxY)
        }

        // 1. Buat ViewController manual
        let popoverVC = NSViewController()
        popoverVC.view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        popoverVC.view.wantsLayer = true
        popoverVC.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Tambahkan label sebagai isi popover (opsional)
        let label = NSTextField(wrappingLabelWithString: "Data nilai siswa selain tahun ajaran yang diketik akan dijadikan nilai historis dan ditampilkan di Rincian Siswa, bukan Kelas Aktif.")
        label.frame = NSRect(x: 10, y: -10, width: 180, height: 100)
        label.isSelectable = false
        popoverVC.view.addSubview(label)

        // 2. Buat popover
        let popover = NSPopover()
        popover.contentViewController = popoverVC
        popover.behavior = .transient
        popover.animates = true

        // 3. Simpan referensi agar tidak langsung di-deinit (opsional tapi penting)
        currentPopover = popover

        // 4. Tampilkan popover
        popover.show(relativeTo: info.bounds, of: info, preferredEdge: .maxY)
    }

    deinit {
        #if DEBUG
            print("deinit naikKelasVC")
        #endif
    }
}

extension NaikKelasVC: KategoriBaruDelegate {
    /// Metode delegate yang dipanggil ketika kategori baru (semester) ditambahkan.
    ///
    /// Metode ini memperbarui menu pop-up dengan kategori baru tersebut dan
    /// otomatis memilihnya.
    /// - Parameter category: Nama kategori baru yang ditambahkan.
    /// - Parameter ofType: Tipe kategori, yang diharapkan berupa `CategoryType.semester`.
    /// - Returns: Void
    /// - Catatan: Metode ini mengasumsikan bahwa menu pop-up sudah ada
    ///   dan telah diinisialisasi sebelumnya.
    ///   Kategori baru akan disisipkan di posisi kedua dari terakhir pada menu,
    ///   tepat sebelum opsi "Tambah...".
    ///   Jika menu pop-up tidak ada, metode ini tidak akan melakukan apa pun.
    ///   Pastikan menu pop-up sudah diinisialisasi dengan benar sebelum memanggil metode ini.
    ///   Hal ini penting untuk menghindari kesalahan runtime saat mencoba mengakses menu.
    ///   Jika menu pop-up belum diinisialisasi, sebaiknya tangani kasus tersebut
    ///   dengan menampilkan peringatan atau mencatat pesan kesalahan.
    ///   Metode ini biasanya dipanggil ketika pengguna berhasil menambahkan semester baru
    ///   melalui jendela kategori, sehingga aplikasi dapat memperbarui tampilan UI-nya.
    ///   Kategori baru akan ditambahkan ke menu pop-up, dan menu tersebut
    ///   akan otomatis memilih kategori yang baru ditambahkan.
    func didAddNewCategory(_ category: String, ofType _: CategoryType) {
        let menuItem = NSMenuItem()
        menuItem.title = category
        if let menu = popUp.menu {
            let insertionIndex = max(menu.items.count - 2, 0)
            menu.insertItem(menuItem, at: insertionIndex)
        }
        popUp.selectItem(withTitle: category)
        didCloseWindow()
    }

    /// Metode delegate yang dipanggil ketika jendela kategori ditutup.
    ///
    /// Metode ini membersihkan referensi ke jendela kategori dan mengaturnya menjadi `nil`.
    /// - Returns: Void
    /// - Catatan: Metode ini dipanggil ketika pengguna menutup jendela kategori,
    ///   baik setelah menambahkan kategori baru maupun ketika jendela ditutup tanpa menambahkan apa pun.
    ///   Metode ini memastikan bahwa referensi `kategoriWindow` dibersihkan dengan benar
    ///   untuk mencegah kebocoran memori.
    ///   Jika jendela sudah bernilai `nil`, metode ini tidak akan melakukan apa pun.
    ///   Hal ini penting untuk memastikan aplikasi tidak mempertahankan referensi
    ///   ke jendela yang sudah tidak diperlukan, yang dapat menyebabkan kebocoran memori
    ///   dan masalah kinerja.
    ///   Setelah metode ini dipanggil, `kategoriWindow` akan diset menjadi `nil`,
    ///   menandakan bahwa tidak ada jendela kategori yang aktif.
    ///   Metode ini biasanya dipanggil ketika pengguna berhasil menambahkan kategori baru
    ///   atau memutuskan untuk menutup jendela kategori tanpa melakukan perubahan.
    ///   Penting untuk memanggil metode ini agar aplikasi tetap responsif
    ///   dan tidak menyimpan referensi yang tidak diperlukan ke jendela yang sudah ditutup.
    ///   Jika pengguna ingin membuka kembali jendela kategori di lain waktu,
    ///   instance baru dari `NSWindowController` dapat dibuat sesuai kebutuhan.
    ///   Dengan cara ini, aplikasi dapat mengelola jendelanya secara efisien dan menghindari kebocoran memori.
    func didCloseWindow() {
        kategoriWindow?.contentViewController = nil
        kategoriWindow?.close()
        kategoriWindow = nil
    }
}
