//
//  DetilWindow.swift
//  Data Manager
//
//  Created by Bismillah on 05/11/23.
//

import Cocoa

/// Protokol yang digunakan untuk menangani ketika jendela
/// ``DetilWindow`` ditutup.
/// Protokol ini dirancang untuk pemeriksaan jika ada data yang belum disimpan.
protocol WindowWillCloseDetailSiswa: AnyObject {
    /// Fungsi untuk pemeriksaan apakah jendela boleh ditutup.
    /// Ini akan di set ke false ketika ada data yang belum disimpan
    /// di ``DetailSiswaController``.
    /// - Returns: Nilai `Boolean` yang menentukan boleh tidaknya jendela ditutup.
    func shouldAllowWindowClose() -> Bool

    /// Fungsi untuk menyimpan semua perubahan ke database yang ditangani
    /// oleh class yang memanggil delegasi.
    /// - Parameter completion: Logika yang dijalankan setelah semua proses selesai.
    func processDatabaseOperations(completion: @escaping () -> Void)
}

/// Protokol delegasi ketika ``DetilWindow`` ditutup
/// untuk membersihkan referensi jendela di ``AppDelegate/openedSiswaWindows``.
protocol DetilWindowDelegate: AnyObject {
    /// Fungsi yang ditangani oleh class yang memanggil delegasi.
    /// - Parameter window: Referensi jendela yang akan dibersihkan.
    func detailWindowDidClose(_ window: DetilWindow)
}

/// Class `NSWindowController` yang mengelola jendela **Rincian Siswa**.
class DetilWindow: NSWindowController, NSWindowDelegate {
    /// Properti data *frame* jendela.
    var windowData: WindowData?

    /// Properti protokol ``DetilWindowDelegate``
    weak var closeWindow: DetilWindowDelegate?
    /// Properti protokol ``WindowWillCloseDetailSiswa``
    weak var closeWindowDelegate: WindowWillCloseDetailSiswa?

