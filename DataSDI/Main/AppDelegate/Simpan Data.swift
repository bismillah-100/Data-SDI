//
//  Simpan Data.swift
//  Data SDI
//
//  Created by MacBook on 06/08/25.
//

import AppKit
import SQLite

/// Pengelola data-data yang dihapus dari viewModel manapun untuk dihapus juga dari
/// basis data. Membaca data dari ``SingletonData`` tempat dimana referensi
/// data-data yang dihapus dari viewModel disimpan.
class SimpanData {
    /// Singleton simpan data
    static let shared = SimpanData()

    private var progressWindowController: NSWindowController!
    private var progressViewController: ProgressBarVC! // ViewController untuk progress bar

    private var windowsNeedSaving = 0
    private var alert: NSAlert?

    private var dataCount: Int = 0

    private init() {}

    /// Mengecek apakah ada data yang belum disimpan sebelum aplikasi ditutup.
    ///
    /// Fungsi ini dipanggil ketika aplikasi hendak keluar (`applicationShouldTerminate`).
    /// Ia akan melakukan hal-hal berikut:
    /// - Mengecek seluruh jendela ``DetailSiswaController`` apakah memiliki data yang belum disimpan.
    /// - Jika ada, akan memanggil ``DetailSiswaController/saveDataWillTerminate(_:)`` dan menunda proses terminasi dengan `terminateLater`.
    /// - Jika tidak ada jendela yang butuh disimpan, tetapi ada data yang perlu disimpan berdasarkan ``calculateTotalDeletedData()``,
    ///   maka akan menampilkan alert konfirmasi dan jendela progres untuk menyimpan data sebelum keluar.
    /// - Jika tidak ada data yang perlu disimpan sama sekali, proses terminasi akan dilanjutkan.
    ///
    /// - Parameter sender: Objek `NSApplication` yang meminta aplikasi diterminasi.
    /// - Returns: `NSApplication.TerminateReply` — `.terminateNow`, `.terminateLater`, atau lainnya, tergantung status penyimpanan data.
    func checkUnsavedData(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Membuat instance dari ProgressWindowController menggunakan storyboard atau XIB

        let openWindows = NSApplication.shared.windows
        windowsNeedSaving = 0
        for window in openWindows {
            if let viewController = window.contentViewController as? DetailSiswaController {
                if viewController.dataButuhDisimpan {
                    viewController.saveDataWillTerminate(sender)
                    windowsNeedSaving += 1
                }
            }
        }
        if windowsNeedSaving > 0 {
            NotificationCenter.default.addObserver(self, selector: #selector(checkAllDataSaved), name: Notification.Name("DataSaved"), object: nil)
            return .terminateLater
        }
        if dataCount != 0 {
            let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil)

            // Memastikan ProgressWindowController terhubung dengan benar
            if let progressWindowController = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController, let progressViewController = progressWindowController.contentViewController as? ProgressBarVC {
                // Simpan referensi ke controller untuk digunakan nanti
                self.progressWindowController = progressWindowController
                self.progressViewController = progressViewController
                // Menampilkan jendela progress
                showAlert("Data terbaru belum disimpan.", informativeText: "Semua perubahan data akan disimpan dan perubahan tidak dapat diurungkan setelah konfirmasi OK", tutupApp: true, window: AppDelegate.shared.mainWindow)

                return .terminateLater // Menunda terminasi sampai proses selesai
            }
        }

        return .terminateNow
    }

