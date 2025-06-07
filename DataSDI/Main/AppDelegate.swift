//
//  AppDelegate.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 19/10/23.
//

import Cocoa
import SQLite

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem?
    private var popover1: NSPopover?
    private var popover2: NSPopover?
    private var mainWindow: NSWindow!
    private var progressWindowController: NSWindowController!
    private var progressViewController: ProgressBarVC!  // ViewController untuk progress bar
    let operationQueue = OperationQueue()
    var groupMenuItem = NSMenuItem()
    var helpWindow: NSWindowController?
    lazy var openedSiswaWindows: [Int64: DetilWindow] = [:]
    lazy var openedKelasWindows: [String: NSWindow] = [:]
    private var windowsNeedSaving = 0
    let userDefaults = UserDefaults.standard
    private let tempFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("update-list.csv")
    private let fileManager = FileManager.default
    private let libraryAgent = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".datasdi-update/agent/")
    var appAgent: String = ""
    var alert: NSAlert?
    var preferencesWindow: NSPanel?
    static var shared: AppDelegate {
        return NSApp.delegate as! AppDelegate
    }
    let sharedDefaults = SharedPlist.shared
    override init () {
        super.init()
        userDefaults.register(defaults: ["aplFirstLaunch": true])
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        userDefaults.register(defaults: ["NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints" : true])
        let defaultShowSuggestions: [String: Any] = ["showSuggestions": true]
        userDefaults.register(defaults: defaultShowSuggestions)
        let defaultShowSuggestionstTable: [String: Any] = ["showSuggestionsDiTabel": true]
        userDefaults.register(defaults: defaultShowSuggestionstTable)
        let defaultUpdateSemuaNamaGuru: [String: Any] = ["updateNamaGuruDiMapelDanKelasSama": false]
        userDefaults.register(defaults: defaultUpdateSemuaNamaGuru)
        userDefaults.register(defaults: ["tambahkanDaftarGuruBaru": true])
        userDefaults.register(defaults: ["timpaNamaGuruSebelumnya": false])
        userDefaults.register(defaults: ["maksimalSaran": 10])
        userDefaults.register(defaults: ["grupTransaksi": false])
        userDefaults.register(defaults: ["urutanTransaksi": "terbaru"])
        userDefaults.register(defaults: ["tampilkanSiswaLulus" : true])
        userDefaults.register(defaults: ["sembunyikanSiswaBerhenti" : false])
        userDefaults.register(defaults: ["sidebarVisibility" : true])
        userDefaults.register(defaults: ["autoCheckUpdates" : true])
        userDefaults.register(defaults: ["NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints": false])
        userDefaults.register(defaults: ["sidebarRingkasanKelas" : "Kelas"])
        userDefaults.register(defaults: ["sidebarRingkasanGuru" : "Guru"])
        userDefaults.register(defaults: ["sidebarRingkasanSiswa" : "Siswa"])
        userDefaults.synchronize()
        mainWindow = NSApplication.shared.windows[0]
        if let image = NSImage(systemSymbolName: "icloud.and.arrow.up", accessibilityDescription: .none),
           let largeImage = image.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration) {
            ReusableFunc.cloudArrowUp = largeImage
        }
        
        if let image = NSImage(systemSymbolName: "checkmark.icloud", accessibilityDescription: .none),
           let largeImage = image.withSymbolConfiguration(ReusableFunc.largeSymbolConfiguration) {
            ReusableFunc.cloudCheckMark = largeImage
        }

        DatabaseController.shared.deleteOldBackups()
        scheduleBackup()
        ReusableFunc.updateSuggestions()
        
        prepareNotificationDelegate()
        
        // Install Update-Helper untuk automasi pembaruan
        salinHelper()
        
        if userDefaults.bool(forKey: "autoCheckUpdates") {
            grantNotificationPermission()
            Task { [unowned self] in
                try? await Task.sleep(nanoseconds: 5000_000_000)
                let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "sdi.UpdateHelper")
                if runningApps.first == nil {
                    checkAppUpdates(true)
                }
            }
        }
        
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            if let image = NSImage(systemSymbolName: "graduationcap.fill", accessibilityDescription: nil) {
                button.image = image
            }
            button.toolTip = "Data SDI"
        }

        // Buat menu
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
            textFieldHeaderPrint.centerYAnchor.constraint(equalTo: headerPrintMenu.centerYAnchor)
        ])

        headerPrintMenuItem.view = headerPrintMenu
        menu.addItem(headerPrintMenuItem)
        

        // Menu item 2: Input Siswa Baru
        let menuItem1 = NSMenuItem(title: "Siswa Baru", action: #selector(showInputSiswaBaru), keyEquivalent: "")
        menuItem1.target = self
        menu.addItem(menuItem1)
        
        let menuItem2 = NSMenuItem(title: "Nilai Siswa di Kelas", action: #selector(showInputNilai), keyEquivalent: "")
        menuItem2.target = self
        menu.addItem(menuItem2)

        // Atur menu ke status item
        statusBarItem?.menu = menu
        
        operationQueue.qualityOfService = .utility
        operationQueue.maxConcurrentOperationCount = 1
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKeyNotification(_:)), name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: DatabaseController.tanggalBerhentiBerubah, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: DatabaseController.siswaBaru, object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowDidResignKey(_:)),
                                               name: NSWindow.didResignKeyNotification,
                                               object: nil)
        createFileMonitor()
        guard let mainMenu = NSApp.mainMenu,
              let viewMenuItem = mainMenu.items.first(where: {$0.identifier?.rawValue == "view"}),
              let viewMenu = viewMenuItem.submenu,
              let groupMenuItem = viewMenu.items.first(where: { $0.identifier?.rawValue == "gunakanGrup" }) else {
            return
        }
        self.groupMenuItem = groupMenuItem
    }
    
    private func salinHelper() {
        let fileManager = FileManager.default
        appAgent = libraryAgent.path + "/UpdateHelper.app"
        let appBundlePath = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/UpdateHelper.app")
        
        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: "sdi.UpdateHelper").first {
            // Coba terminasi secara normal
            if !runningApp.terminate() {
                #if DEBUG
                print("Mencoba force terminate...")
                #endif
                runningApp.forceTerminate()
            } else {
                #if DEBUG
                print("Aplikasi berhasil dihentikan.")
                #endif
            }
            
            // Tunggu sampai aplikasi benar-benar sudah berhenti
            while !runningApp.isTerminated {
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
            #if DEBUG
            print("UpdateHelper telah benar-benar dihentikan.")
            #endif
        }

        func getBundleVersion(at url: URL) -> String? {
            guard let bundle = Bundle(url: url),
                  let version = bundle.infoDictionary?["CFBundleVersion"] as? String else {
                return nil
            }
            return version
        }

        let versionInAppBundle = getBundleVersion(at: appBundlePath)
        let versionInLibrary = getBundleVersion(at: libraryAgent.appendingPathComponent("/UpdateHelper.app"))

        var shouldCopy = false

        if !fileManager.fileExists(atPath: appAgent) {
            shouldCopy = true
        } else if let versionApp = versionInAppBundle, let versionLib = versionInLibrary, versionApp.compare(versionLib, options: .numeric) == .orderedDescending {
            // Versi di appBundle lebih baru
            do {
                try fileManager.removeItem(atPath: appAgent)
                shouldCopy = true
            } catch {
                print("❌: \(error.localizedDescription)")
            }
        }

        if shouldCopy {
            do {
                try fileManager.createDirectory(at: libraryAgent, withIntermediateDirectories: true, attributes: nil)
                if fileManager.fileExists(atPath: appAgent) {
                    try fileManager.removeItem(atPath: appAgent)
                }
                try fileManager.copyItem(atPath: appBundlePath.path, toPath: appAgent)
                #if DEBUG
                print("✅ UpdateHelper berhasil disalin (baru atau versi lebih baru).")
                #endif
            } catch {
                print("❌: \(error.localizedDescription)")
            }
        } else {
            print("ℹ️ UpdateHelper sudah ada dan versi terbaru.")
        }
    }
    
    func checkAppUpdates(_ atLaunch: Bool) {
        if self.sharedDefaults.bool(forKey: "updateNanti", reload: true) == true && !atLaunch {
            DispatchQueue.main.async {
                ReusableFunc.showAlert(title: "Pembaruan telah diunduh", message: "Pembaruan akan diinstal ketika aplikasi ditutup.")
            }
            return
        }
        self.fetchCSVData(from: "https://drive.google.com/uc?export=view&id=1X-gRNUHtZZTp4HYfJkbFPSWVFtqhyJmO") { [weak self] updates in
            guard let self = self, let (version, build, link) = updates else { return }
            // Versi aplikasi saat ini
            let currentVersion = Int(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0") ?? 0
            let currentBuild = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0

            // Gabungkan semua release notes
            var shouldUpdate: Bool = false
            var url: URL!
            
            if version > currentVersion || (version == currentVersion && build > currentBuild) {
                url = link
                self.sharedDefaults.set(link.absoluteString, forKey: "link")
                self.sharedDefaults.set(version, forKey: "newVersion")
                self.sharedDefaults.set(build, forKey: "newBuild")
                shouldUpdate = true
            } else {
                print("currentVersion: \(currentVersion) (\(currentBuild), newVersion: \(version) (\(build)")
            }
            
            if atLaunch,
               let skipVersion = self.sharedDefaults.integer(forKey: "skipVersion"),
               let skipBuild = self.sharedDefaults.integer(forKey: "skipBuild"),
               let newVersion = self.sharedDefaults.integer(forKey: "newVersion"),
               let newBuild = self.sharedDefaults.integer(forKey: "newBuild"),
               skipVersion != 0 && skipBuild != 0,
               (newVersion <= skipVersion && newBuild <= skipBuild) {
                return
            }
            
            if atLaunch && shouldUpdate {
                self.notifUpdateAvailable(url, currentVersion: currentVersion, currentBuild: currentBuild)
                return
            }
            
            if !atLaunch && !shouldUpdate {
                self.notifNotAvailableUpdate()
            }
            
            if !atLaunch && shouldUpdate {
                self.sharedDefaults.set(currentVersion, forKey: "currentVersion")
                self.sharedDefaults.set(currentBuild, forKey: "currentBuild")
                self.sharedDefaults.set(url.absoluteString, forKey: "link")
                NSWorkspace.shared.open(URL(fileURLWithPath: self.appAgent))
            }
            
            do {
                if FileManager.default.fileExists(atPath: self.tempFilePath.path) {
                    try FileManager.default.removeItem(at: self.tempFilePath)
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func fetchCSVData(from urlString: String, completion: @escaping ((Int, Int, URL)?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        // Mulai download file
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                print("Error downloading file: \(error)")
                completion(nil)
                return
            }

            guard let tempURL = tempURL else {
                print("Temp URL is nil")
                completion(nil)
                return
            }
            
            do {
                if FileManager.default.fileExists(atPath: self.tempFilePath.path) {
                    try FileManager.default.removeItem(at: self.tempFilePath)
                }
                // Pindahkan file dari URL temporary ke tempFilePath
                try FileManager.default.moveItem(at: tempURL, to: self.tempFilePath)

                // Baca file CSV dari tempFilePath
                let content = try String(contentsOf: self.tempFilePath, encoding: .utf8)

                // Normalisasi newline: ganti semua `\r\n` (Windows-style) menjadi `\n` (Unix-style)
                let normalizedContent = content.replacingOccurrences(of: "\r\n", with: "\n")

                // Parsing CSV
                let rows = normalizedContent.split(separator: "\n")
                guard let firstRow = rows.first else {
                    completion(nil)
                    return
                }

                let columns = firstRow.split(separator: ";")
                if let version = Int(columns[0]),
                   let build = Int(columns[1]),
                   let link = URL(string: String(columns[2])) {
                    completion((version, build, link))
                } else {
                    completion(nil)
                }
            } catch {
                print("Error reading file: \(error)")
                completion(nil)
            }
        }
        task.resume()
    }

    private func createFileMonitor() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataSiswaFolderURL = documentsDirectory.appendingPathComponent("Data SDI")
        let dbFilePath = dataSiswaFolderURL.appendingPathComponent("data.sqlite3").path
        
        fileMonitor = FileMonitor(filePath: dbFilePath) { [weak self] in
            self?.handleFileChange()
        }
    }
    
    var fileMonitor: FileMonitor?
    
    private func handleFileChange() {
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.notify(queue: .main) { [unowned self] in
            self.fileMonitor = nil
            alert = nil
            alert = NSAlert()
            alert?.messageText = "Perubahan Terdeteksi pada File"
            alert?.informativeText = "File mungkin belum sepenuhnya diunduh dari iCloud Drive atau sedang dalam proses modifikasi. Selesaikan proses unduhan atau modifikasi file terlebih dahulu. Jika tidak ada file baru, aplikasi akan membuat file baru dan mereset data."
            alert?.alertStyle = .critical
            alert?.addButton(withTitle: "OK")
            alert?.addButton(withTitle: "Tutup Aplikasi")
            let response = alert?.runModal()
            if response == .alertFirstButtonReturn {
                dispatchGroup.enter()
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let dataSiswaFolderURL = documentsDirectory.appendingPathComponent("Data SDI")
                let dbFilePath = dataSiswaFolderURL.appendingPathComponent("data.sqlite3").path
                DatabaseController.shared.reloadDatabase(withNewPath: dbFilePath)
                dispatchGroup.leave()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dispatchGroup.enter()
                    NotificationCenter.default.post(name: .saveData, object: nil)
                    dispatchGroup.leave()
                    // Reinisialisasi FileMonitor untuk file baru
                    if FileManager.default.fileExists(atPath: dbFilePath) {
                        if self.fileMonitor != nil {
                            self.fileMonitor = nil
                        }
                        self.createFileMonitor()
                        Task {
                            await SuggestionCacheManager.shared.clearCache()
                        }
                    }
                }
            } else {
                dispatchGroup.enter()
                DispatchQueue.global(qos: .userInitiated).sync {
                    DatabaseController.shared.siapkanTabel()
                    dispatchGroup.leave()
                }
                
                dispatchGroup.notify(queue: .main) {
                    NSApp.terminate(nil)
                }
            }
        }
    }
    
    @IBAction func pembaruanManual(_ sender: Any) {
        checkAppUpdates(false)
    }
    
    @IBAction func clearSuggestionsTable(_ sender: Any) {
        Task {
            await SuggestionCacheManager.shared.clearCache()
        }
    }
    // Fungsi untuk menambahkan menu ke icon aplikasi di dock ketika diklik kanan
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
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
    
    @objc func windowDidBecomeKeyNotification(_ notification: Notification) {
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
    func updateUndoRedoMenu(for splitViewController: SplitVC) {
        guard let containerView = splitViewController.splitViewItems.first(where: {$0.viewController is ContainerSplitView})?.viewController as? ContainerSplitView else { return }
        let viewController = containerView.currentContentController
        // Pergi melalui setiap split view item dan temukan view controller yang sesuai
        if let kelasVC = viewController as? KelasVC {
            kelasVC.updateUndoRedo(self)
            kelasVC.updateMenuItem(self)
        } else if let siswaViewController = viewController as? SiswaViewController {
            siswaViewController.updateUndoRedo(self)
            siswaViewController.updateMenuItem(self)
        } else if let guruViewController = viewController as? GuruViewController {
            guruViewController.updateMenuItem(self)
            guruViewController.updateUndoRedo(self)
        } else if let invetory = viewController as? InventoryView {
            invetory.updateMenuItem(self)
            invetory.updateUndoRedo()
        } else if let transaksi = viewController as? TransaksiView {
            ReusableFunc.resetMenuItems()
            transaksi.updateMenuItem(self)
            transaksi.updateUndoRedo()
        } else if let jumlahSiswa = viewController as? JumlahSiswa {
            jumlahSiswa.updateMenuItem(self)
        } else if ((viewController as? Struktur) != nil) {
            ReusableFunc.resetMenuItems()
        } else if let jumlahTransaksi = viewController as? JumlahTransaksi {
            jumlahTransaksi.updateMenuItem(self)
        } else if let stats = viewController as? Stats {
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false, block: { timer in
                stats.setupToolbar()
                timer.invalidate()
            })
        }
    }
    
    func updateUndoRedoMenu(for anotherWindowController: DetailSiswaController) {
        if let detilWindow = NSApp.keyWindow?.windowController as? DetilWindow {
            if let detailSiswaController = detilWindow.contentViewController as? DetailSiswaController {
                detailSiswaController.resetMenuItems()
                detailSiswaController.updateMenuItem(self)
                detailSiswaController.updateUndoRedo(self)
            }
        }
    }

    func findMenuItem(in menu: NSMenu, withIdentifier identifier: String) -> NSMenuItem? {
        for item in menu.items {
            if let submenu = item.submenu {
                // Cari dalam submenu rekursif
                if let foundItem = findMenuItem(in: submenu, withIdentifier: identifier) {
                    return foundItem
                }
            } else if item.identifier?.rawValue == identifier {
                // Menu item ditemukan
                return item
            }
        }
        // Menu item tidak ditemukan di menu dan sub-menu
        return nil
    }
    @objc func showInputNilai() {
        // Tampilkan popover1 seperti sebelumnya
        if let button = statusBarItem?.button {
            popover1 = createPopover1(
                withViewControllerIdentifier: NSStoryboard.SceneIdentifier("AddDetilDiKelas"),
                storyboardName: "AddDetaildiKelas",
                forPopover: popover1
            )
            popover1?.behavior = .semitransient
            popover1?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc func showInputSiswaBaru() {
        // Tampilkan popover2 seperti sebelumnya
        if let button = statusBarItem?.button {
            popover2 = createPopover(forPopover: popover2)
            popover2?.behavior = .semitransient
            popover2?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func createPopover(forPopover popover: NSPopover?) -> NSPopover? {
        let viewController = AddDataViewController(nibName: "AddData", bundle: nil)

        let newPopover = NSPopover()
        newPopover.contentViewController = viewController
        newPopover.behavior = .transient
        return newPopover
    }
    func createPopover1(withViewControllerIdentifier identifier: NSStoryboard.SceneIdentifier, storyboardName: String, forPopover popover: NSPopover?) -> NSPopover? {
        guard let viewController = NSStoryboard(name: NSStoryboard.Name(storyboardName), bundle: nil)
            .instantiateController(withIdentifier: identifier) as? AddDetaildiKelas else {
            return nil
        }
        viewController.appDelegate = true
        let newPopover = NSPopover()
        newPopover.contentViewController = viewController
        newPopover.behavior = .transient
        return newPopover
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindow.makeKeyAndOrderFront(nil)
            return false
        } else {
            return true
        }
    }
    
    
    func scheduleBackup() {
        let calendar = Calendar.current
        let currentDate = Date()
        
        // Check if today is the first day of the month
        if calendar.component(.day, from: currentDate) == 1 {
            // If yes, schedule the backup
            Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(backup), userInfo: nil, repeats: false)
        } else {
            
        }
    }

    @objc func backup() {
        DatabaseController.shared.backupDatabase()
    }
    
    @IBAction func tampilkanBantuan(_ sender: Any?) {
        guard AppDelegate.shared.helpWindow == nil else {
            AppDelegate.shared.helpWindow?.window?.makeKeyAndOrderFront(sender)
            return
        }
        let storyboard = NSStoryboard(name: NSStoryboard.Name("HelpWindow"), bundle: nil)
        if let helpWindowController = storyboard.instantiateController(withIdentifier: "HelpWindowController") as? NSWindowController, let view = helpWindowController.contentViewController as? HelpViewController,
           let window = helpWindowController.window {
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
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        DatabaseController.shared.checkPoint()
        if self.sharedDefaults.bool(forKey: "updateNanti", reload: true) == true {
            NSWorkspace.shared.open(URL(fileURLWithPath: self.appAgent))
        }
        if UserDefaults.standard.bool(forKey: "aplFirstLaunch") {
            UserDefaults.standard.setValue(false, forKey: "aplFirstLaunch")
        }
        if DataManager.shared.myUndoManager.canUndo {
            DataManager.shared.copyDatabaseToDocuments()
        }
        FileManager.default.cleanupTempImages()
        ReusableFunc.cleanupTemporaryFiles()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Core Data stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Data Manager")
        
        let fm = FileManager.default
        let source = DataManager.sourceURL
        let dest = DataManager.destURL
        var wait: Bool = false
        let semaphore = DispatchSemaphore(value: 0) // Untuk menunggu proses copy
        
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            if !fm.fileExists(atPath: dest.path) {
                if fm.ubiquityIdentityToken != nil {
                    DispatchQueue.main.async { [unowned self] in
                        self.alert = nil
                        self.alert = NSAlert()
                        self.alert?.messageText = "Data Administrasi di iCloud belum diunduh."
                        self.alert?.informativeText = "Data administrasi lebih lama ditampilkan karena menunggu unduhan selesai. Sekarang data sudah diunduh dan siap digunakan."
                        self.alert?.runModal()
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
                }
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

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                print("❌", error.localizedDescription)
            } else {
                print("success", storeDescription)
            }
        })
        return container
    }()

    // MARK: - Core Data Saving and Undo support
    // MARK: - JUMLAH SISWA SINGLETON DATASOURCE
    private var procDataDidChangeNotif: DispatchWorkItem?
    @objc private func dataDidChange() {
        AppDelegate.shared.procDataDidChangeNotif?.cancel()
        let newWorkItem = DispatchWorkItem { [weak self] in
            self?.procDataDidChange()
        }
        AppDelegate.shared.procDataDidChangeNotif = newWorkItem
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1, execute: newWorkItem)
    }
    @objc private func procDataDidChange() {
        Task(priority: .background) { [weak self] in
            guard self != nil else {return}
            let updatedMonthliData = await DatabaseController.shared.getDataForTableView()
            if updatedMonthliData != SingletonData.monthliData {
                SingletonData.monthliData = updatedMonthliData
                try? await Task.sleep(nanoseconds: 100_000_000)
                NotificationCenter.default.post(name: .jumlahSiswa, object: nil)
            }
        }
    }
    @IBAction func saveAction(_ sender: AnyObject?) {
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
        let calculate = calculateTotalDeletedData()
        // Membuat instance dari ProgressWindowController menggunakan storyboard atau XIB
        
        let openWindows = NSApplication.shared.windows
        windowsNeedSaving = 0
        for window in openWindows {
            if let viewController = window.contentViewController as? DetailSiswaController {
                if viewController.dataButuhDisimpan {
                    viewController.saveDataWillTerminate(sender)
                    windowsNeedSaving += 1
                }
            }
        }
        if windowsNeedSaving > 0 {
            NotificationCenter.default.addObserver(self,selector: #selector(checkAllDataSaved), name: Notification.Name("DataSaved"), object: nil)
            return .terminateLater
        }
        if calculate != 0 {
            let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil)
            
            // Memastikan ProgressWindowController terhubung dengan benar
            if let progressWindowController = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController, let progressViewController = progressWindowController.contentViewController as? ProgressBarVC {
                
                // Simpan referensi ke controller untuk digunakan nanti
                self.progressWindowController = progressWindowController
                self.progressViewController = progressViewController
                // Menampilkan jendela progress
                showAlert("Data terbaru belum disimpan.", informativeText: "Semua perubahan data akan disimpan dan perubahan tidak dapat diurungkan setelah konfirmasi OK", tutupApp: true, window: mainWindow)
                
                return .terminateLater  // Menunda terminasi sampai proses selesai
            } else {
                
            }
        }
        // If we got here, it is time to quit.
        return .terminateNow
    }
    
    @objc func checkAllDataSaved() {
        windowsNeedSaving -= 1
        if windowsNeedSaving == 0 {
            // Semua data telah disimpan, lanjutkan menutup aplikasi
            DatabaseController.shared.vacuumDatabase()
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
    }
    
    func calculateTotalDeletedData() -> Int {
        let deletedDataArrayCount = SingletonData.deletedDataArray.reduce(0) { $0 + $1.data.count }
        let pastedDataCount = SingletonData.pastedData.reduce(0) { $0 + $1.data.count }
        let deletedDataKelasCount = SingletonData.deletedDataKelas.reduce(0) { $0 + $1.data.count }
        let deletedSiswasArrayCount = SingletonData.deletedSiswasArray.reduce(0) { $0 + $1.count }
        let deletedSiswaArrayCount = SingletonData.deletedSiswaArray.count
        let siswaNaik = SingletonData.siswaNaikArray.reduce(0) { total, current in
            // Hanya menghitung jika siswaID tidak kosong
            total + (current.siswaID.isEmpty ? 0 : current.siswaID.count)
        }
        let undoTambahSiswa = SingletonData.undoAddSiswaArray.reduce(0) { $0 + $1.count }
        let undoPasteSiswa = SingletonData.redoPastedSiswaArray.reduce(0) { $0 + $1.count }
        let hapusInventory = SingletonData.deletedInvID.count
        let hapusKolomInventory = SingletonData.deletedColumns.reduce(0) {$0 + $1.columnName.count }
        let undoAddKolomInventory = SingletonData.undoAddColumns.reduce(0) {$0 + $1.columnName.count }
        
        
        // let undoStackCount = SingletonData.undoStack.reduce(0) { $0 + $1.value.count }
        
        let hapusGuru = SingletonData.deletedGuru.count + SingletonData.undoAddGuru.count
        
        return deletedDataArrayCount + pastedDataCount + deletedDataKelasCount /* + undoStackCount */ + deletedSiswasArrayCount + deletedSiswaArrayCount + siswaNaik + hapusGuru + hapusInventory + hapusKolomInventory + undoAddKolomInventory + undoTambahSiswa + undoPasteSiswa
    }
    
    @IBAction func save(_ sender: NSMenuItem) {
        guard !(NSApp.keyWindow?.windowController is DetilWindow) else {
            if let window = NSApp.keyWindow?.windowController as? DetilWindow, let viewController = window.contentViewController as? DetailSiswaController {
                viewController.saveButton(self)
            }
            return
        }
        let calculate = calculateTotalDeletedData()
        guard calculate != 0 else {
            alert = nil
            alert = NSAlert()
            alert?.icon = NSImage(systemSymbolName: "checkmark.icloud.fill", accessibilityDescription: .none)
            alert?.messageText = "Data yang tersedia telah diperbarui"
            alert?.informativeText = "Tidak ditemukan perubahan data yang belum disimpan. Semua modifikasi terbaru telah berhasil tersimpan di basis data."
            alert?.addButton(withTitle: "OK")
            if let window = NSApplication.shared.mainWindow {
                // Menampilkan alert sebagai sheet dari jendela utama
                alert?.beginSheetModal(for: window) { (response) in
                    if response == .alertFirstButtonReturn {
                        window.endSheet(window, returnCode: .cancel)
                        NSApp.reply(toApplicationShouldTerminate: false)
                    }
                }
            }
            return
        }
        guard let mainWindow = NSApp.mainWindow else {
            showAlert("Konfirmasi Penyimpanan Perubahan",
                      informativeText: "Perubahan terbaru yang telah dilakukan tidak dapat dibatalkan setelah Anda mengonfirmasi dengan menekan tombol OK.",
                      tutupApp: false,
                      window: nil)
            return
        }
        
        showAlert("Konfirmasi Penyimpanan Perubahan", informativeText: "Perubahan terbaru yang telah dilakukan tidak dapat dibatalkan setelah Anda mengonfirmasi dengan menekan tombol OK.", tutupApp: false, window: mainWindow)
    }
    
    func showAlert(_ messageText: String, informativeText: String, tutupApp: Bool, window: NSWindow?) {
        alert = nil
        alert = NSAlert()
        if messageText.isEmpty {
            alert?.messageText = "Konfirmasi Penyimpanan Perubahan"
        } else {
            alert?.messageText = messageText
        }
        
        if informativeText.isEmpty {
            alert?.informativeText = "Perubahan terbaru yang telah dilakukan tidak dapat dibatalkan setelah Anda mengonfirmasi dengan menekan tombol OK."
        } else {
            alert?.informativeText = informativeText
        }
        alert?.icon = ReusableFunc.cloudArrowUp
        alert?.alertStyle = .critical
        alert?.addButton(withTitle: "OK")
        alert?.addButton(withTitle: "Batalkan")
        alert?.addButton(withTitle: "Batalkan & Tutup Aplikasi")
        
        if let mainWindow = window, mainWindow.isVisible {
            
            // Menampilkan alert sebagai sheet dari jendela utama
            alert?.beginSheetModal(for: mainWindow) { [self] (response) in
                handleAlertResponse(response, tutupApp: tutupApp, window: mainWindow)
            }
        } else {
            // Tampilkan sebagai panel jika main window invisible
            
            let response = (alert?.runModal())!
            handleAlertResponse(response, tutupApp: tutupApp, window: window ?? NSWindow())
        }
    }

    private func handleAlertResponse(_ response: NSApplication.ModalResponse, tutupApp: Bool, window: NSWindow) {
        switch response {
        case .alertFirstButtonReturn:
            simpanPerubahan(tutupApp: tutupApp)
        case .alertSecondButtonReturn:
            NSApp.reply(toApplicationShouldTerminate: false)
        case .alertThirdButtonReturn:
            NSApp.reply(toApplicationShouldTerminate: true)
        default:
            break
        }
    }

    func simpanPerubahan(tutupApp: Bool) {
        let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil)
        guard let progressWindowController = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController,
              let progressViewController = progressWindowController.contentViewController as? ProgressBarVC else {
            return
        }
        
        self.progressWindowController = progressWindowController
        self.progressViewController = progressViewController
        
        if let progressWindow = progressWindowController.window {
            if let mainWindow = NSApp.mainWindow, mainWindow.isVisible {
                // Jika main window visible, tampilkan sebagai sheet
                mainWindow.beginSheet(progressWindow)
            } else {
                // Jika main window invisible, tampilkan sebagai panel biasa
                progressWindow.center() // Posisikan di tengah layar
                progressWindow.makeKeyAndOrderFront(nil)
            }
        }
        
        let totalDeletedData = calculateTotalDeletedData()

        guard totalDeletedData > 0 else {
            handleNoDataToDelete(tutupApp: tutupApp)
            return
        }

        self.progressViewController.totalStudentsToUpdate = totalDeletedData

        let allDataToDelete = gatherAllDataToDelete()

        operationQueue.addOperation {
            // Tentukan update frequency seperti di KelasVC
            let updateFrequency = totalDeletedData > 100 ? max(totalDeletedData / 10, 1) : 1
            var processedDeletedCount = 0
            
            for (_, item) in allDataToDelete.enumerated() {
                self.processDeleteItem(item)
                processedDeletedCount += 1
                
                // Update progress berdasarkan interval
                if processedDeletedCount % updateFrequency == 0 || processedDeletedCount == totalDeletedData {
                    OperationQueue.main.addOperation {
                        self.progressViewController.currentStudentIndex = processedDeletedCount
                    }
                }
            }

            // Selesaikan penghapusan
            self.finishDeletion(totalDeletedData: totalDeletedData, tutupApp: tutupApp)
        }
    }

    private func handleNoDataToDelete(tutupApp: Bool) {
        self.progressViewController.totalStudentsToUpdate = 1
        self.progressViewController.currentStudentIndex = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.stopModal()
            NSApp.reply(toApplicationShouldTerminate: tutupApp)
        }
    }

    private func gatherAllDataToDelete() -> [(table: Table?, kelasAwal: String?, kelasDikecualikan: String?, kelasID: Int64, isHapusKelas: Bool, isSiswaNaik: Bool, hapusGuru: Bool, hapusInventory: Bool, hapusKolomInventory: Bool, namaKolomInventory: String)] {
        var allDataToDelete = [(table: Table?, kelasAwal: String?, kelasDikecualikan: String?, kelasID: Int64, isHapusKelas: Bool, isSiswaNaik: Bool, hapusGuru: Bool, hapusInventory: Bool, hapusKolomInventory: Bool, namaKolomInventory: String)]()
        
        
        // MARK:- SISWA DATA
        // Mengumpulkan data dari deletedSiswasArray
        for deletedSiswaArrayItem in SingletonData.deletedSiswasArray {
            allDataToDelete.append(contentsOf: deletedSiswaArrayItem.map { (table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.id, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "") })
        }
        for undoAddSiswaArrayItem in SingletonData.undoAddSiswaArray {
            allDataToDelete.append(contentsOf: undoAddSiswaArrayItem.map { (table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.id, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "") })
        }
        
        for deletedSiswaArrayItem in SingletonData.redoPastedSiswaArray {
            allDataToDelete.append(contentsOf: deletedSiswaArrayItem.map { (table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.id, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "") })
        }
        // Mengumpulkan data dari deletedSiswaArray
        allDataToDelete.append(contentsOf: SingletonData.deletedSiswaArray.map { (table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.id, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "") })
        
        // Mengumpulkan data dari pastedData
        for pastedDataItem in SingletonData.pastedData {
            let currentClassTable = pastedDataItem.table
            let dataArray = pastedDataItem.data
            allDataToDelete.append(contentsOf: dataArray.map { (table: currentClassTable, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.kelasID, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "") })
        }

        
        // MARK:- KELAS DATA
        // Mengumpulkan data dari deletedDataArray
        for deletedData in SingletonData.deletedDataArray {
            let currentClassTable = deletedData.table
            let dataArray = deletedData.data
            allDataToDelete.append(contentsOf: dataArray.map { (table: currentClassTable, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.kelasID, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "") })
        }
        
        // Mengumpulkan data dari deletedDataKelas
        for deletedName in SingletonData.deletedDataKelas {
            let classTable = deletedName.table
            let data = deletedName.data
            allDataToDelete.append(contentsOf: data.map { (table: classTable, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.kelasID, isHapusKelas: true, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "") })
        }
        
        // Mengumpulkan data dari undoStack
//        for (key, dataArrayList) in SingletonData.undoStack {
//            let currentClassTable: Table?
//
//            // Tentukan tabel berdasarkan kunci
//            switch key {
//            case "Kelas 1", "Kelas 2", "Kelas 3", "Kelas 4", "Kelas 5", "Kelas 6":
//                currentClassTable = Table(key.lowercased().replacingOccurrences(of: " ", with: ""))
//            default:
//
//                continue
//            }
//
//            for dataArray in dataArrayList {
//                allDataToDelete.append(contentsOf: dataArray.map { (table: currentClassTable, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.kelasID, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "") })
//            }
//        }
        
        
        // MARK: - DATA SISWA DAN KELAS
        for siswa in SingletonData.siswaNaikArray {
            // Ambil siswaID, kelasAwal, dan kelasDikecualikan dari tuple
            let siswaIDs = siswa.siswaID
            let kelasAwal = siswa.kelasAwal.first // Mengambil kelas awal pertama jika ada
            let kelasDikecualikan = siswa.kelasDikecualikan.first // Mengambil kelas dikecualikan pertama jika ada
            
            // Iterasi melalui setiap siswaID
            for id in siswaIDs {
                allDataToDelete.append((table: nil, kelasAwal: kelasAwal, kelasDikecualikan: kelasDikecualikan, kelasID: id, isHapusKelas: false, isSiswaNaik: true, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: ""))
            }
        }
        
        
        
        // MARK:- GURU DATA
        for guruID in SingletonData.deletedGuru {
            allDataToDelete.append((table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: guruID, isHapusKelas: false, isSiswaNaik: false, hapusGuru: true, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: ""))
        }
        
        for guruID in SingletonData.undoAddGuru {
            allDataToDelete.append((table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: guruID, isHapusKelas: false, isSiswaNaik: false, hapusGuru: true, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: ""))
        }
        
        
        
        // MARK: - INVENTORY
        for invID in SingletonData.deletedInvID {
            allDataToDelete.append((table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: invID, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: true, hapusKolomInventory: false, namaKolomInventory: ""))
        }
        
        for (columnName, _) in SingletonData.deletedColumns {
            allDataToDelete.append((table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: -1, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: true, namaKolomInventory: columnName))
        }
        for (columnName, _) in SingletonData.undoAddColumns {
            allDataToDelete.append((table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: -1, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: true, namaKolomInventory: columnName))
        }
        
        return allDataToDelete
    }

    private func processDeleteItem(_ item: (table: Table?, kelasAwal: String?, kelasDikecualikan: String?, kelasID: Int64, isHapusKelas: Bool, isSiswaNaik: Bool, hapusGuru: Bool, hapusInventory: Bool, hapusKolomInventory: Bool, namaKolomInventory: String)) {
        if item.hapusGuru == true && item.hapusInventory == false {
            DatabaseController.shared.hapusGuru(idGuruValue: item.kelasID)
        } else if item.isHapusKelas {
            DatabaseController.shared.hapusDataKelas(kelasID: item.kelasID, fromTabel: item.table ?? Table("Kelas"))
        } else if let table = item.table {
            DatabaseController.shared.deleteDataFromKelas(table: table, kelasID: item.kelasID)
        } else if item.isSiswaNaik == false && item.hapusInventory == false && item.hapusKolomInventory == false {
            DatabaseController.shared.hapusDaftar(idValue: item.kelasID)
        } else if item.isSiswaNaik == true && item.hapusInventory == false && item.hapusKolomInventory == false {
            DatabaseController.shared.processSiswaNaik()
        } else if item.hapusInventory == true && item.hapusKolomInventory == false {
            Task {
                await DynamicTable.shared.setupDatabase()
                await DynamicTable.shared.deleteData(withID: item.kelasID)
            }
        } else if item.hapusKolomInventory == true {
            Task {
                await DynamicTable.shared.setupDatabase()
                await DynamicTable.shared.deleteColumn(tableName: "main_table", columnName: item.namaKolomInventory)
            }
        }
    }

    private func finishDeletion(totalDeletedData: Int, tutupApp: Bool) {
        OperationQueue.main.addOperation {
            if let window = self.progressWindowController.window {
                self.progressViewController.currentStudentIndex = totalDeletedData
                if tutupApp {
                    DatabaseController.shared.notifQueue.async {
                        DatabaseController.shared.vacuumDatabase()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            NSApp.mainWindow?.endSheet(window)
                            window.close()  // Menutup jendela progress
                            NSApp.reply(toApplicationShouldTerminate: true)
                        }
                    }
                } else {
                    DatabaseController.shared.notifQueue.async {
                    self.clearDeletedData()
                    DatabaseController.shared.vacuumDatabase()
                    NotificationCenter.default.post(name: .saveData, object: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            NSApp.mainWindow?.endSheet(window)
                            window.close()  // Menutup jendela progress
                            NSApp.reply(toApplicationShouldTerminate: false)
                            ReusableFunc.showProgressWindow(3, pesan: "\(totalDeletedData) pembaruan berhasil disimpan", image: NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: .none) ?? ReusableFunc.menuOnStateImage!)
                        }
                    }
                }
            }
        }
    }

    private func clearDeletedData() {
        SingletonData.deletedStudentIDs.removeAll()
        SingletonData.deletedKelasAndSiswaIDs.removeAll()
        SingletonData.deletedDataArray.removeAll()
        SingletonData.pastedData.removeAll()
        SingletonData.deletedDataKelas.removeAll()
        SingletonData.undoStack.removeAll()
        SingletonData.deletedSiswasArray.removeAll()
        SingletonData.deletedSiswaArray.removeAll()
        SingletonData.siswaNaikArray.removeAll()
        SingletonData.siswaNaikId.removeAll()
        SingletonData.deletedGuru.removeAll()
        SingletonData.undoAddGuru.removeAll()
        SingletonData.deletedColumns.removeAll()
        SingletonData.deletedInvID.removeAll()
        SingletonData.undoAddColumns.removeAll()
        SingletonData.redoPastedSiswaArray.removeAll()
        SingletonData.undoAddSiswaArray.removeAll()
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