    /**
         Kelas pembantu untuk membuat jendela detail dengan tampilan konten yang diberikan.

         - Parameter contentViewController: View controller yang akan menjadi konten utama jendela.
     */
    convenience init(contentViewController: NSViewController) {
        let window = NSWindow(contentViewController: contentViewController)
        window.styleMask.insert([.fullSizeContentView, .titled, .closable, .miniaturizable, .resizable])
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.animationBehavior = .documentWindow
        self.init(window: window)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
        window?.identifier = NSUserInterfaceItemIdentifier("JendelaDetail")
        if let windowFrameData = UserDefaults.standard.data(forKey: "JendelaDetail") {
            do {
                windowData = try JSONDecoder().decode(WindowData.self, from: windowFrameData)
            } catch {}
        }

        if let windowData {
            var frame = windowData.frame

            if frame.size.width < 100 || frame.size.height < 100 {
                frame = NSRect(x: 910, y: 400, width: 500, height: 500)
            }

            if let screen = NSScreen.main {
                if frame.origin.x < 0 || frame.origin.y < 0 || frame.origin.x + frame.size.width > screen.frame.width || frame.origin.y + frame.size.height > screen.frame.height {
                    frame = NSRect(x: 910, y: 400, width: 500, height: 500)
                }

                window?.setFrame(frame, display: true)
            }
        } else {
            let defaultSize = NSSize(width: 500, height: 500)
            window?.setContentSize(defaultSize)
        }

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { [weak self] _ in
            if let self, let window {
                windowData = WindowData(frame: window.frame)
                saveWindowData()
            }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: nil) { [weak self] _ in
            if let self, let window {
                windowData = WindowData(frame: window.frame)
                saveWindowData()
            }
        }
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        guard let delegate = closeWindowDelegate else { return true }
        if delegate.shouldAllowWindowClose() {
            return true
        } else {
            delegate.processDatabaseOperations { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    self?.close()
                }
            }
            return false
        }
    }

    func windowWillClose(_: Notification) {
        closeWindow?.detailWindowDidClose(self)
    }

    func windowDidResignKey(_: Notification) {
        NotificationCenter.default.post(name: Notification.Name("DetilWindowDidResignKey"), object: self)
    }

    /**
         Memuat data jendela dari UserDefaults.

         Fungsi ini mencoba untuk mengambil data `WindowData` yang disimpan di UserDefaults dengan kunci "JendelaDetail".
         Jika data ditemukan, fungsi akan mencoba untuk mendekode data JSON menjadi objek `WindowData`.
         Jika proses dekode berhasil, fungsi akan mengembalikan objek `WindowData` yang telah didekode.
         Jika terjadi kesalahan selama proses dekode, pesan kesalahan akan dicetak ke konsol (hanya dalam mode DEBUG) dan fungsi akan mengembalikan `nil`.
         Jika tidak ada data yang ditemukan di UserDefaults dengan kunci yang diberikan, fungsi akan mengembalikan `nil`.

         - Returns: Objek `WindowData` jika berhasil dimuat dan didekode, atau `nil` jika terjadi kesalahan atau tidak ada data yang ditemukan.
     */
    func loadWindowData() -> WindowData? {
        if let windowFrameData = UserDefaults.standard.data(forKey: "JendelaDetail") {
            do {
                return try JSONDecoder().decode(WindowData.self, from: windowFrameData)
            } catch {
                #if DEBUG
                    print(error.localizedDescription)
                #endif
            }
        }
        return nil
    }

    /// Fungsi yang menyimpan frame ``DetilWindow`` ke UserDefaults.
    func saveWindowData() {
        do {
            let data = try JSONEncoder().encode(windowData)
            UserDefaults.standard.set(data, forKey: "JendelaDetail")
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /**
     Menyesuaikan posisi jendela berdasarkan bingkai dasar dan pengali offset.

     Fungsi ini menghitung posisi baru untuk jendela berdasarkan bingkai dasar yang diberikan dan pengali offset.
     Posisi jendela disesuaikan dengan menambahkan atau mengurangi offset yang dikalikan dengan pengali offset ke koordinat x dan y dari bingkai dasar.
     Fungsi ini juga memastikan bahwa jendela tetap berada dalam batas layar dengan menyesuaikan posisi jika jendela akan keluar dari layar.

     - Parameter:
        - baseFrame: Bingkai dasar untuk memposisikan jendela. Jika nilainya `nil`, bingkai default dengan posisi (910, 400) dan ukuran (500, 500) akan digunakan.
        - offsetMultiplier: Pengali untuk offset. Ini menentukan seberapa jauh jendela akan dipindahkan dari bingkai dasar.
     */
    func adjustWindowPosition(baseFrame: NSRect?, offsetMultiplier: Int) {
        guard let screen = NSScreen.main else { return }

        let offset: CGFloat = 20
        var newFrame = baseFrame ?? NSRect(x: 910, y: 400, width: 500, height: 500)

        // Sesuaikan posisi berdasarkan offset multiplier
        newFrame.origin.x += CGFloat(offsetMultiplier) * offset
        newFrame.origin.y -= CGFloat(offsetMultiplier) * offset

        // Pastikan jendela tetap berada dalam batas layar
        if newFrame.origin.x + newFrame.size.width > screen.frame.width {
            newFrame.origin.x = screen.frame.width - newFrame.size.width - offset
        }
        if newFrame.origin.y < screen.frame.origin.y {
            newFrame.origin.y = screen.frame.origin.y + offset
        }

        window?.setFrame(newFrame, display: true)
    }

    deinit {
        #if DEBUG
            print("DetilWindowController deinit!")
        #endif
        closeWindow = nil
        closeWindowDelegate = nil
        windowData = nil
        window?.delegate = nil
        contentViewController = nil
        window = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
    }
}

/// Struct yang menyimpan data lokasi dan frame ``DetilWindow``.
struct WindowData: Codable {
    /// Frame `NSRect` pada layar.
    var frame: NSRect
}
