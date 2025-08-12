//
//  AppUpdate.swift
//  Data SDI
//
//  Created by MacBook on 08/08/25.
//

import Cocoa

private let tempFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("update-list.csv")
private let libraryAgent = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".datasdi-update/agent/")

extension AppDelegate {
    /// Action untuk menu item "Periksa Pembaruan..."" di menu bar.
    /// - Parameter sender: Objek pemicu dapat berupa apapun.
    @IBAction func pembaruanManual(_: Any) {
        Task {
            await checkAppUpdates(false)
        }
    }

    /// Action untuk menu item "Setel Ulang Prediksi Ketik".
    /// Fungsi ini digunakan untuk menjalankan logika penghapusan
    /// *cache* prediksi ketik.
    @IBAction func clearSuggestionsTable(_: Any) {
        Task {
            await SuggestionCacheManager.shared.clearCache()
        }
    }

    /// Fungsi untuk menyalin update-agent ke folder `~/.datasdi-update`.
    func salinHelper() {
        let fileManager = FileManager.default
        appAgent = libraryAgent.path + "/UpdateHelper.app"
        let appBundlePath = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/UpdateHelper.app")

        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: "sdi.UpdateHelper").first {
            // Coba terminasi secara normal
            if !runningApp.terminate() {
                #if DEBUG
                    print("Mencoba force terminate...")
                #endif
                runningApp.forceTerminate()
            } else {
                #if DEBUG
                    print("Aplikasi berhasil dihentikan.")
                #endif
            }

            // Tunggu sampai aplikasi benar-benar sudah berhenti
            while !runningApp.isTerminated {
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
            #if DEBUG
                print("UpdateHelper telah benar-benar dihentikan.")
            #endif
        }

        func getBundleVersion(at url: URL) -> String? {
            guard let bundle = Bundle(url: url),
                  let version = bundle.infoDictionary?["CFBundleVersion"] as? String
            else {
                return nil
            }
            return version
        }

        let versionInAppBundle = getBundleVersion(at: appBundlePath)
        let versionInLibrary = getBundleVersion(at: libraryAgent.appendingPathComponent("/UpdateHelper.app"))

        var shouldCopy = false

        if !fileManager.fileExists(atPath: appAgent) {
            shouldCopy = true
        } else if let versionApp = versionInAppBundle, let versionLib = versionInLibrary, versionApp.compare(versionLib, options: .numeric) == .orderedDescending {
            // Versi di appBundle lebih baru
            do {
                try fileManager.removeItem(atPath: appAgent)
                shouldCopy = true
            } catch {
                #if DEBUG
                    print("❌: \(error.localizedDescription)")
                #endif
            }
        }

        if shouldCopy {
            do {
                try fileManager.createDirectory(at: libraryAgent, withIntermediateDirectories: true, attributes: nil)
                if fileManager.fileExists(atPath: appAgent) {
                    try fileManager.removeItem(atPath: appAgent)
                }
                try fileManager.copyItem(atPath: appBundlePath.path, toPath: appAgent)
                #if DEBUG
                    print("✅ UpdateHelper berhasil disalin (baru atau versi lebih baru).")
                #endif
            } catch {
                #if DEBUG
                    print("❌: \(error.localizedDescription)")
                #endif
            }
        } else {
            #if DEBUG
                print("ℹ️ UpdateHelper sudah ada dan versi terbaru.")
            #endif
        }
    }

