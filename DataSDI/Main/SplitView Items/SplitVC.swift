//
//  SplitVC.swift
//  Data Manager
//
//  Created by Bismillah on 13/11/23.
//

import Cocoa
import SwiftUI

/// Class ini mengelola tampilan split view utama aplikasi.
/// Ini mengatur sidebar dan konten utama, serta menangani interaksi dengan menu dan toolbar.
class SplitVC: NSSplitViewController {
    /// Sidebar item yang berisi sidebar view controller.
    weak var sidebarItem: NSSplitViewItem?
    /// Kontainer view yang berisi konten utama aplikasi.
    weak var contentContainerView: NSSplitViewItem?

    private var workItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        saveOriginalMenuItems()
        setupViewControllers()
    }

    /// Menyiapkan view controller untuk sidebar dan konten utama.
    /// Ini membuat instance dari `SidebarViewController` dan `ContainerSplitView`,
    /// lalu menambahkannya ke split view controller.
    func setupViewControllers() {
        let sidebarVC = SidebarViewController(nibName: "Sidebar", bundle: nil)
        let sidebar = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem = sidebar

        if let sidebarItem {
            addSplitViewItem(sidebarItem)
            sidebarItem.titlebarSeparatorStyle = .automatic
            sidebarItem.allowsFullHeightLayout = true
            sidebarItem.minimumThickness = 135
        }

        let containerVC = ContainerSplitView(nibName: "ContainerSplitView", bundle: nil)
        let splitViewItem = NSSplitViewItem(viewController: containerVC)
        contentContainerView = splitViewItem

        if let contentContainerView {
            addSplitViewItem(contentContainerView)
            contentContainerView.titlebarSeparatorStyle = .shadow

            // Set sidebar delegate
            if let sidebarViewController = sidebarItem?.viewController as? SidebarViewController {
                sidebarViewController.delegate = contentContainerView.viewController as? SidebarDelegate
            }
        }
        // Mengatur delegate untuk split view controller agar dapat menangani perubahan ukuran dan interaksi lainnya.
        splitView.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        splitView.autosaveName = "splitViewConf"
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let toolbar = view.window?.toolbar,
           let simpanToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "simpan" })
        {
            simpanToolbarItem.isEnabled = true
            simpanToolbarItem.target = self
            simpanToolbarItem.action = #selector(saveData(_:))
        }

        setupMainMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(updateToolbarImage(_:)), name: .bisaUndo, object: nil)
    }

    /// Menyimpan item menu asli untuk digunakan nanti, seperti undo, redo, copy, paste, delete, dan new.
    /// Ini penting untuk mengembalikan fungsi asli dari menu tersebut jika diperlukan.
    /// Fungsi ini hanya akan dijalankan sekali, berkat pengecekan `SingletonData.savedMenuItemDefaults`.
    func saveOriginalMenuItems() {
        guard !SingletonData.savedMenuItemDefaults else { return }
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
              let new = fileMenuItem.items.first(where: { $0.identifier?.rawValue == "new" }) else { return }

        SingletonData.originalUndoTarget = undoMenuItem.target as AnyObject?
        SingletonData.originalUndoAction = undoMenuItem.action
        SingletonData.originalRedoTarget = redoMenuItem.target as AnyObject?
        SingletonData.originalRedoAction = redoMenuItem.action
        SingletonData.originalCopyTarget = copyMenuItem.target as AnyObject?
        SingletonData.originalCopyAction = copyMenuItem.action
        SingletonData.originalPasteTarget = pasteMenuItem.target as AnyObject?
        SingletonData.originalPasteAction = pasteMenuItem.action
        SingletonData.originalDeleteTarget = deleteMenuItem.target as AnyObject?
        SingletonData.originalDeleteAction = deleteMenuItem.action
        SingletonData.savedMenuItemDefaults = true

        SingletonData.originalNewTarget = new.target as AnyObject?
        SingletonData.originalNewAction = new.action
    }

    /// Fungsi ini menangani aksi penyimpanan data ketika item toolbar "simpan" ditekan.
    @objc func saveData(_ sender: Any) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.save(sender as? NSMenuItem ?? NSMenuItem())
        }
    }

    /// Fungsi ini menangani pembaruan gambar toolbar berdasarkan jumlah data yang dihapus.
    /// Jika ada data yang dihapus, gambar toolbar akan diubah menjadi ikon upload cloud.
    /// Jika tidak ada data yang dihapus, gambar akan diubah menjadi ikon centang cloud.
    /// - Parameter notification: Notification yang diterima ketika ada perubahan pada jumlah data yang dihapus.
    @objc func updateToolbarImage(_: Notification) {
        workItem?.cancel()
        workItem = DispatchWorkItem {
            let calculate = SimpanData.shared.calculateTotalDeletedData()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let window = AppDelegate.shared.mainWindow.windowController as? WindowController else { return }
                if calculate != 0 {
                    if let simpanToolbarItem = window.simpanToolbar.view as? NSButton {
                        if simpanToolbarItem.image != ReusableFunc.cloudArrowUp {
                            simpanToolbarItem.image = ReusableFunc.cloudArrowUp
                        }
                    }
                } else {
                    if let simpanToolbarItem = window.simpanToolbar.view as? NSButton {
                        if simpanToolbarItem.image != ReusableFunc.cloudCheckMark {
                            simpanToolbarItem.image = ReusableFunc.cloudCheckMark
                        }
                    }
                }
            }
        }
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.1, execute: workItem!)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .bisaUndo, object: nil)
    }
}

