//
//  Menu Bar.swift
//  Data SDI
//
//  Created by MacBook on 08/08/25.
//

import Cocoa

extension AppDelegate: NSPopoverDelegate {
    @objc func showPopoverNilai(_: Any?) {
        ReusableFunc.resetMenuItems()
        if let button = statusBarItem?.button,
           let popover = popoverAddDataKelas
        {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Membuka popover ``AddDetaildiKelas``.
    func showInputNilai(_ kelas: Int? = nil) {
        if popoverAddDataKelas == nil {
            popoverAddDataKelas = createPopover1(
                withViewControllerIdentifier: NSStoryboard.SceneIdentifier("AddDetilDiKelas"),
                storyboardName: "AddDetaildiKelas",
                forPopover: popoverAddDataKelas
            )
        }
        showPopoverNilai(self)

        if let addNilai = popoverAddDataKelas?.contentViewController as? AddDetaildiKelas {
            addNilai.kelasPopUpButton.isEnabled = true
            addNilai.statusSiswaKelas.isEnabled = true
            addNilai.dataArray.removeAll()
            if let kelas {
                addNilai.tabKelas(index: kelas)
            }
        }
    }

    /// Membuka popover ``AddDataViewController``.
    @objc func showInputSiswaBaru() {
        ReusableFunc.resetMenuItems()
        // Tampilkan popover2 seperti sebelumnya
        if let button = statusBarItem?.button {
            if popoverAddSiswa == nil {
                popoverAddSiswa = createPopover(forPopover: popoverAddSiswa)
                popoverAddSiswa?.behavior = .semitransient
            }
            popoverAddSiswa?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /**
     Membuat sebuah popover baru untuk menampilkan konten `AddDataViewController`.

     - Parameter popover: Popover yang ada (opsional). Parameter ini tidak digunakan dalam implementasi fungsi ini.
     - Returns: Sebuah instance `NSPopover` yang telah dikonfigurasi dengan `AddDataViewController` sebagai kontennya, atau `nil` jika pembuatan popover gagal. Popover ini memiliki perilaku `.transient`, yang berarti akan menutup secara otomatis ketika pengguna berinteraksi di luar popover.
     */
    func createPopover(forPopover _: NSPopover?) -> NSPopover? {
        let viewController = AddDataViewController(nibName: "AddData", bundle: nil)

        let newPopover = NSPopover()
        newPopover.contentViewController = viewController
        newPopover.behavior = .semitransient
        return newPopover
    }

    /**
     Membuat dan mengkonfigurasi sebuah NSPopover.

     - Parameter identifier: Identifier dari view controller yang akan diinstanceasi dari storyboard.
     - Parameter storyboardName: Nama dari storyboard yang akan digunakan untuk menginstanceasi view controller.
     - Parameter popover: Popover yang akan dikonfigurasi. Jika nil, popover baru akan dibuat.

     - Returns: Sebuah instance NSPopover yang telah dikonfigurasi, atau nil jika view controller gagal diinstanceasi.
     */
    func createPopover1(withViewControllerIdentifier identifier: NSStoryboard.SceneIdentifier, storyboardName: String, forPopover _: NSPopover?) -> NSPopover? {
        guard let viewController = NSStoryboard(name: NSStoryboard.Name(storyboardName), bundle: nil)
            .instantiateController(withIdentifier: identifier) as? AddDetaildiKelas
        else {
            return nil
        }
        viewController.appDelegate = true
        if let splitVC = mainWindow.contentViewController as? SplitVC,
           let containerVC = splitVC.contentContainerView?.viewController as? ContainerSplitView
        {
            let kelasVC = containerVC.kelasVC
            viewController.onSimpanClick = { [weak kelasVC] dataArray, tambah, _, _ in
                kelasVC?.updateTable(dataArray, tambahData: tambah)
            }
        }

        let newPopover = NSPopover()
        newPopover.contentSize = NSSize(width: 296, height: 420)
        newPopover.contentViewController = viewController
        newPopover.behavior = .semitransient
        return newPopover
    }
}
