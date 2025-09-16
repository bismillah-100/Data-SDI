//
//  AddTeacherRoles.swift
//  Data SDI
//
//  Created by Bismillah on 03/10/24.
//

import Cocoa

/// Class yang menangani input jabatan guru untuk mata pelajaran dan kelas tertentu
/// di ``AddDetaildiKelas``.
class AddTeacherRoles: NSViewController {
    var onJabatanSelected: (([String: String]) -> Void)?
    /// Outlet scrollView yang memuat ``TeacherRoleView`` untuk menampilkan nama-nama nama guru.
    @IBOutlet weak var scrollView: NSScrollView!
    /// Outlet tombol "simpan".
    @IBOutlet weak var saveButton: NSButton!
    /// Outlet tombol "tutup".
    @IBOutlet weak var tutupButton: NSButton!
    /// Outlet root view. View yang digunakan ``AddTeacherRoles``.
    @IBOutlet var contentView: NSView!
    /// Outlet tombol dengan label ketika textField ``TeacherRoleView/jabatanTextField`` belum diisi.
    @IBOutlet weak var alertTextField: NSButton!
    /// Outline title jendela.
    @IBOutlet weak var windowTitle: NSTextField!
    /// Leading constraint pesan warning.
    @IBOutlet weak var leadingConstraint: NSLayoutConstraint!

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
         Setiap elemen dalam array ini adalah instance dari `TeacherRoleView`.
     */
    var mapelViews: [TeacherRoleView] = []

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

        alertTextField.isHidden = true
        windowTitle.stringValue = "Masukkan struktur guru"
    }

    /**
        Memuat data guru dan membuat tampilan yang sesuai.

        - Parameter daftarGuru: Array tuple yang berisi data guru. Setiap tuple terdiri dari nama guru (String) dan jabatan (String).
     */
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
         Membuat dan menata tampilan untuk setiap guru yang akan ditambahkan jabatan.

         Fungsi ini secara dinamis menghasilkan tampilan ``TeacherRoleView`` untuk setiap entri data guru,
         menambahkannya ke ``contentView``, dan menata letaknya menggunakan `NSLayoutConstraint`. Fungsi ini juga
         menangani penambahan garis pemisah antara setiap tampilan guru dan memastikan bahwa tata letak
         secara dinamis menyesuaikan dengan guru yang ada.

         - Parameter: Tidak ada. Fungsi ini menggunakan properti ``guruData`` untuk menghasilkan tampilan.

         Proses:
         1.  Menghapus semua subview yang ada dari ``contentView`` dan mengosongkan array ``mapelViews`` untuk memulai dengan tampilan yang bersih.
         2.  Mengurutkan data mata pelajaran berdasarkan nama mata pelajaran untuk memastikan urutan tampilan yang konsisten.
         3.  Membuat instance ``TeacherRoleView`` untuk setiap guru dalam ``guruData`` dan menambahkannya ke ``contentView``,
             dan mengaktifkan constraint tata letak untuk memposisikannya dengan benar.
         4.  Menambahkan ``LineView`` sebagai pemisah visual antara setiap ``TeacherRoleView``, kecuali yang terakhir.
         5.  Menghitung tinggi total yang dibutuhkan untuk semua tampilan mata pelajaran dan pemisah, memastikan bahwa tinggi minimum
             dipertahankan bahkan jika hanya ada satu mata pelajaran.
         6.  Menyesuaikan tinggi ``scrollView`` dan ``contentView`` berdasarkan tinggi total yang dihitung dan tinggi maksimum yang diizinkan.
         7.  Mengatur constraint untuk ``scrollView`` untuk memastikan posisinya yang benar dalam tampilan induk.
         8.  Memperbarui tinggi tampilan induk untuk mengakomodasi ``scrollView`` dan padding yang sesuai.
         9.  Menggulir ``scrollView`` ke bagian bawah dan memicu pembaruan tata letak.

         Catatan:
         -   ``TeacherRoleView`` adalah tampilan khusus yang menampilkan informasi mata pelajaran dan memungkinkan pengeditan.
         -   ``LineView`` adalah tampilan sederhana yang digunakan sebagai garis pemisah.
         -   Constraint tata letak digunakan untuk memastikan bahwa tampilan diposisikan dan diukur dengan benar dalam ``scrollView``.
     */
    func createMapelViews() {
        // Clear existing subviews
        contentView.subviews.forEach { $0.removeFromSuperview() }
        mapelViews.removeAll()

        // Pilih source data dan total count
        let source: [(title: String, subtitle: String)] = guruData

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

    /// Menambahkan dan mengatur tampilan ``TeacherRoleView`` secara dinamis ke dalam ``contentView``.
    ///
    /// Fungsi ini digunakan untuk membuat tampilan edit mapel dan guru berdasarkan data yang diberikan.
    /// Setiap tampilan akan diatur posisinya menggunakan Auto Layout, dan jika bukan item terakhir,
    /// akan ditambahkan garis pemisah (``LineView``) di bawahnya.
    ///
    /// - Parameters:
    ///   - index: Indeks dari item saat ini dalam iterasi. Digunakan untuk menentukan posisi dan constraint.
    ///   - title: Nama mata pelajaran yang akan ditampilkan di ``TeacherRoleView``.
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
        let mapelView = TeacherRoleView(title: title, subtitle: subtitle)
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

    /// Action untuk tombol ``tutupButton``. Digunakan untuk menutup tampilan ``TeacherRoleView``.
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
     Menangani aksi saat tombol simpan diklik. Fungsi ini melakukan iterasi melalui setiap ``TeacherRoleView`` untuk mendapatkan data mata pelajaran dan guru yang telah diperbarui.
     Data yang diperbarui kemudian dikemas ulang dan dikirim melalui `NotificationCenter` untuk memberitahu komponen lain dalam aplikasi tentang perubahan tersebut.
     Selain itu, fungsi ini juga menangani penambahan guru baru ke daftar guru jika opsi yang sesuai diaktifkan.

     - Parameter sender: Objek yang mengirim aksi (tombol simpan).
     */
    @IBAction func saveButtonClicked(_: Any) {
        var guru2jabatan: [String: String] = [:]

        for mapelView in mapelViews {
            let namaGuru = mapelView.getMapelName()
            let namaJabatan = mapelView.getGuruName()
            guard !namaJabatan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                alertTextField.isHidden = false
                alertTextField.title = " Isi semua struktur dengan benar."

                ReusableFunc.vibrateWithConstraint(view: alertTextField, constraint: leadingConstraint, originalConstant: 18)
                return
            }
            guru2jabatan[namaGuru] = namaJabatan
        }

        // Kirim notifikasi / gunakan delegate / continuation
        onJabatanSelected?(guru2jabatan)
        dismiss(nil)
    }

    /**
         Fungsi ini digunakan untuk mengubah setiap kata pada `stringValue` dari `jabatanTextField` di setiap ``mapelViews`` menjadi huruf kapital di awal kata.

         - Parameter sender: Objek yang memicu aksi ini.
     */
    @IBAction func kapitalkan(_: Any) {
        for view in mapelViews {
            view.jabatanTextField.stringValue = view.jabatanTextField.stringValue.capitalized
        }
    }

    /**
     Mengubah semua teks pada `jabatanTextField` di setiap ``mapelViews`` menjadi huruf besar.

     Fungsi ini melakukan iterasi pada setiap ``mapelViews`` dan mengubah nilai string pada `jabatanTextField` menjadi huruf besar menggunakan fungsi `uppercased()`.
     */
    @IBAction func hurufBesar(_: Any) {
        for view in mapelViews {
            view.jabatanTextField.stringValue = view.jabatanTextField.stringValue.uppercased()
        }
    }
}

