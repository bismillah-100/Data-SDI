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
    func prepareNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }
    func grantNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
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
    
    func notifUpdateAvailable(_ downloadLink: URL, currentVersion: Int, currentBuild: Int) {
        // Kirim notifikasi ke pengguna jika ada pembaruan baru
        let content = UNMutableNotificationContent()
        if let newVersion = self.sharedDefaults.integer(forKey: "newVersion"),
           let newBuild = self.sharedDefaults.integer(forKey: "newBuild") {
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
        self.sharedDefaults.set(currentVersion, forKey: "currentVersion")
        self.sharedDefaults.set(currentBuild, forKey: "currentBuild")
        self.sharedDefaults.set(downloadLink.absoluteString, forKey: "link")
        self.userDefaults.set(currentVersion, forKey: "currentVersion")
        self.userDefaults.set(currentBuild, forKey: "currentBuild")
        self.userDefaults.set(downloadLink.absoluteString, forKey: "link")
    }
    
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
        DispatchQueue.main.async {UNUserNotificationCenter.current().add(request)}
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let currentVersion = Int(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0") ?? 0
        let currentBuild = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
        self.sharedDefaults.set(currentVersion, forKey: "currentVersion")
        self.sharedDefaults.set(currentBuild, forKey: "currentBuild")
        openUpdateAgent()
        completionHandler()
    }
    
    func openUpdateAgent() {
        // Cari aplikasi yang sedang berjalan berdasarkan bundle ID
        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: "sdi.UpdateHelper").first {
            // Aplikasi sudah berjalan, buat jadi aktif
            runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            #if DEBUG
            print("Aplikasi sudah berjalan dan sekarang diaktifkan.")
            #endif
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: self.appAgent))
        }
    }
}

