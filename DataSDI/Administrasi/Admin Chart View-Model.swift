//
//  Admin Chart View-Model.swift
//  Data SDI
//
//  Created by MacBook on 23/06/25.
//

import Foundation
import SwiftUI
import Charts

/// ViewModel untuk mengelola data dan logika bisnis terkait chart pada modul Administrasi.
/// Kelas ini mengimplementasikan `ObservableObject` sehingga dapat digunakan untuk binding data pada tampilan SwiftUI.
/// 
/// Gunakan kelas ini untuk mengambil, memproses, dan menyediakan data yang diperlukan oleh chart di tampilan admin.
class AdminChartViewModel: ObservableObject {
    /// Membuat singleton.
    static let shared = AdminChartViewModel()
    
    /// Data yang ditampilkan charts per-tahun
    @Published private(set) var yearlyChartData: [ChartDataPoint] = []
    
    /// Data yang ditampilkan charts per-bulan
    @Published private(set) var monthlyChartData: [ChartDataPoint] = []
    
    /// Caching hasil perhitungan tahun sebelumnya
    private(set) var yearlyTotalSurplusCache: [Int: Double] = [:]
    
    /// Background context coredata **Thread yang dikelola CoreData™️**
    let context = DataManager.shared.managedObjectContext // Inisialisasi dengan context Anda
    
    @Published var filterJenis: String = "Pemasukan"
    
