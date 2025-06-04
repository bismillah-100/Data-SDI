//
//  SplitViewController.swift
//  Data Manager
//
//  Created by Bismillah on 13/11/23.
//

import Cocoa
class SplitVC: NSSplitViewController, SidebarDelegate, WindowControllerDelegate {
    func increaseSize() {
        
    }
    func decreaseSize() {
    }
    var isSidebarHidden = false
    var siswaViewController: SiswaViewController!
    var guruViewController: GuruViewController!
    var kelasVC: KelasVC!
    var jumlahSiswa: JumlahSiswa!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Mendapatkan referensi ke child view controllers dari NSSplitViewController
        guard
            let sidebarViewController = splitViewItems.first?.viewController as? SidebarViewController,
            let siswaViewController = splitViewItems.first(where: { $0.viewController is SiswaViewController })?.viewController as? SiswaViewController,
            let guruViewController = splitViewItems.first(where: { $0.viewController is GuruViewController })?.viewController as? GuruViewController
            let jumlahSiswa = splitViewItems.first(where: { $0.viewController is JumlahSiswa})?. viewController as? JumlahSiswa
        else {
            fatalError("Child view controllers not found in the NSSplitViewController.")
        }

        // Cek apakah KelasVC ada di splitViewItems
        if let kelasVCItem = splitViewItems.first(where: { $0.viewController is KelasVC }) {
            kelasVC = kelasVCItem.viewController as? KelasVC
            addSplitViewItem(NSSplitViewItem(viewController: kelasVC))
        }
        
        // Set sidebar delegate
        sidebarViewController.delegate = self
        
        // Inisialisasi view controllers
        self.siswaViewController = siswaViewController
        self.guruViewController = guruViewController
        self.jumlahSiswa = jumlahSiswa
        splitView.autosaveName = "splitViewConf"
        // Tampilkan tampilan siswa secara default
        didSelectSidebarItem(index: 1)
    }
    
    // Implementasi dari SidebarDelegate
    func didSelectSidebarItem(index: Int) {
        // Implementasikan logika untuk menyesuaikan tampilan di NSSplitViewController
        // Berdasarkan pemilihan di sidebar (index)
        if index == 1 {
            showViewController(siswaViewController)
        } else if index == 2 {
            showViewController(guruViewController)
        } else if index >= 3 && index <= 8 {
            kelasVC?.tabView.selectTabViewItem(at: index - 3)
            showViewController(kelasVC)
        }
    }
    func didSelectKelasItem(index: Int) {
        // Implementasi logika untuk menyesuaikan tampilan di NSSplitViewController
        // Berdasarkan pemilihan kelas di sidebar (index)
        if index >= 1 && index <= 6 {
            kelasVC?.tabView.selectTabViewItem(at: index - 1)
            showViewController(kelasVC)
            NotificationCenter.default.post(name: .enableStatsAndCSVButtons, object: nil)
        }
    }

    private func showViewController(_ viewController: NSViewController) {
        // Hapus semua split view items yang terkait dengan viewController
        splitViewItems.removeAll { $0.viewController == kelasVC || $0.viewController == siswaViewController || $0.viewController == guruViewController }
        
        // Buat NSSplitViewItem baru
        let splitViewItem = NSSplitViewItem(viewController: viewController)
        addSplitViewItem(splitViewItem)
        
        // Jika terdapat lebih dari dua split view items, hapus yang terakhir
        if splitViewItems.count > 2 {
            if let lastSplitViewItem = splitViewItems.last,
               lastSplitViewItem.viewController != viewController {
                removeSplitViewItem(lastSplitViewItem)
            }
        }
        // Posting notifikasi untuk menonaktifkan tombol-tombol
        if viewController is SiswaViewController || viewController is GuruViewController {
            NotificationCenter.default.post(name: .disableButtons, object: nil)
        } else if let kelasVC = viewController as? KelasVC {
            NotificationCenter.default.post(name: .enableStatsAndCSVButtons, object: kelasVC)
        }
    }
    func searchSiswa(_ searchText: String) {
        siswaViewController.searchSiswa(searchText)
    }
    @objc override func toggleSidebar(_ sender: Any?) {
        isSidebarHidden.toggle()
        adjustSidebarVisibility()
    }
    
    func adjustSidebarVisibility() {
        if isSidebarHidden {
            // Sembunyikan sidebar
            splitViewItems.first?.isCollapsed = true
        } else {
            // Tampilkan sidebar
            splitViewItems.first?.isCollapsed = false
        }
    }
}

extension SplitVC: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.toggleSidebar]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.toggleSidebar]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.target = self
        toolbarItem.action = #selector(toggleSidebar(_:))
        
        switch itemIdentifier {
        case .toggleSidebar:
            toolbarItem.label = "Toggle Sidebar"
            toolbarItem.image = NSImage(named: NSImage.touchBarSidebarTemplateName)
        default:
            return nil
        }
        
        return toolbarItem
    }
}