/// Class untuk view setiap data guru di ``AddTeacherRoles``.
class TeacherRoleView: NSView {
    /// Outlet label yang digunakan untuk memuat nama mata pelajaran.
    @IBOutlet var guruLabel: NSTextField!
    /// Outlet input untuk pengetikan nama guru di suatu mata pelajaran tertentu.
    @IBOutlet var jabatanTextField: NSTextField!

    /// Instance ``SuggestionManager``.
    var suggestionManager: SuggestionManager!
    /// Properti untuk `NSTextField` yang sedang aktif menerima pengetikan.
    var activeText: NSTextField!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    /**
         Inisialisasi tampilan untuk mengedit data mata pelajaran.

         - Parameter mapel: Nama mata pelajaran yang akan ditampilkan sebagai label.
         - Parameter guru: Nama guru yang akan ditampilkan di text field.
     */
    init(title: String, subtitle: String) {
        guruLabel = NSTextField(labelWithString: title)
        jabatanTextField = NSTextField(string: subtitle)
        jabatanTextField.placeholderString = "sebagai..."
        super.init(frame: .zero)
        setupViews()
    }

    /**
         Inisialisasi tampilan AddTeacherRoles dari sebuah pengkode.

         - Parameter coder: Sebuah objek NSCoder yang berisi informasi yang dibutuhkan untuk menginisialisasi tampilan.

         Inisialisasi properti `guruLabel` dan `jabatanTextField` dengan objek `NSTextField` baru. Memanggil inisialisasi superclass dan mengatur `wantsLayer` menjadi `true` untuk mengaktifkan dukungan layer. Mengatur warna latar belakang layer menjadi transparan dan memanggil `setupViews()` untuk mengatur tampilan antarmuka pengguna.
     */
    required init?(coder: NSCoder) {
        guruLabel = NSTextField()
        jabatanTextField = NSTextField()
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = .clear
        setupViews()
    }

    /**
         Menyiapkan tampilan untuk AddTeacherRoles, termasuk label mata pelajaran dan text field guru.

         Fungsi ini melakukan inisialisasi dan konfigurasi elemen-elemen UI,
         menambahkan constraint layout untuk mengatur posisi dan ukuran elemen-elemen tersebut di dalam view.

         - Note: Fungsi ini juga mengatur delegate untuk jabatanTextField dan menginisialisasi SuggestionManager.
     */
    func setupViews() {
        guruLabel.translatesAutoresizingMaskIntoConstraints = false
        jabatanTextField.translatesAutoresizingMaskIntoConstraints = false
        jabatanTextField.bezelStyle = .roundedBezel
        addSubview(guruLabel)
        addSubview(jabatanTextField)
        jabatanTextField.delegate = self
        suggestionManager = SuggestionManager(suggestions: [""])
        guruLabel.widthAnchor.constraint(equalToConstant: 250).isActive = true

        NSLayoutConstraint.activate([
            guruLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            guruLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            jabatanTextField.leadingAnchor.constraint(equalTo: guruLabel.trailingAnchor, constant: 4),
            jabatanTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            jabatanTextField.centerYAnchor.constraint(equalTo: centerYAnchor),
            jabatanTextField.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    /**
         Mengembalikan nama mata pelajaran dari tampilan.

         - Returns: String yang berisi nama mata pelajaran.
     */
    func getMapelName() -> String {
        guruLabel.stringValue
    }

    /**
         Mengembalikan nama guru dari `textField`.

         - Returns: `String` yang berisi nama guru.
     */
    func getGuruName() -> String {
        jabatanTextField.stringValue
    }
}

extension TeacherRoleView: NSTextFieldDelegate {
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
        let suggestionsDict = [jabatanTextField: Array(ReusableFunc.jabatan)]

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

    func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
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
