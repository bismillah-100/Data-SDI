//
//  EditMapel.swift
//  Data SDI
//
//  Created by Bismillah on 03/10/24.
//

import Cocoa

/// Class yang menangani pengeditan nama guru untuk mata pelajaran tertentu
/// di ``KelasVC``.
class EditMapel: NSViewController {
    var onJabatanSelected: (([String: String]) -> Void)?
    /// Outlet scrollView yang memuat ``MapelEditView`` untuk menampilkan nama-nama mata pelajaran dan nama guru.
    @IBOutlet weak var scrollView: NSScrollView!
    /// Outlet tombol "simpan".
    @IBOutlet weak var saveButton: NSButton!
    /// Outlet tombol "tutup".
    @IBOutlet weak var tutupButton: NSButton!
    /// Outlet root view. View yang digunakan ``EditMapel``.
    @IBOutlet var contentView: NSView!
    /// Outlet tombol pilihan untuk menyimpan data baru ke daftar guru.
    @IBOutlet weak var tambahDaftarGuru: NSButton!
    /// Outline title jendela.
    @IBOutlet weak var windowTitle: NSTextField!
    /// Leading constraint pesan warning.
    @IBOutlet weak var leadingConstraint: NSLayoutConstraint!

    /// Opsi ketika ``EditMapel`` digunakan untuk menambah struktur guru
    /// sehingga bisa menyesuaikan konten yang ditampilkan.
    var tambahStrukturGuru: Bool = false

    /// Menyimpan data guru dalam bentuk pasangan `title` dan `subtitle`.
    ///
    /// Properti ini digunakan untuk menampilkan informasi guru, seperti nama dan detail tambahan.
    /// Biasanya digunakan sebagai sumber data untuk tampilan UI seperti daftar, popover, atau tabel.
    ///
    /// - `title`: Nama atau label utama dari guru (misalnya nama lengkap).
    /// - `subtitle`: Informasi tambahan seperti mata pelajaran, jabatan, atau kontak.
    ///
    /// Contoh:
    /// ```swift
    /// guruData = [
    ///     (title: "Ibu Sari", subtitle: "Guru Kelas"),
    ///     (title: "Pak Budi", subtitle: "Wali Kelas")
    /// ]
    /// ```
    var guruData: [(title: String, subtitle: String)] = []

    /**
         Array yang menyimpan tampilan edit untuk setiap mata pelajaran.
         Setiap elemen dalam array ini adalah instance dari `MapelEditView`.
     */
    var mapelViews: [MapelEditView] = []

    /// Berisi data mata pelajaran yang akan ditampilkan dan diubah dalam tampilan.
    ///
    /// Setiap elemen dalam array adalah tuple yang berisi:
    ///   - Nama mata pelajaran (String)
    ///   - ID mata pelajaran (String)
    ///   - Tipe tabel yang terkait dengan mata pelajaran (TableType)
    var mapelData: [(String, String, TableType)] = []

    private let spacing: CGFloat = 8
    private let mapelViewHeight: CGFloat = 30
    private let lineHeight: CGFloat = 1
    private let maxHeight: CGFloat = 302
    private let bottomPadding: CGFloat = 42
    private let topPadding: CGFloat = 42 // Sudah didefinisikan

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
    }

    override func viewDidAppear() {
        if let sheetWindow = view.window {
            // Menonaktifkan kemampuan untuk memperbesar ukuran sheet
            sheetWindow.styleMask.remove(.resizable)
        }

        if tambahStrukturGuru {
            tambahDaftarGuru.isHidden = true
            windowTitle.stringValue = "Masukkan struktur guru"
            return
        }
    }

