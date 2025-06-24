import Cocoa

/// Nilai Kelas tertentu dan Semua Nilai siswa di dalamnya.
class NilaiKelas: NSViewController {
    /// Outlet tableView.
    @IBOutlet weak var tableview: NSTableView!
    /// Outlet label untuk nama kelas.
    @IBOutlet weak var kelasLabel: NSTextField!
    /// Outlet rata-rata dan jumlah nilai kelas.
    @IBOutlet weak var avgdanjumlah: NSTextField!
    /// Outlet popup menu semester
    @IBOutlet weak var semesterPopUp: NSPopUpButton!
    /// Outlet jumlah nilai kelas.
    @IBOutlet weak var jumlahNilaiKelas: NSTextField!
    /// Outlet scrollView yang memuat tableView.
    @IBOutlet weak var scrollView: NSScrollView!
    // Properti jumlah nilai kelas.
    var jumlahnilai = ""
    /// Array untuk menyimpan data dari database.
    var data: [StudentSummary] = []
    /// Data yang telah difilter setelah pemilihan popup ``semesterPopUp``.
    var filteredData: [KelasModels] = []
    /// Array untuk menyimpan semua data di kelas.
    var kelasModel: [KelasModels] = []
    /// Properti nama kelas.
    var namaKelas = ""
    /// Array untuk menyimpan nama-nama mata pelajaran serta nilai, rata-rata nilai, dan nama guru.
    var mapelData: [MapelSummary] = [] // New property for subject data
    /// Outlet untuk membuka class ini di jendela baru.
    @IBOutlet weak var inNewWindow: NSButton!
    /// Outlet menu ekspor ke XLSX/PDF.
    @IBOutlet weak var shareMenu: NSButton!
    /// Outlet menu ``shareMenu``.
    @IBOutlet var menuItem: NSMenu!
    /// Outlet VisualEffect.
    @IBOutlet weak var visualEffect: NSVisualEffectView!
    /// Outlet constraint bagian atas ``topStack``. Diperbarui ketika class ini ditampilkan dalam jendela baru.
    @IBOutlet weak var stackViewTopConstraint: NSLayoutConstraint!
    /// Outlet constraint untuk tinggi ``visualEffect``. Diperbarui ketika class ini ditampilkan dalam jendela baru.
    @IBOutlet weak var visualEffectHeightConstraint: NSLayoutConstraint!
    /// Properti yang menyatakan jika view ini ditampilkan dalam window baru.
    var isNewWindow: Bool = false
    /// Work item untuk memperbarui tampilan baris ketika di slide ke-kiri atau ke-kanan.
    var workItem: DispatchWorkItem?
    /// Outlet stackView yang memuat judul kelas dan nilai kelas serta menu item semester dan ekspor data.
    @IBOutlet weak var topStack: NSStackView!

