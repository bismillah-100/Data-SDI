//
//  Public Functions.swift
//  Data SDI
//
//  Created by Bismillah on 28/09/24.
//

import Cocoa
import UniformTypeIdentifiers

/// Sebuah kelas pembungkus (`wrapper class`) generik untuk sebuah array.
///
/// Kelas ini menyediakan referensi ke sebuah array, memungkinkannya untuk dibagikan dan dimodifikasi
/// di antara beberapa bagian kode yang memerlukan perilaku referensi (bukan *copy-by-value*).
/// Ini sangat berguna dalam skenario di mana array perlu diperbarui oleh beberapa *closure* atau
/// ketika dilewatkan ke fungsi yang memerlukan modifikasi *in-place* tanpa harus mengembalikan
/// array yang dimodifikasi secara eksplisit.
///
/// Penggunaan utama:
/// - Memungkinkan modifikasi array dalam *closure* atau konteks asinkron di mana array asli
///   tidak dapat langsung ditangkap sebagai `inout` atau diubah oleh penangkapan nilai (`value capture`).
/// - Berbagi array antar objek tanpa menyalin seluruh konten array.
///
/// - Generic Parameter `T`: Tipe elemen yang disimpan dalam array.
public final class ArrayWrapper<T> {
    /// Array yang dibungkus oleh kelas ini.
    /// Properti ini dapat diakses dan dimodifikasi secara langsung.
    var array: [T]

    /// Menginisialisasi `ArrayWrapper` baru dengan array yang diberikan.
    ///
    /// - Parameter array: Array awal yang akan dibungkus.
    init(_ array: [T]) {
        self.array = array
    }
}

/// Fungsi-fungsi yang berguna agar bisa digunakan oleh class lain tanpa membuat fungsi baru.
public class ReusableFunc {
    /// Digunakan untuk menyimpan data autokomplesi umum yang akan ditampilkan kepada pengguna.
    public static var autoCompletionData: [AutoCompletion] = []
    
    /// Digunakan untuk menyimpan data autokomplesi spesifik entitas (misalnya, nama siswa, alamat, dll.).
    public static var autoCompletionEntity: [AutoCompletion] = []
    
    /// Properti untuk prediksi ketik nama siswa yang terdaftar.
    public static var namasiswa: Set<String> = []
    
    /// Properti untuk prediksi ketik alamat yang terkait dengan data siswa atau entitas lainnya.
    public static var alamat: Set<String> = []
    
    /// Properti untuk prediksi ketik nama ayah siswa.
    public static var namaAyah: Set<String> = []
    
    /// Properti untuk prediksi ketik nama ibu siswa.
    public static var namaIbu: Set<String> = []
    
    /// Properti untuk prediksi ketik nama wali siswa.
    public static var namawali: Set<String> = []
    
    /// Properti untuk prediksi ketik Nomor Induk Siswa (NIS).
    public static var nis: Set<String> = []
    
    /// Properti untuk prediksi ketik Nomor Induk Siswa Nasional (NISN).
    public static var nisn: Set<String> = []
    
    /// Properti untuk prediksi ketik nomor telepon atau string terkait kontak lainnya.
    public static var tlvString: Set<String> = []
    
    /// Properti untuk prediksi ketik tempat dan tanggal lahir.
    public static var ttl: Set<String> = []
    
    /// Properti untuk prediksi ketik nama mata pelajaran.
    public static var mapel: Set<String> = []
    
    /// Properti untuk prediksi ketik nama guru.
    public static var namaguru: Set<String> = []
    
    /// Properti untuk prediksi ketik data semester.
    public static var semester: Set<String> = []
    
    /// Properti untuk prediksi ketik kategori.
    public static var kategori: Set<String> = []
    
    /// Properti untuk prediksi ketik nama acara atau kegiatan.
    public static var acara: Set<String> = []
    
    /// Properti untuk prediksi ketik keperluan.
    public static var keperluan: Set<String> = []
    
    /// Properti untuk prediksi ketik nama jabatan atau posisi.
    public static var jabatan: Set<String> = []

    /// Informasi kolom di tabel kelas yang digunakan di KelasVC dan DetailSiswaViewController
    public static let columnInfos: [ColumnInfo] = [
        ColumnInfo(identifier: "namasiswa", customTitle: "Nama Siswa"),
        ColumnInfo(identifier: "mapel", customTitle: "Mata Pelajaran"),
        ColumnInfo(identifier: "nilai", customTitle: "Nilai"),
        ColumnInfo(identifier: "semester", customTitle: "Semester"),
        ColumnInfo(identifier: "namaguru", customTitle: "Nama Guru"),
        ColumnInfo(identifier: "tgl", customTitle: "Tanggal Dicatat"),
    ]

    /// OperationQueue
    static let operationQueue = OperationQueue()

    /// Gambar silang "x"
    static let stopProgressImage = NSImage(named: NSImage.stopProgressFreestandingTemplateName)
    
    /// Gambar centang "✔︎"
    static let menuOnStateImage = NSImage(named: NSImage.menuOnStateTemplateName)

    /// Gambar awan dengan tanda centang, diatur di class SplitVC
    public static var cloudCheckMark = NSImage()
    
    /// Gambar awan dengan tanda panah ke atas, diatur di class SplitVC
    public static var cloudArrowUp = NSImage()
    
    /// konfigurasi symbol dengan ukuran besar
    public static let largeSymbolConfiguration = NSImage.SymbolConfiguration(scale: .large)

    /// Properti yang digunakan untuk menampilkan jendela pemuatan data
    public static var progressWindowController: NSWindowController?
    
    /// Properti yang digunakan untuk menampilkan jendela overlay notifikasi
    public static var alertWindowController: NSWindowController?
    
    /// WorkItem untuk penutupan jendela overlay notifikasi
    static var closeAlertWorkItem: DispatchWorkItem?

    /// Referensi global untuk db_controller(pengelola database siswa/inventaris/guru)
    static var dbController: DatabaseController!

    /// Untuk label ketika memproses file excel/pdf
    static var progress = ""
    
