//
//  Toolbar Action.swift
//  Data SDI
//
//  Created by Admin on 15/04/25.
//

import Cocoa

// WINDOW CONTROLLER ACTION
extension WindowController {
    /// Menangani aksi ketika tombol "Add Data" pada toolbar ditekan.
    /// - Parameter sender: Item toolbar yang memicu aksi ini.
    @IBAction func addData(_ sender: NSToolbarItem) {
        guard let splitViewController = window?.contentViewController as? SplitVC else {
            return
        }
        if let viewController = splitViewController.splitViewItems.last(where: { $0.viewController is ContainerSplitView })?.viewController as? ContainerSplitView {
            if let activeVC = viewController.currentContentController as? KelasVC {
                activeVC.addData(sender)
            } else if let activeVC = viewController.currentContentController as? InventoryView {
                activeVC.addColumnButtonClicked(sender)
            }
        }
    }

    /// Menangani aksi ketika item toolbar ditekan untuk menampilkan ScrollView.
    /// - Parameter sender: Item toolbar (`NSToolbarItem`) yang memicu aksi ini.
    @IBAction func showScrollView(_ sender: NSToolbarItem) {
        if let splitViewController = window?.contentViewController as? SplitVC {
            if let viewController = splitViewController.splitViewItems.last(where: { $0.viewController is ContainerSplitView })?.viewController as? ContainerSplitView {
                if let activeVC = viewController.currentContentController as? KelasVC {
                    activeVC.showScrollView(sender) // atau operasikan sesuai kebutuhan Anda
                } else if let kelasHistory = viewController.currentContentController as? KelasHistoryVC {
                    kelasHistory.rekapNilai(sender)
                }
            }
        }
    }

    /// Menangani aksi ketika tombol "Tambah Siswa" pada toolbar ditekan.
    /// - Parameter sender: Item toolbar yang memicu aksi ini.
    @IBAction func addSiswa(_ sender: NSToolbarItem) {
        if let splitViewController = contentViewController as? SplitVC {
            if let containerView = splitViewController.splitViewItems.last(where: { $0.viewController is ContainerSplitView })?.viewController as? ContainerSplitView {
                let viewController = containerView.currentContentController
                if let kelasVC = viewController as? KelasVC {
                    kelasVC.addSiswa(sender)
                    return
                } else if let siswaViewController = viewController as? SiswaViewController {
                    siswaViewController.addSiswa(sender)
                    return
                } else if let transaksiView = viewController as? TransaksiView {
                    transaksiView.addTransaksi(sender)
                    return
                } else if let guruViewController = viewController as? TugasMapelVC {
                    guruViewController.addGuru(sender)
                    return
                } else if let inventory = viewController as? InventoryView {
                    inventory.addRowButtonClicked(sender)
                    return
                } else if let guru = viewController as? GuruVC {
                    guru.tambahGuru(sender)
                    return
                }
            }
        }
    }

    /// Menangani aksi ketika tombol "Statistik" pada toolbar ditekan.
    /// - Parameter sender: Item toolbar yang memicu aksi ini.
    @IBAction func Statistik(_ sender: NSToolbarItem) {
        guard let splitVC = window?.contentViewController as? SplitVC,
              let contentContainerView = splitVC.contentContainerView?.viewController as? ContainerSplitView
        else { return }

        let statistikChart = contentContainerView.statistikView

        statistikChart.sheetWindow = true
        let detailWindow = NSWindow(contentViewController: statistikChart)
        detailWindow.title = "Statistik Kelas"
        // Set properties to display as sheet window
        detailWindow.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        detailWindow.isReleasedWhenClosed = true
        detailWindow.standardWindowButton(.zoomButton)?.isHidden = true // Optional: Hide zoom button
        detailWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true // Optional: Hide miniaturize button

        if let splitVC = contentViewController as? SplitVC,
           let contentContainerView = splitVC.contentContainerView?.viewController as? ContainerSplitView,
           let currentController = contentContainerView.currentContentController as? KelasHistoryVC
        {
            if let a = currentController.previousTahunAjaran1,
               let b = currentController.previousTahunAjaran2,
               !a.isEmpty, !b.isEmpty
            {
                statistikChart.tahunAjaran = a + "/" + b
            }
        }
        // Present as a sheet window
        if let mainWindow = NSApplication.shared.mainWindow {
            mainWindow.beginSheet(detailWindow, completionHandler: nil)
        }

        statistikChart.verline.isHidden = false
    }

    /// Menangani aksi ketika tombol "Tutup Sheet Window" pada toolbar ditekan.
    @objc func tutupSheetWindow() {
        if let sheetWindow = NSApplication.shared.mainWindow?.attachedSheet {
            NSApplication.shared.mainWindow?.endSheet(sheetWindow)
            sheetWindow.orderOut(nil)
        }
    }