    @Published var period: ChartPeriod!
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(deleteCache(_:)), name: .perubahanData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deleteCache(_:)), name: DataManager.dataDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deleteCache(_:)), name: DataManager.dataDieditNotif, object: nil)
    }
    
    /// Menemukan indeks bulan terakhir yang memiliki nilai data lebih besar dari nol.
    ///
    /// Fungsi ini mengiterasi array `data` dari belakang ke depan, mencari indeks pertama
    /// (bulan terakhir) yang memiliki nilai positif. Ini berguna untuk menentukan
    /// sampai bulan mana data valid atau signifikan tersedia.
    ///
    /// - Parameter data: Sebuah array `[Double]` yang merepresentasikan nilai data bulanan.
    ///                   (Indeks 0 = Januari, ..., Indeks 11 = Desember).
    ///
    /// - Returns: Indeks (`Int`) bulan terakhir yang memiliki nilai positif.
    ///            Mengembalikan `0` jika tidak ada bulan dengan nilai positif ditemukan
    ///            atau array `data` kosong.
    func findLastMonthWithData(_ data: [Double]) -> Int {
        // Cari indeks terakhir yang memiliki nilai lebih dari 0
        for i in stride(from: data.count - 1, through: 0, by: -1) {
            if data[i] > 0 {
                return i
            }
        }
        return 0 // Jika tidak ada data, kembalikan 0
    }

    /// Memuat data bulanan administrasi untuk jenis transaksi dan tahun tertentu.
    /// - Parameters:
    ///   - jenis: Jenis administrasi. Berupa enum dari ``JenisTransaksi`` (Pengeluaran, Pemasukan, atau Lainnya)
    ///   - tahun: Tahun yang dipilih yang digunakan untuk memfitlter data bulan pada tahun apa yang akan digunakan. Tahun bisa diabaikan untuk menampilkan data di setiap tahun yang ada.
    /// - Returns: Nilai yang didapatkan dari Database.
    func fetchMonthlyData(_ jenis: JenisTransaksi, tahun: Int?) -> [Double] {
        // Array untuk menyimpan total pemasukan per bulan (1-12)
        var monthlyTotals = Array(repeating: 0.0, count: 12)

        // Ambil data dari Core Data
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()

        // Buat predikat dasar untuk memfilter jenis
        var predicates: [NSPredicate] = [NSPredicate(format: "jenis == %i", jenis.rawValue)]

        // Jika tahun bukan nil, tambahkan filter tahun
        if let tahun {
            let calendar = Calendar.current
            let startDate = calendar.date(from: DateComponents(year: tahun, month: 1, day: 1))!
            let endDate = calendar.date(from: DateComponents(year: tahun + 1, month: 1, day: 1))!
            let yearPredicate = NSPredicate(format: "tanggal >= %@ AND tanggal < %@", startDate as NSDate, endDate as NSDate)
            predicates.append(yearPredicate)
        }

        // Gabungkan predikat
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            let results = try context.fetch(fetchRequest)

            // Filter data dan kelompokkan berdasarkan bulan
            for result in results {
                let bulan = result.bulan
                if bulan >= 1, bulan <= 12 {
                    monthlyTotals[Int(bulan) - 1] += result.jumlah // Tambahkan jumlah pemasukan
                }
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        return monthlyTotals
    }

    /// Cari tahun dengan nilai terbesar di data administrasi.
    /// - Returns: Nilai tahun terbesar yang didapatkan.
    func fetchLatestYear() -> Int {
        // Buat fetch request untuk mendapatkan data dengan tanggal terbaru
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tanggal", ascending: false)]

        do {
            let results = try context.fetch(fetchRequest)
            if let latestEntity = results.first {
                let calendar = Calendar.current
                return calendar.component(.year, from: latestEntity.tanggal ?? Date())
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }
        return Calendar.current.component(.year, from: Date()) // Default ke tahun saat ini jika tidak ada data
    }

    /// Menghitung surplus kumulatif bulanan untuk tahun tertentu atau tahun terbaru yang tersedia.
    ///
    /// Fungsi ini menghitung surplus (pemasukan dikurangi pengeluaran) untuk setiap bulan,
    /// kemudian menghitung saldo kumulatif bulanan dengan mempertimbangkan saldo akhir dari semua
    /// tahun sebelumnya sebagai saldo awal.
    ///
    /// - Parameter tahun: Tahun untuk menghitung surplus kumulatif.
    ///   Jika `nil`, fungsi akan menggunakan tahun terbaru yang tersedia di data.
    ///
    /// - Returns: Sebuah array `[Double]` yang merepresentasikan surplus kumulatif untuk setiap bulan
    ///   (indeks 0 untuk Januari, indeks 11 untuk Desember).
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `fetchLatestYear()` untuk mendapatkan tahun terbaru.
    ///   - Fungsi ini bergantung pada `calculateTotalSurplusUntil(year:)` untuk mendapatkan saldo
    ///     akhir dari tahun-tahun sebelumnya.
    ///   - Fungsi ini bergantung pada `fetchMonthlyData(_:tahun:)` untuk mendapatkan data pemasukan
    ///     dan pengeluaran bulanan.
    func calculateMonthlyCumulativeSurplus(tahun: Int?) -> [Double] {
        if tahun == nil {
            // Ambil tahun terakhir yang tersedia di data
            let latestYear = fetchLatestYear()
            let saldoAkhirTahunSebelumnya = calculateTotalSurplusUntil(year: latestYear)

            // Ambil data pemasukan dan pengeluaran untuk tahun ini
            let pemasukan = fetchMonthlyData(JenisTransaksi.pemasukan, tahun: latestYear)
            let pengeluaran = fetchMonthlyData(JenisTransaksi.pengeluaran, tahun: latestYear)

            // Hitung surplus: pemasukan - pengeluaran
            var surplus: [Double] = []
            for i in 0 ..< 12 {
                surplus.append(pemasukan[i] - pengeluaran[i])
            }

            // Hitung saldo kumulatif dengan saldo awal dari semua tahun sebelumnya
            var cumulativeSurplus: [Double] = []
            var currentBalance = saldoAkhirTahunSebelumnya
            for value in surplus {
                currentBalance += value
                cumulativeSurplus.append(currentBalance)
            }
            return cumulativeSurplus
        }

        // Ambil saldo kumulatif dari semua tahun sebelumnya
        let saldoAkhirTahunSebelumnya = calculateTotalSurplusUntil(year: tahun!)

        // Ambil data pemasukan dan pengeluaran untuk tahun ini
        let pemasukan = fetchMonthlyData(JenisTransaksi.pemasukan, tahun: tahun)
        let pengeluaran = fetchMonthlyData(JenisTransaksi.pengeluaran, tahun: tahun)

        // Hitung surplus: pemasukan - pengeluaran
        var surplus: [Double] = []
        for i in 0 ..< 12 {
            surplus.append(pemasukan[i] - pengeluaran[i])
        }

        // Hitung saldo kumulatif dengan saldo awal dari semua tahun sebelumnya
        var cumulativeSurplus: [Double] = []
        var currentBalance = saldoAkhirTahunSebelumnya
        for value in surplus {
            currentBalance += value
            cumulativeSurplus.append(currentBalance)
        }
        return cumulativeSurplus
    }

    /// Menghitung total surplus kumulatif dari tahun pertama yang tersedia hingga tahun yang ditentukan (eksklusif).
    ///
    /// Fungsi ini mengiterasi dari tahun pertama yang tercatat hingga tahun yang diberikan (`year` - 1),
    /// mengakumulasi surplus tahunan untuk setiap tahun. Untuk mengoptimalkan kinerja, fungsi ini
    /// menggunakan `yearlyTotalSurplusCache` untuk menyimpan dan mengambil surplus tahunan yang telah dihitung sebelumnya.
    /// Jika surplus untuk suatu tahun belum ada di *cache*, fungsi akan menghitungnya menggunakan
    /// `calculateYearlySurplus(forYear:)` dan menyimpannya ke *cache*.
    ///
    /// - Parameter year: Tahun batas atas (eksklusif) hingga surplus akan dihitung.
    ///                   Hanya surplus dari tahun-tahun *sebelum* tahun ini yang akan dimasukkan.
    ///
    /// - Returns: Total surplus kumulatif (`Double`) dari tahun pertama yang tersedia hingga
    ///            tahun yang ditentukan (tidak termasuk tahun yang ditentukan). Mengembalikan `0.0`
    ///            jika tahun yang ditentukan adalah tahun pertama atau sebelumnya.
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `fetchYearRange()` untuk mendapatkan tahun pertama yang tercatat.
    ///   - Fungsi ini bergantung pada `calculateYearlySurplus(forYear:)` untuk menghitung surplus tahunan
    ///     jika tidak ditemukan di *cache*.
    ///   - `yearlyTotalSurplusCache` diasumsikan sebagai kamus `[Int: Double]` yang digunakan untuk *caching*.
    func calculateTotalSurplusUntil(year: Int) -> Double {
        let (firstYear, _) = fetchYearRange() // Cari tahun pertama
        guard year > firstYear else { return 0.0 } // Tidak ada surplus jika sebelum tahun pertama

        var totalSurplus = 0.0
        for currentYear in firstYear ..< year {
            if let cachedSurplus = yearlyTotalSurplusCache[currentYear] {
                // Ambil surplus dari cache jika sudah dihitung sebelumnya
                totalSurplus += cachedSurplus
            } else {
                // Hitung surplus tahunan jika belum ada di cache
                let yearlySurplus = calculateYearlySurplus(forYear: currentYear)
                yearlyTotalSurplusCache[currentYear] = yearlySurplus // Simpan ke cache
                totalSurplus += yearlySurplus
            }
        }
        return totalSurplus
    }

    /// Mengambil rentang tahun (tahun pertama dan tahun terakhir) dari entitas yang tersimpan.
    ///
    /// Fungsi ini melakukan *fetch* semua entitas dari Core Data, mengurutkannya berdasarkan
    /// properti `tanggal` secara menaik untuk mengidentifikasi tanggal paling awal dan paling akhir.
    /// Kemudian, ia mengekstrak komponen tahun dari tanggal-tanggal ini.
    ///
    /// - Returns: Sebuah *tuple* `(Int, Int)` yang berisi tahun pertama dan tahun terakhir
    ///            dari data yang tersedia. Jika tidak ada data yang ditemukan atau terjadi kesalahan,
    ///            fungsi akan mengembalikan tahun saat ini sebagai tahun pertama dan terakhir.
    ///
    /// - Catatan:
    ///   - Fungsi ini mengasumsikan adanya konteks Core Data (`context`) dan entitas bernama `Entity`
    ///     dengan properti `tanggal` yang bertipe `Date`.
    ///   - Dalam mode `DEBUG`, kesalahan *fetch* akan dicetak ke konsol.
    func fetchYearRange() -> (Int, Int) {
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tanggal", ascending: true)] // Urutkan ASC untuk tahun pertama

        do {
            let results = try context.fetch(fetchRequest)
            if let firstEntity = results.first,
               let lastEntity = results.last,
               let firstDate = firstEntity.tanggal,
               let lastDate = lastEntity.tanggal
            {
                let calendar = Calendar.current
                let firstYear = calendar.component(.year, from: firstDate)
                let lastYear = calendar.component(.year, from: lastDate)
                return (firstYear, lastYear)
            }
        } catch {
            #if DEBUG
                print(error.localizedDescription)
            #endif
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        return (currentYear, currentYear) // Default jika tidak ada data
    }

    /// Menghitung total surplus (pemasukan dikurangi pengeluaran) untuk tahun yang ditentukan.
    ///
    /// Fungsi ini mengambil data pemasukan dan pengeluaran bulanan untuk tahun yang diberikan,
    /// kemudian menjumlahkan selisih antara pemasukan dan pengeluaran untuk setiap bulan
    /// untuk mendapatkan total surplus tahunan.
    ///
    /// - Parameter year: Tahun (`Int`) di mana surplus akan dihitung.
    ///
    /// - Returns: Total surplus tahunan (`Double`) untuk tahun yang ditentukan.
    ///
    /// - Catatan:
    ///   - Fungsi ini bergantung pada `fetchMonthlyData(_:tahun:)` untuk mengambil data keuangan bulanan.
    func calculateYearlySurplus(forYear year: Int) -> Double {
        // Ambil data pemasukan dan pengeluaran untuk tahun tertentu
        let pemasukan = fetchMonthlyData(JenisTransaksi.pemasukan, tahun: year)
        let pengeluaran = fetchMonthlyData(JenisTransaksi.pengeluaran, tahun: year)

        // Hitung total surplus untuk tahun tersebut
        var totalSurplus = 0.0
        for i in 0 ..< 12 {
            totalSurplus += (pemasukan[i] - pengeluaran[i])
        }
        return totalSurplus
    }
    
    
    /// Menghitung surplus kumulatif berdasarkan jenis filter yang diberikan.
    ///
    /// Fungsi ini mengambil data dari Core Data, memfilter berdasarkan `filterJenis`,
    /// lalu mengelompokkan dan menjumlahkan nilai `jumlah` per tahun. Hasilnya berupa
    /// array tahun dan data surplus kumulatif per tahun.
    ///
    /// - Parameter filterJenis: Jenis data yang akan difilter (misal: "Pendapatan", "Pengeluaran").
    /// - Returns: Tuple yang berisi array tahun (`years`) dan array data surplus kumulatif (`data`).
    func calculateCumulativeSurplus(_ filterJenis: String) -> (years: [Int], data: [Double]) {
        // 1. Menyiapkan data untuk chart berdasarkan filterJenis
        var yearlyData: [Double] = []
        var years: [Int] = [] // Declare years here

        // Menyiapkan permintaan fetch untuk semua jenis data
        let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: "Entity", in: context)

        // Ekspresi untuk menghitung total per tahun
        let sumExpression = NSExpression(format: "sum:(jumlah)")
        let sumExpressionDesc = NSExpressionDescription()
        sumExpressionDesc.name = "yearTotal"
        sumExpressionDesc.expression = sumExpression
        sumExpressionDesc.expressionResultType = .doubleAttributeType

        // Filter berdasarkan jenis yang dipilih
        let jenisPredicate = NSPredicate(format: "jenis == %i", JenisTransaksi.from(filterJenis).rawValue)
        fetchRequest.predicate = jenisPredicate
        fetchRequest.propertiesToGroupBy = ["tanggal"] // Kelompokkan berdasarkan tahun
        fetchRequest.propertiesToFetch = ["tanggal", sumExpressionDesc]
        fetchRequest.resultType = .dictionaryResultType

        do {
            let results = try context.fetch(fetchRequest) as? [[String: Any]] ?? []

            // Proses hasil fetch
            for result in results {
                guard let tanggal = result["tanggal"] as? Date,
                      let total = result["yearTotal"] as? Double
                else {
                    continue
                }

                let year = Calendar.current.component(.year, from: tanggal)

                // Gabungkan data per tahun yang sama
                if let index = years.firstIndex(of: year) {
                    yearlyData[index] += total
                } else {
                    years.append(year)
                    yearlyData.append(total)
                }
            }

            // **Tambahkan Proses untuk "Jumlah Saldo"**
            if filterJenis == "Jumlah Saldo" {
                // Pisahkan data untuk Pemasukan dan Pengeluaran
                var totalPemasukan: [Double] = Array(repeating: 0.0, count: years.count)
                var totalPengeluaran: [Double] = Array(repeating: 0.0, count: years.count)

                // Ambil data pemasukan per tahun
                let pemasukanPredicate = NSPredicate(format: "jenis == %i", JenisTransaksi.pemasukan.rawValue)
                let pemasukanFetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest()
                pemasukanFetchRequest.entity = NSEntityDescription.entity(forEntityName: "Entity", in: context)
                pemasukanFetchRequest.predicate = pemasukanPredicate
                pemasukanFetchRequest.propertiesToGroupBy = ["tanggal"]
                pemasukanFetchRequest.propertiesToFetch = ["tanggal", sumExpressionDesc]
                pemasukanFetchRequest.resultType = .dictionaryResultType

                let pemasukanResults = try context.fetch(pemasukanFetchRequest) as? [[String: Any]] ?? []
                for result in pemasukanResults {
                    guard let tanggal = result["tanggal"] as? Date,
                          let total = result["yearTotal"] as? Double
                    else {
                        continue
                    }
                    let year = Calendar.current.component(.year, from: tanggal)
                    if let index = years.firstIndex(of: year) {
                        totalPemasukan[index] += total
                    } else {
                        // This scenario means a year exists in Pemasukan but not in the initial fetch
                        // This can lead to out-of-bounds if not handled carefully.
                        // For robustness, you might want to re-evaluate the initial fetch
                        // to include all years from both Pemasukan and Pengeluaran,
                        // or add new years here and resize totalPemasukan/Pengeluaran.
                        // For now, let's assume `years` will contain all relevant years from the initial pass
                        // or that if a year is new, it's added consistently.
                        // A safer approach might involve a dictionary to map year to total.
                        years.append(year)
                        totalPemasukan.append(total)
                        totalPengeluaran.append(0) // Ensure pengeluaran has a corresponding entry
                    }
                }

                // Ambil data pengeluaran per tahun
                let pengeluaranPredicate = NSPredicate(format: "jenis == %i", JenisTransaksi.pengeluaran.rawValue)
                let pengeluaranFetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest()
                pengeluaranFetchRequest.entity = NSEntityDescription.entity(forEntityName: "Entity", in: context)
                pengeluaranFetchRequest.predicate = pengeluaranPredicate
                pengeluaranFetchRequest.propertiesToGroupBy = ["tanggal"]
                pengeluaranFetchRequest.propertiesToFetch = ["tanggal", sumExpressionDesc]
                pengeluaranFetchRequest.resultType = .dictionaryResultType

                let pengeluaranResults = try context.fetch(pengeluaranFetchRequest) as? [[String: Any]] ?? []
                for result in pengeluaranResults {
                    guard let tanggal = result["tanggal"] as? Date,
                          let total = result["yearTotal"] as? Double
                    else {
                        continue
                    }
                    let year = Calendar.current.component(.year, from: tanggal)
                    if let index = years.firstIndex(of: year) {
                        totalPengeluaran[index] += total
                    } else {
                        // Similar handling as for Pemasukan
                        years.append(year)
                        totalPengeluaran.append(total)
                        totalPemasukan.append(0) // Ensure pemasukan has a corresponding entry
                    }
                }

                // After fetching all, ensure `totalPemasukan` and `totalPengeluaran`
                // are aligned with the `years` array.
                // A more robust way to merge and sum by year would be to use dictionaries first,
                // then convert to arrays.
                var yearlyPemasukanDict: [Int: Double] = [:]
                var yearlyPengeluaranDict: [Int: Double] = [:]

                // Repopulate dictionaries from fetched results (or adapt the loops above)
                for result in pemasukanResults {
                    if let tanggal = result["tanggal"] as? Date,
                       let total = result["yearTotal"] as? Double {
                        let year = Calendar.current.component(.year, from: tanggal)
                        yearlyPemasukanDict[year, default: 0.0] += total
                    }
                }
                for result in pengeluaranResults {
                    if let tanggal = result["tanggal"] as? Date,
                       let total = result["yearTotal"] as? Double {
                        let year = Calendar.current.component(.year, from: tanggal)
                        yearlyPengeluaranDict[year, default: 0.0] += total
                    }
                }

                let allYearsSet = Set(yearlyPemasukanDict.keys).union(Set(yearlyPengeluaranDict.keys))
                years = allYearsSet.sorted() // Sort years in ascending order

                var surplusData: [Double] = []
                for year in years {
                    let pemasukan = yearlyPemasukanDict[year] ?? 0.0
                    let pengeluaran = yearlyPengeluaranDict[year] ?? 0.0
                    let surplus = pemasukan - pengeluaran
                    surplusData.append(surplus)
                }

                // **Agregasi surplusData untuk mendapatkan saldo kumulatif** (jumlah saldo)
                var cumulativeSaldo: [Double] = []
                var currentSaldo: Double = 0
                for surplus in surplusData {
                    currentSaldo += surplus
                    cumulativeSaldo.append(currentSaldo)
                }

                yearlyData = cumulativeSaldo // Use cumulativeSaldo for chart if filterJenis is "Jumlah Saldo"
            }
        } catch {
            print(error.localizedDescription)
        }
        return (years: years, data: yearlyData) // Return both years and data
    }
    
    /// Notifikasi yang diterima ketika ada perubahan data Administrasi.
    ///
    /// Membersihkan *cache* data administrasi tahun per tahun yang sebelumnya dibuat untuk meningkatkan waktu pemuatan.
    @objc func deleteCache(_ notification: Notification) {
        guard !yearlyTotalSurplusCache.isEmpty else { return }
        deleteCache()
    }

    /// Fungsi untuk menghapus cache data administrasi tahun per tahun yang sebelumnya dibuat untuk meningkatkan waktu pemuatan.
    func deleteCache() {
        yearlyTotalSurplusCache.removeAll()
    }
    
    /// Menyiapkan data bulanan untuk chart berdasarkan jenis filter dan tahun yang dipilih.
    /// - Parameter filterJenis: Jenis data yang ingin difilter (misal: "Jumlah Saldo" atau jenis lainnya).
    /// - Parameter tahun: Tahun yang ingin ditampilkan datanya. Jika nil, akan menggunakan tahun saat ini.
    /// 
    /// Fungsi ini akan mengambil data bulanan dari sumber data (misal: Core Data) sesuai dengan filter dan tahun.
    /// Jika filterJenis adalah "Jumlah Saldo", maka data yang diambil berupa akumulasi saldo bulanan.
    /// Data yang dihasilkan hanya sampai bulan terakhir yang memiliki data.
    /// Data yang sudah diproses akan disimpan dalam `monthlyChartData` dalam bentuk array `ChartDataPoint`
    /// dengan tanggal pada hari pertama setiap bulan dan nilai total pada bulan tersebut.
    func prepareMonthlyData(_ filterJenis: String, tahun: Int?) {
        // 1. Fetch data dari Core Data (atau sumber lain)
        var data: [Double] = []
        if filterJenis != "Jumlah Saldo" {
            data = fetchMonthlyData(JenisTransaksi.from(filterJenis), tahun: tahun)
        } else {
            data = calculateMonthlyCumulativeSurplus(tahun: tahun)
        }

        // Temukan indeks bulan terakhir yang memiliki data
        let lastMonthWithData = findLastMonthWithData(data)

        // Potong data hanya sampai bulan terakhir yang memiliki data
        let truncatedData = Array(data.prefix(lastMonthWithData + 1))

        // Ensure 'tahun' (year) is accessible here. Assuming 'tahun' is a property of the current class/struct.
        // If 'tahun' is not available here, you'll need to pass it from where this function is called,
        // or retrieve it if it's dynamic (e.g., current year, or selected year from a picker).
        // For this example, I'll assume `tahun` is available in the scope where `displayLineChart` is called.

        // Get the current year if `tahun` is nil in calculateMonthlyCumulativeSurplus.
        // If `calculateMonthlyCumulativeSurplus` always returns data for the specific `tahun`,
        // then `self.tahun` (or a passed `tahun` variable) should be used here.
        let currentChartYear: Int
        if let explicitYear = tahun { // Assuming 'tahun' is the selected year for the chart
            currentChartYear = explicitYear
        } else {
            // If tahun is nil, calculateMonthlyCumulativeSurplus uses fetchLatestYear().
            // You'll need to ensure this logic is consistent.
            // For simplicity, let's assume `self.tahun` always has a value here for charting.
            // Or, you might need to pass the actual year used from viewModel.calculateMonthlyCumulativeSurplus.
            // For demonstration, let's use the current year if `self.tahun` is nil.
            currentChartYear = Calendar.current.component(.year, from: Date())
        }
        period = .monthly
        monthlyChartData.removeAll()
        let processedData: [(month: Date, amount: Double)] = truncatedData.enumerated().compactMap { index, amount in
            let actualMonth = index + 1

            // Create a Date object for the first day of the specific month and year
            guard let date = Calendar.current.date(from: DateComponents(year: currentChartYear, month: actualMonth, day: 1)) else {
                return (Date(), Double())
            }
            return (month: date, amount: amount)
        }
        let allValues = processedData.map { $0.amount }
        let (minValue, maxValue) = ReusableFunc.makeRoundedNumber(actualMin: allValues.min() ?? 0, actualMax: allValues.max() ?? 0)
        monthlyChartData = processedData.map { data in
            ChartDataPoint(date: data.month, value: data.amount, minValue: minValue, maxValue: maxValue)
        }
    }

    /// Menyiapkan data surplus tahunan berdasarkan jenis filter yang diberikan.
    /// Fungsi ini akan menghitung surplus kumulatif per tahun, lalu mengonversinya menjadi array `ChartDataPoint`
    /// dengan tanggal yang diset ke 1 Januari setiap tahunnya.
    /// - Parameter filterJenis: Jenis filter yang digunakan untuk menghitung surplus tahunan.
    func prepareYearlyData(_ filterJenis: String) {
        let (years, yearlySurplus) = calculateCumulativeSurplus(filterJenis)
        period = .yearly
        yearlyChartData.removeAll()

        // Proses data menjadi (Date, amount)
        let processedData: [(date: Date, amount: Double)] = years.enumerated().compactMap { index, year in
            guard index < yearlySurplus.count else { return nil }
            let amount = yearlySurplus[index]
            guard let date = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) else {
                return nil
            }
            return (date: date, amount: amount)
        }

        // Hitung nilai min & max
        let amounts = processedData.map { $0.amount }
        let (minValue, maxValue) = ReusableFunc.makeRoundedNumber(
            actualMin: amounts.min() ?? 0.0,
            actualMax: amounts.max() ?? 0.0
        )

        // Buat ChartDataPoint dengan info min & max
        yearlyChartData = processedData.map {
            ChartDataPoint(date: $0.date, value: $0.amount, minValue: minValue, maxValue: maxValue)
        }
    }
    
    func updateAnimateFlag(at index: Int, period: ChartPeriod) {
        switch period {
        case .monthly:
            guard monthlyChartData.indices.contains(index) else { return }
            monthlyChartData[index].animate = true
        case .yearly:
            guard yearlyChartData.indices.contains(index) else { return }
            yearlyChartData[index].animate = true
        }
    }
}