    /**
         Menyimpan perubahan data yang telah dilakukan.

         Fungsi ini menangani proses penyimpanan data, termasuk menampilkan peringatan jika tidak ada perubahan yang perlu disimpan,
         atau meminta konfirmasi kepada pengguna sebelum menyimpan perubahan yang tidak dapat dibatalkan.
     */
    func simpanData() {
        guard dataCount != 0 else {
            alert = nil
            alert = NSAlert()
            alert?.icon = NSImage(systemSymbolName: "checkmark.icloud.fill", accessibilityDescription: .none)
            alert?.messageText = "Data yang tersedia telah diperbarui"
            alert?.informativeText = "Tidak ditemukan perubahan data yang belum disimpan. Semua modifikasi terbaru telah berhasil tersimpan di basis data."
            alert?.addButton(withTitle: "OK")
            if let window = NSApplication.shared.mainWindow {
                // Menampilkan alert sebagai sheet dari jendela utama
                alert?.beginSheetModal(for: window) { response in
                    if response == .alertFirstButtonReturn {
                        window.endSheet(window, returnCode: .cancel)
                        NSApp.reply(toApplicationShouldTerminate: false)
                    }
                }
            }
            return
        }
        guard let mainWindow = NSApp.mainWindow else {
            SimpanData.shared.showAlert("Konfirmasi Penyimpanan Perubahan",
                                        informativeText: "Perubahan terbaru yang telah dilakukan tidak dapat dibatalkan setelah Anda mengonfirmasi dengan menekan tombol OK.",
                                        tutupApp: false,
                                        window: nil)
            return
        }

        SimpanData.shared.showAlert("Konfirmasi Penyimpanan Perubahan", informativeText: "Perubahan terbaru yang telah dilakukan tidak dapat dibatalkan setelah Anda mengonfirmasi dengan menekan tombol OK.", tutupApp: false, window: mainWindow)
    }

    /**
         Menghitung total data yang dihapus dari berbagai sumber data singleton.

         Fungsi ini menjumlahkan jumlah data yang dihapus dari array `deletedDataArray`, `pastedData`, `deletedDataKelas`, `deletedSiswasArray`, dan `deletedSiswaArray`.
         Selain itu, fungsi ini juga menghitung jumlah siswa yang naik kelas (`siswaNaik`), jumlah operasi undo tambah siswa (`undoTambahSiswa`), jumlah operasi undo paste siswa (`undoPasteSiswa`), jumlah inventory yang dihapus (`hapusInventory`), jumlah kolom inventory yang dihapus (`hapusKolomInventory`), jumlah operasi undo tambah kolom inventory (`undoAddKolomInventory`), serta jumlah guru yang dihapus atau di-undo penambahannya (`hapusGuru`).

         - Returns: Jumlah total data yang dihapus sebagai `Int`.
     */
    func calculateTotalDeletedData() -> Int {
        let deletedDataArrayCount = SingletonData.deletedDataArray.reduce(0) { $0 + $1.data.count }
        let pastedDataCount = SingletonData.pastedData.reduce(0) { $0 + $1.data.count }
        let deletedDataKelasCount = SingletonData.deletedDataKelas.reduce(0) { $0 + $1.data.count }
        let deletedSiswasArrayCount = SingletonData.deletedSiswasArray.reduce(0) { $0 + $1.count }
        let deletedSiswaArrayCount = SingletonData.deletedSiswaArray.count
        let siswaNaik = SingletonData.siswaNaikArray.reduce(0) { total, current in
            // Hanya menghitung jika siswaID tidak kosong
            total + (current.siswaID.isEmpty ? 0 : current.siswaID.count)
        }
        let undoTambahSiswa = SingletonData.undoAddSiswaArray.reduce(0) { $0 + $1.count }
        let undoPasteSiswa = SingletonData.redoPastedSiswaArray.reduce(0) { $0 + $1.count }
        let hapusInventory = SingletonData.deletedInvID.count
        let hapusKolomInventory = SingletonData.deletedColumns.reduce(0) { $0 + $1.columnName.count }
        let undoAddKolomInventory = SingletonData.undoAddColumns.reduce(0) { $0 + $1.columnName.count }

        // let undoStackCount = SingletonData.undoStack.reduce(0) { $0 + $1.value.count }

        let hapusGuru = SingletonData.deletedGuru.count + SingletonData.undoAddGuru.count + SingletonData.deletedTugasGuru.count
        
        let addedNilaiKelas = SingletonData.insertedID.count

        dataCount = deletedDataArrayCount + pastedDataCount + deletedDataKelasCount /* + undoStackCount */ + deletedSiswasArrayCount + deletedSiswaArrayCount + siswaNaik + hapusGuru + hapusInventory + hapusKolomInventory + undoAddKolomInventory + undoTambahSiswa + undoPasteSiswa + addedNilaiKelas
        #if DEBUG
            print("dataCount:", dataCount)
        #endif
        return dataCount
    }

