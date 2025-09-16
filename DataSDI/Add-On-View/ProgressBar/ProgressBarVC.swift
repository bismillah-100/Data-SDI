//
//  ProgressBarVC.swift
//  Data SDI
//
//  Created by Bismillah on 28/12/23.
//

import Cocoa
import Foundation

/// Class untuk menampilkan progress bar yang digunakan di berbagai controller seperti `DetailSiswaController`, `EditData`, dan `AddDataViewController`.
/// Digunakan untuk menampilkan kemajuan proses pembaruan data siswa.
///
/// `ProgressBarVC`
///
/// View controller yang menampilkan indikator progress bar
/// untuk memantau status pembaruan data siswa.
///
/// Kelas ini digunakan saat proses pembaruan data yang jumlahnya cukup besar.
/// Progress bar akan menampilkan sejauh mana proses sudah berjalan,
/// baik melalui angka (label) maupun indikator visual (progress bar).
///
/// `ProgressBarVC` biasanya ditampilkan sebagai jendela modal kecil
/// yang berisi informasi jumlah data yang sudah berhasil diperbarui.
///
/// ## Properties
/// - `progressLabel`: Label teks yang menampilkan informasi progres
///   dalam format "Pembaruan <controller>: <current>/<total>".
/// - `progressIndicator`: Indikator visual (bar) yang menunjukkan progres numerik.
/// - `totalStudentsToUpdate`: Jumlah total data yang akan diperbarui,
///   dipakai untuk mengatur nilai maksimum progress bar.
/// - `currentStudentIndex`: Indeks data yang sedang diperbarui saat ini,
///   dipakai untuk mengupdate label dan nilai progress bar.
/// - `controller`: Nama atau identitas proses yang sedang berjalan,
///   akan tampil di label untuk konteks tambahan.
///
/// ## Usage Example
/// ```swift
/// let progressVC = ProgressBarVC(nibName: "ProgressBarVC", bundle: nil)
/// progressVC.loadView()
/// progressVC.totalStudentsToUpdate = siswa.count
/// progressVC.controller = "Data Siswa"
///
/// // Tampilkan window progress
/// let progressWindow = NSWindow(contentViewController: progressVC)
/// let progressController = NSWindowController(window: progressWindow)
/// progressController.showWindow(nil)
///
/// // Update progress selama proses berjalan
/// for (index, siswa) in siswa.enumerated() {
///     // lakukan update data...
///     progressVC.currentStudentIndex = index + 1
/// }
/// ```
///
/// ## Deinitialization
/// Saat `ProgressBarVC` dilepas, outlet `progressIndicator`
/// akan dihapus dari superview dan referensi internal di-nil-kan
/// untuk memastikan tidak ada memory leak.
class ProgressBarVC: NSViewController {
    /// Outlet untuk label yang menampilkan informasi progres.
    @IBOutlet weak var progressLabel: NSTextField!
    /// Outlet untuk NSProgressIndicator yang menampilkan indikator progres.
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    /// Kontroler yang menginisialisasi progress bar, digunakan untuk menampilkan informasi tentang proses pembaruan data.
    var controller: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        progressIndicator.minValue = 0
        progressIndicator.maxValue = Double(totalStudentsToUpdate)
    }

    /// Properti untuk menyimpan jumlah total siswa yang akan diperbarui.
    /// Digunakan untuk mengatur nilai maksimum dari `progressIndicator`.
    /// Nilai ini akan diatur sebelum memulai proses pembaruan data siswa.
    var totalStudentsToUpdate: Int = 0 {
        didSet {
            progressIndicator.maxValue = Double(totalStudentsToUpdate)
        }
    }

    /// Properti untuk menyimpan indeks siswa saat ini yang sedang diperbarui.
    /// Digunakan untuk memperbarui label progres dan indikator progres saat proses pembaruan data siswa berlangsung.
    /// Nilai ini akan diupdate setiap kali proses pembaruan data siswa mencapai siswa berikutnya.
    /// Nilai ini akan diatur oleh proses pembaruan data siswa.
    var currentStudentIndex: Int = 0 {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                progressLabel.stringValue = "Pembaruan \(controller ?? ""): \(currentStudentIndex) daftar dari \(totalStudentsToUpdate) data"
                progressIndicator.doubleValue = Double(currentStudentIndex)
            }
        }
    }

    deinit {
        progressIndicator.removeFromSuperviewWithoutNeedingDisplay()
        progressLabel = nil
        controller = nil
    }
}

class ProgressBarWindow: NSWindowController, NSWindowDelegate {
    override func awakeFromNib() {
        super.awakeFromNib()
        window?.delegate = self
        if let windowFrameData = UserDefaults.standard.data(forKey: "ProgressWindowFrame"),
           let windowFrame = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: windowFrameData)
        {
            // Mendapatkan ukuran dan posisi jendela dari data yang disimpan
            let frame = windowFrame.rectValue
            // Mengatur ulang ukuran dan posisi jendela
            window?.setFrame(frame, display: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: NSValue(rect: window.frame), requiringSecureCoding: false)
                UserDefaults.standard.set(data, forKey: "ProgressWindowFrame")
            } catch {}
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
