//
//  Chart Kelas View-Model.swift
//  Data SDI
//
//  Created by MacBook on 22/06/25.
//

import Foundation

/// ViewModel untuk mengelola data dan logika bisnis terkait chart pada modul Administrasi.
/// Kelas ini mengimplementasikan `ObservableObject` sehingga dapat digunakan untuk binding data pada tampilan SwiftUI.
///
/// Gunakan kelas ini untuk mengambil, memproses, dan menyediakan data yang diperlukan oleh chart di tampilan admin.
class ChartKelasViewModel {
    /// Controller untuk mengakses database.
    let dbController = DatabaseController.shared
    
    /// Semua data per kelas yang ter-fetch
    var kelasByType: [TableType: [KelasModels]] = [:]
    
    /// Variabel untuk menyimpan semester yang dipilih untuk pie chart semester 1.
    var selectedSemester1: String?
    /// Variabel untuk menyimpan semester yang dipilih untuk pie chart semester 2.
    var selectedSemester2: String?
    
    /// Variabel yang menyimpan data siswa setelah didapatkan dan dikalkulasi dari database.
    /// Digunakan untuk menampilkan statistik siswa tertentu.
    private(set) var studentData: [KelasChartModel] = []
    
    /// Variabel yang menyimpan data kelas setelah didapatkan dan dikalkulasi dari database.
    /// Digunakan untuk menampilkan statistik kelas.
    private(set) var kelasData: [KelasChartModel] = []
    
    /// Memperbarui data untuk grafik dan mengatur ulang data entri.
    func updateData() async {
        kelasByType = await dbController.getAllKelas()
    }
    
    /// Fungsi untuk memuat data siswa berdasarkan ID siswa.
    /// - Parameter siswaID: ID siswa yang digunakan untuk memuat data kelas.
    func loadSiswaData(siswaID: Int64) async {
        kelasByType = await dbController.getAllKelas(for: siswaID)
    }
    
    // MARK: MEMBUAT DATA UNTUK CHARTS
    
    /// Menghitung dan memproses data rata-rata nilai siswa untuk setiap kelas berdasarkan daftar semester yang diberikan.
    ///
    /// Fungsi ini akan:
    /// - Menghapus data kelas sebelumnya.
    /// - Menghitung rata-rata nilai (`overallAverage`) untuk setiap kelas dari data yang tersedia pada semester yang dipilih.
    /// - Menentukan nilai minimum domain Y (`overallAverageYStart`) untuk chart, dibulatkan ke bawah ke puluhan terdekat dan tidak melebihi 100.
    /// - Membuat dan mengisi array `kelasData` dengan objek `KelasChartModel` yang sudah diproses.
    ///
    /// - Parameter semesters: Array string yang merepresentasikan daftar semester yang akan diproses secara asinkron.
    func makeData(_ semesters: [String]) async {
        kelasData.removeAll()

        // 1) Hitung rata-rata per kelas berdasarkan dictionary kelasByType
        let processed: [(className: String, overallAverage: Double, index: Int)] =
            TableType.allCases.map { type in
                let models = kelasByType[type] ?? []

                // total nilai & siswa hitung berdasarkan semester filter
                var totalNilai: Double = 0
                var totalSiswa = 0

                for sem in semesters {
                    let code = sem.split(separator: " ").last.map(String.init) ?? sem
                    let siswaSem = models.filter { $0.semester == code }
                    totalNilai += siswaSem.reduce(0) { $0 + Double($1.nilai) }
                    totalSiswa += siswaSem.count
                }

                let avg = totalSiswa > 0
                    ? totalNilai / Double(totalSiswa)
                    : 0

                return (
                    className: type.stringValue,
                    overallAverage: avg,
                    index: type.rawValue
                )
            }

        // 2) Cari minimum rata-rata untuk y-axis start
        let minAvg = processed.map(\.overallAverage).min() ?? 0
        let roundedMin = floor(minAvg / 10) * 10
        let finalMin = max(roundedMin, 0) // pastikan ≥ 0

        // 3) Buat KelasChartModel
        kelasData = processed.map {
            KelasChartModel(
                index: $0.index,
                className: $0.className,
                overallAverage: $0.overallAverage,
                overallAverageYStart: finalMin
            )
        }
    }
    