    override func viewDidLoad() {
        super.viewDidLoad()
        if isNewWindow {
            view.window?.delegate = self
            inNewWindow.isHidden = true
            topStack.needsLayout = true
            stackViewTopConstraint.constant += 12
            visualEffectHeightConstraint.constant += 12
            scrollView.contentInsets.top += 12
        }
        tableview.delegate = self
        tableview.dataSource = self

        visualEffect.material = .headerView
        configureSemesterPopUp()
        semesterSelectionChanged()
        updateScrollViewSize()
        let menu = NSMenu()
        tableview.menu = menu
        menu.delegate = self
        kelasLabel.alphaValue = 0.8
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        jumlahNilaiKelas.stringValue = "Total Nilai \(namaKelas): \(jumlahnilai)"
        kelasLabel.stringValue = "\(namaKelas)"
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.semesterPopUp.selectItem(at: 0)
        }
    }

    /// Buka popover Nilai Kelas sebagai jendela baru
    /// - Parameter sender: event yang memicu.
    @IBAction func newWindow(_ sender: Any) {
        let jumlahnilai = jumlahnilai
        let namaKelas = namaKelas
        let kelasModel = kelasModel
        
        dismiss(sender)
        view.window?.performClose(sender)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            // Load NilaiSiswa XIB
            let nilaiSiswaVC = NilaiKelas(nibName: "NilaiKelas", bundle: nil)
            // Setel data StudentSummary untuk ditampilkan
            nilaiSiswaVC.jumlahnilai = jumlahnilai
            nilaiSiswaVC.namaKelas = namaKelas
            nilaiSiswaVC.kelasModel = kelasModel
            nilaiSiswaVC.isNewWindow = true
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE d MMM H:m:s"
            let currentDate = dateFormatter.string(from: Date())
            
            // Membuat window baru untuk NilaiSiswa
            let window = NSWindow(contentViewController: nilaiSiswaVC)
            window.title = "\(namaKelas) - update \(currentDate)" // Menambahkan tanggal dan waktu di judul
            
            window.setFrameAutosaveName("KalkulasiNilaiKelasWindow")
            window.titlebarAppearsTransparent = true
            window.isRestorable = false
            window.styleMask.insert([.fullSizeContentView, .resizable, .miniaturizable, .closable])
            window.delegate = nilaiSiswaVC
            window.makeKeyAndOrderFront(sender)
            AppDelegate.shared.openedKelasWindows[kelasLabel.stringValue] = window
        }
    }

    /// Menghitung ringkasan nilai siswa (`StudentSummary`) untuk kelas dan semester tertentu.
    ///
    /// Fungsi ini memfilter data siswa berdasarkan semester yang diberikan, lalu mengelompokkan
    /// nilai berdasarkan nama siswa untuk menghitung total nilai dan jumlah mata pelajaran
    /// yang diambil oleh setiap siswa. Akhirnya, ia membuat objek `StudentSummary` untuk
    /// setiap siswa, menghitung rata-rata nilai, dan mengurutkan hasilnya berdasarkan
    /// total nilai siswa dari yang tertinggi ke terendah.
    ///
    /// - Parameters:
    ///   - kelas: Array `KelasModels` yang berisi data nilai lengkap untuk suatu kelas.
    ///   - semester: `String` yang menunjukkan semester yang akan difilter ("1" atau "2" atau yang lainnya).
    /// - Returns: Array `[StudentSummary]` yang berisi ringkasan nilai setiap siswa
    ///            untuk semester yang ditentukan, diurutkan berdasarkan total nilai.
    private func createCustomSummaries(forKelas kelas: [KelasModels], semester: String) async -> [StudentSummary] {
        // Filter data siswa untuk semester yang ditentukan
        let siswaSemester = kelas.filter { $0.semester == semester }

        // Menghitung total nilai dan rata-rata nilai setiap siswa
        var summaries: [StudentSummary] = []
        var nilaiSiswaDictionary: [String: (totalNilai: Int, jumlahSiswa: Int)] = [:]

        // Mengumpulkan data total nilai dan jumlah siswa per siswa
        for siswa in siswaSemester {
            if var data = nilaiSiswaDictionary[siswa.namasiswa] {
                data.totalNilai += Int(siswa.nilai)
                data.jumlahSiswa += 1
                nilaiSiswaDictionary[siswa.namasiswa] = data
            } else {
                nilaiSiswaDictionary[siswa.namasiswa] = (totalNilai: Int(siswa.nilai), jumlahSiswa: 1)
            }
        }

        // Konversi data ke array `StudentSummary`
        for (namaSiswa, data) in nilaiSiswaDictionary {
            let averageScore = Double(data.totalNilai) / Double(data.jumlahSiswa)
            let summary = StudentSummary(name: namaSiswa, averageScore: averageScore, totalScore: data.totalNilai)
            summaries.append(summary)
        }

        // Sortir berdasarkan `totalScore` dari nilai tertinggi ke terendah (opsional)
        summaries.sort { $0.totalScore > $1.totalScore }

        return summaries
    }

    /// Menghitung ringkasan mata pelajaran (`MapelSummary`) untuk kelas dan semester tertentu.
    ///
    /// Fungsi ini memfilter data siswa berdasarkan semester, kemudian mengidentifikasi semua
    /// mata pelajaran unik dalam semester tersebut. Untuk setiap mata pelajaran, fungsi ini
    /// menghitung total nilai, jumlah siswa, rata-rata nilai, dan nama guru.
    /// Hasilnya adalah array `MapelSummary` yang diurutkan berdasarkan rata-rata nilai tertinggi.
    ///
    /// - Parameters:
    ///   - kelas: Array `KelasModels` yang berisi data nilai lengkap untuk suatu kelas.
    ///   - semester: `String` yang menunjukkan semester yang akan difilter ("1" atau "2", atau yang lainnya.).
    /// - Returns: Array `[MapelSummary]` yang berisi ringkasan setiap mata pelajaran
    ///            untuk semester yang ditentukan, diurutkan berdasarkan rata-rata nilai.
    private func calculateMapelSummaries(forKelas kelas: [KelasModels], semester: String) async -> [MapelSummary] {
        let siswaSemester = kelas.filter { $0.semester == semester }
        let uniqueMapels = Set(siswaSemester.map(\.mapel))
        var summaries: [MapelSummary] = []

        for mapel in uniqueMapels {
            let siswaMapel = siswaSemester.filter { $0.mapel == mapel }
            let totalNilai = siswaMapel.reduce(0) { $0 + $1.nilai }
            let jumlahSiswa = siswaMapel.count
            let averageScore = Double(totalNilai) / Double(jumlahSiswa)
            let namaGuru = siswaMapel.first(where: { !$0.namaguru.isEmpty })?.namaguru ?? "-"

            summaries.append(MapelSummary(
                name: mapel,
                totalScore: Double(totalNilai),
                averageScore: averageScore,
                totalStudents: jumlahSiswa,
                namaGuru: namaGuru
            ))
        }
        return summaries.sorted(by: { $0.averageScore > $1.averageScore })
    }

    /// Dijalankan ketika pilihan semester berubah.
    @objc private func semesterSelectionChanged() {
        Task(priority: .background) { [weak self] in
            guard let s = self else { return }
            guard var selectedSemester = s.semesterPopUp.titleOfSelectedItem else { return }
            if selectedSemester.contains("Semester") {
                selectedSemester = selectedSemester.replacingOccurrences(of: "Semester ", with: "")
            }

            s.filteredData = s.kelasModel.filter { $0.semester == selectedSemester }

            let totalNilai = s.filteredData.reduce(0) { $0 + $1.nilai }
            let rataRataNilai = s.filteredData.isEmpty ? 0.0 : Double(totalNilai) / Double(s.filteredData.count)

            s.avgdanjumlah.stringValue = "Nilai Semester \(selectedSemester): \(totalNilai), Rata-rata: \(String(format: "%.2f", rataRataNilai))"

            // Update both student and subject data
            s.data = await s.createCustomSummaries(forKelas: s.kelasModel, semester: selectedSemester)
            s.mapelData = await s.calculateMapelSummaries(forKelas: s.kelasModel, semester: selectedSemester)

            await MainActor.run { [weak self] in
                self?.tableview.reloadData()
                self?.updateScrollViewSize()
            }
        }
    }

    /// Konfigurasi awal pilihan semester.
    ///
    /// Menambahkan pilihan semester-semester yang ada di dalam kelas ke dalam NSPopUpButton.
    private func configureSemesterPopUp() {
        // Mengambil semester unik dari kelasModel
        let uniqueSemesters = Set(kelasModel.map(\.semester)).sorted { ReusableFunc.semesterOrder($0, $1) }

        // Menghapus semua item dari NSPopUpButton
        semesterPopUp.removeAllItems()

        // Menambahkan item semester yang diformat ke NSPopUpButton tanpa item kosong
        let formattedSemesters = uniqueSemesters
            .map { ReusableFunc.formatSemesterName($0) }
            .filter { !$0.isEmpty } // Memastikan item tidak kosong
        semesterPopUp.addItems(withTitles: formattedSemesters)

        // Mengatur target dan action NSPopUpButton
        semesterPopUp.target = self
        semesterPopUp.action = #selector(semesterSelectionChanged)
    }

    /// Konfigurasi menu item.
    ///
    /// Reset ulang menuItem di Menu Bar.
    /// - Parameter sender: event yang memicu.
    @objc func updateMenuItem(_ sender: Any?) {
        if let mainMenu = NSApp.mainMenu,
           let editMenuItem = mainMenu.item(withTitle: "Edit"),
           let editMenu = editMenuItem.submenu,
           let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" })
        {
            let isRowSelected = tableview.selectedRowIndexes.count > 0

            // Update item menu "Copy"
            copyMenuItem.isEnabled = isRowSelected
            if isRowSelected {
                copyMenuItem.target = self
//                copyMenuItem.action = originalCopyAction
            } else {
//                copyMenuItem.target = originalCopyTarget
//                copyMenuItem.action = originalCopyAction
//                copyMenuItem.isEnabled = false
            }
        }
    }

    /// Memunculkan Custom PopUp untuk tombol berbagi.
    /// - Parameter sender: event yang memicu harus NSButton
    @IBAction func shareButton(_ sender: NSButton) {
        menuItem.popUp(positioning: nil, at: NSPoint(x: -2, y: sender.bounds.height + 4), in: sender)
    }

    /// Mengatur ulang ukuran `scrollView` dan jendela induknya secara dinamis
    /// berdasarkan jumlah konten dalam `tableview`.
    ///
    /// Fungsi ini menghitung tinggi konten yang diperlukan oleh `tableview`
    /// (berdasarkan jumlah baris data dan tinggi setiap baris) dan menyesuaikan
    /// tinggi `scrollView` serta jendela induknya untuk mengakomodasi konten tersebut.
    /// Ini memastikan `scrollView` tidak terlalu kecil atau terlalu besar,
    /// dan jendela tetap pada posisi atasnya saat ukurannya berubah.
    /// Animasi digunakan untuk transisi ukuran yang mulus.
    private func updateScrollViewSize() {
        // Memastikan ada jendela yang terhubung ke tampilan ini, jika tidak, keluar dari fungsi.
        guard let window = view.window else { return }

        // Hitung total tinggi konten yang dibutuhkan oleh tableview.
        let rowHeight = tableview.rowHeight + CGFloat(2) // Tinggi setiap baris termasuk spasi
        let dataTotal = data.count + mapelData.count + 2 // Total baris data yang ada

        // Perhitungan tinggi konten total:
        // Mengambil jumlah baris data dikalikan tinggi baris, lalu menguranginya
        // untuk baris 'daftar siswa' dan 'daftar mapel' (asumsi ini adalah header atau footer yang tidak dihitung sebagai data).
        // Menambahkan offset `42 + 52` untuk padding atau elemen UI tambahan di dalam scroll view.
        let totalContentHeight = CGFloat(dataTotal) * rowHeight
            - rowHeight // potong row daftar siswa
            - rowHeight // potong row daftar mapel
            + 42 + 52 // offset untuk padding atau elemen lain dalam scroll view

        // Konstanta untuk membatasi ukuran scroll view dan jendela.
        let maxHeight: CGFloat = 500 // Tinggi maksimum yang diizinkan untuk scroll view.
        let kelasStackHeight: CGFloat = 58 // Tinggi dari elemen stack yang mungkin ada di atas scroll view.
        let padding: CGFloat = 48 // Padding tambahan di sekitar konten.
        let minHeight: CGFloat = 116 // Tinggi minimum yang diizinkan untuk scroll view.

        // Hitung tinggi `scrollView` yang diinginkan, dengan memastikan ia berada dalam batas `minHeight` dan `maxHeight`.
        var scrollViewHeight = totalContentHeight
        scrollViewHeight = max(scrollViewHeight, minHeight) // Tinggi tidak boleh kurang dari minHeight.
        // Tinggi tidak boleh melebihi `maxHeight` dikurangi tinggi stack kelas dan padding.
        scrollViewHeight = min(scrollViewHeight, maxHeight - kelasStackHeight - padding)

        // Hitung ukuran dan posisi baru untuk jendela induk.
        let parentViewHeight = scrollViewHeight + kelasStackHeight + padding // Total tinggi jendela yang baru.

        // Pastikan lebar jendela tetap sama dengan lebar jendela saat ini.
        let currentWidth = window.frame.width
        let newSize = NSSize(width: currentWidth, height: parentViewHeight) // Ukuran jendela yang baru.

        // Sesuaikan `origin.y` untuk mempertahankan posisi atas jendela saat tingginya berubah.
        let currentFrame = window.frame
        let newOrigin = NSPoint(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y + (currentFrame.height - parentViewHeight)
        )

        // Buat `NSRect` baru untuk frame jendela dengan posisi dan ukuran yang disesuaikan.
        let newFrame = NSRect(origin: newOrigin, size: newSize)
        // Batasi frame baru agar tidak melebihi batas layar.
        let constrainedFrame = window.constrainFrameRect(newFrame, to: window.screen)

        // Atur properti `scrollView` sebelum menganimasikan perubahan ukuran jendela.
        scrollView.setFrameSize(NSSize(
            width: currentWidth - (window.contentView?.frame.width ?? 0 - scrollView.frame.width),
            height: scrollViewHeight
        ))

        // Konfigurasi scroller berdasarkan apakah konten melebihi tinggi scroll view.
        scrollView.hasVerticalScroller = totalContentHeight > scrollViewHeight
        scrollView.hasHorizontalScroller = false // Horizontal scroller selalu dimatikan.
        scrollView.hasHorizontalRuler = false // Penggaris horizontal selalu dimatikan.
        scrollView.autohidesScrollers = false // Scroller tidak otomatis sembunyi.
        scrollView.verticalScrollElasticity = .allowed // Elastisitas gulir vertikal diizinkan.

        // Memaksa layout ulang untuk komponen-komponen yang terpengaruh.
        scrollView.needsLayout = true
        scrollView.layoutSubtreeIfNeeded()
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()

        // Animasi perubahan ukuran jendela ke frame yang baru.
        window.animator().setFrame(constrainedFrame, display: true, animate: true)
    }

    deinit {
#if DEBUG
        print("deinit NilaiKelas")
#endif
        for subViews in view.subviews {
            subViews.removeFromSuperviewWithoutNeedingDisplay()
        }
        self.view.removeFromSuperviewWithoutNeedingDisplay()
    }
}