    /**
        Memeriksa apakah semua data telah disimpan.

        Fungsi ini dipanggil setiap kali sebuah jendela selesai menyimpan datanya.
        Setelah semua jendela selesai menyimpan (windowsNeedSaving mencapai 0),
        fungsi ini akan melakukan vacuum database dan kemudian melanjutkan proses
        penutupan aplikasi.
     */
    @objc func checkAllDataSaved() {
        windowsNeedSaving -= 1
        if windowsNeedSaving == 0 {
            // Semua data telah disimpan, lanjutkan menutup aplikasi
            DatabaseController.shared.vacuumDatabase()
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
    }

    /**
         Menampilkan sebuah alert dengan pesan dan informasi yang dapat dikustomisasi.

         - Parameter messageText: Teks utama yang ditampilkan pada alert. Jika kosong, akan menggunakan pesan default "Konfirmasi Penyimpanan Perubahan".
         - Parameter informativeText: Teks informatif tambahan yang ditampilkan pada alert. Jika kosong, akan menggunakan pesan default yang menjelaskan bahwa perubahan tidak dapat dibatalkan.
         - Parameter tutupApp: Nilai boolean yang menentukan apakah aplikasi harus ditutup setelah tombol "Batalkan & Tutup Aplikasi" ditekan.
         - Parameter window: Jendela NSWindow tempat alert akan ditampilkan sebagai sheet modal. Jika nil, alert akan ditampilkan sebagai panel.
     */
    func showAlert(_ messageText: String, informativeText: String, tutupApp: Bool, window: NSWindow?) {
        alert = nil
        alert = NSAlert()
        if messageText.isEmpty {
            alert?.messageText = "Konfirmasi Penyimpanan Perubahan"
        } else {
            alert?.messageText = messageText
        }

        if informativeText.isEmpty {
            alert?.informativeText = "Perubahan terbaru yang telah dilakukan tidak dapat dibatalkan setelah Anda mengonfirmasi dengan menekan tombol OK."
        } else {
            alert?.informativeText = informativeText
        }
        alert?.icon = ReusableFunc.cloudArrowUp
        alert?.alertStyle = .critical
        alert?.addButton(withTitle: "OK")
        alert?.addButton(withTitle: "Batalkan")
        alert?.addButton(withTitle: "Batalkan & Tutup Aplikasi")

        if let mainWindow = window, mainWindow.isVisible {
            // Menampilkan alert sebagai sheet dari jendela utama
            alert?.beginSheetModal(for: mainWindow) { [self] response in
                handleAlertResponse(response, tutupApp: tutupApp, window: mainWindow)
            }
        } else {
            // Tampilkan sebagai panel jika main window invisible

            let response = (alert?.runModal())!
            handleAlertResponse(response, tutupApp: tutupApp, window: window ?? NSWindow())
        }
    }

    /**
         Menangani respons dari alert modal.

         Fungsi ini menerima respons dari alert modal dan melakukan tindakan yang sesuai berdasarkan tombol yang ditekan oleh pengguna.

         - Parameter response: Respons dari alert modal (NSApplication.ModalResponse).
         - Parameter tutupApp: Nilai boolean yang menunjukkan apakah aplikasi harus ditutup setelah menangani respons.
         - Parameter window: Jendela yang menampilkan alert.

         Tindakan yang dilakukan berdasarkan respons:
         - .alertFirstButtonReturn: Memanggil fungsi `simpanPerubahan(tutupApp:)` untuk menyimpan perubahan.
         - .alertSecondButtonReturn: Menolak permintaan untuk menutup aplikasi.
         - .alertThirdButtonReturn: Menerima permintaan untuk menutup aplikasi.
         - default: Tidak melakukan tindakan apa pun.
     */
    func handleAlertResponse(_ response: NSApplication.ModalResponse, tutupApp: Bool, window _: NSWindow) {
        switch response {
        case .alertFirstButtonReturn:
            simpanPerubahan(tutupApp: tutupApp)
        case .alertSecondButtonReturn:
            NSApp.reply(toApplicationShouldTerminate: false)
        case .alertThirdButtonReturn:
            NSApp.reply(toApplicationShouldTerminate: true)
        default:
            break
        }
    }

    /**
         Menyimpan perubahan data dengan menampilkan progress bar. Fungsi ini menghitung total data yang akan dihapus,
         menampilkan window progress, dan memproses penghapusan data secara asinkron.

         - Parameter tutupApp: Boolean yang menentukan apakah aplikasi harus ditutup setelah proses penyimpanan selesai.

         Proses:
         1. Menghitung total data yang akan dihapus menggunakan `calculateTotalDeletedData()`.
         2. Jika tidak ada data yang dihapus, memanggil `handleNoDataToDelete(tutupApp:)`.
         3. Menampilkan window progress bar (sebagai sheet jika window utama terlihat, atau sebagai panel jika tidak).
         4. Mengumpulkan semua data yang akan dihapus menggunakan `gatherAllDataToDelete()`.
         5. Memproses penghapusan data secara asinkron menggunakan `OperationQueue`.
         6. Mengupdate progress bar secara berkala berdasarkan `updateFrequency`.
         7. Setelah semua data selesai dihapus, memanggil `finishDeletion(totalDeletedData:tutupApp:)`.

         Catatan:
         - `totalDeletedData` harus lebih besar dari 0 agar proses penghapusan berlanjut.
         - `updateFrequency` ditentukan berdasarkan jumlah total data yang dihapus untuk mengoptimalkan update progress bar.
     */
    func simpanPerubahan(tutupApp: Bool) {
        let storyboard = NSStoryboard(name: "ProgressBar", bundle: nil)
        guard let progressWindowController = storyboard.instantiateController(withIdentifier: "UpdateProgressWindowController") as? NSWindowController,
              let progressViewController = progressWindowController.contentViewController as? ProgressBarVC
        else {
            return
        }

        self.progressWindowController = progressWindowController
        self.progressViewController = progressViewController

        if let progressWindow = progressWindowController.window {
            if let mainWindow = NSApp.mainWindow, mainWindow.isVisible {
                // Jika main window visible, tampilkan sebagai sheet
                mainWindow.beginSheet(progressWindow)
            } else {
                // Jika main window invisible, tampilkan sebagai panel biasa
                progressWindow.center() // Posisikan di tengah layar
                progressWindow.makeKeyAndOrderFront(nil)
            }
        }

        let totalDeletedData = calculateTotalDeletedData()

        guard totalDeletedData > 0 else {
            handleNoDataToDelete(tutupApp: tutupApp)
            return
        }

        self.progressViewController.totalStudentsToUpdate = totalDeletedData

        let allDataToDelete = gatherAllDataToDelete()

        DatabaseController.shared.notifQueue.async {
            // Tentukan update frequency seperti di KelasVC
            let updateFrequency = totalDeletedData > 100 ? max(totalDeletedData / 10, 1) : 1
            var processedDeletedCount = 0

            for (_, item) in allDataToDelete.enumerated() {
                self.processDeleteItem(item)
                processedDeletedCount += 1

                // Update progress berdasarkan interval
                if processedDeletedCount % updateFrequency == 0 || processedDeletedCount == totalDeletedData {
                    DispatchQueue.main.async {
                        self.progressViewController.currentStudentIndex = processedDeletedCount
                    }
                }
            }

            // Selesaikan penghapusan
            self.finishDeletion(totalDeletedData: totalDeletedData, tutupApp: tutupApp)
        }
    }

    /// Fungsi ini dijalankan ketika aplikasi akan ditutup dan tidak ada data yang akan dihapus dari database.
    /// - Parameter tutupApp: Nilai `Boolean` untuk penutupan aplikasi.
    func handleNoDataToDelete(tutupApp: Bool) {
        progressViewController.totalStudentsToUpdate = 1
        progressViewController.currentStudentIndex = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.stopModal()
            NSApp.reply(toApplicationShouldTerminate: tutupApp)
        }
    }