    /// Mengambil dan mencetak rata-rata nilai untuk semester tertentu di setiap kelas
    /// (rata-rata nilai semua siswa di kelas tersebut untuk semester itu).
    /// - Parameter targetSemester: String yang menunjukkan semester yang ingin diambil ("Semester 1" atau "Semester 2").
    func makeSemesterData(_ targetSemester: String) async -> [KelasChartModel] {
        // Konversi "Semester 1" → "1"
        let semCode = targetSemester
            .replacingOccurrences(of: "Semester ", with: "")

        // 1) Hitung rata-rata per kelas
        let processed: [(type: TableType, avg: Double)] =
            TableType.allCases.map { type in
                let models = kelasByType[type] ?? []
                let filtered = models.filter { $0.semester == semCode }
                let avg = calculateAverage(from: filtered)
                return (type, avg)
            }

        // 2) Cari nilai minimum untuk Y-start
        let minAvg = processed.map(\.avg).min() ?? 0
        let yStart = max(floor(minAvg / 10) * 10, 0)

        // 3) Bangun KelasChartModel
        return processed.map { pair in
            KelasChartModel(
                index: pair.type.rawValue,
                className: pair.type.stringValue,
                semester1Average: pair.avg,
                overallAverageYStart: yStart
            )
        }
    }
    
    // MARK: - ALL CHART FOR KELAS
    
    /// Menentukan urutan dua semester.
    /// Fungsi ini mengurutkan semester 1 terlebih dahulu, diikuti semester 2, lalu urutan leksikografis untuk semester lainnya.
    ///
    /// - Parameters:
    ///   - semester1: Sebuah `String` yang merepresentasikan semester pertama untuk dibandingkan.
    ///   - semester2: Sebuah `String` yang merepresentasikan semester kedua untuk dibandingkan.
    /// - Returns: `true` jika `semester1` harus datang sebelum `semester2` dalam urutan,
    ///            `false` jika `semester2` harus datang sebelum atau sama dengan `semester1`.
    func semesterOrder(_ semester1: String, _ semester2: String) -> Bool {
        if semester1 == "1" { return true }
        if semester2 == "1" { return false }
        if semester1 == "2" { return true }
        if semester2 == "2" { return false }
        return semester1 < semester2
    }
    
    /// Memformat angka semester menjadi nama semester yang lebih mudah dibaca.
    /// Fungsi ini mengonversi angka semester (misalnya, "1", "2") menjadi format string yang lebih deskriptif
    /// (misalnya, "Semester 1", "Semester 2"). Jika semester tidak dikenal, ia akan mengembalikan input asli.
    ///
    /// - Parameter semester: Sebuah `String` yang merepresentasikan angka semester (misalnya, "1", "2", dll.).
    /// - Returns: Sebuah `String` yang diformat dari nama semester.
    func formatSemesterName(_ semester: String) -> String {
        switch semester {
        case "1":
            "Semester 1"
        case "2":
            "Semester 2"
        default:
            "\(semester)"
        }
    }
    
    // MARK: - INDIVIDUAL CHART
    
    /// Memproses data chart untuk siswa tertentu berdasarkan `siswaID`.
    /// Fungsi ini akan menghitung rata-rata nilai untuk semua semester dan khusus semester 1 & 2,
    /// kemudian mengurutkan nama kelas secara numerik, membersihkan data sebelumnya,
    /// dan membangun array data baru (`studentData`) yang berisi model data untuk setiap kelas.
    ///
    /// - Parameter siswaID: ID siswa (`Int64?`) yang datanya akan diproses. Jika nil, fungsi tidak melakukan apa-apa.
    /// - Catatan: Fungsi ini berjalan secara asynchronous.
    func processChartData(_ siswaID: Int64?) async {
        guard let siswaID else { return }

        let averageDataAllSemesters = calculateAverageAllSemesters(for: siswaID)
        let averageDataSemester1And2 = calculateAverageSemester1And2(for: siswaID)

        let sortedClasses = averageDataAllSemesters.keys.sorted { kelas1, kelas2 in
            let index1 = Int(kelas1.replacingOccurrences(of: "Kelas ", with: "")) ?? 0
            let index2 = Int(kelas2.replacingOccurrences(of: "Kelas ", with: "")) ?? 0
            return index1 < index2
        }

        studentData.removeAll()

        // Bangun array sementara dulu tanpa overallAverageYStart
        let tempResults: [(
            index: Int,
            className: String,
            overallAverage: Double,
            semester1Average: Double,
            semester2Average: Double
        )] = sortedClasses.enumerated().map { (index, className) in
            let overallAvg = averageDataAllSemesters[className] ?? 0.0
            let semester1Avg = averageDataSemester1And2[className]?["Semester 1"] ?? 0.0
            let semester2Avg = averageDataSemester1And2[className]?["Semester 2"] ?? 0.0

            return (index, className, overallAvg, semester1Avg, semester2Avg)
        }
        
        // Sekarang baru buat struct dengan semua nilai termasuk finalMin
        studentData = tempResults.map { item in
            KelasChartModel(
                index: item.index,
                className: item.className,
                overallAverage: item.overallAverage,
                semester1Average: item.semester1Average,
                semester2Average: item.semester2Average,
                overallAverageYStart: 0
            )
        }
    }
    
