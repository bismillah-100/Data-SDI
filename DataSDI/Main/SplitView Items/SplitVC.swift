//
//  SplitViewController.swift
//  Data Manager
//
//  Created by Bismillah on 13/11/23.
//

import Cocoa
import SwiftUI

class SplitVC: NSSplitViewController {
    weak var sidebarItem: NSSplitViewItem?
    weak var contentContainerView: NSSplitViewItem?
    private var window: NSWindow?

    override func viewDidLoad() {
        super.viewDidLoad()
//        if windowIdentifier == nil {
//            setWindowIdentifier(UUID().uuidString)
//        }
        saveOriginalMenuItems()
        setupViewControllers()
    }
    
    private func setupViewControllers() {
        let sidebarVC = SidebarViewController(nibName: "Sidebar", bundle: nil)
        let sidebar = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem = sidebar
        
        if let sidebarItem = sidebarItem {
            addSplitViewItem(sidebarItem)
            sidebarItem.titlebarSeparatorStyle = .automatic
            sidebarItem.allowsFullHeightLayout = true
            sidebarItem.minimumThickness = 135
        }
        
        let containerVC = ContainerSplitView(nibName: "ContainerSplitView", bundle: nil)
        let splitViewItem = NSSplitViewItem(viewController: containerVC)
        contentContainerView = splitViewItem
        
        if let contentContainerView = contentContainerView {
            self.addSplitViewItem(contentContainerView)
            contentContainerView.titlebarSeparatorStyle = .shadow
        
            // Set sidebar delegate
            if let sidebarViewController = sidebarItem?.viewController as? SidebarViewController {
                sidebarViewController.delegate = contentContainerView.viewController as? SidebarDelegate
            }
        }
        
        splitView.delegate = self
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        splitView.autosaveName = "splitViewConf"

    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if let toolbar = view.window?.toolbar,
           let simpanToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "simpan" }) {
            simpanToolbarItem.isEnabled = true
            simpanToolbarItem.target = self
            simpanToolbarItem.action = #selector(saveData(_:))
        }
        
        setupMainMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(updateToolbarImage(_:)), name: .bisaUndo, object: nil)
    }
    
    func saveOriginalMenuItems() {
        guard !SingletonData.savedMenuItemDefaults else {return}
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
              let new = fileMenuItem.items.first(where: {$0.identifier?.rawValue == "new"}) else { return }
        
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
    
    @objc func saveData(_ sender: Any) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.save(sender as? NSMenuItem ?? NSMenuItem())
        }
    }
    
    @objc func updateToolbarImage(_ notification: Notification) {
        let calculate = AppDelegate.shared.calculateTotalDeletedData()
        if calculate != 0 {
            if let toolbar = self.view.window?.toolbar, let simpanToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "simpan" }) {
                if simpanToolbarItem.image != ReusableFunc.cloudArrowUp {
                    simpanToolbarItem.image = ReusableFunc.cloudArrowUp
                }
            }
        } else {
            if let toolbar = self.view.window?.toolbar, let simpanToolbarItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "simpan" }) {
                if simpanToolbarItem.image != ReusableFunc.cloudCheckMark {
                    simpanToolbarItem.image = ReusableFunc.cloudCheckMark
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .bisaUndo, object: nil)
    }
}


extension SplitVC: NSWindowDelegate {
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
            window.center()  // fallback jika visibleFrame tidak tersedia
        }
        
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        AppDelegate.shared.preferencesWindow = window
    }
    
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
            AppDelegate.shared.preferencesWindow = nil
        }
    }
}