//    /**
//         Memuat data mata pelajaran dan membuat tampilan yang sesuai.
//
//         - Parameter mapelData: Array tuple yang berisi data mata pelajaran. Setiap tuple terdiri dari nama mata pelajaran (String), nilai (String), dan tipe tabel (TableType).
//     */
//    func loadMapelData(mapelData: [(String, String, TableType)]) {
//        self.mapelData = mapelData
//        createMapelViews()
//    }

    func loadGuruData(daftarGuru: [(String, String)]) {
        guruData = daftarGuru
        createMapelViews()
    }

    /**
         Mengatur tampilan scroll view dan content view di dalamnya.

         Fungsi ini menginisialisasi scroll view dan content view, mengatur constraint untuk memastikan scroll view mengisi seluruh tampilan,
         dan content view menyesuaikan dengan lebar scroll view. Selain itu, fungsi ini menambahkan constraint untuk memastikan
         tinggi minimum scroll view adalah 50 poin. Constraint tinggi yang sudah ada akan dihapus sebelum menambahkan yang baru.
     */
    func setupScrollView() {
        scrollView.documentView = contentView

        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.widthAnchor.constraint(equalTo: view.widthAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // Remove existing height constraint if any
        if let existingHeightConstraint = scrollView.constraints.first(where: { $0.firstAttribute == .height }) {
            scrollView.removeConstraint(existingHeightConstraint)
        }

        // Add constraint to limit minimum height of scrollView
        let minHeightConstraint = scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        minHeightConstraint.priority = .required
        minHeightConstraint.isActive = true
    }

    /**
         Membuat dan menata tampilan untuk setiap mata pelajaran (Mapel) yang dapat diedit.

         Fungsi ini secara dinamis menghasilkan tampilan ``MapelEditView`` untuk setiap entri data mata pelajaran,
         menambahkannya ke ``contentView``, dan menata letaknya menggunakan `NSLayoutConstraint`. Fungsi ini juga
         menangani penambahan garis pemisah antara setiap tampilan mata pelajaran atau guru dan memastikan bahwa tata letak
         secara dinamis menyesuaikan dengan jumlah mata pelajaran atau guru yang ada.

         - Parameter: Tidak ada. Fungsi ini menggunakan properti ``mapelData`` untuk menghasilkan tampilan.

         Proses:
         1.  Menghapus semua subview yang ada dari ``contentView`` dan mengosongkan array ``mapelViews`` untuk memulai dengan tampilan yang bersih.
         2.  Mengurutkan data mata pelajaran berdasarkan nama mata pelajaran untuk memastikan urutan tampilan yang konsisten.
         3.  Membuat instance ``MapelEditView`` untuk setiap mata pelajaran dalam ``mapelData``
             atau untuk setiap guru dalam ``guruData`` dan menambahkannya ke ``contentView``,
             dan mengaktifkan constraint tata letak untuk memposisikannya dengan benar.
         4.  Menambahkan ``LineView`` sebagai pemisah visual antara setiap ``MapelEditView``, kecuali yang terakhir.
         5.  Menghitung tinggi total yang dibutuhkan untuk semua tampilan mata pelajaran dan pemisah, memastikan bahwa tinggi minimum
             dipertahankan bahkan jika hanya ada satu mata pelajaran.
         6.  Menyesuaikan tinggi ``scrollView`` dan ``contentView`` berdasarkan tinggi total yang dihitung dan tinggi maksimum yang diizinkan.
         7.  Mengatur constraint untuk ``scrollView`` untuk memastikan posisinya yang benar dalam tampilan induk.
         8.  Memperbarui tinggi tampilan induk untuk mengakomodasi ``scrollView`` dan padding yang sesuai.
         9.  Menggulir ``scrollView`` ke bagian bawah dan memicu pembaruan tata letak.

         Catatan:
         -   ``MapelEditView`` adalah tampilan khusus yang menampilkan informasi mata pelajaran dan memungkinkan pengeditan.
         -   ``LineView`` adalah tampilan sederhana yang digunakan sebagai garis pemisah.
         -   Constraint tata letak digunakan untuk memastikan bahwa tampilan diposisikan dan diukur dengan benar dalam ``scrollView``.
     */
    func createMapelViews() {
        // Clear existing subviews
        contentView.subviews.forEach { $0.removeFromSuperview() }
        mapelViews.removeAll()

        // Pilih source data dan total count
        let source: [(title: String, subtitle: String)]
        if !tambahStrukturGuru {
            source = mapelData.map { ($0.0, $0.1) } // (mapel, guru)
        } else {
            source = guruData
        }
        let total = source.count

        // 3. Loop dan layout
        var bottomView: NSView? = nil
        for (index, item) in source.enumerated() {
            loopMapelEditView(index: index,
                              title: item.title,
                              subtitle: item.subtitle,
                              isLast: index == total - 1, data: source,
                              bottomView: &bottomView)
        }

        // Calculate total height with minimum height for single item
        let totalItemSpacing = CGFloat(max(1, source.count - 1)) * (spacing * 2 + lineHeight)
        let totalMapelViewsHeight = CGFloat(source.count) * mapelViewHeight
        let totalHeight = max(
            mapelViewHeight + (spacing * 2), // Minimum height for single item
            totalMapelViewsHeight + totalItemSpacing + (spacing * 2)
        )

        // Set up scrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = totalHeight > maxHeight

        // Update heights
        let newHeight = min(totalHeight, maxHeight)
        contentView.frame.size.height = totalHeight

        // ScrollView constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: topPadding),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -bottomPadding),
        ])

        // Update view height - ensure minimum height when single item
        let finalViewHeight = newHeight + bottomPadding + topPadding
        view.frame.size.height = finalViewHeight

        // Update scroll view
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollView.documentView?.bounds.height ?? 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        view.layoutSubtreeIfNeeded()
    }

    /// Menambahkan dan mengatur tampilan `MapelEditView` secara dinamis ke dalam `contentView`.
    ///
    /// Fungsi ini digunakan untuk membuat tampilan edit mapel dan guru berdasarkan data yang diberikan.
    /// Setiap tampilan akan diatur posisinya menggunakan Auto Layout, dan jika bukan item terakhir,
    /// akan ditambahkan garis pemisah (`LineView`) di bawahnya.
    ///
    /// - Parameters:
    ///   - index: Indeks dari item saat ini dalam iterasi. Digunakan untuk menentukan posisi dan constraint.
    ///   - title: Nama mata pelajaran yang akan ditampilkan di `MapelEditView`.
    ///   - subtitle: Nama guru yang terkait dengan mata pelajaran.
    ///   - isLast: Boolean yang menunjukkan apakah item ini adalah item terakhir dalam daftar.
    ///   - data: Array data sumber yang digunakan untuk menentukan jumlah total item dan posisi.
    ///   - bottomView: Referensi ke view terakhir yang ditambahkan sebelumnya, digunakan untuk menentukan posisi vertikal. Akan diperbarui dengan view baru yang ditambahkan.
    private func loopMapelEditView(
        index: Int,
        title: String,
        subtitle: String,
        isLast _: Bool,
        data: [Any],
        bottomView: inout NSView?
    ) {
        let mapelView = MapelEditView(mapel: title, guru: subtitle, tambahStrukturGuru: tambahStrukturGuru)
        mapelViews.append(mapelView)

        contentView.addSubview(mapelView)
        mapelView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mapelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 9),
            mapelView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            mapelView.heightAnchor.constraint(equalToConstant: mapelViewHeight),
            mapelView.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -8),
        ])

        // Constraint untuk first MapelView
        if index == 0 {
            mapelView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: spacing).isActive = true
        } else {
            if let view = bottomView {
                mapelView.topAnchor.constraint(equalTo: view.bottomAnchor, constant: spacing).isActive = true
            }
        }

        bottomView = mapelView

        // Tambahkan line view jika bukan item terakhir
        if index < data.count - 1 {
            let lineView = LineView()
            contentView.addSubview(lineView)
            lineView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                lineView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                lineView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                lineView.topAnchor.constraint(equalTo: mapelView.bottomAnchor, constant: spacing),
                lineView.heightAnchor.constraint(equalToConstant: lineHeight),
            ])

            bottomView = lineView
        }

        // Pastikan bottom constraint selalu diset untuk setiap MapelView
        if index == data.count - 1 {
            mapelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -spacing).isActive = true
        }
    }

    /// Action untuk tombol ``tutupButton``. Digunakan untuk menutup tampilan ``MapelEditView``.
    @IBAction func tutup(_ sender: Any) {
        if let window = view.window {
            if let sheetParent = window.sheetParent {
                // If the window is a sheet, end the sheet
                sheetParent.endSheet(window, returnCode: .cancel)
            } else {
                // If the window is not a sheet, perform the close action
                window.performClose(sender)
            }
        }
    }

    /**
     Menangani aksi saat tombol simpan diklik. Fungsi ini melakukan iterasi melalui setiap `MapelEditView` untuk mendapatkan data mata pelajaran dan guru yang telah diperbarui.
     Data yang diperbarui kemudian dikemas ulang dan dikirim melalui `NotificationCenter` untuk memberitahu komponen lain dalam aplikasi tentang perubahan tersebut.
     Selain itu, fungsi ini juga menangani penambahan guru baru ke daftar guru jika opsi yang sesuai diaktifkan.

     - Parameter sender: Objek yang mengirim aksi (tombol simpan).
     */
    @IBAction func saveButtonClicked(_ sender: Any) {
        var guru2jabatan: [String: String] = [:]

        for mapelView in mapelViews {
            let namaGuru = mapelView.getMapelName()
            let namaJabatan = mapelView.getGuruName()
            guard !namaJabatan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                tambahDaftarGuru.isHidden = false
                tambahDaftarGuru.title = " Isi semua struktur dengan benar."

                ReusableFunc.vibrateWithConstraint(view: tambahDaftarGuru, constraint: leadingConstraint, originalConstant: 18)
                return
            }
            guru2jabatan[namaGuru] = namaJabatan
        }

        // Kirim notifikasi / gunakan delegate / continuation
        onJabatanSelected?(guru2jabatan)
        dismiss(nil)