    /// Mengkalkulasi nilai semua semester di setiap kelas dan mengembalikan nilai Nama Kelas dan Nilai Kelas
    /// - Parameter siswaID: ID Siswa yang diproses
    /// - Returns: Pengembalian nilai semua kelas dan jumlah nilai dari semua semester  yang telah dikalkulasi ke dalam format Array String: Double
    func calculateAverageAllSemesters(for siswaID: Int64) -> [String: Double] {
        kelasByType.reduce(into: [:]) { result, pair in
            let (type, models) = pair
            let siswaData = models.filter { $0.siswaID == siswaID }

            let total = siswaData.reduce(0) { $0 + $1.nilai }
            let average = siswaData.isEmpty ? 0 : Double(total) / Double(siswaData.count)

            result[type.stringValue] = average
        }
    }
    
    /// Mengkalkulasi nilai rata-rata semester 1 dan 2 di setiap kelas dan mengembalikan nilai dari setiap semester.
    /// - Parameter siswaID: ID Siswa yang diproses
    /// - Returns: Pengembalian nilai dalam Dictionary dengan format [Kelas: [Semester 1: Nilai], [Semester 2: Nilai]]
    func calculateAverageSemester1And2(for siswaID: Int64) -> [String: [String: Double]] {
        kelasByType.reduce(into: [:]) { result, pair in
            let (type, models) = pair

            let semester1 = models.filter { $0.siswaID == siswaID && $0.semester == "1" }
            let semester2 = models.filter { $0.siswaID == siswaID && $0.semester == "2" }

            func average(_ list: [KelasModels]) -> Double {
                guard !list.isEmpty else { return 0 }
                return Double(list.reduce(0) { $0 + $1.nilai }) / Double(list.count)
            }

            result[type.stringValue] = [
                "Semester 1": average(semester1),
                "Semester 2": average(semester2)
            ]
        }
    }
    
    /// Mengambil data siswa untuk semester tertentu dalam sebuah array KelasModels.
    /// - Parameters:
    ///   - classData: Array dari KelasModels yang mewakili data untuk satu kelas.
    ///   - siswaID: ID Siswa yang akan difilter.
    ///   - semester: String yang menunjukkan semester ("1" atau "2").
    /// - Returns: Array KelasModels yang berisi data siswa yang relevan untuk semester tersebut.
    func getSemesterData(for classData: [KelasModels], siswaID: Int64? = nil, semester: String) -> [KelasModels] {
        if let siswaID {
            return classData.filter { $0.siswaID == siswaID && $0.semester == semester }
        } else {
            return classData.filter { $0.semester == semester }
        }
    }
    
    /// Menghitung rata-rata nilai dari sekumpulan data KelasModels.
    /// - Parameter data: Array dari KelasModels yang berisi nilai-nilai yang akan dirata-ratakan.
    /// - Returns: Nilai rata-rata dalam bentuk Double. Mengembalikan 0 jika array kosong.
    func calculateAverage(from data: [KelasModels]) -> Double {
        guard !data.isEmpty else {
            return 0.0 // Mengembalikan 0 jika tidak ada data untuk menghindari pembagian dengan nol
        }
        let totalNilai = data.reduce(0.0) { $0 + Double($1.nilai) }
        return totalNilai / Double(data.count)
    }
}