extension NilaiKelas: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        1 + data.count + 1 + mapelData.count // Headers + student data + subject header + subject data
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard tableColumn?.identifier == NSUserInterfaceItemIdentifier("siswa"),
              let cell = tableview.makeView(withIdentifier: NSUserInterfaceItemIdentifier("combinedCell"), owner: self) as? NSTableCellView
        else {
            return nil
        }

        if let line = cell.subviews.first(where: { $0.identifier?.rawValue == "lineTableView" }) as? NSBox {
            line.isHidden = row == 0 ? true : false

            if let topConstraint = cell.constraints.first(where: { constraint in
                (constraint.firstItem as? NSView) == line && constraint.firstAttribute == .top
            }) {
                // Jika cell header dengan mapel: constant = 6, jika cell biasa: constant = 0
                topConstraint.constant = row == data.count + 1 ? 6 : 0
            }
        }

        // Section headers
        if row == 0 {
            return createHeaderCell(title: "Daftar Siswa", mapel: false)
        } else if row == data.count + 1 {
            return createHeaderCell(title: "Daftar Mata Pelajaran", mapel: true)
        }

        // Student data section
        if row <= data.count {
            return createStudentCell(for: data[row - 1], at: row)
        }

        // Subject data section
        let mapelIndex = row - (data.count + 2)
        if mapelIndex < mapelData.count {
            return createMapelCell(for: mapelData[mapelIndex])
        }

        return nil
    }

    /// Membuat dan mengonfigurasi `NSTableCellView` kustom yang berfungsi sebagai header di `NSTableView`.
    ///
    /// Sel ini didesain untuk menampilkan judul utama ("Daftar Siswa" atau "Daftar Mapel")
    /// beserta sub-teks deskriptif dan sebuah ikon. Fungsi ini secara dinamis menyesuaikan
    /// batasan (constraints) tata letak (layout constraints) `NSTextField` dan `NSImageView`
    /// di dalamnya untuk mengakomodasi dua baris teks dengan gaya yang berbeda, serta
    /// mengubah ikon dan teks deskriptif berdasarkan parameter `title` dan `mapel`.
    ///
    /// - Parameters:
    ///   - title: `String` yang menjadi judul utama sel header (misalnya, "Daftar Siswa", "Daftar Mapel").
    ///   - mapel: `Bool` yang menunjukkan apakah sel ini untuk daftar mata pelajaran (`true`)
    ///            atau daftar siswa (`false`). Ini memengaruhi penyesuaian layout dan konten.
    /// - Returns: Sebuah `NSTableCellView` yang telah dikonfigurasi, atau `nil` jika gagal
    ///            membuat sel dari `tableview`.
    private func createHeaderCell(title: String, mapel: Bool) -> NSTableCellView? {
        // Mencoba mendaur ulang atau membuat NSTableCellView dengan identifier "combinedCell".
        let cell = tableview.makeView(withIdentifier: NSUserInterfaceItemIdentifier("combinedCell"), owner: self) as? NSTableCellView

        // Memastikan textField dan imageView berhasil ditemukan di dalam cell.
        if let textField = cell?.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("siswaTextField") }) as? NSTextField,
           let imageView = cell?.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("imageView") }) as? NSImageView
        {
            imageView.isHidden = false // Memastikan imageView terlihat.

            // Hapus constraint tinggi bawaan (misalnya: siswaTextField.height == 46)
            if let heightConstraint = textField.constraints.first(where: { $0.firstAttribute == .height }) {
                textField.removeConstraint(heightConstraint)
            }

            // Hapus constraint vertikal (leading, top, bottom) dari cell yang berkaitan dengan textField.
            cell?.constraints.forEach { constraint in
                if let firstItem = constraint.firstItem as? NSView, firstItem == textField,
                   constraint.firstAttribute == .leading ||
                   constraint.firstAttribute == .top ||
                   constraint.firstAttribute == .bottom
                {
                    cell?.removeConstraint(constraint)
                }
            }

            // Tambahkan constraint baru untuk textField
            textField.translatesAutoresizingMaskIntoConstraints = false // Penting untuk Auto Layout.

            if !mapel { // Konfigurasi layout untuk header "Daftar Siswa"
                NSLayoutConstraint.activate([
                    // Batasan leading textField ke trailing imageView dengan jarak 4.
                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                    // Batasan trailing textField ke trailing cell dengan jarak 10 dari kanan.
                    textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -10),
                    // Batasan top textField ke top cell dengan jarak 3.
                    textField.topAnchor.constraint(equalTo: cell!.topAnchor, constant: 3),
                    // Batasan bottom textField ke bottom cell dengan jarak 5 dari bawah.
                    textField.bottomAnchor.constraint(equalTo: cell!.bottomAnchor, constant: -5),
                ])
            } else if mapel { // Konfigurasi layout untuk header "Daftar Mapel"
                // Hapus constraint centerY terkait imageView (jika ada).
                if let centerYConstraint = cell?.constraints.first(where: { constraint in
                    (constraint.firstItem as? NSView) == imageView && constraint.firstAttribute == .centerY
                }) {
                    cell?.removeConstraint(centerYConstraint)
                }

                imageView.translatesAutoresizingMaskIntoConstraints = false // Penting untuk Auto Layout.

                NSLayoutConstraint.activate([
                    // ImageView diatur agar rata bawah dengan cell dengan jarak 4 dari bawah.
                    imageView.bottomAnchor.constraint(equalTo: cell!.bottomAnchor, constant: -4),

                    // TextField diatur agar dimulai setelah imageView dengan jarak 4.
                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                    // Batasan trailing textField ke trailing cell dengan jarak 10 dari kanan.
                    textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -10),
                    // Batasan top textField ke top cell dengan jarak 14 (lebih jauh ke bawah).
                    textField.topAnchor.constraint(equalTo: cell!.topAnchor, constant: 14),
                    // Batasan bottom textField ke bottom cell tanpa jarak.
                    textField.bottomAnchor.constraint(equalTo: cell!.bottomAnchor, constant: 0),
                ])
            }

            // Membuat attributed string untuk judul utama dengan gaya tertentu.
            let attributedString = NSMutableAttributedString(string: "\(title)\n", attributes: [
                .foregroundColor: NSColor.secondaryLabelColor, // Warna teks utama
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold), // Font teks utama
            ])

            var keterangan = "" // String untuk sub-teks deskriptif.

            // Mengatur ikon dan sub-teks berdasarkan judul.
            if title == "Daftar Siswa" {
                imageView.image = NSImage(systemSymbolName: "person.crop.rectangle.stack", accessibilityDescription: .none)
                keterangan = "Nilai per-siswa \(semesterPopUp.titleOfSelectedItem ?? "Semester ini")"
            } else { // Asumsi "Daftar Mapel"
                imageView.image = NSImage(systemSymbolName: "book", accessibilityDescription: .none)
                keterangan = "Nilai per-mapel \(semesterPopUp.titleOfSelectedItem ?? "Semester ini")"
            }

            // Membuat attributed string untuk sub-teks dengan gaya yang berbeda.
            let secondaryAttributedString = NSAttributedString(string: keterangan, attributes: [
                .foregroundColor: NSColor.secondaryLabelColor, // Warna teks sekunder
                .font: NSFont.systemFont(ofSize: 13), // Font teks sekunder
            ])

            // Gabungkan teks utama dan sekunder ke dalam satu attributed string.
            attributedString.append(secondaryAttributedString)

            // Tetapkan attributed string ke NSTextField untuk menampilkan teks dengan gaya kustom.
            textField.attributedStringValue = attributedString
        }
        return cell // Mengembalikan cell yang sudah dikonfigurasi.
    }

    /// Membuat dan mengonfigurasi `NSTableCellView` kustom untuk menampilkan ringkasan siswa (`StudentSummary`).
    ///
    /// Sel ini didesain untuk menampilkan nama siswa, rata-rata nilai, dan total nilai.
    /// Fungsi ini menyembunyikan `imageView` yang mungkin ada dalam sel dan secara dinamis
    /// menyesuaikan batasan (constraints) tata letak `NSTextField` untuk mengakomodasi
    /// dua baris teks dengan gaya yang berbeda. Teks utama menampilkan nomor urut dan nama siswa,
    /// sedangkan teks sekunder menampilkan rata-rata dan total nilai.
    ///
    /// - Parameters:
    ///   - student: Objek `StudentSummary` yang berisi data ringkasan siswa yang akan ditampilkan.
    ///   - rowIndex: `Int` yang menunjukkan indeks baris siswa dalam tabel, digunakan untuk penomoran.
    /// - Returns: Sebuah `NSTableCellView` yang telah dikonfigurasi dengan data siswa,
    ///            atau `nil` jika gagal membuat sel dari `tableview`.
    private func createStudentCell(for student: StudentSummary, at rowIndex: Int) -> NSTableCellView? {
        // Mencoba mendaur ulang atau membuat NSTableCellView dengan identifier "combinedCell".
        let cell = tableview.makeView(withIdentifier: NSUserInterfaceItemIdentifier("combinedCell"), owner: self) as? NSTableCellView

        // Memastikan textField dan imageView berhasil ditemukan di dalam cell.
        if let textField = cell?.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("siswaTextField") }) as? NSTextField,
           let imageView = cell?.subviews.first(where: { $0.identifier?.rawValue == "imageView" }) as? NSImageView
        {
            // Sembunyikan imageView dan hapus gambarnya karena tidak digunakan untuk sel siswa.
            imageView.isHidden = true
            imageView.image = nil

            // Hapus constraint tinggi bawaan (misalnya: siswaTextField.height == 46)
            if let heightConstraint = textField.constraints.first(where: { $0.firstAttribute == .height }) {
                textField.removeConstraint(heightConstraint)
            }

            // Hapus constraint vertikal (leading, top, bottom) dari cell yang berkaitan dengan textField.
            cell?.constraints.forEach { constraint in
                if let firstItem = constraint.firstItem as? NSView, firstItem == textField,
                   constraint.firstAttribute == .leading ||
                   constraint.firstAttribute == .top ||
                   constraint.firstAttribute == .bottom
                {
                    cell?.removeConstraint(constraint)
                }
            }

            // Tambahkan constraint baru untuk textField agar mengisi sebagian besar lebar cell.
            textField.translatesAutoresizingMaskIntoConstraints = false // Penting untuk Auto Layout.
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4), // Jarak dari leading cell.
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -10), // Jarak dari trailing cell.
                textField.topAnchor.constraint(equalTo: cell!.topAnchor, constant: 6), // Jarak dari top cell.
                textField.bottomAnchor.constraint(equalTo: cell!.bottomAnchor, constant: -3), // Jarak dari bottom cell.
            ])

            // Buat teks utama (nomor urut dan nama siswa) dan teks sekunder (rata-rata dan total nilai).
            let mainText = "\(rowIndex). \(student.name)\n"
            let secondaryText = "Rata-rata: \(String(format: "%.2f", student.averageScore))\nJumlah Nilai: \(student.totalScore)"

            // Atur atribut untuk teks utama, termasuk pengaturan pemotongan teks dengan elipsis.
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail // Membatasi teks dengan elipsis jika terlalu panjang.

            let attributedString = NSMutableAttributedString(string: mainText, attributes: [
                .foregroundColor: NSColor.controlTextColor, // Warna teks utama.
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold), // Font teks utama.
                .paragraphStyle: paragraphStyle, // Tambahkan paragraph style.
            ])

            // Batasi lebar menggunakan NSTextContainer (meskipun dalam konteks NSTextField,
            // ini mungkin tidak memiliki efek visual langsung jika tidak diatur dengan NSTextView).
            // Baris-baris ini mungkin tidak diperlukan jika layouting sepenuhnya dikendalikan oleh Auto Layout.
            let textContainer = NSTextContainer(size: CGSize(width: 100, height: 20)) // Batasi width 100
            let layoutManager = NSLayoutManager()
            let textStorage = NSTextStorage(attributedString: attributedString)

            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            textContainer.lineFragmentPadding = 0 // Menghindari padding bawaan

            // Buat attributed string untuk teks sekunder.
            let secondaryAttributedString = NSAttributedString(string: secondaryText, attributes: [
                .foregroundColor: NSColor.controlTextColor, // Warna teks sekunder.
                .font: NSFont.systemFont(ofSize: 13), // Font teks sekunder.
            ])

            // Gabungkan teks utama dan sekunder.
            attributedString.append(secondaryAttributedString)

            // Tetapkan attributed string ke NSTextField untuk menampilkan teks dengan gaya kustom.
            textField.attributedStringValue = attributedString
        }

        return cell // Mengembalikan cell yang sudah dikonfigurasi.
    }

    /// Membuat dan mengonfigurasi `NSTableCellView` kustom untuk menampilkan ringkasan mata pelajaran (`MapelSummary`).
    ///
    /// Sel ini didesain untuk menampilkan nama mata pelajaran, rata-rata nilai, total nilai,
    /// jumlah siswa yang terdaftar, dan nama guru pengampu. Fungsi ini menyembunyikan
    /// `imageView` dan secara dinamis menyesuaikan batasan (constraints) tata letak
    /// `NSTextField` untuk mengakomodasi dua baris teks dengan gaya yang berbeda:
    /// baris pertama untuk nama mata pelajaran, dan baris kedua untuk detail ringkasan lainnya.
    ///
    /// - Parameters:
    ///   - mapel: Objek `MapelSummary` yang berisi data ringkasan mata pelajaran yang akan ditampilkan.
    /// - Returns: Sebuah `NSTableCellView` yang telah dikonfigurasi dengan data mata pelajaran,
    ///            atau `nil` jika gagal membuat sel dari `tableview`.
    private func createMapelCell(for mapel: MapelSummary) -> NSTableCellView? {
        // Mencoba mendaur ulang atau membuat NSTableCellView dengan identifier "combinedCell".
        let cell = tableview.makeView(withIdentifier: NSUserInterfaceItemIdentifier("combinedCell"), owner: self) as? NSTableCellView

        // Memastikan textField dan imageView berhasil ditemukan di dalam cell.
        if let textField = cell?.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("siswaTextField") }) as? NSTextField,
           let imageView = cell?.subviews.first(where: { $0.identifier?.rawValue == "imageView" }) as? NSImageView
        {
            // Sembunyikan imageView dan hapus gambarnya karena tidak digunakan untuk sel mata pelajaran.
            imageView.image = nil
            imageView.isHidden = true

            // Hapus constraint tinggi bawaan (misalnya: siswaTextField.height == 46)
            if let heightConstraint = textField.constraints.first(where: { $0.firstAttribute == .height }) {
                textField.removeConstraint(heightConstraint)
            }

            // Hapus constraint vertikal (leading, top, bottom) dari cell yang berkaitan dengan textField.
            cell?.constraints.forEach { constraint in
                if let firstItem = constraint.firstItem as? NSView, firstItem == textField,
                   constraint.firstAttribute == .leading ||
                   constraint.firstAttribute == .top ||
                   constraint.firstAttribute == .bottom
                {
                    cell?.removeConstraint(constraint)
                }
            }

            // Tambahkan constraint baru untuk textField agar mengisi sebagian besar lebar cell.
            textField.translatesAutoresizingMaskIntoConstraints = false // Penting untuk Auto Layout.
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4), // Jarak dari leading cell.
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -10), // Jarak dari trailing cell.
                textField.topAnchor.constraint(equalTo: cell!.topAnchor, constant: 6), // Jarak dari top cell.
                textField.bottomAnchor.constraint(equalTo: cell!.bottomAnchor, constant: -3), // Jarak dari bottom cell.
            ])

            // Buat teks utama (nama mata pelajaran) dan teks sekunder (detail ringkasan).
            let title = "\(mapel.name)\n"
            let keterangan = "Rata-rata Mapel: \(String(format: "%.2f", mapel.averageScore)), Jumlah Nilai: \(Int(mapel.totalScore))\nSiswa: \(mapel.totalStudents), Guru: \(mapel.namaGuru)"

            // Buat attributed string untuk judul utama dengan gaya yang berbeda.
            let attributedString = NSMutableAttributedString(string: title, attributes: [
                .foregroundColor: NSColor.controlTextColor, // Warna teks utama.
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold), // Font teks utama.
            ])

            // Buat attributed string untuk teks sekunder.
            let secondaryAttributedString = NSAttributedString(string: keterangan, attributes: [
                .foregroundColor: NSColor.controlTextColor, // Warna teks sekunder.
                .font: NSFont.systemFont(ofSize: 13), // Font teks sekunder.
            ])

            // Gabungkan teks utama dan sekunder.
            attributedString.append(secondaryAttributedString)

            // Tetapkan attributed string ke NSTextField untuk menampilkan teks dengan gaya kustom.
            textField.attributedStringValue = attributedString
        }
        return cell // Mengembalikan cell yang sudah dikonfigurasi.
    }
}

