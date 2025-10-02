//
//  DataManager.swift //  Administrasi
//
//  Created by Bismillah on 13/11/23.
//

import CoreData
import Foundation
import SQLite3

/// Pengelola baca/tulis database CoreData.
///
/// Logika pengelolaan data di dalam file sqlite yang dibuat CoreData.
/// Menyalin file ke direktori ~/Application Support/DataSDI/ untuk editing.
/// *Checkpoint* ketika aplikasi akan ditutup untuk integrasi file WAL dan SHM ke file sqlite
/// dan menyimpannya di direktori ~/Documents/DataSDI/
class DataManager {
    /// Singleton untuk mengelola data Administrasi
    static let shared: DataManager = .init()

    /// url ke file Data Manager.sqlite di folder ~/Library/Apllication Support/
    static let sourceURL = {
        #if DEBUG
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("DataSDI/Data Manager.sqlite")
        #else
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Data SDI/Data Manager.sqlite")
        #endif
    }()

    /// url ke file Administrasi.sdi di folder dokumen
    static let destURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Data SDI/Administrasi.sdi")

    /// Private initializer untuk singleton DataManager.shared
    private init() {
        let context = persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        managedObjectContext = context
    }

    /// Notifikasi data administrasi jika berubah.
    static let dataDidChangeNotification = NSNotification.Name("DataManagerDataDidChange")
    /// Notifikasi data administrasi jika diperbarui.
    static let dataDieditNotif = NSNotification.Name("DataDiedit")
    /// Notifikasi data administrasi jika dihapus.
    static let dataDihapusNotif = NSNotification.Name("DataDihapus")
    /// Notifikasi data administrasi jika ditambah.
    static let dataDitambahNotif = NSNotification.Name("DataDitambah")

    /// UndoManager untuk TransaksiView.
    var myUndoManager: UndoManager = .init()

    /// Sebuah Instance `NSManagedObjectContext` yang dikonfigurasi untuk operasi di *background*.
    ///
    /// Konteks ini diambil dari `persistentContainer` milik `AppDelegate` dan diatur untuk
    /// secara otomatis menggabungkan perubahan dari konteks induknya (`automaticallyMergesChangesFromParent = true`).
    /// Ini sangat berguna untuk melakukan operasi Core Data yang intensif tanpa memblokir *thread* utama UI,
    /// memastikan aplikasi tetap responsif.
    ///
    /// - Catatan:
    ///   - Mengasumsikan bahwa `NSApplication.shared.delegate` dapat di-*cast* ke `AppDelegate`.
    ///   - `AppDelegate` harus memiliki properti `persistentContainer` yang mengembalikan `NSPersistentContainer`.
    ///   - Penggunaan konteks *background* ini membantu menjaga performa aplikasi tetap lancar
    ///     saat melakukan *fetch* atau menyimpan data dalam jumlah besar.
    var managedObjectContext: NSManagedObjectContext!

    // MARK: - Core Data stack

    /**
         Memuat persistent container untuk aplikasi.

         Properti ini secara lazy melakukan inisialisasi NSPersistentContainer dengan nama "Data Manager".
         Properti ini menangani proses penyalinan data awal dari lokasi penyimpanan iCloud (jika ada) ke lokasi penyimpanan lokal,
         serta membandingkan ukuran dan tanggal modifikasi file untuk memastikan data yang digunakan adalah yang terbaru.

         - Note: Properti ini menggunakan DispatchSemaphore untuk menunggu proses penyalinan selesai sebelum memuat persistent stores.
         - Warning: Pastikan untuk menangani potensi error yang mungkin terjadi selama proses penyalinan atau pemuatan persistent stores.
     */
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Data Manager")