    /**
      Mengumpulkan semua data yang akan dihapus dari berbagai sumber data.

      - Returns: Array tuple yang berisi informasi tentang data yang akan dihapus.

      Fungsi ini mengumpulkan data dari berbagai array dan singleton yang menyimpan informasi tentang siswa, kelas, guru, dan inventaris yang akan dihapus. Data yang dikumpulkan mencakup ID, tabel terkait, dan flag yang menunjukkan jenis penghapusan yang akan dilakukan.

      Setiap tuple return berisi:
         - **`table`**: Tabel yang terkait dengan data (opsional).
         - **`kelasAwal`**: Kelas awal siswa (opsional).
         - **`kelasDikecualikan`**: Kelas yang dikecualikan untuk siswa (opsional).
         - **`kelasID`**: ID kelas atau item yang akan dihapus.
         - **`isHapusKelas`**: Boolean yang menunjukkan apakah kelas harus dihapus.
         - **`isSiswaNaik`**: Boolean yang menunjukkan apakah siswa naik kelas.
         - **`hapusGuru`**: Boolean yang menunjukkan apakah guru harus dihapus.
         - **`hapusInventory`**: Boolean yang menunjukkan apakah item inventaris harus dihapus.
         - **`hapusKolomInventory`**: Boolean yang menunjukkan apakah kolom inventaris harus dihapus.
         - **`namaKolomInventory`**: Nama kolom inventaris yang akan dihapus.

     - Note: Fungsi ini menggunakan data dari singleton `SingletonData` untuk mengumpulkan informasi penghapusan.
     */
    func gatherAllDataToDelete() -> [(table: Table?, kelasAwal: String?, kelasDikecualikan: String?, kelasID: Int64, isHapusKelas: Bool, isSiswaNaik: Bool, hapusGuru: Bool, hapusInventory: Bool, hapusKolomInventory: Bool, namaKolomInventory: String, hapusTugasGuru: Bool)] {
        var allDataToDelete = [(table: Table?, kelasAwal: String?, kelasDikecualikan: String?, kelasID: Int64, isHapusKelas: Bool, isSiswaNaik: Bool, hapusGuru: Bool, hapusInventory: Bool, hapusKolomInventory: Bool, namaKolomInventory: String, hapusTugasGuru: Bool)]()

        // MARK: - SISWA DATA

        // Mengumpulkan data dari deletedSiswasArray
        for deletedSiswaArrayItem in SingletonData.deletedSiswasArray {
            allDataToDelete.append(contentsOf: deletedSiswaArrayItem.map { (table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.id, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: false) })
        }
        for undoAddSiswaArrayItem in SingletonData.undoAddSiswaArray {
            allDataToDelete.append(contentsOf: undoAddSiswaArrayItem.map { (table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.id, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: false) })
        }

        for deletedSiswaArrayItem in SingletonData.redoPastedSiswaArray {
            allDataToDelete.append(contentsOf: deletedSiswaArrayItem.map { (table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.id, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: false) })
        }
        // Mengumpulkan data dari deletedSiswaArray
        allDataToDelete.append(contentsOf: SingletonData.deletedSiswaArray.map { (table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.id, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: false) })

        // Mengumpulkan data dari pastedData
        for pastedDataItem in SingletonData.pastedData {
            let currentClassTable = pastedDataItem.table
            let dataArray = pastedDataItem.data
            allDataToDelete.append(contentsOf: dataArray.map { (table: currentClassTable, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.kelasID, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: false) })
        }

        // MARK: - KELAS DATA

        // Mengumpulkan data dari deletedDataArray
        for deletedData in SingletonData.deletedDataArray {
            let currentClassTable = deletedData.table
            let dataArray = deletedData.data
            allDataToDelete.append(contentsOf: dataArray.map { (table: currentClassTable, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.kelasID, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: false) })
        }

        // Mengumpulkan data dari deletedDataKelas
        for deletedName in SingletonData.deletedDataKelas {
            let classTable = deletedName.table
            let data = deletedName.data
            allDataToDelete.append(contentsOf: data.map { (table: classTable, kelasAwal: nil, kelasDikecualikan: nil, kelasID: $0.kelasID, isHapusKelas: true, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: false) })
        }
        
        // MARK: - NILAI KELAS YANG BELUM DISIMPAN
        for data in SingletonData.insertedID {
            allDataToDelete.append((table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: data, isHapusKelas: true, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: false))
        }

        // MARK: - DATA SISWA DAN KELAS

        for siswa in SingletonData.siswaNaikArray {
            // Ambil siswaID, kelasAwal, dan kelasDikecualikan dari tuple
            let siswaIDs = siswa.siswaID
            let kelasAwal = siswa.kelasAwal.first // Mengambil kelas awal pertama jika ada
            let kelasDikecualikan = siswa.kelasDikecualikan.first // Mengambil kelas dikecualikan pertama jika ada

            // Iterasi melalui setiap siswaID
            for id in siswaIDs {
                allDataToDelete.append((table: nil, kelasAwal: kelasAwal, kelasDikecualikan: kelasDikecualikan, kelasID: id, isHapusKelas: false, isSiswaNaik: true, hapusGuru: false, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: false))
            }
        }

        // MARK: - GURU DATA

        for guruID in SingletonData.deletedGuru {
            allDataToDelete.append((table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: guruID, isHapusKelas: false, isSiswaNaik: false, hapusGuru: true, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: false))
        }

        for guruID in SingletonData.undoAddGuru {
            allDataToDelete.append((table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: guruID, isHapusKelas: false, isSiswaNaik: false, hapusGuru: true, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: false))
        }

        // MARK: - TUGAS GURU

        for id in SingletonData.deletedTugasGuru {
            allDataToDelete.append((table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: id, isHapusKelas: false, isSiswaNaik: false, hapusGuru: true, hapusInventory: false, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: true))
        }

        // MARK: - INVENTORY

        for invID in SingletonData.deletedInvID {
            allDataToDelete.append((table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: invID, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: true, hapusKolomInventory: false, namaKolomInventory: "", hapusTugasGuru: false))
        }

        for (columnName, _) in SingletonData.deletedColumns {
            allDataToDelete.append((table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: -1, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: true, namaKolomInventory: columnName, hapusTugasGuru: false))
        }
        for (columnName, _) in SingletonData.undoAddColumns {
            allDataToDelete.append((table: nil, kelasAwal: nil, kelasDikecualikan: nil, kelasID: -1, isHapusKelas: false, isSiswaNaik: false, hapusGuru: false, hapusInventory: false, hapusKolomInventory: true, namaKolomInventory: columnName, hapusTugasGuru: false))
        }

        return allDataToDelete
    }

