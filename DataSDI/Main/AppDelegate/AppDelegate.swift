//
//  AppDelegate.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 19/10/23.
//

import AppKit

/// Implementasi `NSApplicationDelegate``.
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    /// Status item di Menu Bar
    private(set) var statusBarItem: NSStatusItem?
    /// Popover ``AddDetaildiKelas``.
    var popoverAddDataKelas: NSPopover?
    /// Popover ``NilaiKelas``.
    lazy var popoverTableNilaiSiswa: NSPopover? = {
        let popover = NSPopover()
        // Load NilaiSiswa XIB
        let nilaiSiswaVC = NilaiKelas(nibName: "NilaiKelas", bundle: nil)
        // Tampilkan NilaiSiswa sebagai popover
        popover.contentViewController = nilaiSiswaVC
        popover.behavior = .semitransient
        return popover
    }()

    /// Popover ``AddDataViewController``.
    var popoverAddSiswa: NSPopover?
    /// Jendela utama yang digunakan aplikasi.
    private(set) var mainWindow: NSWindow!
    /// Menu item untuk mengelompokkan data Administrasi dan Daftar Siswa.
    var groupMenuItem: NSMenuItem = .init()
    var helpWindow: NSWindowController?
    lazy var openedSiswaWindows: [Int64: DetilWindow] = [:]
    lazy var openedKelasWindows: [String: NSWindow] = [:]
    var openedAdminChart: NSWindow?
    /// Properti singleton ``OverlayEditorManager`` untuk prediksi pengetikan
    /// di dalam cell tableView.
    var editorManager: OverlayEditorManager!
    let userDefaults: UserDefaults = .standard
    var appAgent: String = ""
    var alert: NSAlert?
    var preferencesWindow: NSPanel?
    static var shared: AppDelegate {
        NSApp.delegate as! AppDelegate
    }

    let sharedDefaults: SharedPlist = .shared

    override init() {
        super.init()
        DatabaseController.createDataSiswaFolder()
        userDefaults.register(defaults: ["aplFirstLaunch": true])
    }

    func applicationDidFinishLaunching(_: Notification) {
        // 1. Pengaturan Awal (Sinkron)
        //    Ini adalah operasi yang cepat dan harus segera selesai saat aplikasi diluncurkan.
        userDefaults.register(defaults: [
            "IntegrasiUndoSiswaKelas": true,
            "showSuggestions": true,
            "showSuggestionsDiTabel": true,
            "maksimalSaran": 10,
            "grupTransaksi": false,
            "urutanTransaksi": "terbaru",
            "tampilkanSiswaLulus": true,
            "sembunyikanSiswaBerhenti": false,
            "sidebarVisibility": true,
            "autoCheckUpdates": true,
            "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints": false, // Pastikan hanya ada satu nilai
            "sidebarRingkasanKelas": "Kelas",
            "sidebarRingkasanGuru": "Guru",
            "sidebarRingkasanSiswa": "Siswa",
            "kapitalkanPengetikan": true,
        ])
        userDefaults.synchronize()

        mainWindow = NSApplication.shared.windows[0]

        // Pendaftaran NotificationCenter harus terjadi segera
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKeyNotification(_:)), name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: DatabaseController.siswaBaru, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey(_:)), name: NSWindow.didResignKeyNotification, object: nil)

        ReusableFunc.dateFormatter = DateFormatter()
        ReusableFunc.dateFormatter?.dateFormat = "dd MM yyyy"

        // Pengaturan gambar icon
        if let image = NSImage(systemSymbolName: "icloud.and.arrow.up", accessibilityDescription: .none) {
            ReusableFunc.cloudArrowUp = image.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)!
        }
        if let image = NSImage(systemSymbolName: "checkmark.icloud", accessibilityDescription: .none) {
            ReusableFunc.cloudCheckMark = image.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration)!
        }

        Task(priority: .medium) { @MainActor in
            self.setupUI()
            await Task.yield()
            self.salinHelper()
            self.prepareNotificationDelegate()
            self.grantNotificationPermission()
        }
        // 2. Operasi Latar Belakang (Asinkron)
        //    Jalankan semua pekerjaan berat di background untuk menjaga UI tetap responsif.
        Task.detached(priority: .low) { [weak self] in
            guard let self else { return }
            await Task.yield()
            await DatabaseController.shared.tabelNoRelationCleanup()
            // Gunakan TaskGroup untuk menjalankan operasi I/O secara konkuren
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await IdsCacheManager.shared.loadAllCaches()
                }
                group.addTask {
                    await ReusableFunc.updateSuggestions()
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    // Lanjutkan dengan operasi background lainnya setelah UI siap
                    if self.userDefaults.bool(forKey: "autoCheckUpdates") {
                        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "sdi.UpdateHelper")
                        if runningApps.first == nil {
                            await self.checkAppUpdates(true)
                        }
                    }
                }
            }
        }

        Task(priority: .low) { @MainActor in
            await Task.yield()
            DatabaseController.shared.deleteOldBackups()
            createFileMonitor()
            scheduleBackup()
        }
    }

    // 3. Pindahkan semua kode UI ke dalam metode terpisah
    private func setupUI() {
        // Pengaturan menu
        let editMenu = NSApp.mainMenu?.item(withTitle: "Edit")?.submenu
        ReusableFunc.undoMenuItem = editMenu?.items.first(where: { $0.identifier?.rawValue == "undo" })
        ReusableFunc.redoMenuItem = editMenu?.items.first(where: { $0.identifier?.rawValue == "redo" })
        ReusableFunc.salinMenuItem = editMenu?.items.first(where: { $0.identifier?.rawValue == "copy" })
        ReusableFunc.deleteMenuItem = editMenu?.items.first(where: { $0.identifier?.rawValue == "hapus" })
        ReusableFunc.pasteMenuItem = editMenu?.items.first(where: { $0.identifier?.rawValue == "paste" })
        let fileMenu = NSApp.mainMenu?.item(withTitle: "File")?.submenu
        ReusableFunc.newMenuItem = fileMenu?.items.first(where: { $0.identifier?.rawValue == "new" })

        // Pengaturan status bar
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button, let image = NSImage(systemSymbolName: "graduationcap.fill", accessibilityDescription: nil) {
            button.image = image
            button.toolTip = "Data SDI"
        }

        // Pembuatan menu status bar
        let menu = NSMenu()
        // Menu item 1: Input Nilai di Kelas
        let headerPrintMenuItem = NSMenuItem()
        let headerPrintMenu = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 22))

        let textFieldHeaderPrint = NSTextField(labelWithString: "Catat Data:")
        textFieldHeaderPrint.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        textFieldHeaderPrint.textColor = .secondaryLabelColor
        textFieldHeaderPrint.isBordered = false
        textFieldHeaderPrint.isEditable = false
        textFieldHeaderPrint.drawsBackground = false
        headerPrintMenu.addSubview(textFieldHeaderPrint)

        textFieldHeaderPrint.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textFieldHeaderPrint.leadingAnchor.constraint(equalTo: headerPrintMenu.leadingAnchor, constant: 14),
            textFieldHeaderPrint.trailingAnchor.constraint(equalTo: headerPrintMenu.trailingAnchor, constant: -8),
            textFieldHeaderPrint.centerYAnchor.constraint(equalTo: headerPrintMenu.centerYAnchor),
        ])

        headerPrintMenuItem.view = headerPrintMenu
        menu.addItem(headerPrintMenuItem)

        let menuItem1 = NSMenuItem(title: "Siswa Baru", action: #selector(showInputSiswaBaru), keyEquivalent: "")
        menuItem1.target = self
        menu.addItem(menuItem1)
        let menuItem2 = NSMenuItem(title: "Nilai Siswa di Kelas", action: #selector(showPopoverNilai(_:)), keyEquivalent: "")
        menuItem2.target = self
        menu.addItem(menuItem2)
        statusBarItem?.menu = menu

        // Pengaturan popover
        popoverAddSiswa = createPopover(forPopover: popoverAddSiswa)
        popoverAddDataKelas = createPopover1(
            withViewControllerIdentifier: NSStoryboard.SceneIdentifier("AddDetilDiKelas"),
            storyboardName: "AddDetaildiKelas",
            forPopover: popoverAddDataKelas
        )

        // Pengaturan operation queue
        ReusableFunc.operationQueue.maxConcurrentOperationCount = 1
        ReusableFunc.operationQueue.qualityOfService = .utility
    }

    /// Instance ``FileMonitor`` untuk mengawasi file database jika dihapus/diubah.
    var fileMonitor: FileMonitor?

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindow.makeKeyAndOrderFront(nil)
            return false
        } else {
            return true
        }
    }

    // Fungsi untuk menambahkan menu ke icon aplikasi di dock ketika diklik kanan
    func applicationDockMenu(_: NSApplication) -> NSMenu? {
        let dockMenu = NSMenu()

        let dockMenuItem = NSMenuItem(title: "Periksa Pembaruan", action: #selector(pembaruanManual(_:)), keyEquivalent: "")
        dockMenu.addItem(dockMenuItem)

        // You can add more menu items or customize the Dock menu as needed

        return dockMenu
    }

    @objc func windowDidResignKey(_ notification: Notification) {
        // Pastikan objek notifikasi adalah NSWindow
        guard let window = notification.object as? NSWindow else { return }

        // Periksa apakah window memiliki sheet yang aktif
        if window.attachedSheet == nil {
            // Jika ada sheet yang aktif, jangan akhiri pengeditan
            return
        }

        // Akhiri pengeditan untuk editor aktif di jendela itu
        window.endEditing(for: nil)
    }

    @objc func windowDidBecomeKeyNotification(_: Notification) {
        // Handle window did become key notification, update undo-redo menu items based on the active view controller.
        if let activeWindow = NSApp.keyWindow {
            if let splitViewController = activeWindow.contentViewController as? SplitVC {
                updateUndoRedoMenu(for: splitViewController)
            } else if (activeWindow.windowController as? DetilWindow) != nil {
                let viewController = activeWindow.contentViewController as? DetailSiswaController
                updateUndoRedoMenu(for: viewController ?? DetailSiswaController())
            } else {
                ReusableFunc.resetMenuItems()
            }
        }
    }

    /// Fungsi untuk memperbarui action dan target menu item di menu bar
    /// agar sesuai dengan contentView yang ditampilkan ``SplitVC``.
    /// - Parameter splitViewController: ``SplitVC`` yang akan ditangani.
    func updateUndoRedoMenu(for splitViewController: SplitVC) {
        guard let containerView = splitViewController.splitViewItems.first(where: { $0.viewController is ContainerSplitView })?.viewController as? ContainerSplitView else { return }
        let viewController = containerView.currentContentController
        // Pergi melalui setiap split view item dan temukan view controller yang sesuai
        if let kelasVC = viewController as? KelasVC {
            kelasVC.updateUndoRedo(self)
            kelasVC.updateMenuItem(self)
        } else if let siswaViewController = viewController as? SiswaViewController {
            siswaViewController.updateUndoRedo(self)
            siswaViewController.updateMenuItem(self)
        } else if let guruViewController = viewController as? TugasMapelVC {
            guruViewController.updateMenuItem(self)
            guruViewController.updateUndoRedo(self)
        } else if let inventory = viewController as? InventoryView {
            inventory.updateMenuItem(self)
            inventory.updateUndoRedo()
        } else if let transaksi = viewController as? TransaksiView {
            ReusableFunc.resetMenuItems()
            transaksi.updateMenuItem(self)
            transaksi.updateUndoRedo()
        } else if let jumlahSiswa = viewController as? JumlahSiswa {
            jumlahSiswa.updateMenuItem(self)
        } else if (viewController as? Struktur) != nil {
            ReusableFunc.resetMenuItems()
        } else if let jumlahTransaksi = viewController as? JumlahTransaksi {
            jumlahTransaksi.updateMenuItem(self)
        } else if let stats = viewController as? Stats {
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false, block: { timer in
                stats.setupToolbar()
                timer.invalidate()
            })
        } else if let guru = viewController as? GuruVC {
            ReusableFunc.resetMenuItems()
            guru.updateMenuItem()
            guru.setupToolbar()
            guru.updateUndoRedo(self)
        } else if let historiKelas = viewController as? KelasHistoryVC {
            ReusableFunc.resetMenuItems()
            historiKelas.updateMenuItem()
            historiKelas.setupToolbar()
        }
    }

    /// Fungsi untuk memperbarui action dan target menu item di menu bar ketika perpindahan
    /// keyWindow (jendela aktif) antara ``DetilWindow`` dan ``WindowController``.
    /// - Parameter anotherWindowController: DetailSiswaController.
    func updateUndoRedoMenu(for _: DetailSiswaController) {
        if let detilWindow = NSApp.keyWindow?.windowController as? DetilWindow {
            if let detailSiswaController = detilWindow.contentViewController as? DetailSiswaController {
                ReusableFunc.resetMenuItems()
                detailSiswaController.updateMenuItem(self)
                detailSiswaController.updateUndoRedo(self)
            }
        }
    }

    /// Action untuk menu item "Tampilkan Bantuan".
    /// - Parameter sender: Objek pemicu dapat berupa apapun.
    @IBAction func tampilkanBantuan(_ sender: Any?) {
        guard AppDelegate.shared.helpWindow == nil else {
            AppDelegate.shared.helpWindow?.window?.makeKeyAndOrderFront(sender)
            return
        }
        let storyboard = NSStoryboard(name: NSStoryboard.Name("HelpWindow"), bundle: nil)
        if let helpWindowController = storyboard.instantiateController(withIdentifier: "HelpWindowController") as? NSWindowController, let view = helpWindowController.contentViewController as? HelpViewController,
           let window = helpWindowController.window
        {
            // Set ukuran awal window
            window.setContentSize(NSSize(width: 450, height: 330))
            // Set initial window alpha value to 0 for fade-in animation
            view.view.window?.alphaValue = 0

            // Show window with animation
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2 // Animation duration
                view.view.window?.animator().alphaValue = 1 // Fade-in animation
            }, completionHandler: nil)

            view.view.window?.makeKeyAndOrderFront(nil)
            AppDelegate.shared.helpWindow = helpWindowController
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_: Notification) {
        DatabaseController.shared.checkPoint()

        if sharedDefaults.bool(forKey: "updateNanti", reload: true) == true {
            NSWorkspace.shared.open(URL(fileURLWithPath: appAgent))
        }

        if UserDefaults.standard.bool(forKey: "aplFirstLaunch") {
            UserDefaults.standard.setValue(false, forKey: "aplFirstLaunch")
        }

        if DataManager.shared.myUndoManager.canUndo {
            DataManager.shared.copyDatabaseToDocuments()
        }

        #if DEBUG
            try? FileManager.default.removeItem(at: DataManager.sourceURL)
            try? FileManager.default.removeItem(atPath: DataManager.sourceURL.path + "-shm")
            try? FileManager.default.removeItem(atPath: DataManager.sourceURL.path + "-wal")
        #endif

        FileManager.default.cleanupTempImages()

        ReusableFunc.cleanupTemporaryFiles()
    }

    // MARK: - Core Data stack

    /**
         Memuat persistent container untuk aplikasi.

         Properti ini secara lazy melakukan inisialisasi NSPersistentContainer dengan nama "Data Manager".
         Properti ini menangani proses penyalinan data awal dari lokasi penyimpanan iCloud (jika ada) ke lokasi penyimpanan lokal,
         serta membandingkan ukuran dan tanggal modifikasi file untuk memastikan data yang digunakan adalah yang terbaru.

         - Note: Properti ini menggunakan DispatchSemaphore untuk menunggu proses penyalinan selesai sebelum memuat persistent stores.
         - Warning: Pastikan untuk menangani potensi error yang mungkin terjadi selama proses penyalinan atau pemuatan persistent stores.
     */
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Data Manager")

        let fm = FileManager.default
        let source = DataManager.sourceURL
        let dest = DataManager.destURL
        var wait = false
        let semaphore = DispatchSemaphore(value: 0) // Untuk menunggu proses copy

        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            if !fm.fileExists(atPath: dest.path) {
                do {
                    let resourceValues = try dest.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
                    // Check if it's an iCloud item AND not downloaded
                    if let isUbiquitous = resourceValues.isUbiquitousItem, isUbiquitous {
                        if let downloadingStatus = resourceValues.ubiquitousItemDownloadingStatus {
                            switch downloadingStatus {
                            case .current:
                                // This case implies it's downloaded, but we are in !fileExists,
                                // so this path might not be taken often, or it means something is wrong
                                // if fileExists is false but status is .current.
                                // For safety, if it's .current, you might assume it's there or will be shortly.
                                break
                            case .downloaded:
                                // Similar to .current, implies it's downloaded.
                                break
                            case .notDownloaded:
                                // The file exists in iCloud but has not been downloaded to the local device.
                                DispatchQueue.main.async { [unowned self] in
                                    alert = nil
                                    alert = NSAlert()
                                    alert?.messageText = "Data Administrasi belum diunduh dari iCloud."
                                    alert?.informativeText = "Aplikasi dimuat lebih lama untuk menunggu data administrasi siap."
                                    alert?.runModal()
                                }
                                do {
                                    try fm.startDownloadingUbiquitousItem(at: dest)
                                    #if DEBUG
                                        print("Memulai unduhan dari iCloud...")
                                    #endif
                                    // Tunggu hingga file tersedia sebelum melanjutkan
                                    while !fm.fileExists(atPath: dest.path) {
                                        #if DEBUG
                                            print("Menunggu file selesai diunduh...")
                                        #endif
                                        sleep(1) // Polling setiap 1 detik
                                    }
                                } catch {
                                    #if DEBUG
                                        print("❌: \(error.localizedDescription)")
                                    #endif
                                }
                            default:
                                break
                            }
                        }
                    }
                } catch { print(error.localizedDescription) }
            }
            do {
                try? fm.removeItem(atPath: source.path + "-shm")
                try? fm.removeItem(atPath: source.path + "-wal")
                // Pastikan dest ada sebelum mengecek atributnya
                if fm.fileExists(atPath: dest.path) {
                    let sourceAttributes = try? fm.attributesOfItem(atPath: source.path)
                    let destAttributes = try? fm.attributesOfItem(atPath: dest.path)

                    // Ambil ukuran file dan tanggal modifikasi
                    let sourceSize = sourceAttributes?[.size] as? UInt64
                    let destSize = destAttributes?[.size] as? UInt64

                    let sourceDate = sourceAttributes?[.modificationDate] as? Date
                    let destDate = destAttributes?[.modificationDate] as? Date

                    // Periksa apakah ukuran dan tanggal modifikasi sama
                    if sourceSize != destSize || sourceDate != destDate {
                        wait = true
                        try? fm.removeItem(at: source)
                        try fm.copyItem(at: dest, to: source)
                    }
                }
            } catch {
                #if DEBUG
                    print("❌", error.localizedDescription)
                #endif
            }
            if wait {
                sleep(2) // Jeda 2 detik sebelum melanjutkan
            }
            semaphore.signal() // Selesai
        }

        // Tunggu sampai proses salin selesai
        semaphore.wait()

        container.loadPersistentStores(completionHandler: { storeDescription, error in
            if let error {
                print("❌", error.localizedDescription)
            } else {
                #if DEBUG
                    print("success", storeDescription)
                #endif
            }
        })
        return container
    }()

    // MARK: - Core Data Saving and Undo support

    // MARK: - JUMLAH SISWA SINGLETON DATASOURCE

    private var procDataDidChangeNotif: DispatchWorkItem?

    /// Fungsi untuk menjalankan pemrosesan ketika ada data tanggal berhenti atau tahun daftar
    /// siswa yang berubah dan memposting notifikasi ke ``JumlahSiswa`` untuk segera memperbarui
    /// kalkulasi.
    @objc func dataDidChange() {
        AppDelegate.shared.procDataDidChangeNotif?.cancel()
        let newWorkItem = DispatchWorkItem { [weak self] in
            self?.procDataDidChange()
        }
        AppDelegate.shared.procDataDidChangeNotif = newWorkItem
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1, execute: newWorkItem)
    }

    /**
         Menangani perubahan data yang dipicu oleh `procDataDidChange`.

         Fungsi ini dijalankan sebagai sebuah Task dengan prioritas background. Fungsi ini bertugas untuk:
         1. Mengambil data terbaru untuk TableView dari DatabaseController.
         2. Membandingkan data terbaru dengan data yang ada di SingletonData.
         3. Jika data berbeda, memperbarui SingletonData dengan data terbaru.
         4. Menunggu selama 0.1 detik (100 juta nanodetik) untuk memberikan jeda.
         5. Memposting notifikasi `jumlahSiswa` ke NotificationCenter.

         - Note: Fungsi ini menggunakan `[weak self]` untuk menghindari retain cycle.
         - Note: Penundaan (sleep) dilakukan untuk memberikan waktu bagi UI untuk memperbarui diri sebelum notifikasi diposting.
     */
    @objc func procDataDidChange() {
        Task(priority: .background) { [weak self] in
            guard self != nil else { return }
            let updatedMonthliData = await DatabaseController.shared.getDataForTableView()
            if updatedMonthliData != SingletonData.monthliData {
                SingletonData.monthliData = updatedMonthliData
                try? await Task.sleep(nanoseconds: 100_000_000)
                NotificationCenter.default.post(name: .jumlahSiswa, object: nil)
            }
        }
    }

    /// Action untuk menyimpan perubahan data administrasi.
    @IBAction func saveAction(_: AnyObject?) {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        let context = persistentContainer.viewContext

        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Customize this code block to include application-specific recovery steps.
                let nserror = error as NSError
                NSApplication.shared.presentError(nserror)
            }
        }
    }

//    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
//        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
//        return persistentContainer.viewContext.undoManager
//    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        SimpanData.shared.checkUnsavedData(sender)
    }

    /**
         Menyimpan perubahan data yang telah dilakukan.

         Fungsi ini menangani proses penyimpanan data, termasuk menampilkan peringatan jika tidak ada perubahan yang perlu disimpan,
         atau meminta konfirmasi kepada pengguna sebelum menyimpan perubahan yang tidak dapat dibatalkan.

         - Parameter:
            - sender: `NSMenuItem` yang memicu aksi penyimpanan.
     */
    @IBAction func save(_: NSMenuItem) {
        guard !(NSApp.keyWindow?.windowController is DetilWindow) else {
            if let window = NSApp.keyWindow?.windowController as? DetilWindow, let viewController = window.contentViewController as? DetailSiswaController {
                viewController.saveButton(self)
            }
            return
        }

        SimpanData.shared.simpanData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