        let fm = FileManager.default
        let source = DataManager.sourceURL
        let dest = DataManager.destURL
        var wait = false
        let semaphore = DispatchSemaphore(value: 0) // Untuk menunggu proses copy

        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            if !fm.fileExists(atPath: dest.path) {
                do {
                    let resourceValues = try dest.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
                    // Check if it's an iCloud item AND not downloaded
                    if let isUbiquitous = resourceValues.isUbiquitousItem, isUbiquitous {
                        if let downloadingStatus = resourceValues.ubiquitousItemDownloadingStatus {
                            switch downloadingStatus {
                            case .current:
                                // This case implies it's downloaded, but we are in !fileExists,
                                // so this path might not be taken often, or it means something is wrong
                                // if fileExists is false but status is .current.
                                // For safety, if it's .current, you might assume it's there or will be shortly.
                                break
                            case .downloaded:
                                // Similar to .current, implies it's downloaded.
                                break
                            case .notDownloaded:
                                // The file exists in iCloud but has not been downloaded to the local device.
                                DispatchQueue.main.async { [unowned self] in
                                    let alert = NSAlert()
                                    alert.messageText = "Data Administrasi belum diunduh dari iCloud."
                                    alert.informativeText = "Aplikasi dimuat lebih lama untuk menunggu data administrasi siap."
                                    alert.runModal()
                                }
                                do {
                                    try fm.startDownloadingUbiquitousItem(at: dest)
                                    #if DEBUG
                                        print("Memulai unduhan dari iCloud...")
                                    #endif
                                    // Tunggu hingga file tersedia sebelum melanjutkan
                                    while !fm.fileExists(atPath: dest.path) {
                                        #if DEBUG
                                            print("Menunggu file selesai diunduh...")
                                        #endif
                                        sleep(1) // Polling setiap 1 detik
                                    }
                                } catch {
                                    #if DEBUG
                                        print("❌: \(error.localizedDescription)")
                                    #endif
                                }
                            default:
                                break
                            }
                        }
                    }
                } catch { print(error.localizedDescription) }
            }
            do {
                /// jangan ubah `try?` ke `try`. karena akan masuk ke catch jika item tidak ada.
                try? fm.removeItem(atPath: source.path + "-shm")
                try? fm.removeItem(atPath: source.path + "-wal")
                // Pastikan dest ada sebelum mengecek atributnya
                if fm.fileExists(atPath: dest.path) {
                    /// jangan ubah `try?` ke `try`. karena akan masuk ke catch jika item tidak ada.
                    let sourceAttributes = try? fm.attributesOfItem(atPath: source.path)
                    let destAttributes = try? fm.attributesOfItem(atPath: dest.path)

                    // Ambil ukuran file dan tanggal modifikasi
                    let sourceSize = sourceAttributes?[.size] as? UInt64
                    let destSize = destAttributes?[.size] as? UInt64

                    let sourceDate = sourceAttributes?[.modificationDate] as? Date
                    let destDate = destAttributes?[.modificationDate] as? Date

                    // Periksa apakah ukuran dan tanggal modifikasi sama
                    if sourceSize != destSize || sourceDate != destDate {
                        wait = true
                        /// jangan ubah `try?` ke `try`. karena akan masuk ke catch jika item tidak ada.
                        try? fm.removeItem(at: source)
                        try fm.copyItem(at: dest, to: source)
                    }
                }
            } catch {
                #if DEBUG
                    print("❌", error.localizedDescription)
                #endif
            }
            if wait {
                sleep(2) // Jeda 2 detik sebelum melanjutkan
            }
            semaphore.signal() // Selesai
        }

        // Tunggu sampai proses salin selesai
        semaphore.wait()

        container.loadPersistentStores(completionHandler: { storeDescription, error in
            if let error {
                print("❌", error.localizedDescription)
            } else {
                #if DEBUG
                    print("success", storeDescription)
                #endif
            }
        })
        return container
    }()

    /// Memeriksa dan menetapkan UUID ke entitas yang belum memilikinya.
    ///
    /// Fungsi ini melakukan *fetch* semua `Entity` dari Core Data yang properti `id`-nya adalah `nil`.
    /// Tergantung pada nilai parameter `postNotification`, fungsi ini akan melakukan salah satu dari dua hal:
    ///
    /// 1.  **Jika `postNotification` adalah `true` (default):**
    ///     Jika ada entitas dengan `id` `nil`, fungsi ini akan memposting notifikasi
    ///     `.didAssignUUID`. Ini berguna untuk memberi tahu bagian lain dari aplikasi bahwa
    ///     ada entitas yang perlu diperbarui UUID-nya.
    ///
    /// 2.  **Jika `postNotification` adalah `false`:**
    ///     Fungsi ini akan mengiterasi semua entitas yang `id`-nya `nil`, menetapkan `UUID()` baru
    ///     ke masing-masing entitas, dan kemudian menyimpan perubahan ke Core Data. Ini adalah
    ///     mekanisme untuk memperbaiki data yang tidak memiliki UUID.
    ///
    /// Penanganan kesalahan dasar disertakan, dan kesalahan akan dicetak ke konsol dalam mode `DEBUG`.
    ///
    /// - Parameter postNotification: Sebuah `Bool` yang menentukan perilaku fungsi.
    ///   - `true`: Hanya memposting notifikasi jika ditemukan entitas tanpa UUID.
    ///   - `false`: Menetapkan UUID dan menyimpan perubahan ke entitas yang tidak memilikinya.
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `DataManager.shared.managedObjectContext` untuk interaksi Core Data.
    ///   - `Entity` diasumsikan sebagai objek `NSManagedObject` dengan properti `id` yang bertipe `UUID?`.
    ///   - `.didAssignUUID` adalah `Notification.Name` yang telah didefinisikan sebelumnya di dalam Folder /Main/Extensions/Notification.
    func checkAndAssignUUIDIfNeeded(postNotification: Bool = true) {
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == nil")

        do {
            let entitiesWithNilID = try DataManager.shared.managedObjectContext.fetch(fetchRequest)
            if postNotification {
                if !entitiesWithNilID.isEmpty {
                    NotificationCenter.default.post(name: .didAssignUUID, object: nil)
                }
            } else {
                if !entitiesWithNilID.isEmpty {
                    for entity in entitiesWithNilID {
                        entity.id = UUID()
                    }
                    try DataManager.shared.managedObjectContext.save()
                }
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
    }

    /// Menambahkan entitas data baru ke Core Data dengan detail yang diberikan.
    ///
    /// Fungsi ini membuat objek `Entity` baru di dalam `NSManagedObjectContext` yang dikelola oleh `DataManager.shared`.
    /// Semua properti yang relevan dari entitas diatur menggunakan nilai parameter yang disediakan.
    /// Setelah entitas diatur, perubahan disimpan ke Core Data. Jika penyimpanan berhasil,
    /// notifikasi `DataManager.dataDitambahNotif` akan diposting, berisi entitas yang baru ditambahkan.
    ///
    /// Selain itu, fungsi ini memperbarui koleksi global dari string unik untuk **kategori**, **acara**, dan **keperluan**
    /// yang disimpan dalam `ReusableFunc`. Ini melibatkan pemisahan string input berdasarkan spasi,
    /// membersihkan entri, dan menambahkan versi yang dikapitalisasi dan dipangkas ke set yang sesuai.
    ///
    /// - Parameters:
    ///   - id: `UUID` unik untuk entitas data.
    ///   - jenis: `String` yang menunjukkan jenis data (misalnya, "Pemasukan", "Pengeluaran").
    ///   - dari: `String` yang menunjukkan sumber atau asal data.
    ///   - jumlah: `Double` yang menunjukkan nilai numerik data.
    ///   - kategori: `String` yang menunjukkan kategori data.
    ///   - acara: `String` yang menunjukkan acara terkait data.
    ///   - keperluan: `String` opsional yang menunjukkan keperluan data.
    ///   - tanggal: `Date` yang menunjukkan tanggal data.
    ///   - bulan: `Int16` yang menunjukkan bulan data.
    ///   - tahun: `Int16` yang menunjukkan tahun data.
    ///   - tanda: `Bool` yang menunjukkan status penandaan data.
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `DataManager.shared.managedObjectContext` untuk manajemen Core Data.
    ///   - `Entity` diasumsikan sebagai kelas `NSManagedObject` yang dihasilkan dari model Core Data.
    ///   - `DataManager.dataDitambahNotif` diasumsikan sebagai `Notification.Name` yang telah didefinisikan.
    ///   - `ReusableFunc.kategori`, `ReusableFunc.acara`, dan `ReusableFunc.keperluan` diasumsikan sebagai
    ///     properti `Set<String>` statis atau global yang dapat diakses untuk menyimpan string unik.
    ///   - Kesalahan saat menyimpan ke Core Data akan dicetak ke konsol dalam mode `DEBUG`.
    func addData(id: UUID, jenis: Int16, dari: String, jumlah: Double, kategori: String, acara: String, keperluan: String, tanggal: Date, bulan: Int16, tahun: Int16, tanda: Bool) {
        if let entity = NSEntityDescription.entity(forEntityName: "Entity", in: DataManager.shared.managedObjectContext) {
            let data = NSManagedObject(entity: entity, insertInto: DataManager.shared.managedObjectContext) as! Entity
            // Setel nilai-nilai atribut sesuai kebutuhan
            data.id = id
            data.jenis = jenis
            data.dari = dari
            data.jumlah = jumlah

            // ✅ STRING KE RELATIONSHIP:
            data.kategori = getOrCreateUniqueString(value: kategori, context: managedObjectContext)
            data.acara = getOrCreateUniqueString(value: acara, context: managedObjectContext)
            data.keperluan = getOrCreateUniqueString(value: keperluan, context: managedObjectContext)

            data.tanggal = tanggal
            data.bulan = bulan
            data.tahun = tahun
            data.ditandai = tanda
            // Simpan perubahan ke Core Data
            do {
                try managedObjectContext.save()
                NotificationCenter.default.post(name: DataManager.dataDitambahNotif, object: nil, userInfo: ["data": data])
            } catch let error as NSError {
                #if DEBUG
                    print(error)
                #endif
            }
            var kategoriW: Set<String> = []
            var acaraW: Set<String> = []
            var keperluanW: Set<String> = []
            kategoriW.formUnion(kategori.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            kategoriW.insert(kategori.capitalizedAndTrimmed())
            ReusableFunc.kategori.formUnion(kategoriW)

            acaraW.formUnion(acara.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            acaraW.insert(acara.capitalizedAndTrimmed())
            ReusableFunc.acara.formUnion(acaraW)

            let perlu = keperluan
            keperluanW.formUnion(perlu.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            keperluanW.insert(perlu.capitalizedAndTrimmed())
            ReusableFunc.keperluan.formUnion(keperluanW)
        }
    }

    /// Mengambil atau membuat `UniqueString` berdasarkan nilai string yang diberikan.
    ///
    /// Fungsi ini akan mencari entitas `UniqueString` di Core Data yang memiliki `value`
    /// sama dengan parameter `value`. Jika sudah ada, fungsi akan mengembalikan
    /// entitas tersebut. Jika belum ada, fungsi akan membuat entitas baru,
    /// meng-intern nilai string untuk efisiensi memori, lalu mengembalikannya.
    ///
    /// Gunakan fungsi ini setiap kali ingin menetapkan nilai string pada properti
    /// relasi seperti `acara`, `keperluan`, atau `kategori`.
    ///
    /// - Parameters:
    ///   - value: Nilai string yang akan dicari atau dibuat menjadi entitas `UniqueString`.
    ///   - context: `NSManagedObjectContext` yang digunakan untuk melakukan fetch atau insert.
    /// - Returns: Objek `UniqueString` yang sesuai dengan nilai yang diberikan.
    func getOrCreateUniqueString(value: String, context: NSManagedObjectContext) -> UniqueString {
        let request: NSFetchRequest<UniqueString> = UniqueString.fetchRequest()
        request.predicate = NSPredicate(format: "value == %@", value)

        if let existing = try? context.fetch(request).first {
            return existing
        } else {
            let newUniqueString = UniqueString(context: context)
            newUniqueString.id = UUID()
            newUniqueString.value = StringInterner.shared.intern(value)
            return newUniqueString
        }
    }

    /// Seperti fungsi `addData(id:)` namun ini untuk data yang benar-benar baru dan memasukkan id UUID secara acak.
    /// - Returns: Ini adalah UUID yang dibuat yang bisa digunakan untuk proses undo/redo penambahan data di administrasi.
    func addData(jenis: Int16, dari: String, jumlah: Double, kategori: String, acara: String, keperluan: String, tanggal: Date, bulan: Int16, tahun: Int16, tanda: Bool) -> UUID? {
        if let entity = NSEntityDescription.entity(forEntityName: "Entity", in: DataManager.shared.managedObjectContext) {
            let data = NSManagedObject(entity: entity, insertInto: DataManager.shared.managedObjectContext) as! Entity
            // Setel nilai-nilai atribut sesuai kebutuhan
            data.id = UUID()
            data.jenis = jenis
            data.dari = dari
            data.jumlah = jumlah

            data.kategori = getOrCreateUniqueString(value: kategori, context: managedObjectContext)
            data.acara = getOrCreateUniqueString(value: acara, context: managedObjectContext)
            data.keperluan = getOrCreateUniqueString(value: keperluan, context: managedObjectContext)

            data.tanggal = tanggal
            data.bulan = bulan
            data.tahun = tahun
            data.ditandai = tanda
            // Simpan perubahan ke Core Data
            do {
                try managedObjectContext.save()
                NotificationCenter.default.post(name: DataManager.dataDitambahNotif, object: nil, userInfo: ["data": data])
            } catch let error as NSError {
                #if DEBUG
                    print(error)
                #endif
            }
            var kategoriW: Set<String> = []
            var acaraW: Set<String> = []
            var keperluanW: Set<String> = []
            kategoriW.formUnion(kategori.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            kategoriW.insert(kategori.capitalizedAndTrimmed())
            ReusableFunc.kategori.formUnion(kategoriW)

            acaraW.formUnion(acara.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            acaraW.insert(acara.capitalizedAndTrimmed())
            ReusableFunc.acara.formUnion(acaraW)

            let perlu = keperluan
            keperluanW.formUnion(perlu.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
            keperluanW.insert(perlu.capitalizedAndTrimmed())
            ReusableFunc.keperluan.formUnion(keperluanW)

            return data.id
        }
        return nil
    }

    /// Mengambil data yang relevan untuk fitur pelengkapan otomatis dari Core Data.
    ///
    /// Fungsi ini melakukan *fetch* semua `Entity` dari Core Data, secara spesifik hanya mengambil
    /// properti `kategori`, `acara`, dan `keperluan`. Hasil *fetch* dikembalikan sebagai array
    /// dari kamus (`[[String: Any]]`), di mana setiap kamus mewakili satu entitas dan berisi
    /// nilai-nilai untuk properti yang diminta.
    ///
    /// Fungsi ini juga mencoba untuk mengubah hasil *fetch* menjadi array objek `AutoCompletion`
    /// meskipun pada akhirnya mengembalikan `result` asli dari *fetch* yang bertipe `[[String: Any]]`.
    ///
    /// - Returns: Sebuah array opsional `[[String: Any]]` yang berisi kamus data
    ///            (`kategori`, `acara`, `keperluan`) dari setiap entitas yang berhasil diambil.
    ///            Mengembalikan `nil` jika *fetch* gagal atau hasilnya tidak dapat di-*cast*
    ///            dengan benar.
    ///
    /// - Catatan:
    ///   - `managedObjectContext` diasumsikan sebagai `NSManagedObjectContext` yang tersedia
    ///     untuk melakukan operasi Core Data.
    ///   - `Entity` diasumsikan sebagai nama entitas Core Data yang valid.
    ///   - `AutoCompletion` diasumsikan sebagai struktur atau kelas yang memiliki properti
    ///     `kategori`, `acara`, dan `keperluan` (meskipun bagian ini dari kode tampaknya tidak
    ///     digunakan untuk nilai kembalian).
    ///   - Kesalahan saat *fetch* akan dicetak ke konsol dalam mode `DEBUG`.
    func fetchAutoCompletionData() -> [AutoCompletion] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Entity")
        fetchRequest.resultType = .managedObjectResultType

        do {
            let fetchedResults = try managedObjectContext.fetch(fetchRequest)
            guard let result = fetchedResults as? [NSManagedObject] else { return [] }

            var autoCompleteItems: [AutoCompletion] = []

            for object in result {
                var autoCompleteItem = AutoCompletion()

                if let kategoriObj = object.value(forKey: "kategori") as? NSManagedObject {
                    let rawValue = kategoriObj.value(forKey: "value") as? String ?? ""
                    autoCompleteItem.kategori = StringInterner.shared.intern(rawValue)
                }

                if let acaraObj = object.value(forKey: "acara") as? NSManagedObject {
                    let rawValue = acaraObj.value(forKey: "value") as? String ?? ""
                    autoCompleteItem.acara = StringInterner.shared.intern(rawValue)
                }

                if let keperluanObj = object.value(forKey: "keperluan") as? NSManagedObject {
                    let rawValue = keperluanObj.value(forKey: "value") as? String ?? ""
                    autoCompleteItem.keperluan = StringInterner.shared.intern(rawValue)
                }

                autoCompleteItems.append(autoCompleteItem)
            }

            return autoCompleteItems

        } catch {
            print(error)
            return []
        }
    }

    /// Ini adalah varian spesifik dari operasi pengambilan data sesuai dengan UUID yang diberikan; untuk mengambil *semua* entitas,
    /// lihat ``fetchData()``
    func fetchData(by id: UUID) -> Entity? {
        let fetchRequest = NSFetchRequest<Entity>(entityName: "Entity")

        // Menambahkan predicate untuk filter berdasarkan id
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        // Menambahkan sort descriptor untuk menyortir data berdasarkan tanggal dari terlama ke terbaru
        let sortDescriptor = NSSortDescriptor(key: "tanggal", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            let entity = try managedObjectContext.fetch(fetchRequest).first
            if let acara = entity?.acara {
                acara.value = StringInterner.shared.intern(acara.value ?? "")
            }
            if let keperluan = entity?.keperluan {
                keperluan.value = StringInterner.shared.intern(keperluan.value ?? "")
            }
            if let kategori = entity?.kategori {
                kategori.value = StringInterner.shared.intern(kategori.value ?? "")
            }
            // Mengambil entitas pertama yang sesuai dengan ID
            return entity
        } catch let error as NSError {
            #if DEBUG
                print(error)
            #endif
            return nil
        }
    }

    /// Mengambil semua entitas dari Core Data dan mengembalikannya dalam urutan tanggal menaik.
    /// 
    /// Fungsi ini melakukan operasi *fetch* secara sinkron pada `managedObjectContext` yang dibagikan
    /// oleh `DataManager`. Semua `Entity` akan diambil dan diurutkan berdasarkan properti `tanggal`
    /// dari yang paling lama ke yang paling baru.
    /// 
    /// - Returns: Sebuah array `[Entity]` yang berisi semua entitas yang berhasil diambil dari Core Data.
    ///            Mengembalikan array kosong jika tidak ada data atau jika terjadi kesalahan saat *fetch*.
    /// 
    /// - Catatan:
    ///   - Fungsi ini menggunakan `DataManager.shared.managedObjectContext` yang diasumsikan
    ///     telah dikonfigurasi dengan benar untuk mengakses penyimpanan Core Data.
    ///   - `Entity` diasumsikan sebagai objek `NSManagedObject` yang dihasilkan dari model Core Data
    ///     dengan properti `tanggal`.
    ///   - Kesalahan saat *fetch* akan dicetak ke konsol dalam mode `DEBUG`.
    /// - Parameter tahun: Opsional untuk filter data pada tahun tertentu.
    func fetchData(tahun: Int16? = nil) -> [Entity] {
        var entities: [Entity] = []
        DataManager.shared.managedObjectContext.performAndWait {
            let fetchRequest = NSFetchRequest<Entity>(entityName: "Entity")

            // Menambahkan filter tahun jika parameter tahun tidak nil
            if let tahun = tahun {
                let predicate = NSPredicate(format: "tahun == %d", tahun)
                fetchRequest.predicate = predicate
            }

            // Menambahkan sort descriptor untuk menyortir data berdasarkan tanggal dari terlama ke terbaru
            let sortDescriptor = NSSortDescriptor(key: "tanggal", ascending: true)
            fetchRequest.sortDescriptors = [sortDescriptor]

            do {
                let fetched = try DataManager.shared.managedObjectContext.fetch(fetchRequest)
                // Intern string di sini
                for entity in fetched {
                    if let acara = entity.acara {
                        acara.value = StringInterner.shared.intern(acara.value ?? "")
                    }
                    if let keperluan = entity.keperluan {
                        keperluan.value = StringInterner.shared.intern(keperluan.value ?? "")
                    }
                    if let kategori = entity.kategori {
                        kategori.value = StringInterner.shared.intern(kategori.value ?? "")
                    }
                }

                entities = fetched
            } catch let error as NSError {
                #if DEBUG
                    print(error)
                #endif
            }
        }

        return entities
    }

    /// Mengambil daftar tahun unik dari entity Core Data `Entity`.
    ///
    /// Fungsi ini menggunakan `NSFetchRequest` bertipe `.dictionaryResultType`
    /// untuk hanya mengambil kolom `tahun` (yang diharapkan sudah disimpan sebagai atribut).
    /// Hasilnya diubah ke `Set<Int>` agar hasil benar-benar unik,
    /// lalu dikembalikan sebagai `Array` tahun.
    ///
    /// Jika field `tahun` tidak disimpan langsung di model Core Data,
    /// maka properti `propertiesToFetch` harus diubah agar valid.
    ///
    /// - Returns: Array berisi tahun unik (`[Int]`).
    func fetchUniqueYears() -> [Int] {
        var uniqueYears = Set<Int>()
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Entity")
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = ["tahun"]
        fetchRequest.returnsDistinctResults = true

        do {
            let results = try DataManager.shared.managedObjectContext.fetch(fetchRequest)

            for dict in results {
                if let year = dict["tahun"] as? Int16 {
                    uniqueYears.insert(Int(year))
                }
            }
        } catch {
            #if DEBUG
                print("Fetch unique years failed:", error)
            #endif
        }

        return Array(uniqueYears)
    }

    /// Menandai (atau membatalkan tanda) suatu entitas tanpa memposting notifikasi.
    ///
    /// Fungsi ini memperbarui properti `ditandai` dari `entity` yang diberikan ke nilai `tertandai` yang ditentukan.
    /// Perubahan ini dilakukan dalam blok `performAndWait` pada `managedObjectContext` untuk memastikan
    /// operasi yang aman terhadap *thread*. Jika status penandaan berubah, `UUID` entitas akan
    /// dimasukkan ke dalam set `uuid` (meskipun set ini tidak digunakan setelahnya di dalam fungsi).
    /// Perubahan kemudian disimpan ke Core Data. Kesalahan selama proses penyimpanan akan dicetak ke konsol.
    ///
    /// - Parameters:
    ///   - entity: Objek `Entity` yang akan ditandai atau dibatalkan tandanya.
    ///   - tertandai: Nilai `Bool` yang menunjukkan apakah entitas harus ditandai (`true`)
    ///                atau dibatalkan tandanya (`false`).
    ///
    /// - Catatan:
    ///   - `managedObjectContext` diasumsikan sebagai `NSManagedObjectContext` yang tersedia.
    ///   - `Entity` diasumsikan sebagai objek `NSManagedObject` yang dihasilkan dari model Core Data
    ///     dengan properti `ditandai` (bertipe `Bool`) dan `id` (bertipe `UUID?`).
    ///   - Fungsi ini secara eksplisit *tidak* memposting notifikasi setelah perubahan,
    ///     berbeda dengan beberapa operasi data lainnya.
    func tandaiDataTanpaNotif(_ entity: Entity, tertandai: Bool) {
        var uuid: Set<UUID> = []
        managedObjectContext.performAndWait {
            if entity.ditandai != tertandai {
                entity.ditandai = tertandai
                uuid.insert(entity.id ?? UUID())
            }
            do {
                try managedObjectContext.save()
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    /// Mengedit properti-properti dari entitas Core Data yang sudah ada.
    ///
    /// Fungsi ini memperbarui properti-properti dari objek `Entity` yang diberikan (`entity`)
    /// dengan nilai-nilai baru yang disediakan sebagai parameter. Setelah semua properti diatur,
    /// perubahan disimpan ke `managedObjectContext`. Jika penyimpanan berhasil, notifikasi
    /// `DataManager.dataDiperbaruiNotif` akan diposting, memberi tahu bagian lain dari aplikasi
    /// tentang perubahan yang telah terjadi.
    ///
    /// Selain itu, fungsi ini memperbarui koleksi global dari string unik untuk **kategori**, **acara**,
    /// dan **keperluan** yang disimpan dalam `ReusableFunc`. Ini melibatkan pemisahan string input
    /// berdasarkan spasi, membersihkan entri, dan menambahkan versi yang dikapitalisasi dan dipangkas
    /// ke set yang sesuai.
    ///
    /// - Parameters:
    ///   - entity: Objek `Entity` yang akan diedit. Ini harus merupakan entitas yang sudah ada dan diambil dari Core Data.
    ///   - jenis: `String` baru untuk jenis data (misalnya, "Pemasukan", "Pengeluaran").
    ///   - dari: `String` baru untuk sumber atau asal data.
    ///   - jumlah: `Double` baru untuk nilai numerik data.
    ///   - kategori: `String` baru untuk kategori data.
    ///   - acara: `String` baru untuk acara terkait data.
    ///   - keperluan: `String` opsional baru untuk keperluan data.
    ///   - tanggal: `Date` baru untuk tanggal data.
    ///   - bulan: `Int16` baru untuk bulan data.
    ///   - tahun: `Int16` baru untuk tahun data.
    ///   - tanda: `Bool` baru untuk status penandaan data.
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `managedObjectContext` (diasumsikan `DataManager.shared.managedObjectContext`)
    ///     untuk interaksi Core Data.
    ///   - `DataManager.dataDiperbaruiNotif` diasumsikan sebagai `Notification.Name` yang telah didefinisikan.
    ///   - `ReusableFunc.kategori`, `ReusableFunc.acara`, dan `ReusableFunc.keperluan` diasumsikan sebagai
    ///     properti `Set<String>` statis atau global yang dapat diakses untuk menyimpan string unik.
    ///   - Kesalahan saat menyimpan ke Core Data akan dicetak ke konsol dalam mode `DEBUG`.
    func editData(entity: Entity, jenis: Int16, dari _: String, jumlah: Double, kategori: String, acara: String, keperluan: String?, tanggal _: Date, bulan _: Int16, tahun _: Int16, tanda: Bool) {
        // Setel nilai-nilai atribut sesuai kebutuhan
        if entity.jenis != jenis {
            entity.jenis = jenis
        }

        // ✅ Relasi ke UniqueString
        let currentKategori = entity.kategori?.value ?? ""
        if currentKategori != kategori {
            entity.kategori = getOrCreateUniqueString(value: kategori, context: managedObjectContext)
        }

        let currentAcara = entity.acara?.value ?? ""
        if currentAcara != acara {
            entity.acara = getOrCreateUniqueString(value: acara, context: managedObjectContext)
        }

        let currentKeperluan = entity.keperluan?.value ?? ""
        if currentKeperluan != (keperluan ?? "") {
            if let perlu = keperluan {
                entity.keperluan = getOrCreateUniqueString(value: perlu, context: managedObjectContext)
            } else {
                entity.keperluan = nil
            }
        }

        if entity.jumlah != jumlah {
            entity.jumlah = jumlah
        }

        if entity.ditandai != tanda {
            entity.ditandai = tanda
        }

        // Simpan perubahan ke Core Data
        do {
            try managedObjectContext.save()

        } catch let error as NSError {
            #if DEBUG
                print(error)
            #endif
        }
        var kategoriW: Set<String> = []
        var acaraW: Set<String> = []
        var keperluanW: Set<String> = []
        kategoriW.formUnion(kategori.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
        kategoriW.insert(kategori.capitalizedAndTrimmed())
        ReusableFunc.kategori.formUnion(kategoriW)

        acaraW.formUnion(acara.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
        acaraW.insert(acara.capitalizedAndTrimmed())
        ReusableFunc.acara.formUnion(acaraW)

        let perlu = keperluan ?? ""
        keperluanW.formUnion(perlu.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 2 || ($0.count > 1 && $0.first!.isLetter) })
        keperluanW.insert(perlu.capitalizedAndTrimmed())
        ReusableFunc.keperluan.formUnion(keperluanW)
    }

    /// Menghitung total pemasukan, total pengeluaran, dan saldo akhir dari semua data yang tersimpan.
    ///
    /// Fungsi ini mengambil semua `Entity` dari Core Data dan mengiterasinya untuk menjumlahkan
    /// nilai `jumlah` berdasarkan `jenis` ("Pemasukan" atau "Pengeluaran"). Perhitungan dilakukan
    /// secara sinkron pada `managedObjectContext` untuk memastikan akses data yang aman.
    /// Saldo akhir dihitung sebagai selisih antara total pemasukan dan total pengeluaran.
    ///
    /// - Returns: Sebuah *tuple* `(Double, Double, Double)` yang berisi:
    ///   - Elemen pertama: **Total Pemasukan** (`totalMasuk`).
    ///   - Elemen kedua: **Total Pengeluaran** (`totalKeluar`).
    ///   - Elemen ketiga: **Saldo Akhir** (`saldo`).
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `DataManager.shared.fetchData()` untuk mengambil semua entitas.
    ///   - `Entity` diasumsikan memiliki properti `jenis` (bertipe `String`) dan `jumlah` (bertipe `Double`).
    func calculateSaldo() -> (Double, Double, Double) {
        var totalMasuk = 0.0
        var totalKeluar = 0.0
        DataManager.shared.managedObjectContext.performAndWait {
            let entities = DataManager.shared.fetchData()

            // Iterasi melalui setiap data untuk menghitung total masuk dan keluar
            for entity in entities {
                // Check if entity.jumlah is not nil
                if entity.jenis == JenisTransaksi.pemasukan.rawValue {
                    totalMasuk += entity.jumlah
                } else if entity.jenis == JenisTransaksi.pengeluaran.rawValue {
                    totalKeluar += entity.jumlah
                }
            }
        }

        let saldo = totalMasuk - totalKeluar

        return (totalMasuk, totalKeluar, saldo)
    }

    func internFetchedData(_ entities: [Entity]) -> [Entity] {
        for entity in entities {
            entity.acara?.value = StringInterner.shared.intern(entity.acara?.value ?? "")
            entity.kategori?.value = StringInterner.shared.intern(entity.kategori?.value ?? "")
            entity.keperluan?.value = StringInterner.shared.intern(entity.keperluan?.value ?? "")
        }
        return entities
    }

    /// Menghapus entitas `UniqueString` yang tidak memiliki relasi dengan entitas lain.
    ///
    /// Fungsi ini menjalankan fetch terhadap semua entitas `UniqueString` yang tidak memiliki relasi ke `acaraEntities`, `keperluanEntities`, maupun `kategoriEntities` (relasi kosong), lalu menghapusnya dari konteks manajemen objek.
    ///
    /// Operasi ini bermanfaat untuk membersihkan entitas yatim (orphaned) agar tidak memenuhi database dengan data yang tidak digunakan.
    ///
    /// - Note: Fungsi ini bersifat privat dan hanya digunakan secara internal untuk menjaga kebersihan data lokal.
    ///
    /// - Warning: Pastikan konteks (`managedObjectContext`) dalam keadaan valid. Error saat penyimpanan akan dicetak ke konsol.
    private func clearUniqueString() {
        let request = NSFetchRequest<UniqueString>(entityName: "UniqueString")
        request.predicate = NSPredicate(format:
            "acaraEntities.@count == 0 AND keperluanEntities.@count == 0 AND kategoriEntities.@count == 0")

        do {
            let nonRelationUniqueStrings = try managedObjectContext.fetch(request)
            for orphan in nonRelationUniqueStrings {
                managedObjectContext.delete(orphan)
            }
            try managedObjectContext.save()
        } catch {
            #if DEBUG
                print("Gagal hapus UniqueString non relasi: \(error)")
            #endif
        }
    }

    /// Menyalin file *database* Core Data utama aplikasi ke direktori Dokumen.
    ///
    /// Fungsi ini dirancang untuk membuat salinan *database* yang lengkap dan konsisten.
    /// Ini memastikan semua perubahan tertunda disimpan dan semua transaksi dari
    /// *Write-Ahead Logging* (WAL) dan file Shared Memory (SHM) ditulis ke dalam
    /// file `.sqlite` utama sebelum proses penyalinan.
    ///
    /// - Catatan:
    ///   - Memeriksa keberadaan *database* sumber (`DataManager.sourceURL`).
    ///   - Menyimpan semua perubahan yang belum disimpan dalam `managedObjectContext`.
    ///   - Menjalankan `PRAGMA wal_checkpoint(FULL);` menggunakan SQLite C API untuk
    ///     mengintegrasikan data WAL/SHM ke *database* utama.
    ///   - Merefresh semua objek dalam konteks untuk membersihkan *cache*.
    ///   - Menghapus salinan *database* lama di direktori tujuan (`DataManager.destURL`) jika ada.
    ///   - Menyalin file `.sqlite` utama ke lokasi tujuan.
    ///   - Mencetak pesan keberhasilan atau kesalahan ke konsol (terutama dalam mode `DEBUG`).
    func copyDatabaseToDocuments() {
        guard FileManager.default.fileExists(atPath: DataManager.sourceURL.path) else {
            #if DEBUG
                print("❌ Database sumber tidak ditemukan.")
            #endif
            return
        }

        let context = managedObjectContext
        do {
            // Simpan semua perubahan sebelum menyalin database
            clearUniqueString()

            // Pastikan semua transaksi dari WAL masuk ke database utama
            #if DEBUG
                print("🔄 Memindahkan transaksi WAL ke .sqlite...")
            #endif
            let sqlStatement = "PRAGMA wal_checkpoint(FULL);"

            guard let sqliteURL = context?.persistentStoreCoordinator?.persistentStores.first?.url?.path else {
                #if DEBUG
                    print("❌ Tidak bisa menemukan database.")
                #endif
                return
            }

            var db: OpaquePointer?
            if sqlite3_open_v2(sqliteURL, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK {
                var statement: OpaquePointer? = nil
                if sqlite3_prepare_v2(db, sqlStatement, -1, &statement, nil) == SQLITE_OK {
                    let result = sqlite3_step(statement)
                    if result == SQLITE_ROW || result == SQLITE_DONE {
                        print("✅ WAL checkpoint berhasil, semua transaksi tersimpan.")
                    } else {
                        #if DEBUG
                            print("❌ Error menjalankan WAL checkpoint.")
                        #endif
                    }
                } else {
                    #if DEBUG
                        print("❌ Error menyiapkan statement SQLite.")
                    #endif
                }
                sqlite3_finalize(statement)
                sqlite3_close(db)
            } else {
                print("❌ Error membuka database SQLite.")
            }

            // Refresh agar tidak ada cache yang tertinggal
            context?.refreshAllObjects()

            // Hapus salinan lama jika ada
            if FileManager.default.fileExists(atPath: DataManager.destURL.path) {
                try FileManager.default.removeItem(at: DataManager.destURL)
            }

            // Salin database utama `.sqlite`
            try FileManager.default.copyItem(at: DataManager.sourceURL, to: DataManager.destURL)

            #if DEBUG
                print("✅ Salinan database berhasil dibuat dan WAL serta SHM dihapus.")
            #endif
        } catch {
            #if DEBUG
                print("❌ Error menyalin database: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Properti

/// Sebuah struktur `EntitySnapshot` merepresentasikan salinan data (snapshot) dari sebuah entitas.
///
/// Struktur ini dirancang untuk berfungsi sebagai representasi data entitas yang bersifat nilai (`value type`),
/// cocok untuk digunakan dalam konteks di mana Anda memerlukan salinan data yang tidak terikat
/// langsung ke `NSManagedObjectContext` Core Data. Ini mengimplementasikan protokol `Hashable`,
/// `Comparable`, dan `Equatable` untuk memungkinkan penggunaan dalam koleksi seperti `Set` atau
/// untuk operasi perbandingan dan pengurutan.
///
/// - Catatan Penting:
///   Implementasi `Equatable` (`static func ==`) memiliki overload yang membandingkan `EntitySnapshot`
///   dengan objek `Entity` (Core Data). Hal ini memungkinkan perbandingan langsung antara snapshot
///   dan entitas Core Data yang sebenarnya.
public struct EntitySnapshot: Hashable, Comparable, Equatable {
    /// ID unik entitas. Digunakan sebagai dasar untuk `Hashable` dan *fallback* untuk `Comparable`.
    let id: UUID?
    /// Jenis entitas. Lihat enum ``JenisTransaksi`` untuk detail nilai Int16 yang digunakan.
    let jenis: Int16
    /// Sumber atau asal data entitas.
    let dari: String?
    /// Jumlah numerik entitas.
    let jumlah: Double
    /// Kategori entitas.
    let kategori: UniqueString?
    /// Acara terkait entitas.
    let acara: UniqueString?
    /// Keperluan atau deskripsi tambahan entitas.
    let keperluan: UniqueString?
    /// Tanggal entitas. Digunakan sebagai kriteria pengurutan utama untuk `Comparable`.
    let tanggal: Date?
    /// Bulan entitas (sebagai `Int16`).
    let bulan: Int16?
    /// Tahun entitas (sebagai `Int16`).
    let tahun: Int16?
    /// Status penandaan entitas.
    let ditandai: Bool?

    // MARK: - Implementasi Protokol Comparable

    /// Mengimplementasikan operator `<` untuk membandingkan dua `EntitySnapshot`.
    ///
    /// Pengurutan utama dilakukan berdasarkan properti `tanggal`. Jika `tanggal` tidak tersedia
    /// untuk kedua entitas, pengurutan akan dilakukan berdasarkan representasi string dari `id` (`uuidString`).
    ///
    /// - Parameters:
    ///   - lhs: `EntitySnapshot` di sisi kiri operator.
    ///   - rhs: `EntitySnapshot` di sisi kanan operator.
    /// - Returns: `true` jika `lhs` dianggap "kurang dari" `rhs`, `false` jika sebaliknya.
    public static func < (lhs: EntitySnapshot, rhs: EntitySnapshot) -> Bool {
        // Sorting berdasarkan tanggal jika tersedia
        if let lhsTanggal = lhs.tanggal, let rhsTanggal = rhs.tanggal {
            return lhsTanggal < rhsTanggal
        } else if let lhsID = lhs.id, let rhsID = rhs.id {
            // Fallback sorting berdasarkan ID jika tanggal tidak tersedia
            return lhsID.uuidString < rhsID.uuidString
        }
        return false // Mengembalikan false jika tidak ada kriteria yang valid untuk perbandingan
    }

    // MARK: - Implementasi Protokol Hashable

    /// Mengimplementasikan `hash(into:)` untuk mendukung protokol `Hashable`.
    ///
    /// Hanya properti `id` yang digunakan untuk menghasilkan nilai *hash*, karena `id` diasumsikan
    /// sebagai pengidentifikasi unik untuk setiap entitas.
    ///
    /// - Parameter hasher: `Hasher` yang digunakan untuk menggabungkan nilai *hash*.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Implementasi Protokol Equatable

    /// Mengimplementasikan operator `==` untuk membandingkan `EntitySnapshot` dengan objek `Entity` Core Data.
    ///
    /// Perbandingan dilakukan berdasarkan beberapa properti utama untuk menentukan kesetaraan.
    ///
    /// - Parameters:
    ///   - lhs: `EntitySnapshot` di sisi kiri operator.
    ///   - rhs: Objek `Entity` Core Data di sisi kanan operator.
    /// - Returns: `true` jika `EntitySnapshot` dan `Entity` dianggap sama berdasarkan properti yang dibandingkan,
    ///            `false` jika sebaliknya.
    static func == (lhs: EntitySnapshot, rhs: Entity) -> Bool {
        lhs.id == rhs.id &&
            lhs.jenis == rhs.jenis &&
            lhs.jumlah == rhs.jumlah &&
            lhs.acara == rhs.acara &&
            lhs.kategori == rhs.kategori &&
            lhs.keperluan == rhs.keperluan &&
            lhs.ditandai == rhs.ditandai
    }
}

/// Penambahan perbandingan terbalik.
// periphery:ignore
extension Entity {
    static func == (lhs: Entity, rhs: EntitySnapshot) -> Bool {
        rhs == lhs // This uses the implementation above
    }
}

/// `JenisTransaksi` adalah enumeration bertipe `Int16`
/// yang merepresentasikan jenis-jenis transaksi keuangan.
///
/// Enumeration ini memungkinkan Anda menyimpan nilai `jenis` di database (Core Data)
/// dalam bentuk integer (`Int16`), sehingga lebih hemat memori dan
/// lebih aman dari kesalahan penulisan string.
///
/// Gunakan `title` untuk menampilkan nama jenis transaksi di antarmuka pengguna,
/// dan `imageName` (jika ada) untuk menyesuaikan ikon.
///
/// - Note:
///   Nilai `Int16` harus sesuai dengan `rawValue` masing-masing case.
///   Pastikan nilai default di `.xcdatamodeld` juga konsisten dengan enum ini.
///
/// - Cases:
///   - `lainnya (0)`: Transaksi yang tidak termasuk kategori pengeluaran atau pemasukan.
///   - `pengeluaran (1)`: Transaksi pengeluaran dana.
///   - `pemasukan (2)`: Transaksi pemasukan dana.
enum JenisTransaksi: Int16 {
    /// Transaksi yang tidak termasuk dalam kategori pengeluaran atau pemasukan.
    case lainnya = 0

    /// Transaksi pengeluaran
    case pengeluaran = 1

    /// Transaksi pemasukan
    case pemasukan = 2

    /// Judul jenis transaksi, yang digunakan untuk ditampilkan di UI.
    var title: String {
        switch self {
        case .pemasukan: "Pemasukan"
        case .pengeluaran: "Pengeluaran"
        case .lainnya: "Lainnya"
        }
    }

    /// Mengonversi teks (string) menjadi nilai enum ``JenisTransaksi`` yang sesuai.
    ///
    /// Fungsi ini akan menyesuaikan teks input dengan opsi valid: `pemasukan`, `pengeluaran`, atau `lainnya`.
    /// Perbandingan bersifat **case-insensitive** dan akan memotong spasi ekstra di awal/akhir.
    /// Jika string tidak cocok dengan salah satu nilai valid, maka akan dikembalikan `.lainnya` secara default.
    ///
    /// - Parameter string: Teks input yang akan diubah menjadi ``JenisTransaksi``.
    /// - Returns: Nilai enum ``JenisTransaksi`` yang sesuai dengan string input.
    static func from(_ string: String) -> JenisTransaksi {
        switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "pemasukan": .pemasukan
        case "pengeluaran": .pengeluaran
        case "lainnya": .lainnya
        default: .lainnya
        }
    }
}