//        // Siapkan array untuk menampung data mapel dan guru yang baru
//        var updatedMapelData: [(String, String, String, TableType)] = [] // Tambah variabel untuk guru lama
//
//        // Loop melalui setiap MapelEditView untuk mendapatkan data yang baru
//        for mapelView in mapelViews {
//            let updatedMapel = mapelView.getMapelName()
//            let updatedGuru = mapelView.getGuruName()
//
//            // Cari tipe tabel dan nama guru lama dari mapelData yang asli
//            if let originalData = mapelData.first(where: { $0.0 == updatedMapel }) {
//                let tableType = originalData.2
//                let oldGuru = originalData.1 // Nama guru lama
//                updatedMapelData.append((updatedMapel, updatedGuru, oldGuru, tableType))
//            }
//        }
//
//        // Repack data untuk dikirim dalam notifikasi, termasuk nama guru lama
//        let repackedMapelData = updatedMapelData.map { ["mapel": $0.0, "guruBaru": $0.1, "guruLama": $0.2, "tipeTabel": $0.3] }
//        // Mencatat nama guru baru jika belum tercatat di Daftar Guru
//        if tambahDaftarGuru.state == .on {
//            let dbController = DatabaseController.shared
//            for (_, element) in repackedMapelData.enumerated() {
//                // let tahunIni = Calendar.current.component(.year, from: Date())
//                if let guru = element["guruBaru"] as? String, let mapel = element["mapel"] as? String {
//                    Task {
//                        let guruID = await dbController.insertOrGetGuruID(nama: guru)
//                    }
//                }
//            }
//        }
        // Kirim notifikasi dengan data mapel dan guru yang diperbarui serta guru lama