    /// Properti warna yang digunakan di setiap chart. Berisi enam warna berbeda sesuai kelas.
    public static let classColors: [NSColor] = [
        NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.6, alpha: 1.0), // Warna hijau yang lebih terang
        NSColor(calibratedRed: 246.0 / 255.0, green: 161.0 / 255.0, blue: 81.0 / 255.0, alpha: 1.0), // Warna kuning yang lebih pekat
        NSColor(red: 66.0 / 255.0, green: 133.0 / 255.0, blue: 244.0 / 255.0, alpha: 1.0), // Warna biru yang lebih terang
        NSColor(calibratedRed: 0.8, green: 0.6, blue: 1.0, alpha: 1.0), // Warna ungu yang lebih terang
        NSColor(red: 0.8, green: 0.5, blue: 0.6, alpha: 1.0), // Warna merah muda yang lebih terang
        NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0), // Warna abu-abu yang lebih terang
    ]
    
    private static var totalSize: String? // Total ukuran file

    //// Fungsi untuk memperbarui prediksi ketik untuk data Siswa, Guru, dan Inventaris.
    public static func updateSuggestions() {
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .utility
        operationQueue.addOperation {
            autoCompletionData = DatabaseController.shared.getAllDataForAutoCompletion()
            var namaSet: Set<String> = []
            var alamatSet: Set<String> = []
            var ayahSet: Set<String> = []
            var ibuSet: Set<String> = []
            var waliSet: Set<String> = []
            var ttlSet: Set<String> = []
            var tlvSet: Set<String> = []
            var nisnSet: Set<String> = []
            var nisSet: Set<String> = []
            var mapelSet: Set<String> = []
            var namaGuruSet: Set<String> = []
            var semesterSet: Set<String> = []
            var jabatanSet: Set<String> = []
            // Menambahkan kata-kata dari nama siswa dan alamat, serta versi lengkapnya
            for data in ReusableFunc.autoCompletionData {
                // Memisahkan kata untuk namasiswa dan menambahkan versi lengkap
                let namaWords = data.namasiswa.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                namaSet.formUnion(namaWords) // Menambahkan semua kata
                namaSet.insert(data.namasiswa.trimmingCharacters(in: .whitespacesAndNewlines)) // Menambahkan string utuh

                // Memisahkan kata untuk alamat dan menambahkan versi lengkap
                let alamatWords = data.alamat.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                alamatSet.formUnion(alamatWords) // Menambahkan semua kata
                alamatSet.insert(data.alamat) // Menambahkan string utuh

                let ayahWords = data.ayah.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                ayahSet.formUnion(ayahWords)
                ayahSet.insert(data.ayah)

                let ibuWords = data.ibu.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                ibuSet.formUnion(ibuWords)
                ibuSet.insert(data.ibu)

                let waliWords = data.wali.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                waliSet.formUnion(waliWords)
                waliSet.insert(data.wali)

                let ttlWords = data.tanggallahir.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                ttlSet.formUnion(ttlWords)
                ttlSet.insert(data.tanggallahir)

                let tlvWords = data.tlv.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                ttlSet.formUnion(tlvWords)
                tlvSet.insert(data.tlv)

                let nisWords = data.nis.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                nisSet.formUnion(nisWords)
                nisSet.insert(data.nis)

                let nisnWords = data.nisn.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                nisnSet.formUnion(nisnWords)
                nisnSet.insert(data.nisn)

                let mapelWords = data.mapel.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                mapelSet.formUnion(mapelWords)
                mapelSet.insert(data.mapel)

                // MARK: GURU

                let namaGuruWords = data.namaguru.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                namaGuruSet.formUnion(namaGuruWords)
                namaGuruSet.insert(data.namaguru)

                let semesterWords = data.semester.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                semesterSet.formUnion(semesterWords)
                semesterSet.insert(data.semester)

                let jabatanWords = data.jabatan.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                jabatanSet.formUnion(jabatanWords)
                jabatanSet.insert(data.jabatan)
            }
            // Mengonversi Set ke variabel yang sesuai
            ReusableFunc.namasiswa = Set(namaSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            ReusableFunc.alamat = Set(alamatSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            ReusableFunc.namaAyah = Set(ayahSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            ReusableFunc.namaIbu = Set(ibuSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            ReusableFunc.namawali = Set(waliSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            ReusableFunc.ttl = Set(ttlSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            ReusableFunc.nis = Set(nisSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            ReusableFunc.nisn = Set(nisnSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            ReusableFunc.tlvString = Set(tlvSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            ReusableFunc.mapel = Set(mapelSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            ReusableFunc.namaguru = Set(namaGuruSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            ReusableFunc.semester = Set(semesterSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
            ReusableFunc.jabatan = Set(jabatanSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
        }
    }

    /// Fungsi untuk memperbarui prediksi ketik untuk data Administrasi
    public static func updateSuggestionsEntity() {
        autoCompletionEntity = DataManager.shared.getEntityForAutoCompletion()
        DispatchQueue.global(qos: .background).async {
            var kategoriSet: Set<String> = []
            var acaraSet: Set<String> = []
            var keperluanSet: Set<String> = []
            for data in ReusableFunc.autoCompletionEntity {
                let kategoriWords = data.kategori.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                kategoriSet.formUnion(kategoriWords)
                kategoriSet.insert(data.kategori)

                let acaraWords = data.acara.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                acaraSet.formUnion(acaraWords)
                acaraSet.insert(data.acara)

                let keperluanWords = data.keperluan.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && ($0.count > 2 || ($0.count > 1 && $0.first!.isLetter)) }
                keperluanSet.formUnion(keperluanWords)
                keperluanSet.insert(data.keperluan)
            }
            ReusableFunc.kategori = Set(kategoriSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
            ReusableFunc.keperluan = Set(keperluanSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
            ReusableFunc.acara = Set(acaraSet.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        }
    }

    /// Membangun ulang menu header (context menu) untuk `NSTableView` berdasarkan urutan kolom yang sedang tampil.
    ///
    /// Fungsi ini membuat menu kontekstual baru yang muncul saat pengguna mengklik kanan pada header `NSTableView`.
    /// Setiap item menu mewakili sebuah kolom dan memungkinkan pengguna untuk menyembunyikan atau menampilkan kolom tersebut.
    /// Urutan item menu akan mencerminkan urutan kolom yang saat ini terlihat di tabel.
    ///
    /// - Parameters:
    ///   - tableView: `NSTableView` yang ingin diperbarui menu headernya.
    ///   - tableColumns: Array dari `NSTableColumn` yang saat ini ada di `tableView`. Fungsi ini akan mengiterasi array ini untuk membangun menu.
    ///   - exceptions: Array `String` yang berisi `identifier` kolom yang **tidak** ingin dimasukkan ke dalam menu. Kolom-kolom ini akan diabaikan.
    ///   - target: Objek target yang akan menerima aksi (selector) ketika item menu diklik. Biasanya adalah `NSViewController` atau `NSWindowController`.
    ///   - selector: `Selector` (metode) yang akan dipanggil ketika item menu diklik. Metode ini harus memiliki tanda tangan yang sesuai, biasanya `(sender: Any?)`.
    static func updateColumnMenu(_ tableView: NSTableView, tableColumns: [NSTableColumn], exceptions: [String], target: AnyObject, selector: Selector) {
        // Hapus menu item sebelumnya
        let headerMenu = NSMenu()
        var addedIdentifiers: Set<String> = [] // gunakan Set untuk mencegah duplikasi

        // Iterasi kolom sesuai urutan tampilan saat ini
        for column in tableColumns {
            // Abaikan kolom dengan identifier "Nama" atau yang sudah ditambahkan
            let identifier = column.identifier.rawValue
            if !exceptions.contains(identifier),
               !addedIdentifiers.contains(identifier)
            {
                let menuItem = NSMenuItem(title: column.title, action: selector, keyEquivalent: "")
                menuItem.representedObject = column
                menuItem.target = target // assign target ke objek yang memiliki method tujuan
                menuItem.state = column.isHidden ? .off : .on

                let smallFont = NSFont.menuFont(ofSize: NSFont.systemFontSize(for: .small))
                menuItem.attributedTitle = NSAttributedString(string: column.title,
                                                              attributes: [.font: smallFont])
                headerMenu.addItem(menuItem)
                addedIdentifiers.insert(identifier)
            }
        }
        tableView.headerView?.menu = headerMenu
    }

    /// Mengubah ukuran (`resize`) sebuah gambar `NSImage` ke ukuran target sambil mempertahankan aspek rasio (aspect ratio).
    ///
    /// Fungsi ini menghitung faktor skala yang paling sesuai berdasarkan lebar dan tinggi target,
    /// lalu membuat gambar baru dengan ukuran yang diskalakan secara proporsional.
    /// Gambar hasil tidak akan memiliki area transparan tambahan jika aspek rasionya berbeda.
    ///
    /// - Parameters:
    ///   - image: `NSImage` asli yang ingin diubah ukurannya.
    ///   - to targetSize: `NSSize` yang menentukan ukuran maksimum (lebar dan tinggi) yang diinginkan untuk gambar hasil.
    /// - Returns: `NSImage` baru yang sudah diubah ukurannya sesuai dengan `targetSize` dan mempertahankan aspek rasio. Mengembalikan `nil` jika ada masalah selama proses.
    public static func resizeImage(image: NSImage, to targetSize: NSSize) -> NSImage? {
        let imageSize = image.size

        // Hitung aspect ratio
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height

        // Gunakan ratio terkecil untuk mempertahankan aspect ratio
        let scalingFactor = min(widthRatio, heightRatio)

        // Hitung ukuran baru dengan aspect ratio yang dipertahankan
        let scaledWidth = imageSize.width * scalingFactor
        let scaledHeight = imageSize.height * scalingFactor
        let newSize = NSSize(width: scaledWidth, height: scaledHeight)

        // Buat image baru dengan ukuran yang telah di-resize
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()

        // Gambar image yang di-scale tanpa menambahkan background transparan
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: imageSize),
                   operation: .copy,
                   fraction: 1.0)

        newImage.unlockFocus()

        return newImage
    }

    /// Fungsi untuk membuka Window Rincian Siswa yang menampilkan hanya data dari satu siswa saja.
    /// - Parameters:
    ///   - siswa: Kumpulan siswa dalam Array Model Siswa yang akan dibuka dalam jendela baru
    ///   - viewController: ViewController yang berinteraksi untuk membuka rincian siswa. ini akan diset sebagai delegasi penutupan jendela rincian siswa.
    static func bukaRincianSiswa(_ siswa: [ModelSiswa], viewController: NSViewController) {
        var lastWindowFrame: NSRect?
        for windowController in AppDelegate.shared.openedSiswaWindows.values {
            if let frame = windowController.window?.frame {
                lastWindowFrame = frame
            }
        }
        var baseFrame: NSRect?
        var workItems: [DispatchWorkItem] = []
        for (index, selectedSiswa) in siswa.enumerated() {
            let siswaID = selectedSiswa.id

            // Cek jika jendela detail untuk siswa ini sudah dibuka
            if let existingWindow = AppDelegate.shared.openedSiswaWindows[siswaID]?.window {
                existingWindow.makeKeyAndOrderFront(nil)
                continue
            }

            let workItem = DispatchWorkItem {
                let detailSiswaController = DetailSiswaController(nibName: "DetailSiswa", bundle: nil)
                let detailWindowController = DetilWindow(contentViewController: detailSiswaController)
                detailSiswaController.siswa = selectedSiswa
                if viewController is KelasVC, let kelasVC = viewController as? KelasVC {
                    detailWindowController.closeWindow = kelasVC
                } else if viewController is SiswaViewController, let siswaVC = viewController as? SiswaViewController {
                    detailWindowController.closeWindow = siswaVC
                }
                detailWindowController.windowDidLoad()
                detailWindowController.showWindow(nil)
                detailWindowController.closeWindowDelegate = detailSiswaController

                // Simpan jendela dalam dictionary
                AppDelegate.shared.openedSiswaWindows[siswaID] = detailWindowController

                // Gunakan frame yang disimpan untuk jendela pertama
                if index == 0, lastWindowFrame == nil {
                    baseFrame = detailWindowController.loadWindowData()?.frame ?? NSRect(x: 910, y: 400, width: 500, height: 500)
                } else if let lastFrame = lastWindowFrame {
                    let newOrigin = NSPoint(x: lastFrame.origin.x + 20, y: lastFrame.origin.y - 20)
                    detailWindowController.window?.setFrameOrigin(newOrigin)
                    lastWindowFrame = detailWindowController.window?.frame
                    return
                }

                // Atur posisi window
                detailWindowController.adjustWindowPosition(baseFrame: baseFrame, offsetMultiplier: index)

                // Simpan frame pertama ke UserDefaults
                if index == 0, let frame = detailWindowController.window?.frame {
                    detailWindowController.windowData = WindowData(frame: frame, position: frame.origin)
                    detailWindowController.saveWindowData()
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3, execute: workItem)
            workItems.append(workItem)
        }
    }

    /// Fungsi untuk mereset menuBar menut items seperti; ⌘+N/Z/⌫ dll.
    @objc public static func resetMenuItems() {
        guard let mainMenu = NSApp.mainMenu,
              let editMenuItem = mainMenu.item(withTitle: "Edit"),
              let editMenu = editMenuItem.submenu,
              let undoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "undo" }),
              let redoMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "redo" }),
              let copyMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "copy" }),
              let pasteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "paste" }),
              let deleteMenuItem = editMenu.items.first(where: { $0.identifier?.rawValue == "hapus" }),
              let fileMenu = mainMenu.item(withTitle: "File"),
              let fileMenuItem = fileMenu.submenu,
              let new = fileMenuItem.items.first(where: { $0.identifier?.rawValue == "new" })
        else {
            return
        }

        // set target dan action ke nilai aslinya
        pasteMenuItem.target = SingletonData.originalPasteTarget
        pasteMenuItem.action = SingletonData.originalPasteAction
        copyMenuItem.target = SingletonData.originalCopyTarget
        copyMenuItem.action = SingletonData.originalCopyAction
        undoMenuItem.target = SingletonData.originalUndoTarget
        undoMenuItem.action = SingletonData.originalUndoAction
        redoMenuItem.target = SingletonData.originalRedoTarget
        redoMenuItem.action = SingletonData.originalRedoAction
        deleteMenuItem.target = SingletonData.originalDeleteTarget
        deleteMenuItem.action = SingletonData.originalDeleteAction
        new.target = SingletonData.originalNewTarget
        new.action = SingletonData.originalNewAction
    }

    // MARK: - Window Progress Init Data

    /// Fungsi untuk membuka jendela ketika salah satu view di Sidebar pertama kali ditampilkan. Yaitu ketika view sedang memproses pemuatan data dari Data Base.
    /// - Parameters:
    ///   - view: view yang akan bertindak sebagai induk untuk jendela yang akan ditambahkan sebagai child window.
    ///   - isDataLoaded: sebenarnya tidak perlu, hanya untuk memeriksa apakah data sudah dimuat. namun sudah diatur di dalam ViewController yang menampilkannya.
    public static func showProgressWindow(_ view: NSView, isDataLoaded: Bool) {
        if let existingController = progressWindowController, let window = existingController.window {
            // Menghapus window sebagai child window
            if let parentWindow = window.parent {
                parentWindow.removeChildWindow(window)
                #if DEBUG
                    print("child window cleared from showProgressWindow")
                #endif
                existingController.window?.close()
            }
        }

        // Muat view controller dari XIB, bukan Storyboard
        let progressVC = InitProgress(nibName: "InitProgress", bundle: nil)
        progressVC.loadView()
        progressVC.view.wantsLayer = true
        progressVC.view.layer?.cornerRadius = 10.0
        guard let window = progressVC.view.window else { return }
        window.backingType = .buffered
        window.level = .normal
        window.hasShadow = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = true

        // Menampilkan sebagai jendela modal
        progressWindowController = NSWindowController(window: window)
        if let data = UserDefaults.standard.data(forKey: "WindowFrame"),
           let rectValue = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: data)
        {
            let frame = rectValue.rectValue

            // Mengatur posisi jendela di tengah frame yang dimuat
            let parentWindowFrame = frame
            let windowWidth = window.frame.width
            let windowHeight = window.frame.height
            let newOriginX = parentWindowFrame.origin.x + (parentWindowFrame.width - windowWidth) / 2
            let newOriginY = parentWindowFrame.origin.y + (parentWindowFrame.height - windowHeight) / 2
            window.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))
        } else {
            if let parentWindow = view.window {
                progressWindowController?.window?.center() // Pusatkan ke layar
                progressWindowController?.window?.setFrameOrigin(NSPoint(x: parentWindow.frame.midX - window.frame.width / 2, y: parentWindow.frame.midY - window.frame.height / 2))
            }
        }
        view.window?.addChildWindow(window, ordered: .above)
    }
    /// Fungsi untuk menutup jendela progress pemuatan atau pembaruan data ``progressWindowController``.
    /// - Parameter parentWindow: Jendela induk (`NSWindow`) tempat jendela progres ditampilkan sebagai child window.
    public static func closeProgressWindow(_ parentWindow: NSWindow) {
        guard let window = progressWindowController?.window else { return }
        // Atur NSAnimationContext untuk fade out
        NSAnimationContext.runAnimationGroup({ context in
            // Durasi animasi fade out
            context.duration = 0.5
            // Kurangi alpha value ke 0 (transparent)
            window.animator().alphaValue = 0
        }) {
            // Menghapus window sebagai child window
            parentWindow.removeChildWindow(window)
            #if DEBUG
                print("child window cleared")
            #endif
            // Setelah animasi selesai, tutup window
            progressWindowController?.close()
            // Pastikan referensi ke progressWindowController dihapus
            progressWindowController = nil
        }
    }

    // MARK: - WINDOW OVERLAY NOTIFIKASI

    /// Untuk membuka jendela ``alertWindowController`` dengan delay penutupan yang bisa disesuaikan.
    /// - Parameters:
    ///   - closeAfterDelayInSeconds: Penundaan waktu untuk menutup jendela setelah jendela dibuka.
    ///   - pesan: Pesan yang ditampilkan di dalam jendela overlay.
    ///   - image: NSImage yang digunakan untuk ditampilkan di atas pesan.
    public static func showProgressWindow(_ closeAfterDelayInSeconds: Int, pesan: String, image: NSImage) {
        closeAlertWorkItem?.cancel()
        closeAlertWorkItem = DispatchWorkItem {
            ReusableFunc.closeProgressWindow()
        }
        ReusableFunc.showProgressWindow(pesan: pesan, image: image)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(closeAfterDelayInSeconds), execute: closeAlertWorkItem!)
    }

    /// Membuka Jendela Notifikasi untuk Progress Perubahan Data/Pengaturan.
    ///
    /// Fungsi ini menampilkan overlay jendela kustom dengan pesan dan gambar untuk memberikan notifikasi progres kepada pengguna.
    /// Ini ideal untuk menunjukkan aktivitas seperti penyimpanan data, perubahan pengaturan, atau proses latar belakang singkat lainnya.
    /// Jendela akan muncul di atas jendela aplikasi utama atau terkait dengan tampilan tertentu.
    /// Jika ada jendela notifikasi serupa yang sedang aktif, itu akan ditutup terlebih dahulu sebelum yang baru ditampilkan.
    ///
    /// - Parameters:
    ///   - view: NSView opsional yang menjadi parent atau acuan posisi jendela notifikasi. Jika `nil`, jendela akan muncul sebagai jendela independen di tengah layar utama.
    ///   - pesan: `String` yang berisi teks notifikasi untuk pengguna (misalnya, "Data berhasil disimpan", "Pengaturan sedang diperbarui...", "Memproses perubahan...").
    ///   - image: `NSImage` yang akan ditampilkan di jendela notifikasi, biasanya sebagai ikon status (misalnya, ikon centang untuk sukses, ikon putar untuk sedang proses).
    public static func showProgressWindow(_ view: NSView? = nil, pesan: String, image: NSImage) {
        if let existingController = alertWindowController {
            if let window = existingController.window {
                // Menghapus window sebagai child window
                if let parentWindow = window.parent {
                    parentWindow.removeChildWindow(window)
                    #if DEBUG
                        print("child window cleared from showProgressWindow")
                    #endif
                }
            }
            existingController.window?.close()
        }
        let progressVC = AlertWindow(nibName: "AlertWindow", bundle: nil)
        progressVC.loadView()
        progressVC.configure(with: pesan, image: image)

        guard let window = progressVC.view.window else { return }

        window.level = .floating
        window.hasShadow = false
        window.isOpaque = false
        window.backgroundColor = .clear

        /// * Menyembunyikan title bar
        window.titlebarAppearsTransparent = false

        window.isMovableByWindowBackground = false
        window.styleMask.remove(.titled)
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = true

        /// * Mengatur posisi jendela di tengah layar
        alertWindowController = NSWindowController(window: window)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            alertWindowController?.window?.makeKeyAndOrderFront(nil)
        }
    }
    
    /// Fungsi untuk menutup jendela notifikasi progres (progress window) dengan efek fade out.
    /// Jendela akan memudar secara bertahap selama 0.5 detik sebelum ditutup sepenuhnya.
    /// Setelah animasi selesai, referensi ke ``alertWindowController`` akan dihilangkan
    /// untuk membebaskan memori.
    public static func closeProgressWindow() {
        guard let window = alertWindowController?.window else { return }
        // Atur NSAnimationContext untuk fade out
        NSAnimationContext.runAnimationGroup({ context in
            // Durasi animasi fade out
            context.duration = 0.5
            // Kurangi alpha value ke 0 (transparent)
            window.animator().alphaValue = 0
        }) {
            // Setelah animasi selesai, tutup window
            alertWindowController?.close()
            // Pastikan referensi ke progressWindowController dihapus
            alertWindowController = nil
        }
    }
    
    // MARK: - NSALERT

    /// Menampilkan jendela peringatan (`NSAlert`) standar kepada pengguna.
    ///
    /// Jendela peringatan ini berisi judul, pesan informatif, dan ikon peringatan (`NSImage.cautionName`).
    /// Fungsi ini bersifat modal, yang berarti pengguna harus menutup peringatan sebelum melanjutkan interaksi dengan aplikasi.
    /// Ini ideal untuk notifikasi penting atau kesalahan yang memerlukan perhatian segera dari pengguna.
    ///
    /// - Parameters:
    ///   - title: Judul yang akan ditampilkan di jendela peringatan.
    ///   - message: Pesan informatif yang lebih detail di bawah judul.
    public static func showAlert(title: String, message: String, style: NSAlert.Style? = .warning) {
        let alert = NSAlert()
        alert.alertStyle = style ?? .warning // Mengatur gaya peringatan, default adalah .warning
        alert.messageText = title // Mengatur judul peringatan
        alert.informativeText = message // Mengatur pesan detail peringatan
        alert.icon = NSImage(named: NSImage.cautionName) // Mengatur ikon peringatan (simbol hati-hati)
        alert.addButton(withTitle: "OK") // Menambahkan tombol "OK" untuk menutup peringatan
        alert.runModal() // Menampilkan peringatan secara modal
    }

    // MARK: - TableView

    /// Fungsi untuk memperbesar tinggi `NSTableView`.
    ///
    /// - Parameter tableView: `NSTableView` yang akan diperbarui.
    static func increaseSize(_ tableView: NSTableView) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2 // Durasi animasi
            tableView.rowHeight = min(max(tableView.rowHeight + 20, 16), 36) // Tetapkan batas maksimal 36
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< tableView.numberOfRows))
        }
    }

    /// Fungsi untuk memperkecil tinggi `NSTableView`.
    ///
    /// - Parameter tableView: `NSTableView` yang akan diperbarui.
    static func decreaseSize(_ tableView: NSTableView) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2 // Durasi animasi
            tableView.rowHeight = max(tableView.rowHeight - 20, 16)
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< tableView.numberOfRows))
        }
    }
    
    /// Fungsi untuk menjalankan protokol ``EditableViewType``
    /// untuk memperbarui `editAction` serta delegate dan datasource
    /// dari ``OverlayEditorManager`` di tableView yang aktif.
    ///
    ///   `viewController` yang memuat `tableView` harus mematuhi protokol ``OverlayEditorManagerDelegate``
    ///   dan ``OverlayEditorManagerDataSource`` karena delegate dan datasource
    ///   tersebut akan diterapkan ke `viewController`.
    /// - Parameters:
    ///   - tableView: `EditableTableView` atau `EditableOutlineView` atau subclass `NSTableView` yang
    ///   mematuhi protokol ``EditableViewType``.
    ///   - viewController: `NSViewController` yang memuat `NSTableView`.
    static func delegateEditorManager<T: NSTableView & EditableViewType>(_ tableView: T, viewController: NSViewController) {
        guard let window = viewController.view.window else { return }

        // OverlayEditorManager harus bisa menerima tipe generik T atau menggunakan protokol
        AppDelegate.shared.editorManager = OverlayEditorManager(tableView: tableView, containingWindow: window)
        tableView.editAction = { row, column in
            AppDelegate.shared.editorManager.startEditing(row: row, column: column)
        }

        AppDelegate.shared.editorManager.delegate = (viewController as! any OverlayEditorManagerDelegate)
        AppDelegate.shared.editorManager.dataSource = (viewController as! any OverlayEditorManagerDataSource)
    }

    // MARK: - SEARCH TOOLBAR ITEM

    /// Memperbarui teks pada `NSSearchField` yang tertanam dalam `NSSearchToolbarItem` di sebuah `NSWindow` toolbar.
    ///
    /// Fungsi ini mencari item toolbar dengan identifier "cari". Jika ditemukan, ia akan mengatur nilai teks
    /// pada search field tersebut. Selain itu, fungsi ini juga akan memulai atau mengakhiri interaksi pencarian
    /// (misalnya, menampilkan tombol clear atau indikator lainnya) berdasarkan apakah teks kosong atau tidak.
    ///
    /// - Parameters:
    ///   - window: `NSWindow` yang toolbarnya ingin diperbarui. Dapat berupa `nil` jika jendela tidak tersedia.
    ///   - text: `String` yang akan diatur sebagai nilai pada search field. Jika string ini kosong, interaksi pencarian akan diakhiri.
    public static func updateSearchFieldToolbar(_ window: NSWindow?, text: String) {
        // Memastikan window memiliki toolbar dan menemukan NSSearchToolbarItem dengan identifier "cari"
        guard let toolbar = window?.toolbar,
              let searchFieldToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "cari" }) as? NSSearchToolbarItem
        else { return }

        // Mengatur teks pada search field di dalam toolbar item
        searchFieldToolbarItem.searchField.stringValue = text

        // Memulai atau mengakhiri interaksi pencarian berdasarkan teks yang diberikan
        if !text.isEmpty {
            searchFieldToolbarItem.beginSearchInteraction() // Memulai interaksi pencarian (misalnya, menampilkan tombol clear)
        } else {
            searchFieldToolbarItem.endSearchInteraction() // Mengakhiri interaksi pencarian
        }
    }
    
    // MARK: - Fungsi Pemeriksaan Koneksi Internet Langsung
    
    
    /// Fungsi ini akan memeriksa ketersediaan internet secara asinkron.
    /// - Returns: `true` jika internet tersedia, `false` jika internet offline.
    static func checkInternetConnectivityDirectly() async throws -> Bool {
        // Pilih URL yang Anda yakin selalu online, misal Google atau API server Anda.
        let url = URL(string: "https://www.google.com")!
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // Minta hanya header, lebih cepat dan hemat bandwidth.
        request.timeoutInterval = 5.0 // Batasi waktu respons menjadi 5 detik.

        do {
            let (_, response) = try await URLSession.shared.data(for: request) // Gunakan async data(for:)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                #if DEBUG
                    print("Internet tersedia melalui koneksi langsung.")
                #endif
                return true
            } else {
                #if DEBUG
                    print("Internet tidak tersedia melalui koneksi langsung. Status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                #endif
                return false
            }
        } catch {
            #if DEBUG
                print("Gagal memeriksa koneksi internet. Error: \(error.localizedDescription)")
            #endif
            // Jika ada error (misal, tidak ada koneksi sama sekali, timeout), anggap tidak ada internet
            return false
        }
    }

    // MARK: - PYTHON EXPORT PDF/EXCEL

    /// Memeriksa ketersediaan dan menjalankan perintah (command) sistem dengan argumen yang diberikan.
    ///
    /// Fungsi ini menjalankan sebuah perintah eksternal menggunakan `Process` dan menangkap output standar serta error-nya.
    /// Ini berguna untuk memverifikasi apakah sebuah perintah sistem (seperti `which`, `git`, atau `ffmpeg`) tersedia
    /// dan berfungsi sebagaimana mestinya, atau untuk menjalankan perintah dan mendapatkan outputnya.
    ///
    /// - Parameters:
    ///   - command: `String` yang berisi jalur lengkap ke perintah yang akan dijalankan (misalnya, "/usr/bin/which" atau "/usr/local/bin/git").
    ///   - arguments: Array of `String` yang berisi argumen yang akan dilewatkan ke perintah (misalnya, `["nama_perintah"]` untuk `which`).
    /// - Returns: `String` opsional yang berisi output dari perintah jika perintah berhasil dieksekusi (kode keluar 0).
    ///            Mengembalikan `nil` jika perintah gagal dieksekusi atau tidak ditemukan (kode keluar bukan 0).
    public static func checkCommandAvailability(command: String, arguments: [String]) -> String? {
        #if DEBUG
            print("Memulai checkCommandAvailability untuk command: \(command) dengan arguments: \(arguments)")
        #endif

        let task = Process()

        task.executableURL = URL(fileURLWithPath: command)
        task.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            #if DEBUG
                print("Mencoba menjalankan proses...")
            #endif
            try task.run()
            #if DEBUG
                print("Proses berhasil diluncurkan. Menunggu proses selesai dan membaca output...")
            #endif

            // --- SOLUSI PENTING: BACA OUTPUT SEBELUM waitUntilExit() ---
            // Baca data secara bersamaan di background
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            // -----------------------------------------------------------

            task.waitUntilExit() // Sekarang ini seharusnya tidak akan hang karena pipe buffer sudah diatasi
            #if DEBUG
                print("Proses selesai. Termination status: \(task.terminationStatus)")
            #endif
            let output = String(data: outputData, encoding: .utf8)
            let errorOutput = String(data: errorData, encoding: .utf8)
            #if DEBUG
                print("Output standar dari proses:\n\(output ?? "Tidak ada output")")
            #endif
            if let err = errorOutput, !err.isEmpty {
                #if DEBUG
                    print("Output error dari proses:\n\(err)") // Cetak error output jika ada
                #endif
            }

            if task.terminationStatus == 0 {
                if let unwrappedOutput = output, !unwrappedOutput.contains("Package(s) not found:") {
                    #if DEBUG
                        print("Paket '\(arguments.last ?? "")' ditemukan.")
                    #endif
                    return unwrappedOutput
                } else {
                    #if DEBUG
                        print("Paket '\(arguments.last ?? "")' TIDAK ditemukan (meskipun termination status 0).")
                    #endif
                    return nil
                }
            } else {
                #if DEBUG
                 print("Perintah gagal dengan termination status: \(task.terminationStatus)")
                #endif
                return nil
            }
        } catch {
            #if DEBUG
                print("ERROR: Gagal meluncurkan command '\(command) \(arguments.joined(separator: " "))': \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Memeriksa instalasi Python 3 dan beberapa paket Python penting (pandas, openpyxl, reportlab)
    /// yang dibutuhkan oleh aplikasi. Jika ada yang belum terinstal, fungsi ini akan mencoba menginstalnya.
    ///
    /// Proses ini menampilkan jendela progres modal untuk memberikan umpan balik kepada pengguna
    /// selama pemeriksaan dan potensi instalasi. Alur kerjanya meliputi:
    /// 1. Menampilkan jendela progres.
    /// 2. Mencari jalur instalasi Python 3 yang valid.
    /// 3. Memeriksa dan menginstal paket Python yang diperlukan secara berurutan.
    /// 4. Menyelesaikan proses dan memberikan hasil melalui closure `completion`.
    ///
    /// - Parameters:
    ///   - window: `NSWindow` induk yang akan menampilkan jendela progres sebagai sheet modal.
    ///   - completion: Closure yang akan dipanggil setelah proses pemeriksaan dan instalasi selesai.
    ///     - Parameter `Bool`: `true` jika semua pemeriksaan dan instalasi berhasil, `false` jika ada kegagalan.
    ///     - Parameter `NSWindow?`: Jendela progres itu sendiri (opsional).
    ///     - Parameter `String?`: Jalur Python yang ditemukan dan digunakan (opsional). Ini akan `nil` jika Python tidak ditemukan.
    public static func checkPythonAndPandasInstallation(window: NSWindow?, completion: @escaping (Bool, NSWindow?, String?) -> Void) {
        // Memuat storyboard dan menginisialisasi window controller serta view controller untuk progres
        let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil)
        guard let progressWindowController = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController,
              let progressViewController = progressWindowController.contentViewController as? ProgressBarVC,
              let progressWindow = progressWindowController.window else {
            // Jika gagal memuat UI progres, panggil completion dengan status gagal
            completion(false, nil, nil)
            return
        }

        // Menampilkan jendela progres sebagai sheet modal dari jendela induk
        window?.beginSheet(progressWindow)

        // Mengatur total langkah dan indeks saat ini untuk progress bar
        progressViewController.totalStudentsToUpdate = 4 // Asumsi 4 langkah: Cek Python + 3 paket
        progressViewController.currentStudentIndex = 0
        
        // Wrapper untuk mengumpulkan nama paket yang hilang (jika ada)
        let missingPackagesWrapper = ArrayWrapper<String>([])
        let initialPythonFound: String? // Ubah ke let

        // Daftar jalur umum untuk instalasi Python 3 yang akan diperiksa
        let pythonPaths = [
            "/usr/bin/python3",
            "/opt/local/bin/python3",
            "/usr/local/bin/python3",
        ]
        var pythonFound: String? // Akan diisi jika Python ditemukan

        // Mencari instalasi Python 3 yang valid di antara jalur yang ditentukan secara sinkron di awal
        // (Ini tetap blocking jika `checkCommandAvailability` blocking)
        for path in pythonPaths {
            if let pythonCheck = checkCommandAvailability(command: "/usr/bin/which", arguments: [path]), !pythonCheck.isEmpty {
                pythonFound = path // Python ditemukan, simpan jalurnya
                break // Hentikan pencarian jika sudah ditemukan
            }
        }
        
        initialPythonFound = pythonFound // Beri nilai ke konstanta setelah pencarian selesai
        // *** Akhir Perbaikan ***

        // Pindah ke Task untuk menjalankan alur asinkron utama
        Task {
            do {
                // Perbarui label UI di main thread
                await MainActor.run {
                    progressViewController.progressLabel.stringValue = "Memeriksa alat yang dibutuhkan.."
                }

                // Langkah 1: Memeriksa instalasi Python
                // Panggil versi async dari checkPythonInstallation
                let pythonInstallSuccess = try await checkPythonInstallation(pythonFound: initialPythonFound, progressViewController: progressViewController, window: window, progressWindow: progressWindow)
                
                guard pythonInstallSuccess else {
                    // Jika Python tidak ditemukan, akhiri sheet dan panggil completion dengan status gagal
                    await MainActor.run {
                        window?.endSheet(progressWindow)
                        completion(false, progressWindow, initialPythonFound)
                    }
                    return
                }

                // Pastikan pythonFound diperbarui setelah checkPythonInstallation berhasil
                // (Anda mungkin ingin checkPythonInstallation mengembalikan path Python yang ditemukan)
                // Untuk kesederhanaan, asumsikan pythonFound yang sudah ada adalah yang benar jika checkPythonInstallation berhasil.
                // ATAU, jika checkPythonInstallation mengembalikan String?, Anda bisa gunakan itu.
                // Contoh: let actualPythonPath = try await self.checkPythonInstallation(...)

                // Langkah 2: Cek dan instal 'pandas'
                await MainActor.run {
                    progressViewController.progressLabel.stringValue = "Memeriksa dan menginstal pandas..."
                }
                let pandas = try await self.checkAndInstallPackage(pythonPath: initialPythonFound!, package: "pandas", progressViewController: progressViewController, missingPackagesWrapper: missingPackagesWrapper)
                // Catatan: Jika Anda ingin menghentikan alur jika instalasi paket gagal,
                // Anda bisa tambahkan `guard successForPackage else { ... return }` di sini.
                // Karena `checkAndInstallPackage` sekarang mengembalikan Bool, Anda bisa memeriksanya.
                
                guard pandas else {
                    await MainActor.run { [weak progressWindow] in
                        completion(false, progressWindow, initialPythonFound)
                    }
                    return
                }

                // Langkah 3: Cek dan instal 'openpyxl'
                await MainActor.run {
                    progressViewController.progressLabel.stringValue = "Memeriksa dan menginstal openpyxl..."
                }
                
                let openpyxl = try await self.checkAndInstallPackage(pythonPath: initialPythonFound!, package: "openpyxl", progressViewController: progressViewController, missingPackagesWrapper: missingPackagesWrapper)
                
                guard openpyxl else {
                    await MainActor.run { [weak progressWindow] in
                        completion(false, progressWindow, initialPythonFound)
                    }
                    return
                }
                
                // Langkah 4: Cek dan instal 'reportlab'
                await MainActor.run {
                    progressViewController.progressLabel.stringValue = "Memeriksa dan menginstal reportlab..."
                }
                
                let reportlab = try await self.checkAndInstallPackage(pythonPath: initialPythonFound!, package: "reportlab", progressViewController: progressViewController, missingPackagesWrapper: missingPackagesWrapper)
                
                guard reportlab else {
                    await MainActor.run { [weak progressWindow] in
                        completion(false, progressWindow, initialPythonFound)
                    }
                    return
                }
                
                // Menyelesaikan proses instalasi dan memanggil completion handler utama
                await MainActor.run {
                    self.finishInstallation(missingPackagesWrapper: missingPackagesWrapper, progressViewController: progressViewController, window: window, progressWindow: progressWindow, pythonFound: initialPythonFound, completion: completion)
                }

            } catch {
                // Tangani error yang terjadi di salah satu langkah (Python tidak ditemukan, instalasi gagal, dll.)
                await MainActor.run {
                    window?.endSheet(progressWindow) // Tutup sheet progres
                    completion(false, progressWindow, initialPythonFound)
                }
            }
        }
    }

    /// Memverifikasi apakah Python 3 telah terinstal di sistem.
    ///
    /// Fungsi ini menunda eksekusi sebentar untuk memberikan waktu bagi UI progres untuk diperbarui.
    /// Kemudian, ia memeriksa jalur Python yang telah ditemukan sebelumnya. Jika Python 3 tidak ditemukan
    /// pada jalur yang valid, sebuah peringatan akan ditampilkan kepada pengguna dan proses instalasi
    /// atau pemeriksaan paket berikutnya akan dibatalkan. Jika Python 3 ditemukan, indikator progres
    /// akan diperbarui, menandakan bahwa langkah ini berhasil.
    ///
    /// - Parameters:
    ///   - pythonFound: Sebuah `String` opsional yang berisi jalur lengkap ke instalasi Python 3 yang ditemukan. `nil` jika tidak ditemukan.
    ///   - progressViewController: Instance `ProgressBarVC` yang digunakan untuk memperbarui status dan progres di UI.
    ///   - window: `NSWindow` induk tempat jendela progres ditampilkan (digunakan untuk konteks sheet).
    ///   - progressWindow: `NSWindow` dari jendela progres yang sedang aktif.
    /// - Returns :
    ///     - Bool: `true` jika Python 3 ditemukan dan valid, `false` jika tidak.
    private static func checkPythonInstallation(pythonFound: String?, progressViewController: ProgressBarVC, window: NSWindow?, progressWindow: NSWindow) async throws -> Bool {
        // Penundaan singkat untuk memungkinkan UI progres diperbarui
        await MainActor.run {
            // Memeriksa apakah Python 3 ditemukan.
            // Jika tidak ditemukan atau string kosong, tampilkan peringatan dan panggil completion dengan 'false'.
            guard let foundPython = pythonFound, !foundPython.isEmpty else {
                showAlert(title: "Python belum terinstal", message: "Python 3 tidak terinstal. Silakan instal untuk melanjutkan.")
                return false
            }

            // Perbarui indeks progres dan label di UI karena Python telah ditemukan
            progressViewController.currentStudentIndex = 1
            DispatchQueue.main.async {
                progressViewController.progressLabel.stringValue = "Memeriksa..."
            }
            // Python ditemukan, panggil completion dengan 'true'
            return true
        }
    }

    /// Memeriksa apakah sebuah paket Python tertentu sudah terinstal. Jika belum, fungsi ini akan mencoba menginstalnya.
    ///
    /// Fungsi ini bekerja secara asinkron untuk menjaga UI tetap responsif.
    /// Prosesnya meliputi:
    /// 1. **Pemeriksaan:** Menggunakan `pip show` untuk memverifikasi keberadaan paket.
    /// 2. **Instalasi (jika diperlukan):** Jika paket tidak ditemukan, ia akan memanggil fungsi `installPackage`
    ///    untuk mencoba menginstalnya. Selama proses instalasi, label progres di UI akan diperbarui.
    /// 3. **Penanganan Hasil:** Mencatat paket yang gagal diinstal dan memperbarui tampilan progres.
    ///
    /// - Parameters:
    ///   - pythonPath: Jalur lengkap ke executable Python (misalnya, `/usr/local/bin/python3`).
    ///   - package: Nama paket Python yang akan diperiksa atau diinstal (misalnya, "pandas", "openpyxl").
    ///   - progressViewController: Instance `ProgressBarVC` untuk memperbarui indikator dan label progres di UI.
    ///   - missingPackagesWrapper: `ArrayWrapper<String>` yang digunakan untuk melacak daftar paket yang gagal diinstal.
    /// - Returns:
    ///   - Bool: `true` jika paket berhasil dipasang, `false` jika gagal memasang paket.
    private static func checkAndInstallPackage(pythonPath: String, package: String, progressViewController: ProgressBarVC, missingPackagesWrapper: ArrayWrapper<String>) async throws -> Bool {

        // Pembaruan UI selalu di Main Actor/Thread untuk keamanan
        await MainActor.run {
            progressViewController.progressLabel.stringValue = "Memeriksa dan menginstal \(package)..."
        }

        // Memeriksa apakah paket sudah terinstal dengan menjalankan 'pip show <package>'
        // Asumsi: `checkCommandAvailability` adalah fungsi SINKRON yang bisa langsung dipanggil.
        // Jika itu blocking, Anda mungkin ingin membungkusnya dalam Task { ... } atau MainActor.run { ... }.
        if checkCommandAvailability(command: pythonPath, arguments: ["-m", "pip", "show", package]) == nil {
            // Jika paket belum terinstal, perbarui label UI untuk menunjukkan persiapan instalasi
            await MainActor.run { [weak progressViewController] in
                progressViewController?.progressLabel.stringValue = "Menyiapkan paket. Mohon tunggu..."
            }

            // Panggil fungsi untuk menginstal paket menggunakan `withCheckedContinuation`
            // untuk mengonversi completion-based API menjadi async/await.
            let installationSuccess = await withCheckedContinuation { continuation in
                // Panggil `installPackage` Anda yang asli dengan completion handler
                installPackage(pythonPath: pythonPath, package: package, progressViewController: progressViewController) { success in
                    continuation.resume(returning: success) // Kembali ke async/await dengan hasil boolean
                }
            }

            if installationSuccess {
                // Jika instalasi berhasil
                await MainActor.run {
                    // Perbarui label progres
                    progressViewController.progressLabel.stringValue = "\(package) berhasil diinstal." // Gunakan properti langsung
                    // Perbarui tampilan progres
                    updateProgressForPackage(package: package, progressViewController: progressViewController, terinstal: false) // terinstal: false karena baru diinstal
                    progressViewController.currentStudentIndex += 1 // Inkremental setelah sukse
                    progressViewController.currentStudentIndex = min(progressViewController.currentStudentIndex, 4)
                }
                #if DEBUG
                    print("\(package) berhasil diinstal.")
                #endif
                return true
            } else {
                // Jika instalasi gagal
                missingPackagesWrapper.array.append(package)
                await MainActor.run {
                    progressViewController.progressLabel.stringValue = "Gagal menginstal \(package)." // Gunakan properti langsung
                    progressViewController.currentStudentIndex += 1 // Inkremental meskipun gagal
                    progressViewController.currentStudentIndex = min(progressViewController.currentStudentIndex, 4)
                }
                #if DEBUG
                    print("Gagal menginstal \(package).")
                #endif
                return false // Kembalikan false dari fungsi async
            }
        } else {
            // Jika paket sudah terinstal
            await MainActor.run {
                progressViewController.progressLabel.stringValue = "\(package) sudah terinstal."
                updateProgressForPackage(package: package, progressViewController: progressViewController, terinstal: true)
                progressViewController.currentStudentIndex += 1 // Menambahkan nilai terlebih dahulu
                progressViewController.currentStudentIndex = min(progressViewController.currentStudentIndex, 4)
            }
            #if DEBUG
                print("\(package) sudah terinstal.")
            #endif
            return true
        }
    }

    /// Menginstal paket Python yang ditentukan menggunakan `pip`.
    ///
    /// Fungsi ini menjalankan perintah `pip install` dalam proses terpisah.
    /// Yang istimewa dari fungsi ini adalah kemampuannya untuk membaca output `pip` secara *real-time*
    /// dan memperbarui UI progres, memberikan umpan balik visual kepada pengguna selama pengunduhan
    /// dan instalasi paket. Ini dilakukan dengan menggunakan `readabilityHandler` pada `Pipe`
    /// dan mem-parsing output untuk mengekstrak informasi progres seperti ukuran unduhan dan ETA.
    ///
    /// - Parameters:
    ///   - pythonPath: Jalur lengkap ke executable Python (misalnya, `/usr/local/bin/python3`).
    ///   - package: Nama paket Python yang akan diinstal (misalnya, "pandas", "openpyxl").
    ///   - progressViewController: Instance `ProgressBarVC` yang digunakan untuk memperbarui indikator dan label progres di UI.
    ///   - completion: Closure yang akan dipanggil setelah proses instalasi selesai (berhasil atau gagal).
    ///     - Parameter `Bool`: `true` jika instalasi berhasil, `false` jika terjadi kesalahan.
    private static func installPackage(pythonPath: String, package: String, progressViewController: ProgressBarVC, completion: @escaping (Bool) -> Void) {
        Task {
            guard let isConnected = try? await checkInternetConnectivityDirectly(), isConnected else {
                // Jika checkInternetConnectivityDirectly() mengembalikan nil (error)
                // ATAU jika mengembalikan false (tidak ada koneksi)
                await MainActor.run {
                    progressViewController.progressLabel.stringValue = "Tidak ada koneksi internet. Menutup..."
                    ReusableFunc.showAlert(title: "Internet offline", message: "Koneksi internet diperlukan untuk memasang paket yang dibutuhkan.")
                }
                completion(false) // Menginformasikan bahwa instalasi gagal.
                return // Hentikan eksekusi fungsi jika tidak ada internet.
            }
            
            let task = Process() // Membuat instance baru dari Process
            // Menjalankan pip melalui '/usr/bin/script' untuk menyediakan pseudo-tty,
            // yang diperlukan agar progress bar pip dapat ditampilkan dengan benar.
            task.launchPath = "/usr/bin/script"
            // Argumen untuk 'script': '-q /dev/null' untuk mode quiet,
            // diikuti oleh perintah pip install. '--user' menginstal ke direktori user,
            // '--progress-bar=on' memastikan progress bar terlihat.
            task.arguments = ["-q", "/dev/null", pythonPath, "-u", "-m", "pip", "install", "--user", package, "--progress-bar=on"]
            // Memastikan output Python tidak di-buffer agar bisa dibaca secara real-time
            task.environment = ["PYTHONUNBUFFERED": "1"]
            
            let pipe = Pipe() // Membuat pipe untuk menangkap output standar dan error
            task.standardOutput = pipe // Mengarahkan output standar proses ke pipe
            task.standardError = pipe // Mengarahkan output error proses ke pipe
            
            let pipeReader = pipe.fileHandleForReading
            // Menggunakan readabilityHandler untuk membaca output dari pipe secara asinkron
            pipeReader.readabilityHandler = { handle in
                let availableData = handle.availableData // Mengambil data yang tersedia
                guard let output = String(data: availableData, encoding: .utf8), !output.isEmpty else {
                    return // Abaikan jika tidak ada output atau output kosong
                }
                
                // Hapus ANSI escape codes yang sering muncul di output terminal (misalnya dari progress bar)
                let cleanOutput = output.removingANSIEscapeCodes()
                
                // Karena output bisa mengandung banyak baris (dan '\r' sebagai delimiter untuk pembaruan baris yang sama),
                // ambil baris terakhir yang paling relevan sebagai progres terkini.
                let lines = cleanOutput.components(separatedBy: "\r")
                guard let lastLine = lines.last, !lastLine.isEmpty else { return }
                #if DEBUG
                    print("Last Output:", lastLine) // Mencetak output untuk debugging
                #endif

                // Ambil substring setelah "|" terakhir jika ada.
                var progressText = lastLine
                if let lastPipeIndex = lastLine.lastIndex(of: "|") {
                    progressText = String(lastLine[lastLine.index(after: lastPipeIndex)...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }

                #if DEBUG
                    print("Progress Text:", progressText) // Harusnya: "10 kB 392 kB/s eta 0:00:30"
                #endif
                
                // Regex untuk menangkap informasi progres unduhan (misal: "1.2/12.6 MB")
                let progressPattern = "\\b(\\d+(\\.\\d+)?)/(\\d+(\\.\\d+)?)[ ]*(MB|KB)\\b"
                // Regex untuk menangkap perkiraan waktu selesai (ETA), misal: "eta 0:00:46"
                let etaPattern = "eta\\s+(\\d{1,2}:\\d{1,2}:\\d{1,2})"
                
                // Cek apakah output merupakan header Downloading yang mengandung total file size.
                if cleanOutput.contains("Downloading") {
                    let headerPattern = "\\((\\d+(\\.\\d+)?)[ ]*(MB|KB)\\)"
                    if let headerRegex = try? NSRegularExpression(pattern: headerPattern, options: []),
                       let headerMatch = headerRegex.firstMatch(in: cleanOutput, options: [], range: NSRange(location: 0, length: cleanOutput.utf16.count)),
                       let totalRange = Range(headerMatch.range(at: 1), in: cleanOutput),
                       let unitRange = Range(headerMatch.range(at: 3), in: cleanOutput) {
                        totalSize = "\(cleanOutput[totalRange]) \(cleanOutput[unitRange])"
                    }
                }
                
                var downloaded: String? // Ukuran yang sudah diunduh
                
                var unit: String? // Satuan ukuran (MB/KB)
                var eta: String? // Estimated Time of Arrival
                
                if let progressRegex = try? NSRegularExpression(pattern: progressPattern, options: []),
                   let match = progressRegex.firstMatch(in: lastLine, options: [], range: NSRange(location: 0, length: lastLine.utf16.count)) {
                    
                    if let downloadedRange = Range(match.range(at: 1), in: lastLine) {
                        downloaded = String(lastLine[downloadedRange])
                    }
                    if let totalRange = Range(match.range(at: 3), in: lastLine) {
                        // Jika perlu, Anda bisa memperbarui totalFileSize dari sini juga.
                        totalSize = "\(lastLine[totalRange])"   // Namun, biasanya header sudah mencukupi.
                    }
                    if let unitRange = Range(match.range(at: 5), in: lastLine) {
                        unit = String(lastLine[unitRange])
                    }
                }
                
                // Jika pola utama tidak cocok, gunakan fallback
                if downloaded == nil || unit == nil,
                   progressText.contains("kB/s") || progressText.contains("MB/s") {
                    let fallbackPattern = "^(\\d+(\\.\\d+)?)[ ]*(MB|KB)"
                    if let fallbackRegex = try? NSRegularExpression(pattern: fallbackPattern, options: []),
                       let fallbackMatch = fallbackRegex.firstMatch(in: progressText, options: [], range: NSRange(progressText.startIndex..<progressText.endIndex, in: progressText)) {
                        if let downloadedRange = Range(fallbackMatch.range(at: 1), in: progressText) {
                            downloaded = String(progressText[downloadedRange])
                        }
                        if let unitRange = Range(fallbackMatch.range(at: 3), in: progressText) {
                            unit = String(progressText[unitRange])
                        }
                    }
                }
                
                // Mencoba mencocokkan pola ETA
                if let etaRegex = try? NSRegularExpression(pattern: etaPattern, options: []) {
                    let range = NSRange(location: 0, length: lastLine.utf16.count)
                    if let etaMatch = etaRegex.firstMatch(in: lastLine, options: [], range: range),
                       let etaRange = Range(etaMatch.range(at: 1), in: lastLine)
                    {
                        eta = String(lastLine[etaRange])
                    }
                }
                
                // Perbarui UI di thread utama berdasarkan output yang di-parsing
                Task { @MainActor [unowned progressViewController, downloaded, totalSize, unit, eta, cleanOutput] in
                    if cleanOutput.contains("Requirement already satisfied") {
                        progressViewController.progressLabel.stringValue = "Persyaratan telah terpenuhi."
                    } else if cleanOutput.contains("Successfully installed") {
                        progressViewController.progressLabel.stringValue = "Paket berhasil diinstal."
                    } else if cleanOutput.contains("Installing collected packages") {
                        progressViewController.progressLabel.stringValue = "Memasang paket..."
                    } else if let downloaded, let totalSize, let unit, let eta {
                        // Tampilkan progres unduhan dan ETA jika semua data tersedia
                        progressViewController.progressLabel.stringValue = "Unduh: \(downloaded) \(unit) / \(totalSize) \(unit)   ETA: \(eta)"
                    } else if let eta {
                        progressViewController.progressLabel.stringValue = "Mengunduh... Perkiraan selesai: \(eta)"
                    } else {
                        // Sebagai fallback jika parsing gagal, tampilkan pesan umum
                        progressViewController.progressLabel.stringValue = "Memproses..."
                    }
                }
            }
            
            // `terminationHandler` akan dipanggil setelah proses `pip` selesai
            task.terminationHandler = { process in
                // Hapus handler pembacaan pipe untuk mencegah crash setelah proses berakhir
                pipeReader.readabilityHandler = nil
                totalSize = nil
                // Panggil completion handler dengan status keberhasilan proses
                completion(process.terminationStatus == 0)
            }
            
            // Jalankan proses instalasi
            do {
                try task.run()
            } catch {
                // Tangani kesalahan jika proses tidak dapat dimulai
                await MainActor.run {
                    pipeReader.readabilityHandler = nil // Pastikan handler dihapus
                    totalSize = nil
                    completion(false) // Laporkan kegagalan
                }
            }
        }
    }

    /// Memperbarui tampilan indikator progres dan label di UI berdasarkan status instalasi paket Python tertentu.
    ///
    /// Fungsi ini mengatur ulang indikator progres menjadi mode deterministik dan memperbarui nilai progres
    /// serta pesan yang ditampilkan kepada pengguna. Pesan dan status progres akan bervariasi
    /// tergantung pada nama paket dan apakah paket tersebut sudah terinstal atau sedang diinstal.
    ///
    /// - Parameters:
    ///   - package: Nama paket Python yang sedang diproses (misalnya, "pandas", "openpyxl", "reportlab").
    ///   - progressViewController: Instance `ProgressBarVC` yang bertanggung jawab atas pembaruan UI progres.
    ///   - terinstal: Sebuah `Bool` yang menunjukkan apakah paket yang diperiksa sudah terinstal (`true`)
    ///                atau perlu diinstal (`false`).
    private static func updateProgressForPackage(package: String, progressViewController: ProgressBarVC, terinstal: Bool) {
        // Menghentikan animasi indikator tak tentu dan mengembalikan ke mode deterministik.
        progressViewController.progressIndicator.isIndeterminate = false
        progressViewController.progressIndicator.stopAnimation(self)

        // Mengatur total langkah untuk progress bar. Ini memastikan skala yang konsisten.
        progressViewController.totalStudentsToUpdate = 4

        // Memperbarui pesan progres dan indeks berdasarkan paket dan status instalasinya.
        switch package {
        case "pandas":
            if terinstal {
                progress = "Menyiapkan excel dan pdf..." // Pesan jika 'pandas' sudah terinstal
            } else {
                progress = "Menginstal paket. Mohon tunggu..." // Pesan saat 'pandas' sedang diinstal
            }
            progressViewController.currentStudentIndex = 2 // Mengatur langkah progres untuk 'pandas'
        case "openpyxl":
            if terinstal {
                progress = "Paket Excel siap." // Pesan jika 'openpyxl' sudah terinstal
            } else {
                progress = "Menginstal paket. Mohon tunggu..." // Pesan saat 'openpyxl' sedang diinstal
            }
            progressViewController.currentStudentIndex = 3 // Mengatur langkah progres untuk 'openpyxl'
        case "reportlab":
            if terinstal {
                progress = "Paket PDF siap." // Pesan jika 'reportlab' sudah terinstal
            } else {
                progress = "Menginstal paket. Mohon tunggu..." // Pesan saat 'reportlab' sedang diinstal
            }
            progressViewController.currentStudentIndex = 4 // Mengatur langkah progres untuk 'reportlab'
        default:
            break // Abaikan paket yang tidak dikenal
        }
    }

    /// Menyelesaikan alur pemeriksaan dan instalasi paket Python, serta menangani tampilan akhir progres.
    ///
    /// Fungsi ini menunda eksekusi sejenak untuk memungkinkan UI memperbarui. Kemudian, fungsi ini akan menghentikan
    /// animasi progres deterministik dan memulai animasi tak tentu, menampilkan pesan "Menyiapkan file...".
    ///
    /// Berdasarkan apakah ada paket yang gagal diinstal, fungsi ini akan:
    /// - Jika semua paket berhasil diinstal: Menampilkan pesan "Mengkonversi file..." dan memanggil `completion`
    ///   dengan status keberhasilan (`true`).
    /// - Jika ada paket yang gagal: Menampilkan daftar paket yang gagal dan memanggil `completion` dengan status
    ///   kegagalan (`false`).
    ///
    /// - Parameters:
    ///   - missingPackagesWrapper: `ArrayWrapper<String>` yang berisi daftar nama paket yang gagal diinstal.
    ///   - progressViewController: Instance `ProgressBarVC` yang digunakan untuk mengontrol dan memperbarui tampilan progres.
    ///   - window: `NSWindow` induk tempat jendela progres ditampilkan sebagai sheet.
    ///   - progressWindow: `NSWindow` dari jendela progres yang sedang aktif.
    ///   - pythonFound: `String` opsional yang berisi jalur ke executable Python yang berhasil ditemukan.
    ///   - completion: Closure yang akan dipanggil setelah proses instalasi selesai.
    ///     - Parameter `Bool`: `true` jika semua paket berhasil diinstal, `false` jika ada kegagalan.
    ///     - Parameter `NSWindow?`: Jendela progres itu sendiri.
    ///     - Parameter `String?`: Jalur Python yang ditemukan dan digunakan.
    private static func finishInstallation(missingPackagesWrapper: ArrayWrapper<String>, progressViewController: ProgressBarVC, window: NSWindow?, progressWindow: NSWindow, pythonFound: String?, completion: @escaping (Bool, NSWindow?, String?) -> Void) {
        // Menunda eksekusi untuk memberi waktu UI memperbarui atau menampilkan animasi transisi
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            // Mengubah progress indicator menjadi mode tak tentu (indeterminate)
            // dan memulai animasinya, menunjukkan proses latar belakang yang tidak memiliki persentase jelas.
            progressViewController.progressIndicator.isIndeterminate = true
            progressViewController.progressIndicator.startAnimation(nil)
            progressViewController.progressLabel.stringValue = "Menyiapkan file..."

            // Memeriksa apakah ada paket yang gagal diinstal
            if missingPackagesWrapper.array.isEmpty {
                // Jika tidak ada paket yang hilang, asumsikan instalasi berhasil dan lanjutkan dengan konversi
                progressViewController.progressLabel.stringValue = "Mengkonversi file..."
                // Memanggil completion handler dengan status sukses dan data yang relevan
                completion(true, progressWindow, pythonFound)
            } else {
                // Jika ada paket yang gagal, tampilkan pesan kesalahan yang merinci paket-paket tersebut
                progressViewController.progressLabel.stringValue = "Beberapa paket gagal diinstal: \(missingPackagesWrapper.array.joined(separator: ", "))"
                // Memanggil completion handler dengan status gagal dan data yang relevan
                completion(false, progressWindow, pythonFound)
            }
        }
    }

    /// Menjalankan skrip Python "CSV2XCL.py" di latar belakang untuk mengonversi file CSV menjadi file XLSX.
    ///
    /// Fungsi ini memulai proses Python baru, meneruskan jalur ke skrip Python dan file CSV input sebagai argumen.
    /// Setelah skrip Python selesai, file CSV sementara akan dihapus, dan URL file XLSX hasil
    /// akan dikembalikan melalui closure completion. Proses ini berjalan di DispatchQueue global (latar belakang)
    /// untuk menjaga UI tetap responsif.
    ///
    /// - Parameters:
    ///   - csvFileURL: `URL` dari file CSV yang akan dikonversi.
    ///   - window: `NSWindow` yang terkait (opsional, tidak digunakan secara langsung dalam fungsi ini tetapi mungkin untuk konteks).
    ///   - pythonPath: `String` opsional yang berisi jalur ke executable Python 3.
    ///   - completion: Closure yang akan dipanggil setelah skrip Python selesai.
    ///     - Parameter `URL?`: `URL` dari file XLSX yang dihasilkan jika konversi berhasil, atau `nil` jika gagal.
    public static func runPythonScript(csvFileURL: URL, window: NSWindow?, pythonPath: String?, completion: @escaping (URL?) -> Void) {
        // Jalankan operasi di antrean latar belakang agar UI tidak terblokir.
        DispatchQueue.global(qos: .background).async {
            let process = Process() // Membuat instance proses baru.

            // Pastikan pythonPath tidak nil dan membuat URL dari jalur tersebut.
            guard let validPythonPath = pythonPath else {
                DispatchQueue.main.async { completion(nil) } // Kembali ke main thread jika pythonPath tidak valid
                return
            }
            
            // --- Perbaikan di sini ---
            let executableURL = URL(fileURLWithPath: validPythonPath)
            // -------------------------
            
            process.executableURL = executableURL

            // Dapatkan URL skrip Python "CSV2XCL.py" dari bundle aplikasi.
            if let pythonScriptURL = Bundle.main.url(forResource: "CSV2XCL", withExtension: "py") {
                let pythonScriptPath = pythonScriptURL.path // Dapatkan jalur string dari URL.

                // Atur argumen untuk menjalankan skrip Python dengan jalur ke file CSV input.
                process.arguments = [pythonScriptPath, csvFileURL.path]

                let pipe = Pipe() // Membuat pipe untuk menangkap output dan error dari proses.
                process.standardOutput = pipe // Mengarahkan output standar ke pipe.
                process.standardError = pipe // Mengarahkan output error ke pipe.

                // Menentukan handler yang akan dipanggil ketika proses selesai.
                process.terminationHandler = { _ in
                    // Hapus file CSV sementara setelah proses selesai, tangani error jika ada.
                    try? FileManager.default.removeItem(at: csvFileURL)

                    // Tentukan URL file XLSX yang diharapkan berdasarkan nama file CSV input.
                    // Asumsi: skrip Python menyimpan file XLSX di direktori Application Support
                    // dengan nama yang sama dengan CSV tetapi ekstensi .xlsx.
                    let xlsxFileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(csvFileURL.deletingPathExtension().lastPathComponent).xlsx")

                    // Pindah kembali ke main thread untuk memanggil completion handler dengan hasil.
                    DispatchQueue.main.async {
                        completion(xlsxFileURL) // Kembali ke URL file XLSX di main thread.
                    }
                }

                // Coba jalankan proses.
                do {
                    try process.run()
                } catch {
                    // Tangani error jika proses gagal dimulai.
                    DispatchQueue.main.async {
                        completion(nil) // Kembali dengan nil jika ada error.
                    }
                }
            } else {
                // Jika skrip Python tidak ditemukan di bundle aplikasi.
                DispatchQueue.main.async {
                    completion(nil) // Kembali dengan nil.
                }
            }
        }
    }

    /// Menjalankan skrip Python "CSV2PDF.py" di latar belakang untuk mengonversi file CSV menjadi file PDF.
    ///
    /// Fungsi ini mirip dengan `runPythonScript` tetapi secara khusus memanggil skrip Python yang berbeda
    /// untuk menghasilkan output PDF. Proses ini juga berjalan di antrean latar belakang, menghapus
    /// file CSV sementara setelah selesai, dan mengembalikan URL file PDF yang dihasilkan.
    ///
    /// - Parameters:
    ///   - csvFileURL: `URL` dari file CSV yang akan dikonversi.
    ///   - window: `NSWindow` yang terkait (opsional, tidak digunakan secara langsung dalam fungsi ini).
    ///   - pythonPath: `String` opsional yang berisi jalur ke executable Python 3.
    ///   - completion: Closure yang akan dipanggil setelah skrip Python selesai.
    ///     - Parameter `URL?`: `URL` dari file PDF yang dihasilkan jika konversi berhasil, atau `nil` jika gagal.
    public static func runPythonScriptPDF(csvFileURL: URL, window: NSWindow?, pythonPath: String?, completion: @escaping (URL?) -> Void) {
        // Jalankan operasi di antrean latar belakang agar UI tidak terblokir.
        DispatchQueue.global(qos: .background).async {
            let process = Process() // Membuat instance proses baru.

            // Pastikan pythonPath tidak nil dan membuat URL dari jalur tersebut.
            guard let validPythonPath = pythonPath
            else {
                DispatchQueue.main.async { completion(nil) } // Kembali ke main thread jika pythonPath tidak valid
                return
            }
            
            // --- Perbaikan di sini ---
            let executableURL = URL(fileURLWithPath: validPythonPath)
            // -------------------------
            
            process.executableURL = executableURL

            // Dapatkan URL skrip Python "CSV2PDF.py" dari bundle aplikasi.
            if let pythonScriptURL = Bundle.main.url(forResource: "CSV2PDF", withExtension: "py") {
                let pythonScriptPath = pythonScriptURL.path // Dapatkan jalur string dari URL.

                // Atur argumen untuk menjalankan skrip Python dengan jalur ke file CSV input.
                process.arguments = [pythonScriptPath, csvFileURL.path]

                let pipe = Pipe() // Membuat pipe untuk menangkap output dan error dari proses.
                process.standardOutput = pipe // Mengarahkan output standar ke pipe.
                process.standardError = pipe // Mengarahkan output error ke pipe.

                // Menentukan handler yang akan dipanggil ketika proses selesai.
                process.terminationHandler = { _ in
                    // Hapus file CSV sementara setelah proses selesai, tangani error jika ada.
                    try? FileManager.default.removeItem(at: csvFileURL)

                    // Tentukan URL file PDF yang diharapkan berdasarkan nama file CSV input.
                    // Asumsi: skrip Python menyimpan file PDF di direktori Application Support
                    // dengan nama yang sama dengan CSV tetapi ekstensi .pdf.
                    let pdfFileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(csvFileURL.deletingPathExtension().lastPathComponent).pdf")

                    // Pindah kembali ke main thread untuk memanggil completion handler dengan hasil.
                    DispatchQueue.main.async {
                        completion(pdfFileURL) // Kembali ke URL file PDF di main thread.
                    }
                }

                // Coba jalankan proses.
                do {
                    try process.run()
                } catch {
                    // Tangani error jika proses gagal dimulai.
                    DispatchQueue.main.async {
                        completion(nil) // Kembali dengan nil jika ada error.
                    }
                }
            } else {
                // Jika skrip Python tidak ditemukan di bundle aplikasi.
                DispatchQueue.main.async {
                    completion(nil) // Kembali dengan nil.
                }
            }
        }
    }

    /// Menampilkan panel penyimpanan `NSSavePanel` kepada pengguna untuk memilih lokasi penyimpanan file XLSX atau PDF.
    ///
    /// Fungsi ini mengatur judul panel penyimpanan, nama file awal, dan jenis konten yang diizinkan
    /// berdasarkan parameter `pdf`. Setelah pengguna memilih lokasi atau membatalkan, file sementara
    /// yang dihasilkan oleh skrip Python akan dipindahkan ke lokasi yang dipilih atau dihapus jika dibatalkan.
    /// Fungsi ini juga memperbarui label progres pada sheet yang aktif.
    ///
    /// - Parameters:
    ///   - xlsxFileURL: `URL` dari file sementara (XLSX atau PDF) yang akan disimpan.
    ///   - previousFileName: `String` yang digunakan sebagai dasar untuk nama file awal di panel penyimpanan (misalnya, nama file CSV asli).
    ///   - window: `NSWindow` induk tempat panel penyimpanan akan ditampilkan sebagai sheet.
    ///   - sheetWindow: `NSWindow` dari sheet progres yang sedang ditampilkan (akan diakhiri setelah panel penyimpanan muncul).
    ///   - pdf: `Bool` yang menunjukkan apakah file yang akan disimpan adalah PDF (`true`) atau XLSX (`false`).
    public static func promptToSaveXLSXFile(from xlsxFileURL: URL, previousFileName: String, window: NSWindow?, sheetWindow: NSWindow?, pdf: Bool) {
        // Pastikan operasi ini dijalankan di main thread karena melibatkan UI.
        DispatchQueue.main.async {
            let savePanel = NSSavePanel() // Membuat instance NSSavePanel.

            // Menentukan judul panel dan nama file awal berdasarkan jenis file (PDF atau XLSX).
            var title: String!
            var fileName: String
            if pdf {
                title = "Simpan File PDF..."
                fileName = "\(previousFileName).pdf"
            } else {
                title = "Simpan File XLSX..."
                fileName = "\(previousFileName).xlsx"
            }

            savePanel.title = title // Mengatur judul panel penyimpanan.
            savePanel.nameFieldStringValue = fileName // Mengatur nama file awal.

            // Ekstensi file dari fileName yang telah ditentukan.
            let fileExtension = (fileName as NSString).pathExtension.lowercased()

            // Menentukan `UTType` (Uniform Type Identifier) yang diizinkan berdasarkan ekstensi file.
            let allowedType: UTType? = switch fileExtension {
            case "pdf":
                .pdf
            case "xlsx":
                // Mencoba mendapatkan UTType dari ekstensi atau sebagai jenis yang diimpor.
                UTType(filenameExtension: "xlsx") ?? UTType(importedAs: "com.microsoft.excel.xlsx")
            case "xls":
                // Mencoba mendapatkan UTType dari ekstensi atau sebagai jenis yang diimpor.
                UTType(filenameExtension: "xls") ?? UTType(importedAs: "com.microsoft.excel.xls")
            default:
                nil // Tidak ada tipe spesifik yang diizinkan jika ekstensi tidak cocok.
            }

            if let allowedType {
                savePanel.allowedContentTypes = [allowedType] // Mengatur jenis konten yang diizinkan.
            } else {
                savePanel.allowedContentTypes = [] // Atau bisa juga `[.data]` untuk mengizinkan semua jenis data.
            }

            // Perbarui label progres pada sheet progres yang aktif.
            if let sheet = sheetWindow?.contentViewController as? ProgressBarVC {
                sheet.progressLabel.stringValue = "Pilih folder penyimpanan..."
            }

            // Tampilkan panel penyimpanan sebagai sheet modal dari jendela induk.
            if let window {
                window.endSheet(sheetWindow!) // Tutup sheet progres sebelum menampilkan panel penyimpanan.
                savePanel.beginSheetModal(for: window) { result in
                    if result == .OK, let saveURL = savePanel.url {
                        // Jika pengguna mengklik "Save" dan memilih lokasi.
                        do {
                            // Pindahkan file hasil (XLSX/PDF) dari lokasi sementara ke lokasi yang dipilih pengguna.
                            try FileManager.default.moveItem(at: xlsxFileURL, to: saveURL)
                        } catch {
                            // Tangani error jika gagal memindahkan file.
                            // Anda bisa menambahkan logging atau menampilkan NSAlert di sini.
                        }
                    } else {
                        // Jika pengguna membatalkan dialog penyimpanan.
                        do {
                            // Hapus file sementara karena tidak disimpan.
                            try FileManager.default.removeItem(at: xlsxFileURL)
                            // Tutup sheet progres (jika belum ditutup).
                            window.endSheet(sheetWindow!)
                        } catch {
                            // Tangani error jika gagal menghapus file sementara.
                        }
                    }
                }
            }
        }
    }

    // MARK: - FUNGSI-FUNGSI LAIN
    
    /// Memformat angka `Double` menjadi representasi `String` dengan pemisah ribuan dan hingga dua angka di belakang koma.
    ///
    /// Fungsi ini sangat berguna untuk menampilkan angka seperti nilai mata uang atau data numerik besar
    /// dalam format yang mudah dibaca oleh pengguna, mengikuti konvensi penulisan angka di Indonesia (menggunakan titik sebagai pemisah ribuan).
    ///
    /// - Parameter number: Angka `Double` yang ingin diformat.
    /// - Returns: `String` hasil pemformatan angka. Jika pemformatan gagal, akan mengembalikan representasi string dari angka asli.
    public static func formatNumber(_ number: Double) -> String {
        // Format angka dengan pemisah ribuan dan 2 digit setelah titik desimal
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.groupingSeparator = "."

        return numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    /// Mendapatkan instance `EditableTableView` dari dalam `NSTabViewItem` yang diberikan.
    ///
    /// Fungsi ini dirancang untuk menemukan `NSTableView` yang kemungkinan dibungkus dalam `NSScrollView`
    /// atau diletakkan langsung sebagai subview dalam `NSTabViewItem`.
    ///
    /// - Parameter item: `NSTabViewItem` tempat `EditableTableView` akan dicari.
    /// - Returns: Instance `EditableTableView` yang ditemukan di dalam `NSTabViewItem`.
    /// - Precondition: `NSTabViewItem` harus memiliki `view`. Jika tidak, `fatalError` akan dipicu.
    /// - Precondition: `EditableTableView` harus ditemukan sebagai subview langsung atau di dalam `NSScrollView`. Jika tidak, `fatalError` akan dipicu.
    static func getTableView(from item: NSTabViewItem) -> EditableTableView {
        guard let contentView = item.view else {
            fatalError("TabViewItem tidak memiliki view")
        }

        // Jika NSTableView dibungkus NSScrollView
        if let scrollView = contentView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
           let tableView = scrollView.documentView as? EditableTableView
        {
            return tableView
        }

        // Jika NSTableView langsung sebagai subview
        if let tableView = contentView.subviews.first(where: { $0 is NSTableView }) as? EditableTableView {
            return tableView
        }

        fatalError("Tidak menemukan NSTableView di TabViewItem")
    }

    /// Menentukan urutan dua string semester, dengan prioritas pada "1", lalu "2", dan kemudian urutan leksikografis.
    ///
    /// Fungsi ini dirancang untuk mengurutkan semester di mana "1" (Semester 1) selalu didahulukan,
    /// diikuti oleh "2" (Semester 2). Untuk semester lain, urutan akan ditentukan secara alfabetis (leksikografis).
    /// Ini berguna untuk pengurutan daftar semester secara logis dalam antarmuka pengguna atau laporan.
    ///
    /// - Parameters:
    ///   - semester1: String yang merepresentasikan semester pertama untuk dibandingkan.
    ///   - semester2: String yang merepresentasikan semester kedua untuk dibandingkan.
    /// - Returns: `true` jika `semester1` harus datang sebelum `semester2` dalam urutan, `false` jika sebaliknya.
    public static func semesterOrder(_ semester1: String, _ semester2: String) -> Bool {
        // Prioritaskan "1" sebagai semester paling awal
        if semester1 == "1" { return true }
        if semester2 == "1" { return false }
        // Prioritaskan "2" sebagai semester kedua setelah "1"
        if semester1 == "2" { return true }
        if semester2 == "2" { return false }
        // Untuk semester lainnya, urutkan secara leksikografis (alfabetis)
        return semester1 < semester2
    }

    /// Memformat string representasi semester menjadi nama yang lebih mudah dibaca.
    ///
    /// Fungsi ini mengubah string numerik "1" menjadi "Semester 1" dan "2" menjadi "Semester 2".
    /// Untuk string lain, ia akan mengembalikan string asli. Ini berguna untuk tampilan di UI.
    ///
    /// - Parameter semester: String semester yang ingin diformat (misalnya, "1", "2", "Ganjil 2024").
    /// - Returns: String semester yang sudah diformat (misalnya, "Semester 1", "Semester 2", atau string asli jika tidak "1" atau "2"). Mengembalikan string kosong jika input kosong.
    public static func formatSemesterName(_ semester: String) -> String {
        switch semester {
        case "1":
            "Semester 1"
        case "2":
            "Semester 2"
        default:
            // Jika string kosong, kembalikan string kosong. Jika tidak, kembalikan string asli.
            semester.isEmpty ? "" : "\(semester)"
        }
    }

    /// Pembersihan file sampah yang telah dibuat untuk digunakan oleh aplikasi.
    public static func cleanupTemporaryFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            for fileURL in fileURLs where fileURL.pathExtension == "png" {
                try? FileManager.default.removeItem(at: fileURL)
            }
            for fileURL in fileURLs where fileURL.pathExtension == "jpeg" {
                try? FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Membandingkan dua set nilai berdasarkan tipe data kolom dan kriteria pengurutan sekunder.
    ///
    /// Fungsi ini digunakan untuk tujuan pengurutan, misalnya dalam `NSTableView` atau daftar lainnya.
    /// Perbandingan utama dilakukan berdasarkan `column` dan `value` yang disediakan.
    /// Jika nilai utama sama, perbandingan sekunder akan dilakukan berdasarkan kolom "Nama Barang" dan "Lokasi"
    /// untuk memastikan urutan yang konsisten.
    ///
    /// - Parameters:
    ///   - value1: Kamus `[String: Any]` yang berisi data untuk item pertama yang akan dibandingkan. Diharapkan berisi kunci "column" (tipe `Column`) dan "value" (nilai utama).
    ///   - value2: Kamus `[String: Any]` yang berisi data untuk item kedua yang akan dibandingkan. Diharapkan berisi kunci "column" (tipe `Column`) dan "value" (nilai utama).
    /// - Returns: `ComparisonResult` yang menunjukkan hubungan urutan antara `value1` dan `value2`.
    ///            Mengembalikan `.orderedSame` jika input tidak valid (misalnya, kunci yang diperlukan tidak ada).
    @objc public static func compareValues(_ value1: [String: Any], _ value2: [String: Any]) -> ComparisonResult {
        guard let column = value1["column"] as? Column,
              let primaryValue1 = value1["value"],
              let primaryValue2 = value2["value"]
        else {
            return .orderedSame
        }

        // Fungsi helper untuk mendapatkan hasil perbandingan sekunder
        func getSecondaryComparison(_ item1: [String: Any], _ item2: [String: Any]) -> ComparisonResult {
            let secondaryColumns = ["Nama Barang", "Lokasi"]

            for secondaryColumn in secondaryColumns {
                if let col = SingletonData.columns.first(where: { $0.name == secondaryColumn }),
                   let val1 = item1[secondaryColumn],
                   let val2 = item2[secondaryColumn]
                {
                    let secondaryResult = compareValuesByType(col.type, val1, val2)
                    if secondaryResult != .orderedSame {
                        return secondaryResult
                    }
                }
            }
            return .orderedSame
        }

        // Fungsi helper untuk membandingkan nilai berdasarkan tipe
        func compareValuesByType(_ type: Any.Type, _ val1: Any, _ val2: Any) -> ComparisonResult {
            switch type {
            case is String.Type:
                return (val1 as? String ?? "").compare(val2 as? String ?? "")

            case is Int64.Type:
                let num1 = (val1 as? Int64) ?? 0
                let num2 = (val2 as? Int64) ?? 0
                return num1 < num2 ? .orderedAscending :
                    num1 > num2 ? .orderedDescending : .orderedSame

            case is Data.Type:
                let data1Size = (val1 as? Data)?.count ?? 0
                let data2Size = (val2 as? Data)?.count ?? 0
                let size1MB = Double(data1Size) / (1024 * 1024)
                let size2MB = Double(data2Size) / (1024 * 1024)

                return size1MB < size2MB ? .orderedAscending :
                    size1MB > size2MB ? .orderedDescending : .orderedSame

            default:
                return String(describing: val1).compare(String(describing: val2))
            }
        }

        // Bandingkan nilai utama
        let primaryResult = compareValuesByType(column.type, primaryValue1, primaryValue2)

        // Jika nilai utama sama, gunakan secondary sorting
        if primaryResult == .orderedSame,
           let item1 = value1["item"] as? [String: Any],
           let item2 = value2["item"] as? [String: Any]
        {
            return getSecondaryComparison(item1, item2)
        }

        return primaryResult
    }

    /// Membuat sebuah snapshot (salinan data) dari objek `Entity` yang ada ke dalam struktur `EntitySnapshot`.
    ///
    /// Fungsi ini bertujuan untuk membuat representasi data `Entity` yang bisa digunakan sebagai cadangan
    /// atau untuk tujuan lain yang membutuhkan salinan statis dari data `Entity` pada waktu tertentu seperti untuk digunakan undo/redo.
    /// Ini memastikan bahwa semua properti opsional (`Optional`) pada `Entity` akan memiliki nilai default
    /// yang sesuai (`"Lainnya"`, `""`, `"tanpa kategori"`, `Date()`, dll.) jika nilainya adalah `nil`.
    ///
    /// - Parameter entity: Objek `Entity` yang ingin dibuatkan snapshot-nya.
    /// - Returns: Sebuah instance `EntitySnapshot` yang berisi data dari `entity` yang diberikan.
    public static func createBackup(for entity: Entity) -> EntitySnapshot {
        EntitySnapshot(id: entity.id ?? UUID(), jenis: entity.jenis ?? "Lainnya", dari: entity.dari ?? "", jumlah: entity.jumlah, kategori: entity.kategori ?? "tanpa kategori", acara: entity.acara ?? "tanpa acara", keperluan: entity.keperluan ?? "tanpa keperluan", tanggal: entity.tanggal ?? Date(), bulan: entity.bulan, tahun: entity.tahun, ditandai: entity.ditandai)
    }

    // MARK: - STRING / DOUBLE / INT

    /// Mengubah format sebuah string berdasarkan parameter kapitalisasi yang diberikan.
    ///
    /// Fungsi ini membersihkan string dari spasi di awal atau akhir, lalu menerapkan pemformatan
    /// huruf besar (`uppercased()`) atau kapitalisasi setiap kata (`capitalized`) sesuai kebutuhan.
    /// Jika `newValue` kosong, `oldValue` akan digunakan sebagai input.
    ///
    /// - Parameters:
    ///   - newValue: String baru yang akan diformat.
    ///   - oldValue: String lama yang akan digunakan jika `newValue` kosong setelah pembersihan.
    ///   - hurufBesar: Jika `true`, seluruh string akan dikonversi menjadi huruf besar. Ini akan mengesampingkan parameter `kapital`.
    ///   - kapital: Jika `true` dan `hurufBesar` adalah `false`, setiap kata dalam string akan dimulai dengan huruf kapital.
    /// - Returns: String yang sudah diformat sesuai aturan `hurufBesar` atau `kapital`.
    public static func teksFormat(_ newValue: String, oldValue: String, hurufBesar: Bool, kapital: Bool) -> String {
        // Menghapus spasi dan baris baru di awal/akhir string
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        // Menentukan string input: jika 'trimmed' kosong, gunakan 'oldValue', jika tidak gunakan 'trimmed'
        let input = trimmed.isEmpty ? oldValue : trimmed

        // Menerapkan pemformatan berdasarkan parameter yang diberikan
        if hurufBesar {
            return input.uppercased() // Konversi seluruh string menjadi huruf besar
        } else if kapital {
            return input.capitalized // Mengkapitalisasi huruf pertama setiap kata
        } else {
            return input // Mengembalikan string tanpa perubahan kapitalisasi
        }
    }
    
    /// Mengonversi nilai Double menjadi format mata uang Rupiah Indonesia yang disingkat.
    /// - Parameter value: Nilai yang akan diformat.
    /// - Returns: String hasil format, menggunakan satuan "T" (triliun), "M" (miliar), "Jt" (juta), "Rb" (ribu), atau angka bulat jika kurang dari seribu.
    public static func rupiahCurrencyFormatter(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "%.2f T", value / 1_000_000_000_000)
        } else if value >= 1_000_000_000 {
            return String(format: "%.2f M", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.2f Jt", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.2f Rb", value / 1_000)
        } else {
            return "\(Int(value))"
        }
    }
    
    /// Membulatkan nilai minimum ke bawah dan nilai maksimum ke atas ke puluhan terdekat.
    /// - Parameter actualMin: Nilai minimum asli yang akan dibulatkan.
    /// - Parameter actualMax: Nilai maksimum asli yang akan dibulatkan.
    /// - Returns: Tuple berisi nilai minimum dan maksimum yang sudah dibulatkan.
    ///            Nilai minimum tidak akan kurang dari 0.
    public static func makeRoundedNumber(actualMin: Double, actualMax: Double) -> (Double, Double) {
        // Tambahkan guard untuk mencegah domain invalid
        guard actualMin < actualMax else {
            return (actualMin, actualMax + 1) // fallback
        }
        
        let range = actualMax - actualMin
        let padding = max(range * 0.1, 1) // Minimal padding 1 untuk menghindari domain 0

        let roundedMin = floor((actualMin - padding) / 10.0) * 10.0
        let roundedMax = ceil((actualMax + padding) / 10.0) * 10.0

        let finalMinDomain = max(0.0, roundedMin)
        
        return (finalMinDomain, roundedMax)
    }
    
    // MARK: - NSVIEW
    
    /// Mencari `NSViewController` terdekat dari rantai responder yang sesuai dengan tipe yang diberikan.
    ///
    /// Fungsi ini memulai pencarian dari `initialResponder` yang disediakan dan
    /// menelusuri rantai responder (`nextResponder`) hingga menemukan instance
    /// dari `NSViewController` yang cocok dengan `type` yang diminta.
    ///
    /// - Parameters:
    ///   - initialResponder: Responder awal untuk memulai pencarian. Ini bisa berupa
    ///     `NSView`, `NSWindow`, `NSViewController`, atau objek `NSResponder` lainnya.
    ///     Contoh penggunaan: `someView.nextResponder` atau `someWindow`.
    ///   - type: Tipe `NSViewController` spesifik yang dicari (misalnya, `MyCustomViewController.self`).
    ///     Penggunaan generik `<T>` memungkinkan fungsi ini untuk fleksibel mencari berbagai tipe `NSViewController`.
    ///
    /// - Returns: Instance dari `NSViewController` yang ditemukan dan sesuai dengan tipe `T`,
    ///     atau `nil` jika tidak ada `NSViewController` dari tipe tersebut yang ditemukan
    ///     dalam rantai responder dari `initialResponder`.
    static func findViewController<T: NSViewController>(from initialResponder: NSResponder?, ofType type: T.Type) -> T? {
        var responder: NSResponder? = initialResponder
        
        while let currentResponder = responder {
            // Memeriksa apakah responder saat ini adalah instance dari tipe NSViewController yang diminta.
            if let viewController = currentResponder as? T {
                return viewController // Jika cocok, kembalikan instance tersebut.
            }
            // Jika tidak cocok, lanjutkan ke responder berikutnya dalam rantai.
            responder = currentResponder.nextResponder
        }
        return nil // Jika seluruh rantai responder sudah ditelusuri dan tidak ada yang cocok, kembalikan nil.
    }

    /// Membuat gambar PNG dari sebuah objek `NSView` dengan faktor skala tertentu.
    ///
    /// Fungsi ini akan merender konten dari `NSView` ke dalam sebuah gambar bitmap dengan ukuran yang diperbesar sesuai `scaleFactor`,
    /// lalu mengonversinya menjadi data PNG. Cocok digunakan untuk menghasilkan gambar snapshot dari tampilan NSView dengan resolusi lebih tinggi.
    ///
    /// - Parameter nsView: Objek `NSView` yang akan dirender menjadi gambar.
    /// - Parameter scaleFactor: Faktor skala untuk memperbesar ukuran gambar hasil render. Misal, 2.0 untuk dua kali lebih besar.
    /// - Returns: Data gambar dalam format PNG jika berhasil, atau `nil` jika terjadi kesalahan (misal ukuran view nol atau proses render gagal).
    static func createImageFromNSView(_ nsView: NSView, scaleFactor: CGFloat) -> Data? {
        // Pastikan NSView memiliki ukuran frame yang valid
        guard nsView.frame.size.width > 0 && nsView.frame.size.height > 0 else {
            print("Error: stats NSView has zero dimensions.")
            return nil
        }
        
        // --- Bagian Perubahan untuk Memperbesar Ukuran ---
        let newSize = NSSize(width: nsView.bounds.size.width * scaleFactor,
                             height: nsView.bounds.size.height * scaleFactor)
        
        // Buat NSBitmapImageRep dengan ukuran yang diperbesar
        // Render konten NSView ke ukuran baru ini
        let bitmapRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(newSize.width),
                                         pixelsHigh: Int(newSize.height),
                                         bitsPerSample: 8, // Umumnya 8 bit per komponen warna
                                         samplesPerPixel: 4, // Termasuk Alpha (RGBA)
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .calibratedRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0)
        
        guard let finalBitmapRep = bitmapRep else {
            print("Gagal membuat NSBitmapImageRep dengan ukuran yang diperbesar.")
            return nil
        }
        // Atur NSGraphicsContext untuk menggambar ke bitmapRep
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: finalBitmapRep)
        NSGraphicsContext.current = context
        
        // --- PERBAIKAN DI SINI: Akses cgContext untuk transformasi ---
        if let cgContext = context?.cgContext {
            // Skalakan konteks grafis agar NSView digambar ke ukuran yang lebih besar
            // Gunakan CGAffineTransformScale atau cgContext.scaleBy()
            cgContext.scaleBy(x: scaleFactor, y: scaleFactor)
        } else {
            print("Gagal mendapatkan CGContext dari NSGraphicsContext.")
            NSGraphicsContext.restoreGraphicsState() // Pastikan status dikembalikan jika gagal
            return nil
        }
        
        // Gambar konten NSView ke dalam konteks yang sudah diskalakan
        nsView.displayIgnoringOpacity(nsView.bounds, in: context!)
        
        NSGraphicsContext.restoreGraphicsState()
        // --- Akhir Bagian Perubahan ---
        
        // Membuat NSImage dari NSBitmapImageRep yang sudah diperbesar
        let image = NSImage(size: newSize)
        image.addRepresentation(finalBitmapRep)
        
        // Konversi NSImage ke Data PNG
        if let imageData = image.tiffRepresentation,
           let imageRep = NSBitmapImageRep(data: imageData),
           let pngData = imageRep.representation(using: .png, properties: [:]) {
            return pngData
        } else {
            return nil
        }
    }
}
