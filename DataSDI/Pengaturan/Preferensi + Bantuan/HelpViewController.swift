//
//  HelpViewController.swift
//  Data SDI
//
//  Created by Bismillah on 04/11/24.
//

import Cocoa

/// `HelpViewController` adalah kelas yang mengelola tampilan bantuan dalam aplikasi.
/// Kelas ini bertanggung jawab untuk menampilkan konten bantuan yang disediakan dalam aplikasi.
/// Konten bantuan ini ditampilkan dalam sebuah `NSScrollView` yang memungkinkan pengguna untuk menggulir konten jika diperlukan.
/// Kelas ini juga mengelola interaksi dengan elemen UI seperti tombol radio dan checkbox, meskipun saat ini tidak ada aksi yang terkait dengan interaksi tersebut.
class HelpViewController: NSViewController {
    /// Outlet untuk NSScrollView yang digunakan untuk menampilkan konten bantuan.
    @IBOutlet weak var scrollView: NSScrollView!
    /// Outlet untuk NSView yang berisi konten bantuan.
    @IBOutlet weak var contentView: NSView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    override func viewWillAppear() {
        super.viewWillAppear()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
            guard let self else { return }
            if let docView = scrollView.documentView {
                // Scroll ke atas
                let topPoint = NSPoint(x: 0, y: docView.bounds.height - scrollView.contentView.bounds.height)
                scrollView.scroll(topPoint)
            }
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        AppDelegate.shared.helpWindow = nil
    }

    /// Tidak memicu aksi apapun.
    @IBAction func radioOn(_ sender: NSButton) {
        sender.state = .on
    }

    /// Tidak memicu aksi apapun.
    @IBAction func checkOn(_ sender: NSButton) {
        sender.state = .on
    }

    /// Tidak memicu aksi apapun.
    @IBAction func radioOff(_ sender: NSButton) {
        sender.state = .off
    }

    /// Tidak memicu aksi apapun.
    @IBAction func checOff(_ sender: NSButton) {
        sender.state = .off
    }
}
