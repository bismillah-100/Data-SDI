//
//  Backup Data.swift
//  Data SDI
//
//  Created by MacBook on 08/08/25.
//

import Cocoa

extension AppDelegate {
    /// Penjadwalan untuk mencadangkan file database setiap tanggal 1 di setiap bulan.
    func scheduleBackup() {
        let calendar = Calendar.current
        let currentDate = Date()

        // Check if today is the first day of the month
        if calendar.component(.day, from: currentDate) == 1 {
            // If yes, schedule the backup
            Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(backup), userInfo: nil, repeats: false)
        }
    }

    /// Fungsi yang menjalankan logika pencadangan ``DatabaseController/backupDatabase()``.
    @objc func backup() {
        DatabaseController.shared.backupDatabase()
    }
}