extension SplitVC: NSWindowDelegate {
    /// Fungsi ini membuka panel preferensi ketika item menu "Pengaturan" dipilih.
    /// Jika panel sudah terbuka, fungsi ini akan menjadikannya key window dan menampilkannya.
    /// Jika panel belum terbuka, fungsi ini akan membuat instance baru dari `PreferensiView` dan menampilkannya dalam sebuah `NSPanel`.
    /// Panel ini akan ditempatkan di pojok kiri atas layar yang terlihat.
    /// - Parameter sender: Item menu yang memicu pembukaan panel preferensi.
    /// - Note: Pastikan untuk mengatur target dari item menu "Pengaturan" ke instansi `SplitVC` ini agar fungsi ini dapat dipanggil.
    /// - Note: Fungsi ini juga mengatur delegate dari panel untuk menangani penutupan panel dengan benar.
    @objc func openPreferencesPanel() {
        // Jika window preferensi sudah terbuka, jadikan key window dan tampilkan
        if let existingWindowController = AppDelegate.shared.preferencesWindow {
            existingWindowController.makeKeyAndOrderFront(nil)
            return // Keluar dari fungsi karena panel sudah terbuka
        }

        let hostingController = NSHostingController(rootView: PreferensiView())
        let window = NSPanel(contentViewController: hostingController)
        window.styleMask.insert([.titled, .closable, .resizable, .fullSizeContentView])
        window.styleMask.remove([.miniaturizable])
        window.title = "Pengaturan"
        window.titlebarAppearsTransparent = false
        window.hidesOnDeactivate = false
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .line
        window.collectionBehavior = [.managed, .participatesInCycle]
        window.setContentSize(NSSize(width: 350, height: 500))

        // Tempatkan window di pojok kiri atas layar yang terlihat
        if let screenVisibleFrame = NSScreen.main?.visibleFrame {
            let windowHeight = window.frame.height
            // visibleFrame.origin adalah titik kiri bawah,
            // sehingga posisi baru menjadi:
            // x = screen.origin.x (pojok kiri)
            // y = screen.origin.y + screen.height - windowHeight (pojok atas, tepat di bawah menu)
            let newOrigin = NSPoint(x: screenVisibleFrame.origin.x + 10,
                                    y: screenVisibleFrame.origin.y + screenVisibleFrame.height - windowHeight - 10)
            window.setFrameOrigin(newOrigin)
        } else {
            window.center() // fallback jika visibleFrame tidak tersedia
        }

        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        AppDelegate.shared.preferencesWindow = window
    }

    /// Fungsi ini mengatur item menu "Pengaturan" di menu utama aplikasi.
    /// Ini memastikan bahwa item menu tersebut diaktifkan dan mengarah ke fungsi `openPreferencesPanel`.
    /// Fungsi ini juga mengatur target dari item menu agar dapat memanggil fungsi `openPreferencesPanel` pada instansi `SplitVC`.
    /// - Note: Pastikan untuk memanggil fungsi ini setelah menu utama aplikasi telah diinisialisasi.
    func setupMainMenu() {
        guard let mainMenu = NSApp.mainMenu,
              let appMenuItem = mainMenu.items.first(where: { $0.identifier?.rawValue == "app" }),
              let appMenu = appMenuItem.submenu,
              let preferencesMenuItem = appMenu.items.first(where: { $0.identifier?.rawValue == "preferences" })
        else { return }

        preferencesMenuItem.isEnabled = true
        preferencesMenuItem.action = #selector(openPreferencesPanel)
        // Target harus diatur ke instansi SplitVC yang aktif
        // Ini penting karena `openPreferencesPanel` adalah metode instansi
        // Asumsikan SplitVC adalah NSViewController yang dapat diakses
        preferencesMenuItem.target = self
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSPanel, window == AppDelegate.shared.preferencesWindow {
            if let contentView = AppDelegate.shared.preferencesWindow?.contentView {
                for view in contentView.subviews {
                    view.subviews.removeAll()
                    view.removeFromSuperviewWithoutNeedingDisplay()
                }
            }
            AppDelegate.shared.preferencesWindow = nil
        }
    }
}