extension NilaiKelas: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableview.selectedRow != -1 else { return }
        NSApp.sendAction(#selector(NilaiKelas.updateMenuItem(_:)), to: nil, from: self)
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        // Section headers
        if row == 0 {
            return 40
        } else if row == data.count + 1 {
            return 50
        }
        return 58
    }

    func tableView(_ tableView: NSTableView, toolTipFor cell: NSCell, rect: NSRectPointer, tableColumn: NSTableColumn?, row: Int, mouseLocation: NSPoint) -> String {
        if tableColumn?.identifier.rawValue == "siswa" {
            guard let rowView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView else { return "" }
            return rowView.textField?.stringValue ?? ""
        }
        return ""
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        // Jika baris adalah header cell, jangan izinkan seleksi
        if row == 0 || row == data.count + 1 {
            return false
        }
        return true // Izinkan seleksi untuk baris lain
    }

    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        guard row != 0, row != data.count + 1 else {
            return []
        }
        var oldValue = ""
        var nilaiValue = ""
        var oldValueAttribute = NSMutableAttributedString()
        if edge == .leading {
            let copy = NSTableViewRowAction(style: .regular, title: "Salin Data") { [weak self] rowAction, rowIndex in
                guard let self else { return }
                self.salinRow(IndexSet([row]), header: false)
                guard let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
                      let textField = cell.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("siswaTextField") }) as? NSTextField
                else { return }
                // Subject data section
                let mapelIndex = row - (self.data.count + 2)
                if row <= self.data.count {
                    oldValue = "\(row). \(self.data[row - 1].name)"
                    nilaiValue = "Rata-rata: \(String(format: "%.2f", self.data[row - 1].averageScore))\nJumlah Nilai: \(self.data[row - 1].totalScore)"
                    let firstAttr = NSMutableAttributedString(string: "\(oldValue)\n", attributes: [
                        .foregroundColor: NSColor.controlTextColor,
                        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                    ])
                    let secondAttr = NSMutableAttributedString(string: nilaiValue, attributes: [
                        .foregroundColor: NSColor.controlTextColor,
                        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                    ])

                    firstAttr.append(secondAttr)
                    oldValueAttribute = firstAttr
                } else if mapelIndex < self.mapelData.count {
                    oldValue = "\(self.mapelData[mapelIndex].name)"
                    nilaiValue = "Rata-rata Mapel: \(String(format: "%.2f", self.mapelData[mapelIndex].averageScore)), Jumlah Nilai: \(Int(self.mapelData[mapelIndex].totalScore)), Siswa: \(self.mapelData[mapelIndex].totalStudents), Guru: \(self.mapelData[mapelIndex].namaGuru)"

                    let firstAttr = NSMutableAttributedString(string: "\(oldValue)\n", attributes: [
                        .foregroundColor: NSColor.controlTextColor,
                        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                    ])
                    let secondAttr = NSMutableAttributedString(string: nilaiValue, attributes: [
                        .foregroundColor: NSColor.controlTextColor,
                        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                    ])

                    firstAttr.append(secondAttr)
                    oldValueAttribute = firstAttr
                }
                // Buat teks dengan format
                let mainText = "Nama Berhasil Disalin ✅"
                let secondaryText = "Nilai Berhasil Disalin ✅\n"
                let ThirdText = "Keterangan Berhasil Disalin ✅"
                let attributedString = NSMutableAttributedString(string: "\(mainText)\n", attributes: [
                    .foregroundColor: NSColor.controlTextColor,
                    .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                ])
                let secondaryAttributedString = NSMutableAttributedString(string: secondaryText + ThirdText, attributes: [
                    .foregroundColor: NSColor.controlTextColor,
                    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                ])
                attributedString.append(secondaryAttributedString)
                textField.attributedStringValue = attributedString
                let muatNama = DispatchWorkItem {
                    NSAnimationContext.runAnimationGroup({ context in
                        context.allowsImplicitAnimation = true
                        context.duration = 0.3
                        cell.alphaValue = 0
                    }, completionHandler: {
                        NSAnimationContext.runAnimationGroup { context in
                            context.allowsImplicitAnimation = true
                            context.duration = 0.2
                            cell.alphaValue = 1
                            textField.attributedStringValue = oldValueAttribute
                        }
                    })
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: muatNama)
            }
            copy.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: .none)
            copy.backgroundColor = NSColor.systemBlue
            return [copy]
        } else if edge == .trailing {
            let copy = NSTableViewRowAction(style: .regular, title: "Salin Beserta Kolom") { [weak self] rowAction, rowIndex in
                guard let self else { return }
                self.salinRow(IndexSet([row]), header: true)
                guard let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
                      let textField = cell.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("siswaTextField") }) as? NSTextField
                else { return }
                let mapelIndex = row - (self.data.count + 2)
                if row <= self.data.count {
                    oldValue = "\(row). \(self.data[row - 1].name)"
                    nilaiValue = "Rata-rata: \(String(format: "%.2f", self.data[row - 1].averageScore))\nJumlah Nilai: \(self.data[row - 1].totalScore)"

                    let firstAttr = NSMutableAttributedString(string: "\(oldValue)\n", attributes: [
                        .foregroundColor: NSColor.controlTextColor,
                        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                    ])
                    let secondAttr = NSMutableAttributedString(string: nilaiValue, attributes: [
                        .foregroundColor: NSColor.controlTextColor,
                        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                    ])

                    firstAttr.append(secondAttr)
                    oldValueAttribute = firstAttr

                } else if mapelIndex < self.mapelData.count {
                    oldValue = "\(self.mapelData[mapelIndex].name)"
                    nilaiValue = "Rata-rata Mapel: \(String(format: "%.2f", self.mapelData[mapelIndex].averageScore)), Jumlah Nilai: \(Int(self.mapelData[mapelIndex].totalScore)), Siswa: \(self.mapelData[mapelIndex].totalStudents), Guru: \(self.mapelData[mapelIndex].namaGuru)"

                    let firstAttr = NSMutableAttributedString(string: "\(oldValue)\n", attributes: [
                        .foregroundColor: NSColor.controlTextColor,
                        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                    ])
                    let secondAttr = NSMutableAttributedString(string: nilaiValue, attributes: [
                        .foregroundColor: NSColor.controlTextColor,
                        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                    ])

                    firstAttr.append(secondAttr)
                    oldValueAttribute = firstAttr
                }
                let mainText = "Nama Berhasil Disalin ✅"
                let secondaryText = "Nilai Berhasil Disalin ✅\n"
                let ThirdText = "Keterangan Berhasil Disalin ✅"

                let attributedString = NSMutableAttributedString(string: "\(mainText)\n", attributes: [
                    .foregroundColor: NSColor.controlTextColor,
                    .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                ])
                let secondaryAttributedString = NSMutableAttributedString(string: secondaryText + ThirdText, attributes: [
                    .foregroundColor: NSColor.controlTextColor,
                    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                ])
                attributedString.append(secondaryAttributedString)
                textField.attributedStringValue = attributedString
                let muatNama = DispatchWorkItem {
                    NSAnimationContext.runAnimationGroup({ context in
                        context.allowsImplicitAnimation = true
                        context.duration = 0.3
                        cell.alphaValue = 0
                    }, completionHandler: {
                        NSAnimationContext.runAnimationGroup { context in
                            context.allowsImplicitAnimation = true
                            context.duration = 0.2
                            cell.alphaValue = 1
                            textField.attributedStringValue = oldValueAttribute
                        }
                    })
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: muatNama)
            }
            copy.image = NSImage(systemSymbolName: "tablecells.badge.ellipsis", accessibilityDescription: .none)
            copy.backgroundColor = NSColor.systemGreen
            return [copy]
        }

        return []
    }

    /// Fungsi untuk menyalin data di baris tableView.
    /// - Parameter sender: Objek pemicu dapat berupa apapun.
    @IBAction func copy(_ sender: Any) {
        let isRowSelected = tableview.selectedRowIndexes.count > 0
        if isRowSelected {
            salinRow(tableview.selectedRowIndexes, header: true)
        } else {
            let alert = NSAlert()
            alert.messageText = "Tidak ada baris yang dipilih"
            alert.informativeText = "Pilih salah satu baris untuk menyalin data."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

extension NilaiKelas: NSMenuDelegate {
    /// Dipanggil ketika item menu "Salin" dipilih dari menu konteks `NSTableView`.
    ///
    /// Metode ini menentukan apakah baris yang diklik adalah bagian dari baris yang dipilih.
    /// Jika ya, semua baris yang dipilih akan disalin. Jika tidak, hanya baris yang diklik
    /// yang akan disalin. Fungsi `salinRow` kemudian dipanggil untuk melakukan operasi penyalinan.
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini.
    @objc func salinMenu(_ sender: NSMenuItem) {
        let klikRow = tableview.clickedRow // Baris yang diklik saat menu konteks muncul.
        let rows = tableview.selectedRowIndexes // Indeks baris yang saat ini dipilih.

        // Memeriksa apakah baris yang diklik termasuk dalam set baris yang dipilih.
        if rows.contains(klikRow) {
            // Jika baris yang diklik adalah bagian dari seleksi, salin semua baris yang dipilih.
            salinRow(rows, header: true)
        } else {
            // Jika baris yang diklik bukan bagian dari seleksi, hanya salin baris tersebut.
            salinRow(IndexSet([klikRow]), header: true)
        }
    }

    /// Menyalin data dari baris `NSTableView` yang ditentukan ke papan klip (`NSPasteboard`).
    ///
    /// Fungsi ini mengiterasi melalui indeks baris yang diberikan dan mengekstrak data yang relevan
    /// dari `data` (ringkasan siswa) atau `mapelData` (ringkasan mata pelajaran).
    /// Header kolom opsional dapat ditambahkan di awal setiap bagian data yang disalin.
    /// Data diformat dengan tab (`\t`) sebagai pemisah kolom dan baris baru (`\n`) sebagai pemisah baris,
    /// membuatnya cocok untuk ditempelkan ke aplikasi spreadsheet.
    ///
    /// - Parameters:
    ///   - row: `IndexSet` yang berisi indeks baris yang akan disalin.
    ///   - header: `Bool` yang menunjukkan apakah header kolom harus disertakan dalam data yang disalin.
    func salinRow(_ row: IndexSet, header: Bool) {
        var copiedData = "" // String untuk menyimpan data yang akan disalin.
        var isHeader1Added = false // Flag untuk memastikan header siswa hanya ditambahkan sekali.
        var isHeader2Added = false // Flag untuk memastikan header mata pelajaran hanya ditambahkan sekali.

        for index in row {
            // Menentukan asal data berdasarkan indeks baris.
            // Baris indeks 1 hingga `data.count` adalah data siswa (setelah header pertama).
            if index > 0, index <= data.count {
                // Menambahkan header "Daftar Siswa" jika belum ditambahkan dan `header` adalah true.
                if !isHeader1Added, header {
                    copiedData += "Daftar Siswa\tNilai Rata-rata\tJumlah Nilai"
                    isHeader1Added = true
                }
                // Mengambil item siswa dan memformatnya.
                let item = data[index - 1] // Index dikurangi 1 karena baris 0 adalah header.
                let dataToCopy = "\(item.name)\t\(ReusableFunc.formatNumber(item.averageScore))\t\(item.totalScore)"
                // Menambahkan data ke `copiedData`, menambahkan baris baru jika bukan data pertama.
                copiedData += copiedData.isEmpty ? dataToCopy : "\n" + dataToCopy
            } else if index > data.count + 1 { // Baris setelah data siswa dan header kedua.
                // Menghitung indeks relatif untuk `mapelData`.
                let mapelIndex = index - data.count - 2 // Index dikurangi untuk melewati header kedua.
                if mapelIndex < mapelData.count {
                    // Menambahkan header "Rata-rata Per Mata Pelajaran" jika belum ditambahkan dan `header` adalah true.
                    if !isHeader2Added, header {
                        copiedData += "\n\nRata-rata Per Mata Pelajaran\tRata-rata Nilai\tTotal Nilai\tJumlah Siswa"
                        isHeader2Added = true
                    }
                    // Mengambil item mata pelajaran dan memformatnya.
                    let item = mapelData[mapelIndex]
                    let dataToCopy = "\(item.name)\t\(ReusableFunc.formatNumber(item.averageScore))\t\(Int(item.totalScore))\t\(item.totalStudents)"
                    // Menambahkan data ke `copiedData`, menambahkan baris baru jika bukan data pertama.
                    copiedData += copiedData.isEmpty ? dataToCopy : "\n" + dataToCopy
                }
            }
        }

        // Tambahkan baris baru di akhir jika ada data yang disalin, untuk memastikan format yang benar.
        if !copiedData.isEmpty {
            copiedData += "\n"
        }

        // Menyalin `copiedData` ke papan klip umum (`NSPasteboard.general`).
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil) // Mendeklarasikan tipe data yang akan disalin.
        pasteboard.setString(copiedData, forType: .string) // Menetapkan string ke papan klip.
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let klikRow = tableview.clickedRow
        if klikRow == 0 || klikRow == data.count + 1 {
            return
        }
        // let rows = tableview.selectedRowIndexes
        guard klikRow != -1 else { return }
        let copy = NSMenuItem(title: "Salin", action: #selector(salinMenu(_:)), keyEquivalent: "")
        menu.addItem(copy)
        tableview.menu = menu
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        NotificationCenter.default.post(name: .popupDismissedKelas, object: nil)
    }
}

extension NilaiKelas: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow {
            // Cari kelasID yang sesuai dan hapus dari dictionary
            AppDelegate.shared.openedKelasWindows = AppDelegate.shared.openedKelasWindows.filter { $0.value != closedWindow }
        }
    }
}

