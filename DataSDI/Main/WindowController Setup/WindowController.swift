//
//  WindowController.swift
//  searchfieldtoolbar
//
//  Created by Bismillah on 20/10/23.
//

import Cocoa
import SwiftUI

/// `WindowController` adalah kelas yang mengelola jendela aplikasi utama.
/// Kelas ini mengimplementasikan `NSWindowController` dan `NSWindowDelegate` untuk menangani berbagai peristiwa terkait jendela.
class WindowController: NSWindowController, NSWindowDelegate {
    /// Toolbar yang digunakan untuk mengelola tampilan toolbar
    /// dan fungsionalitas yang terkait dengan toolbar.
    /// Toolbar ini berisi berbagai item toolbar yang dapat digunakan
    /// untuk mengelola data, melakukan kalkulasi, menampilkan statistik,
    /// dan melakukan tindakan lainnya dalam aplikasi.
    @IBOutlet weak var toolbar: MyToolbar!

    /// Outlet toolbarItem yang digunakan untuk menampilkan kalkulasi ``NilaiKelas``.
    @IBOutlet weak var kalkulasiButton: NSButton!
    /// Lihat ``kalkulasiButton`` untuk penjelasan lebih lanjut.
    @IBOutlet weak var kalkulasiToolbar: NSToolbarItem!

    /// Outlet toolbarItem yang digunakan untuk menampilkan field yang memuat tampilan untuk menambahkan siswa baru.
    @IBOutlet weak var tambahSiswa: NSButton!
    /// Lihat ``tambahSiswa`` untuk penjelasan lebih lanjut.
    @IBOutlet weak var addDataToolbar: NSToolbarItem!

    /// Outlet yang digunakan untuk menampilkan Kalkulasi Nilai Kelas dalam grafis melalui ``Stats`` view.
    @IBOutlet weak var statistikButton: NSButton!
    /// Lihat ``statistikButton`` untuk penjelasan lebih lanjut.
    @IBOutlet weak var statistikToolbar: NSToolbarItem!

    /// Outlet toolbarItem yang digunakan untuk menghapus data item yang dipilih pada konten yang ditampilkan.
    @IBOutlet weak var tmblhps: NSButton!
    /// Lihat ``tmblhps`` untuk penjelasan lebih lanjut.
    @IBOutlet weak var hapusToolbar: NSToolbarItem!

    /// Outlet toolbarItem yang digunakan untuk mengedit data item yang dipilih pada konten yang ditampilkan.
    @IBOutlet weak var tmbledit: NSButton!
    /// Lihat ``tmbledit`` untuk penjelasan lebih lanjut.
    @IBOutlet weak var editToolbar: NSToolbarItem!

    /// Outlet toolbarItem yang memuat tampilan untuk mencari data.
    @IBOutlet weak var searchField: NSSearchField!
    /// Lihat ``searchField`` untuk penjelasan lebih lanjut.
    @IBOutlet weak var search: NSSearchToolbarItem!

    /// Outlet toolbarItem yang digunakan untuk menampilkan sidebar.
    @IBOutlet weak var sidebarButton: NSToolbarItem!

    /// Outlet toolbarItem untuk menyimpan data.
    @IBOutlet weak var simpanToolbar: NSToolbarItem!

    /// Outlet toolbarItem yang digunakan untuk menampilkan field yang memuat tampilan untuk menambahkan nilai di kelas.
    @IBOutlet weak var tambahDetaildiKelas: NSButton!
    /// Lihat ``tambahDetaildiKelas`` untuk penjelasan lebih lanjut.
    @IBOutlet weak var datakelas: NSToolbarItem!

    /// Outlet toolbarItem untuk memperbesar/memperkecil tampilan.
    @IBOutlet weak var segmentedControl: NSToolbarItem!

    /// Outlet toolbarItem untuk memuat `NSMenu` yang berisi berbagai tindakan yang dapat dilakukan pada konten yang ditampilkan.
    @IBOutlet weak var actionToolbar: NSToolbarItem!

    /// Outlet toolbarItem yang digunakan untuk menampilkan field yang memuat tampilan Jumlah Nilai Kelas atau Kalkulasi Data Administrasi.
    @IBOutlet weak var jumlahToolbar: NSToolbarItem!
    /// Lihat ``jumlahToolbar`` untuk penjelasan lebih lanjut.
    @IBOutlet weak var jumlahnilaiKelas: NSButton!

    /// Outlet toolbarItem yang memuat `NSMenu` untuk mencetak data.
    @IBOutlet weak var printToolbar: NSToolbarItem!

    /// Outlet sidebarTracking antara ``SidebarViewController`` dan ``ContainerSplitView``.
    @IBOutlet weak var tracking: NSToolbarItem!

    /// Properti jendela yang digunakan untuk mengelola jendela aplikasi.
    /// Properti ini akan diatur ketika jendela dimuat.
    /// Jendela ini akan menampilkan konten yang dikelola oleh `SplitVC`.
    override var window: NSWindow? {
        didSet {
            if let window {
                // Ini sebagai ganti windowDidLoad
                window.contentViewController = SplitVC(nibName: "SplitView", bundle: nil)
                window.toolbar = toolbar
            }
        }
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        window?.delegate = self

        if let windowFrameData = UserDefaults.standard.data(forKey: "WindowFrame"),
           let windowFrame = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: windowFrameData)
        {
            // Mendapatkan ukuran dan posisi jendela dari data yang disimpan
            var frame = windowFrame.rectValue
            if frame.size.width < 50 {
                frame.size.width = 800 // Ganti dengan lebar default yang diinginkan
            }

            if frame.size.height < 50 {
                frame.size.height = 600 // Ganti dengan tinggi default yang diinginkan
            }
            // Mengatur ulang ukuran dan posisi jendela
            window?.setFrame(frame, display: true)
        } else {
            // Jika tidak ada ukuran yang disimpan, gunakan ukuran default di sini.
            let defaultSize = NSSize(width: 800, height: 600)
            window?.setContentSize(defaultSize)
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: nil) { notification in
            if let window = notification.object as? NSWindow {
                _ = window.frame.size
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: window.frame), requiringSecureCoding: false)
                    UserDefaults.standard.set(data, forKey: "WindowFrame")
                } catch {}
            }
        }

        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: nil) { notification in
            if let window = notification.object as? NSWindow {
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: window.frame), requiringSecureCoding: false)
                    UserDefaults.standard.set(data, forKey: "WindowFrame")
                } catch {}
            }
        }
    }

    func windowDidResize(_ notification: Notification) {
        if let window {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: window.frame), requiringSecureCoding: false)
                UserDefaults.standard.set(data, forKey: "WindowFrame")
            } catch {}
        }
    }

    func windowDidMove(_ notification: Notification) {
        if let window {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: window.frame), requiringSecureCoding: false)
                UserDefaults.standard.set(data, forKey: "WindowFrame")
            } catch {}
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        NotificationCenter.default.post(name: .windowControllerBecomeKey, object: self)
    }

    func windowDidResignKey(_ notification: Notification) {
        NotificationCenter.default.post(name: .windowControllerResignKey, object: self)
    }

    func windowDidUpdate(_ notification: Notification) {}

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: window.frame), requiringSecureCoding: false)
                UserDefaults.standard.set(data, forKey: "WindowFrame")
            } catch {}
        }
        NotificationCenter.default.post(name: .windowControllerClose, object: self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
    }
}