//        NotificationCenter.default.post(
//            name: NSNotification.Name(rawValue: "updateGuruMapel"),
//            object: nil,
//            userInfo: ["mapelData": repackedMapelData]
//        )
        dismiss(nil)
    }

    /**
         Fungsi ini digunakan untuk mengubah setiap kata pada `stringValue` dari `guruTextField` di setiap `mapelViews` menjadi huruf kapital di awal kata.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func kapitalkan(_ sender: Any) {
        for view in mapelViews {
            view.guruTextField.stringValue = view.guruTextField.stringValue.capitalized
        }
    }

    /**
     Mengubah semua teks pada `guruTextField` di setiap `mapelViews` menjadi huruf besar.

     Fungsi ini melakukan iterasi pada setiap `mapelViews` dan mengubah nilai string pada `guruTextField` menjadi huruf besar menggunakan fungsi `uppercased()`.
     */
    @IBAction func hurufBesar(_ sender: Any) {
        for view in mapelViews {
            view.guruTextField.stringValue = view.guruTextField.stringValue.uppercased()
        }
    }
}

class MapelEditView: NSView {
    /// Outlet label yang digunakan untuk memuat nama mata pelajaran.
    @IBOutlet var mapelLabel: NSTextField!
    /// Outlet input untuk pengetikan nama guru di suatu mata pelajaran tertentu.
    @IBOutlet var guruTextField: NSTextField!

    /// Instans ``SuggestionManager``.
    var suggestionManager: SuggestionManager!
    /// Properti untuk `NSTextField` yang sedang aktif menerima pengetikan.
    var activeText: NSTextField!

    var tambahStrukturGuru: Bool = false

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    /**
         Inisialisasi tampilan untuk mengedit data mata pelajaran.

         - Parameter mapel: Nama mata pelajaran yang akan ditampilkan sebagai label.
         - Parameter guru: Nama guru yang akan ditampilkan di text field.
     */
    init(mapel: String, guru: String, tambahStrukturGuru: Bool? = false) {
        mapelLabel = NSTextField(labelWithString: mapel)
        guruTextField = NSTextField(string: guru)
        if tambahStrukturGuru == false {
            guruTextField.placeholderString = "Nama Guru \(mapel)"
        } else {
            guruTextField.placeholderString = "sebagai..."
            self.tambahStrukturGuru = tambahStrukturGuru!
        }
        super.init(frame: .zero)
        setupViews()
    }