    /// Menangani aksi ketika tombol "Jumlah" pada toolbar ditekan.
    /// - Parameter sender: Item toolbar yang memicu aksi ini.
    @IBAction func jumlah(_ sender: NSButton) {
        if AppDelegate.shared.openedAdminChart != nil {
            AppDelegate.shared.openedAdminChart?.makeKeyAndOrderFront(sender)
            return
        }

        let jumlahPopOver = NSPopover()
        guard let splitViewController = contentViewController as? SplitVC,
              let containerView = splitViewController.splitViewItems.last(where: { $0.viewController is ContainerSplitView })?.viewController as? ContainerSplitView
        else {
            return
        }

        let viewController = containerView.currentContentController
        if viewController is TransaksiView || viewController is JumlahTransaksi {
            let storyboard = NSStoryboard(name: "AdminChart", bundle: nil)
            // Mengambil view controller dengan ID AdminChart
            if let chartData = storyboard.instantiateController(withIdentifier: "AdminChart") as? AdminChart {
                jumlahPopOver.contentViewController = chartData
                jumlahPopOver.behavior = .semitransient
            }

        } else {
            let statistikViewController = StatistikViewController(nibName: "Statistik", bundle: nil)
            jumlahPopOver.contentViewController = statistikViewController
            jumlahPopOver.contentSize = NSSize(width: 525, height: 320)
            jumlahPopOver.behavior = .semitransient // Menetapkan perilaku jumlahPopOver? menjadi transient

            if let vc = viewController as? KelasHistoryVC {
                if let a = vc.previousTahunAjaran1,
                   let b = vc.previousTahunAjaran2,
                   !a.isEmpty, !b.isEmpty
                {
                    statistikViewController.tahunAjaran = a + "/" + b
                }
            }
        }
        jumlahPopOver.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    /// Menangani aksi ketika tombol "Edit" pada toolbar ditekan.
    /// - Parameter sender: Item toolbar yang memicu aksi ini.
    @IBAction func edit(_ sender: Any) {
        guard let splitViewController = contentViewController as? SplitVC,
              let containerView = splitViewController.splitViewItems.last(where: { $0.viewController is ContainerSplitView })?.viewController as? ContainerSplitView
        else {
            return
        }

        let viewController = containerView.currentContentController

        if let transaksiView = viewController as? TransaksiView {
            transaksiView.edit(sender)
            return
        }
        if let siswaViewController = viewController as? SiswaViewController {
            siswaViewController.edit(sender)
            return
        }
        if let guruViewController = viewController as? TugasMapelVC {
            guruViewController.edit(sender)
            return
        }
        if let inventory = viewController as? InventoryView {
            inventory.edit(sender)
            return
        }
        if let kelas = viewController as? KelasVC {
            kelas.editMapelToolbar(sender)
            return
        }
        if let guru = viewController as? GuruVC {
            guru.editGuru(sender)
            return
        }
    }

    /// Menangani aksi ketika tombol "Hapus" pada toolbar ditekan.
    /// Aksi ini akan menghapus data yang dipilih pada konten saat ini.
    /// - Parameter sender: Item toolbar yang memicu aksi ini.
    @IBAction func hapus(_ sender: Any) {
        guard let splitViewController = contentViewController as? SplitVC,
              let containerView = splitViewController.splitViewItems.last(where: { $0.viewController is ContainerSplitView })?.viewController as? ContainerSplitView
        else {
            return
        }

        let viewController = containerView.currentContentController

        if let transaksiView = viewController as? TransaksiView {
            transaksiView.hapus(sender)
            return
        } else if let siswaViewController = viewController as? SiswaViewController {
            siswaViewController.deleteSelectedRowsAction(sender)
            return
        } else if let guruViewController = viewController as? TugasMapelVC {
            guruViewController.hapusSerentak(sender)
            return
        } else if let inventory = viewController as? InventoryView {
            inventory.delete(sender)
            return
        } else if let kelas = viewController as? KelasVC {
            kelas.hapus(sender)
            return
        } else if let guru = viewController as? GuruVC {
            guru.hapusGuru(sender)
            return
        }
    }

    /// Menangani aksi ketika segmented control pada toolbar diubah.
    /// Aksi ini akan memanggil metode yang sesuai pada konten saat ini berdasarkan jenis view controller yang aktif.
    /// - Parameter sender: Segmented control yang memicu aksi ini.
    @IBAction func segemntedControl(_ sender: NSSegmentedControl) {
        guard let splitViewController = contentViewController as? SplitVC,
              let containerView = splitViewController.splitViewItems.last(where: { $0.viewController is ContainerSplitView })?.viewController as? ContainerSplitView
        else {
            return
        }

        let viewController = containerView.currentContentController

        if let siswa = viewController as? SiswaViewController {
            siswa.segmentedControlValueChanged(sender)
            return
        } else if let transaksi = viewController as? TransaksiView {
            transaksi.segmentedControlValueChanged(sender)
            return
        } else if let saldo = viewController as? JumlahTransaksi {
            saldo.segmentedControlValueChanged(sender)
            return
        } else if let kelas = viewController as? KelasVC {
            kelas.segmentedControlValueChanged(sender)
            return
        } else if let jumlahSiswa = viewController as? JumlahSiswa {
            jumlahSiswa.segmentedControlValueChanged(sender)
            return
        } else if let struktur = viewController as? Struktur {
            struktur.segmentedControlValueChanged(sender)
            return
        } else if let inventory = viewController as? InventoryView {
            inventory.segmentedControlValueChanged(sender)
            return
        }
    }
}