    /**
         Memproses penghapusan item berdasarkan berbagai kondisi yang diberikan.

         Fungsi ini menangani penghapusan data dari database berdasarkan kombinasi flag yang berbeda,
         termasuk penghapusan guru, kelas, data dari kelas, daftar, pemrosesan kenaikan kelas siswa,
         penghapusan data inventaris, dan penghapusan kolom inventaris.

         - Parameter:
             - item: Sebuah tuple yang berisi informasi tentang item yang akan dihapus. Tuple ini mencakup:
                 - table: (Opsional) Tabel yang terkait dengan item.
                 - kelasAwal: (Opsional) Kelas awal item.
                 - kelasDikecualikan: (Opsional) Kelas yang dikecualikan dari item.
                 - kelasID: ID kelas item.
                 - isHapusKelas: Flag yang menunjukkan apakah kelas harus dihapus.
                 - isSiswaNaik: Flag yang menunjukkan apakah siswa naik kelas.
                 - hapusGuru: Flag yang menunjukkan apakah guru harus dihapus.
                 - hapusInventory: Flag yang menunjukkan apakah data inventaris harus dihapus.
                 - hapusKolomInventory: Flag yang menunjukkan apakah kolom inventaris harus dihapus.
                 - namaKolomInventory: (Opsional) Nama kolom inventaris yang akan dihapus.

         Fungsi ini menggunakan `DatabaseController.shared` untuk melakukan operasi penghapusan yang berbeda
         berdasarkan flag yang diberikan. Untuk penghapusan inventaris dan kolom inventaris, fungsi ini menggunakan
         `DynamicTable.shared` dan menjalankan operasi secara asinkron menggunakan `Task`.
     */
    func processDeleteItem(_ item: (table: Table?, kelasAwal: String?, kelasDikecualikan: String?, kelasID: Int64, isHapusKelas: Bool, isSiswaNaik: Bool, hapusGuru: Bool, hapusInventory: Bool, hapusKolomInventory: Bool, namaKolomInventory: String, hapusTugasGuru: Bool)) {
        if item.hapusTugasGuru == true {
            DatabaseController.shared.hapusTugasGuru(item.kelasID)
        } else if item.hapusGuru == true, item.hapusInventory == false {
            DatabaseController.shared.hapusGuru(idGuruValue: item.kelasID)
        } else if item.isHapusKelas {
            DatabaseController.shared.deleteSpecificNilai(nilaiID: item.kelasID)
        } else if item.table != nil {
            DatabaseController.shared.deleteSpecificNilai(nilaiID: item.kelasID)
        } else if item.isSiswaNaik == false, item.hapusInventory == false, item.hapusKolomInventory == false {
            DatabaseController.shared.hapusDaftar(idValue: item.kelasID)
        } else if item.isSiswaNaik == true, item.hapusInventory == false, item.hapusKolomInventory == false {
            
        } else if item.hapusInventory == true, item.hapusKolomInventory == false {
            Task {
                await DynamicTable.shared.setupDatabase()
                await DynamicTable.shared.deleteData(withID: item.kelasID)
            }
        } else if item.hapusKolomInventory == true {
            Task {
                await DynamicTable.shared.setupDatabase()
                await DynamicTable.shared.deleteColumn(tableName: "main_table", columnName: item.namaKolomInventory)
            }
        }
    }