extension NilaiKelas {
    /// Menyimpan data siswa dan mata pelajaran ke dalam file CSV.
    ///
    /// Fungsi ini mengambil ringkasan data siswa (`StudentSummary`) dan data mata pelajaran (`mapelData`),
    /// kemudian mengonversinya menjadi format CSV. Data akan dipisahkan oleh tanda titik koma (`;`)
    /// dan setiap baris diakhiri dengan karakter baris baru (`\n`). Header kolom untuk siswa dan
    /// mata pelajaran akan disertakan. File CSV akan ditulis ke `destinationURL` yang ditentukan.
    ///
    /// - Parameters:
    ///   - header: Array `String` yang berisi header kolom untuk data siswa.
    ///   - siswaData: Array `StudentSummary` yang berisi ringkasan data siswa.
    ///   - destinationURL: `URL` tempat file CSV akan disimpan.
    /// - Throws: `Error` jika terjadi masalah saat menulis data ke file.
    func saveToCSV(header: [String], siswaData: [StudentSummary], destinationURL: URL) throws {
        let siswaRows = siswaData.map { [$0.name, ReusableFunc.formatNumber($0.averageScore), String($0.totalScore)] }

        // Menambahkan header untuk data mapel
        let separator = ["", "", "", ""]
        let mapelHeader = ["Mata Pelajaran", "Rata-rata Nilai", "Jumlah Nilai", "Nama Guru"]
        // Menggabungkan data mapel
        let mapelRows = mapelData.map { [$0.name, ReusableFunc.formatNumber($0.averageScore), ReusableFunc.formatNumber(Double($0.totalScore)), $0.namaGuru] }

        // Menggabungkan semua baris menjadi satu
        let allRows = (siswaRows + [separator] + [mapelHeader] + mapelRows)
        // Menggabungkan header dengan data dan mengubahnya menjadi string CSV
        let csvString = ([header] + allRows).map { $0.joined(separator: ";") }.joined(separator: "\n")

        // Menulis string CSV ke file
        try csvString.write(to: destinationURL, atomically: true, encoding: .utf8)

        // print("File CSV berhasil disimpan di: \(destinationURL.path)")
    }