    /**
         Inisialisasi tampilan EditMapel dari sebuah pengkode.

         - Parameter coder: Sebuah objek NSCoder yang berisi informasi yang dibutuhkan untuk menginisialisasi tampilan.

         Inisialisasi properti `mapelLabel` dan `guruTextField` dengan objek `NSTextField` baru. Memanggil inisialisasi superclass dan mengatur `wantsLayer` menjadi `true` untuk mengaktifkan dukungan layer. Mengatur warna latar belakang layer menjadi transparan dan memanggil `setupViews()` untuk mengatur tampilan antarmuka pengguna.
     */
    required init?(coder: NSCoder) {
        mapelLabel = NSTextField()
        guruTextField = NSTextField()
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = .clear
        setupViews()
    }

    /**
         Menyiapkan tampilan untuk EditMapel, termasuk label mata pelajaran dan text field guru.

         Fungsi ini melakukan inisialisasi dan konfigurasi elemen-elemen UI,
         menambahkan constraint layout untuk mengatur posisi dan ukuran elemen-elemen tersebut di dalam view.

         - Note: Fungsi ini juga mengatur delegate untuk guruTextField dan menginisialisasi SuggestionManager.
     */
    func setupViews() {
        mapelLabel.translatesAutoresizingMaskIntoConstraints = false
        guruTextField.translatesAutoresizingMaskIntoConstraints = false
        guruTextField.bezelStyle = .roundedBezel
        addSubview(mapelLabel)
        addSubview(guruTextField)
        guruTextField.delegate = self
        suggestionManager = SuggestionManager(suggestions: [""])
        if tambahStrukturGuru {
            mapelLabel.widthAnchor.constraint(equalToConstant: 250).isActive = true
        } else {
            mapelLabel.widthAnchor.constraint(equalToConstant: 150).isActive = true
        }

        NSLayoutConstraint.activate([
            mapelLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            mapelLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            guruTextField.leadingAnchor.constraint(equalTo: mapelLabel.trailingAnchor, constant: 4),
            guruTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            guruTextField.centerYAnchor.constraint(equalTo: centerYAnchor),
            guruTextField.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    /**
         Mengembalikan nama mata pelajaran dari tampilan.

         - Returns: String yang berisi nama mata pelajaran.
     */
    func getMapelName() -> String {
        mapelLabel.stringValue
    }

    /**
         Mengembalikan nama guru dari `textField`.

         - Returns: `String` yang berisi nama guru.
     */
    func getGuruName() -> String {
        guruTextField.stringValue
    }
}

extension MapelEditView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        textField.stringValue = textField.stringValue.capitalizedAndTrimmed()
        if !suggestionManager.isHidden {
            suggestionManager.hideSuggestions()
        }
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        activeText = obj.object as? NSTextField
        let suggestionsDict = tambahStrukturGuru
            ? [guruTextField: Array(ReusableFunc.jabatan)]
            : [guruTextField: Array(ReusableFunc.namaguru)]

        if let activeTextField = obj.object as? NSTextField {
            suggestionManager.suggestions = suggestionsDict[activeTextField] ?? []
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return }
        if let activeTextField = obj.object as? NSTextField {
            // Get the current input text
            let currentText = activeTextField.stringValue

            // Find the last word (after the last space)
            if let lastSpaceIndex = currentText.lastIndex(of: " ") {
                let startIndex = currentText.index(after: lastSpaceIndex)
                let lastWord = String(currentText[startIndex...])

                // Update the text field with only the last word
                suggestionManager.typing = lastWord

            } else {
                suggestionManager.typing = activeText.stringValue
            }
        }
        if activeText?.stringValue.isEmpty == true {
            suggestionManager.hideSuggestions()
        } else {
            suggestionManager.controlTextDidChange(obj)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard UserDefaults.standard.bool(forKey: "showSuggestions") else { return false }
        if !suggestionManager.suggestionWindow.isVisible {
            return false
        }
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)):
            suggestionManager.moveUp()
            return true
        case #selector(NSResponder.moveDown(_:)):
            suggestionManager.moveDown()
            return true
        case #selector(NSResponder.insertNewline(_:)):
            suggestionManager.enterSuggestions()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            suggestionManager.hideSuggestions()
            return true
        case #selector(NSResponder.insertTab(_:)):
            suggestionManager.hideSuggestions()
            return false
        default:
            return false
        }
    }
}