    /**
         Memeriksa pembaruan aplikasi dengan membandingkan versi dan build aplikasi saat ini dengan data yang diambil dari file CSV.

         - Parameter atLaunch: Boolean yang menunjukkan apakah pemeriksaan pembaruan dilakukan saat aplikasi diluncurkan atau tidak.

         Fungsi ini melakukan langkah-langkah berikut:
         1. Memeriksa apakah pembaruan telah diunduh sebelumnya dan menunggu untuk diinstal ulang saat aplikasi ditutup. Jika ya, tampilkan pemberitahuan dan keluar dari fungsi.
         2. Mengambil data pembaruan dari file CSV yang terletak di URL yang ditentukan.
         3. Membandingkan versi dan build aplikasi saat ini dengan versi dan build terbaru yang tersedia dari data CSV.
         4. Jika versi atau build terbaru lebih tinggi dari versi atau build saat ini, fungsi akan:
             - Menyimpan URL, versi baru, dan build baru ke dalam UserDefaults.
             - Menetapkan flag `shouldUpdate` menjadi `true`.
         5. Jika pemeriksaan dilakukan saat peluncuran aplikasi dan versi/build terbaru tidak lebih tinggi dari versi/build yang disimpan untuk dilewati, fungsi akan keluar.
         6. Jika pemeriksaan dilakukan saat peluncuran aplikasi dan ada pembaruan yang tersedia, fungsi akan menampilkan pemberitahuan tentang pembaruan yang tersedia.
         7. Jika pemeriksaan tidak dilakukan saat peluncuran aplikasi dan tidak ada pembaruan yang tersedia, fungsi akan menampilkan pemberitahuan bahwa tidak ada pembaruan.
         8. Jika pemeriksaan tidak dilakukan saat peluncuran aplikasi dan ada pembaruan yang tersedia, fungsi akan:
             - Menyimpan versi dan build aplikasi saat ini ke dalam UserDefaults.
             - Menyimpan URL pembaruan ke dalam UserDefaults.
             - Membuka aplikasi agen untuk melakukan pembaruan.
         9. Menghapus file sementara jika ada.
     */
    func checkAppUpdates(_ atLaunch: Bool) async {
        guard let isConnected = try? await ReusableFunc.checkInternetConnectivityDirectly(), isConnected else { return }
        if sharedDefaults.bool(forKey: "updateNanti", reload: true) == true, !atLaunch {
            DispatchQueue.main.async {
                ReusableFunc.showAlert(title: "Pembaruan telah diunduh", message: "Pembaruan akan diinstal ketika aplikasi ditutup.")
            }
            return
        }
        fetchCSVData(from: "https://drive.google.com/uc?export=view&id=1X-gRNUHtZZTp4HYfJkbFPSWVFtqhyJmO") { [weak self] updates in
            guard let self, let (version, build, link) = updates else { return }
            // Versi aplikasi saat ini
            let currentVersion = Int(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0") ?? 0
            let currentBuild = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0

            // Gabungkan semua release notes
            var shouldUpdate = false
            var url: URL!

            if version > currentVersion || (version == currentVersion && build > currentBuild) {
                url = link
                sharedDefaults.set(link.absoluteString, forKey: "link")
                sharedDefaults.set(version, forKey: "newVersion")
                sharedDefaults.set(build, forKey: "newBuild")
                shouldUpdate = true
            } else {
                #if DEBUG
                    print("currentVersion: \(currentVersion) (\(currentBuild)), newVersion: \(version) (\(build))")
                #endif
            }

            if atLaunch,
               let skipVersion = sharedDefaults.integer(forKey: "skipVersion"),
               let skipBuild = sharedDefaults.integer(forKey: "skipBuild"),
               let newVersion = sharedDefaults.integer(forKey: "newVersion"),
               let newBuild = sharedDefaults.integer(forKey: "newBuild"),
               skipVersion != 0, skipBuild != 0,
               newVersion <= skipVersion, newBuild <= skipBuild
            {
                return
            }

            if atLaunch, shouldUpdate {
                notifUpdateAvailable(url, currentVersion: currentVersion, currentBuild: currentBuild)
                return
            }

            if !atLaunch, !shouldUpdate {
                notifNotAvailableUpdate()
            }

            if !atLaunch, shouldUpdate {
                sharedDefaults.set(currentVersion, forKey: "currentVersion")
                sharedDefaults.set(currentBuild, forKey: "currentBuild")
                sharedDefaults.set(url.absoluteString, forKey: "link")
                NSWorkspace.shared.open(URL(fileURLWithPath: appAgent))
            }

            do {
                if FileManager.default.fileExists(atPath: tempFilePath.path) {
                    try FileManager.default.removeItem(at: tempFilePath)
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    /// Mengunduh data CSV dari URL yang diberikan dan memprosesnya untuk mendapatkan informasi versi, build, dan tautan.
    ///
    /// Fungsi ini mengumpulkan data dari berbagai array dan singleton yang menyimpan informasi tentang siswa, kelas, guru, dan inventaris yang akan dihapus. Data yang dikumpulkan mencakup ID, tabel terkait, dan flag yang menunjukkan jenis penghapusan yang akan dilakukan.
    ///
    /// - Parameter:
    ///     - urlString: String representasi dari URL tempat file CSV akan diunduh.
    ///     - completion:
    ///         - Closure yang dipanggil setelah proses pengunduhan dan parsing selesai. Closure ini menerima sebuah tuple opsional `(Int, Int, URL)?`.
    ///             - Int pertama adalah versi yang diekstrak dari file CSV.
    ///             - Int kedua adalah build yang diekstrak dari file CSV.
    ///             - URL adalah tautan yang diekstrak dari file CSV.
    ///   Jika terjadi kesalahan selama proses, closure akan dipanggil dengan nilai `nil`.
    ///
    /// - Note: Fungsi ini mengunduh file ke lokasi sementara, memprosesnya, dan kemudian menghapus file sementara tersebut.
    func fetchCSVData(from urlString: String, completion: @escaping ((Int, Int, URL)?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        // Mulai download file
        let task = URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            if let error {
                #if DEBUG
                    print("Error downloading file: \(error)")
                #endif
                completion(nil)
                return
            }

            guard let tempURL else {
                #if DEBUG
                    print("Temp URL is nil")
                #endif
                completion(nil)
                return
            }

            do {
                if FileManager.default.fileExists(atPath: tempFilePath.path) {
                    try FileManager.default.removeItem(at: tempFilePath)
                }
                // Pindahkan file dari URL temporary ke tempFilePath
                try FileManager.default.moveItem(at: tempURL, to: tempFilePath)

                // Baca file CSV dari tempFilePath
                let content = try String(contentsOf: tempFilePath, encoding: .utf8)

                // Normalisasi newline: ganti semua `\r\n` (Windows-style) menjadi `\n` (Unix-style)
                let normalizedContent = content.replacingOccurrences(of: "\r\n", with: "\n")

                // Parsing CSV
                let rows = normalizedContent.split(separator: "\n")
                guard let firstRow = rows.first else {
                    completion(nil)
                    return
                }

                let columns = firstRow.split(separator: ";")
                if let version = Int(columns[0]),
                   let build = Int(columns[1]),
                   let link = URL(string: String(columns[2]))
                {
                    completion((version, build, link))
                } else {
                    completion(nil)
                }
            } catch {
                #if DEBUG
                    print("Error reading file: \(error)")
                #endif
                completion(nil)
            }
        }
        task.resume()
    }
}