    /// Merespons aksi pengguna untuk mengekspor data ke format Excel (melalui konversi CSV ke Excel menggunakan Python/Pandas).
    ///
    /// Sebelum memulai proses ekspor, fungsi ini memeriksa apakah ada jendela aktif untuk memastikan data kelas telah disiapkan.
    /// Jika tidak ada jendela aktif, sebuah peringatan akan ditampilkan. Jika ada, ia memanggil `ReusableFunc.checkPythonAndPandasInstallation`
    /// untuk memverifikasi ketersediaan Python dan Pandas yang diperlukan untuk konversi.
    ///
    /// Jika Python dan Pandas terinstal, data siswa dan mata pelajaran (`self.data` dan `self.mapelData`) akan
    /// disiapkan, dan `chooseFolderAndSaveCSV` akan dipanggil untuk menyimpan data sebagai CSV sementara
    /// dan kemudian mengonversinya menjadi Excel.
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini.
    @IBAction func exportToExcel(_ sender: NSMenuItem) {
        guard view.window != nil else {
            let alert = NSAlert()
            alert.messageText = "Peringatan"
            alert.informativeText = "Pilih kelas di \"Kelas Aktif\" terlebih dahulu untuk menyiapkan data kelas."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        ReusableFunc.checkPythonAndPandasInstallation(window: self.view.window!) { [weak self] isInstalled, progressWindow, pythonFound in
            if let self, isInstalled {
                let data = self.data
                self.chooseFolderAndSaveCSV(header: ["Nama Siswa", "Rata-rata Nilai", "Jumlah Nilai", "Nama Guru"], siswaData: data, namaFile: "Data \(self.semesterPopUp.titleOfSelectedItem ?? "") \(self.namaKelas.capitalizeFirstLetterOfWords())", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: false)
            } else {
                    DispatchQueue.main.async {
                        if let self {
                            self.view.window!.endSheet(progressWindow!)
                    }
                }
            }
        }
    }

    /// Merespons aksi pengguna untuk mengekspor data ke format PDF.
    ///
    /// Sebelum memulai proses ekspor, fungsi ini memeriksa apakah ada jendela aktif untuk memastikan data kelas telah disiapkan.
    /// Jika tidak ada jendela aktif, sebuah peringatan akan ditampilkan. Jika ada, ia memanggil `ReusableFunc.checkPythonAndPandasInstallation`
    /// untuk memverifikasi ketersediaan Python dan Pandas yang diperlukan untuk konversi.
    ///
    /// Jika Python dan Pandas terinstal, data siswa dan mata pelajaran (`self.data` dan `self.mapelData`) akan
    /// disiapkan, dan `chooseFolderAndSaveCSV` akan dipanggil untuk menyimpan data sebagai CSV sementara
    /// dan kemudian mengonversinya menjadi PDF.
    ///
    /// - Parameter sender: `NSMenuItem` yang memicu aksi ini.
    @IBAction func exportToPDF(_ sender: NSMenuItem) {
        guard view.window != nil else {
            let alert = NSAlert()
            alert.messageText = "Peringatan"
            alert.informativeText = "Pilih kelas di \"Kelas Aktif\" terlebih dahulu untuk menyiapkan data kelas."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        ReusableFunc.checkPythonAndPandasInstallation(window: self.view.window!) { [weak self] isInstalled, progressWindow, pythonFound in
            if let self, isInstalled {
                let data = self.data
                self.chooseFolderAndSaveCSV(header: ["Nama Siswa", "Rata-rata Nilai", "Jumlah Nilai", "Nama Guru"], siswaData: data, namaFile: "Data \(self.semesterPopUp.titleOfSelectedItem ?? "") \(self.namaKelas.capitalizeFirstLetterOfWords())", window: self.view.window!, sheetWindow: progressWindow, pythonPath: pythonFound!, pdf: true)
            } else {
                // print("Instalasi dibatalkan atau gagal.")
                if let self {
                    self.view.window!.endSheet(progressWindow!)
                }
            }
        }
    }

    /// Memilih folder penyimpanan, menyimpan data ke CSV, dan mengonversinya ke format yang diinginkan (Excel atau PDF).
    ///
    /// Fungsi ini pertama-tama menentukan lokasi sementara untuk menyimpan file CSV di direktori dukungan aplikasi.
    /// Kemudian, ia memanggil `saveToCSV` untuk menulis data siswa dan mata pelajaran ke file CSV.
    /// Setelah itu, jika `pdf` adalah `true`, ia akan menjalankan skrip Python untuk mengonversi CSV ke PDF.
    /// Jika `pdf` adalah `false`, ia akan menjalankan skrip Python untuk mengonversi CSV ke XLSX (Excel).
    /// Setelah konversi, pengguna akan diminta untuk menyimpan file hasil konversi ke lokasi yang dipilih.
    ///
    /// - Parameters:
    ///   - header: Array `String` yang berisi header kolom untuk data siswa.
    ///   - siswaData: Array `StudentSummary` yang berisi ringkasan data siswa.
    ///   - namaFile: `String` yang akan digunakan sebagai nama dasar untuk file CSV dan file hasil konversi.
    ///   - window: `NSWindow` induk tempat sheet akan ditampilkan.
    ///   - sheetWindow: `NSWindow` sheet yang menampilkan progres instalasi Python/Pandas.
    ///   - pythonPath: `String` opsional yang berisi jalur ke executable Python.
    ///   - pdf: `Bool` yang menunjukkan apakah konversi harus dilakukan ke PDF (`true`) atau XLSX (`false`).
    func chooseFolderAndSaveCSV(header: [String], siswaData: [StudentSummary], namaFile: String, window: NSWindow?, sheetWindow: NSWindow?, pythonPath: String?, pdf: Bool) {
        // Tentukan lokasi untuk menyimpan file CSV di folder aplikasi
        let csvFileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(namaFile).csv")
        do {
            if pdf {
                try saveToCSV(header: header, siswaData: siswaData, destinationURL: csvFileURL)
                ReusableFunc.runPythonScriptPDF(csvFileURL: csvFileURL, window: window!, pythonPath: pythonPath, completion: { xlsxFileURL in
                    // Setelah konversi ke XLSX selesai, tanyakan pengguna untuk menyimpan file XLSX
                    ReusableFunc.promptToSaveXLSXFile(from: xlsxFileURL!, previousFileName: namaFile, window: window, sheetWindow: sheetWindow, pdf: true)
                })
            } else {
                try saveToCSV(header: header, siswaData: siswaData, destinationURL: csvFileURL)
                ReusableFunc.runPythonScript(csvFileURL: csvFileURL, window: window!, pythonPath: pythonPath, completion: { xlsxFileURL in
                    // Setelah konversi ke XLSX selesai, tanyakan pengguna untuk menyimpan file XLSX
                    ReusableFunc.promptToSaveXLSXFile(from: xlsxFileURL!, previousFileName: namaFile, window: window, sheetWindow: sheetWindow, pdf: false)
                })
            }
        } catch {
            // print("Terjadi kesalahan saat menyimpan CSV: \(error.localizedDescription)")
            self.view.window!.endSheet(sheetWindow!)
        }
    }
}