    /**
     Menyelesaikan proses penghapusan data dan melakukan tindakan lanjutan seperti membersihkan data yang dihapus,
     memvakum database, dan menampilkan notifikasi atau menutup aplikasi.

     - Parameter totalDeletedData: Jumlah total data yang berhasil dihapus.
     - Parameter tutupApp: Nilai boolean yang menentukan apakah aplikasi harus ditutup setelah penghapusan selesai.
                              Jika `true`, aplikasi akan ditutup; jika `false`, aplikasi akan tetap berjalan dan menampilkan notifikasi.
     */
    func finishDeletion(totalDeletedData: Int, tutupApp: Bool) {
        OperationQueue.main.addOperation {
            if let window = self.progressWindowController.window {
                self.progressViewController.currentStudentIndex = totalDeletedData
                if tutupApp {
                    DatabaseController.shared.notifQueue.async {
                        DatabaseController.shared.vacuumDatabase()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            NSApp.mainWindow?.endSheet(window)
                            window.close() // Menutup jendela progress
                            NSApp.reply(toApplicationShouldTerminate: true)
                        }
                    }
                } else {
                    DatabaseController.shared.notifQueue.async {
                        self.clearDeletedData()
                        DatabaseController.shared.vacuumDatabase()
                        NotificationCenter.default.post(name: .saveData, object: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            NSApp.mainWindow?.endSheet(window)
                            window.close() // Menutup jendela progress
                            NSApp.reply(toApplicationShouldTerminate: false)
                            ReusableFunc.showProgressWindow(3, pesan: "\(totalDeletedData) pembaruan berhasil disimpan", image: NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: .none) ?? ReusableFunc.menuOnStateImage!)
                        }
                    }
                }
            }
        }
    }

    /// Fungsi untuk membersihkan semua array yang digunakan untuk
    /// menyimpan referensi data yang dihapus di ``SingletonData``
    /// setelah proses penyimpanan selesai.
    func clearDeletedData() {
        SingletonData.deletedStudentIDs.removeAll()
        SingletonData.deletedKelasAndSiswaIDs.removeAll()
        SingletonData.deletedDataArray.removeAll()
        SingletonData.pastedData.removeAll()
        SingletonData.deletedDataKelas.removeAll()
        SingletonData.undoStack.removeAll()
        SingletonData.deletedSiswasArray.removeAll()
        SingletonData.deletedSiswaArray.removeAll()
        SingletonData.siswaNaikArray.removeAll()
        SingletonData.deletedGuru.removeAll()
        SingletonData.deletedTugasGuru.removeAll()
        SingletonData.undoAddGuru.removeAll()
        SingletonData.deletedColumns.removeAll()
        SingletonData.deletedInvID.removeAll()
        SingletonData.undoAddColumns.removeAll()
        SingletonData.redoPastedSiswaArray.removeAll()
        SingletonData.undoAddSiswaArray.removeAll()
        ImageCacheManager.shared.clear()
        Task {
            await DatabaseController.shared.tabelNoRelationCleanup()
            await IdsCacheManager.shared.clearUpCache()
        }
    }
}
