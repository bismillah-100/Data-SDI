//
//  UserNotification.swift
//  Data SDI
//
//  Created by SDI on 07/04/25.
//

import Cocoa
import UserNotifications
import UserNotificationsUI

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Konfigurasi `delegate` `UNUserNotificationCenter`.
    func prepareNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    /**
         Meminta izin kepada pengguna untuk mengirim notifikasi.

         Fungsi ini akan menampilkan dialog perizinan kepada pengguna untuk mengizinkan aplikasi mengirimkan notifikasi.
         Jika izin diberikan, aplikasi dapat menampilkan pemberitahuan kepada pengguna melalui sistem notifikasi.
         Jika izin ditolak, aplikasi tidak akan dapat mengirimkan notifikasi kepada pengguna.

         - Note: Fungsi ini harus dipanggil sebelum aplikasi mencoba mengirimkan notifikasi kepada pengguna.
     */
    func grantNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                #if DEBUG
                    print("Izin untuk notifikasi diberikan")
                #endif
            } else {
                #if DEBUG
                    print("Izin untuk notifikasi ditolak")
                #endif
            }
        }
    }

    /**
     Menampilkan notifikasi kepada pengguna jika terdapat pembaruan aplikasi yang tersedia.

     Fungsi ini membuat dan mengirimkan notifikasi yang memberitahukan pengguna tentang pembaruan aplikasi yang tersedia,
     termasuk informasi versi dan build terbaru jika tersedia. Fungsi ini juga menyimpan informasi pembaruan
     (versi, build, dan tautan unduhan) ke dalam `UserDefaults` untuk digunakan di lain waktu.

     - Parameter downloadLink: URL tautan unduhan untuk pembaruan aplikasi.
     - Parameter currentVersion: Nomor versi aplikasi saat ini.
     - Parameter currentBuild: Nomor build aplikasi saat ini.
     */
    func notifUpdateAvailable(_ downloadLink: URL, currentVersion: Int, currentBuild: Int) {
        // Kirim notifikasi ke pengguna jika ada pembaruan baru
        let content = UNMutableNotificationContent()
        if let newVersion = sharedDefaults.integer(forKey: "newVersion"),
           let newBuild = sharedDefaults.integer(forKey: "newBuild")
        {
            content.title = "Pembaruan tersedia"
            content.body = "Versi \(newVersion).\(newBuild) - Catatan penuh pembaruan"
        } else {
            content.title = "Pembaruan Tersedia"
            content.body = "Silakan instal untuk mendapatkan fitur terbaru."
        }
        content.sound = UNNotificationSound.default

        // Tentukan trigger untuk notifikasi
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Tentukan permintaan notifikasi
        let request = UNNotificationRequest(identifier: "updateNotification", content: content, trigger: trigger)

        // Tambahkan permintaan notifikasi ke pusat notifikasi
        DispatchQueue.main.async { UNUserNotificationCenter.current().add(request) }
        // disini harus membuka aplikasi agent dan menulis ke sharedDefaults
        sharedDefaults.set(currentVersion, forKey: "currentVersion")
        sharedDefaults.set(currentBuild, forKey: "currentBuild")
        sharedDefaults.set(downloadLink.absoluteString, forKey: "link")
        userDefaults.set(currentVersion, forKey: "currentVersion")
        userDefaults.set(currentBuild, forKey: "currentBuild")
        userDefaults.set(downloadLink.absoluteString, forKey: "link")
    }

    /**
     Menampilkan notifikasi kepada pengguna yang memberitahukan bahwa aplikasi sudah dalam versi terbaru.

     Notifikasi ini akan berbeda tergantung pada pengaturan *autoCheckUpdates* di *UserDefaults*.
     Jika *autoCheckUpdates* aktif, notifikasi akan memberitahukan bahwa notifikasi akan dikirim jika ada pembaruan.
     Jika *autoCheckUpdates* tidak aktif, notifikasi akan meminta pengguna untuk mengaktifkan pemeriksaan pembaruan otomatis di Preferensi.
     */
    func notifNotAvailableUpdate() {
        // Kirim notifikasi ke pengguna jika ada pembaruan baru

        let content = UNMutableNotificationContent()
        let autoUpdateDefaults = UserDefaults.standard.bool(forKey: "autoCheckUpdates")
        content.title = "Aplikasi ini terbaru"
        if autoUpdateDefaults {
            content.body = "Notifikasi akan dikirim jika ada pembaruan"
        } else {
            content.body = "Aktifkan pemeriksaan pembaruan otomatis di Preferensi untuk mendapatkan notifikasi jika ada pembaruan"
        }

        content.sound = UNNotificationSound.default

        // Tentukan trigger untuk notifikasi
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Tentukan permintaan notifikasi
        let request = UNNotificationRequest(identifier: "updateNotification", content: content, trigger: trigger)

        // Tambahkan permintaan notifikasi ke pusat notifikasi
        DispatchQueue.main.async { UNUserNotificationCenter.current().add(request) }
    }

    /// Menangani respons terhadap notifikasi pengguna.
    ///
    /// Fungsi ini dipanggil ketika pengguna berinteraksi dengan notifikasi. Fungsi ini memperbarui versi dan build aplikasi yang tersimpan,
    /// membuka agen pembaruan, dan menyelesaikan handler penyelesaian.
    ///
    /// - Parameter center: Pusat notifikasi pengguna yang memanggil delegate ini.
    /// - Parameter response: Respons pengguna terhadap notifikasi.
    /// - Parameter completionHandler: Blok yang harus dipanggil setelah Anda selesai memproses respons.
    func userNotificationCenter(_: UNUserNotificationCenter,
                                didReceive _: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void)
    {
        let currentVersion = Int(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0") ?? 0
        let currentBuild = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
        sharedDefaults.set(currentVersion, forKey: "currentVersion")
        sharedDefaults.set(currentBuild, forKey: "currentBuild")
        openUpdateAgent()
        completionHandler()
    }

    /**
         Membuka atau mengaktifkan aplikasi Update Agent.

         Fungsi ini memeriksa apakah aplikasi Update Agent sudah berjalan. Jika ya, aplikasi tersebut akan diaktifkan.
         Jika tidak, aplikasi akan dibuka dari path yang ditentukan.
     */
    func openUpdateAgent() {
        // Cari aplikasi yang sedang berjalan berdasarkan bundle ID
        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: "sdi.UpdateHelper").first {
            // Aplikasi sudah berjalan, buat jadi aktif
            runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            #if DEBUG
                print("Aplikasi sudah berjalan dan sekarang diaktifkan.")
            #endif
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: appAgent))
        }
    }
}
