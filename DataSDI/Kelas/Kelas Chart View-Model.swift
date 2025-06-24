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
    
    /// Array untuk menyimpan data kelas 1 hingga kelas 6.
    var kelas1data: [Kelas1Model] = []
    /// Lihat: ``kelas1data``.
    var kelas2data: [Kelas2Model] = []
    /// Lihat: ``kelas1data``.
    var kelas3data: [Kelas3Model] = []
    /// Lihat: ``kelas1data``.
    var kelas4data: [Kelas4Model] = []
    /// Lihat: ``kelas1data``.
    var kelas5data: [Kelas5Model] = []
    /// Lihat: ``kelas1data``.
    var kelas6data: [Kelas6Model] = []
    
    /// Variabel untuk menyimpan semester yang dipilih untuk pie chart semester 1.
    var selectedSemester1: String? = nil
    /// Variabel untuk menyimpan semester yang dipilih untuk pie chart semester 2.
    var selectedSemester2: String? = nil
    
    /// Variabel yang menyimpan data siswa setelah didapatkan dan dikalkulasi dari database.
    /// Digunakan untuk menampilkan statistik siswa tertentu.
    private(set) var studentData: [KelasChartModel] = []
    
    /// Variabel yang menyimpan data kelas setelah didapatkan dan dikalkulasi dari database.
    /// Digunakan untuk menampilkan statistik kelas.
    private(set) var kelasData: [KelasChartModel] = []
    
    /// Memperbarui data untuk grafik dan mengatur ulang data entri.
    func updateData() async {
        kelas1data = await dbController.getallKelas1()
        kelas2data = await dbController.getallKelas2()
        kelas3data = await dbController.getallKelas3()
        kelas4data = await dbController.getallKelas4()
        kelas5data = await dbController.getallKelas5()
        kelas6data = await dbController.getallKelas6()
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
        let kelasDataArray: [([KelasModels], String)] = [
            (kelas1data, "Kelas 1"),
            (kelas2data, "Kelas 2"),
            (kelas3data, "Kelas 3"),
            (kelas4data, "Kelas 4"),
            (kelas5data, "Kelas 5"),
            (kelas6data, "Kelas 6")
        ]

        // Hitung rata-rata nilai untuk setiap kelas dalam satu langkah
        let processedKelasData: [(className: String, overallAverage: Double, index: Int)] = kelasDataArray.map { (kelas, className) in
            var totalNilai: Double = 0
            var totalSiswa: Int = 0

            for semester in semesters {
                let formattedSemester = semester.split(separator: " ").last ?? "1"
                let siswaSemester = kelas.filter { $0.semester == formattedSemester }
                totalNilai += siswaSemester.reduce(0) { $0 + Double($1.nilai) }
                totalSiswa += siswaSemester.count
            }
            let rataRataNilai = totalSiswa > 0 ? totalNilai / Double(totalSiswa) : 0.0
            let index = kelasDataArray.firstIndex { $0.1 == className } ?? 0
            return (className: className, overallAverage: rataRataNilai, index: index)
        }

        // Tentukan commonOverallAverageYStart sebagai nilai maksimum dari semua rata-rata yang sudah dihitung
        let commonOverallAverageYStart = processedKelasData.map { $0.overallAverage }.min() ?? 0.0
        // --- Bagian yang Anda minta: Pembulatan ke bawah ke puluhan terdekat ---
        let roundedMinGrade = floor(commonOverallAverageYStart / 10.0) * 10.0
        // Pastikan roundedMinGrade tidak kurang dari 0
        let finalMinDomain = min(roundedMinGrade, 100)
        
        // Buat objek StudentGradeData menggunakan data yang sudah diproses dan YStart yang ditentukan
        kelasData = processedKelasData.map { data in
            KelasChartModel(
                index: data.index,
                className: data.className,
                overallAverage: data.overallAverage,
                overallAverageYStart: finalMinDomain
            )
        }
    }
    
    /// Mengambil dan mencetak rata-rata nilai untuk semester tertentu di setiap kelas
    /// (rata-rata nilai semua siswa di kelas tersebut untuk semester itu).
    /// - Parameter targetSemester: String yang menunjukkan semester yang ingin diambil ("Semester 1" atau "Semester 2").
    func makeSemesterData(_ targetSemester: String) async -> [KelasChartModel] {
        print("--- Rata-rata Kelas untuk Semester: \(targetSemester) ---")

        let kelasDataArray: [([KelasModels], String)] = [
            (kelas1data, "Kelas 1"),
            (kelas2data, "Kelas 2"),
            (kelas3data, "Kelas 3"),
            (kelas4data, "Kelas 4"),
            (kelas5data, "Kelas 5"),
            (kelas6data, "Kelas 6")
        ]

        // Ubah format 'targetSemester' dari "Semester 1" menjadi "1"
        let semesterNumericString = targetSemester.replacingOccurrences(of: "Semester ", with: "")

        // Process all class data in one go, similar to makeData
        let processedKelasData: [(className: String, averageValue: Double, index: Int)] = kelasDataArray.map { (kelas, className) in
            let semesterDataForClass = getSemesterData(for: kelas, semester: semesterNumericString)
            let averageValue = calculateAverage(from: semesterDataForClass)
            let index = kelasDataArray.firstIndex { $0.1 == className } ?? 0 // Get the correct index
            return (className: className, averageValue: averageValue, index: index)
        }

        // Determine commonOverallAverageYStart based on the averages calculated
        let commonOverallAverageYStart = processedKelasData.map { $0.averageValue }.min() ?? 0.0
        let roundedMinGrade = floor(commonOverallAverageYStart / 10.0) * 10.0
        let finalMinDomain = min(roundedMinGrade, 100)

        // Map the processed data to KelasChartModel, incorporating finalMinDomain
        let semesterData: [KelasChartModel] = processedKelasData.map { data in
            KelasChartModel(
                index: data.index,
                className: data.className,
                semester1Average: data.averageValue, // Assuming semester1Average is used for the specific semester's average
                overallAverageYStart: finalMinDomain
            )
        }
        
        return semesterData
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
        // Assume these functions are the same and return the same dictionary structures
        let averageDataAllSemesters = calculateAverageAllSemesters(forSiswaID: siswaID)
        let averageDataSemester1And2 = calculateAverageSemester1And2(forSiswaID: siswaID)
        
        // Sort class names numerically to ensure correct order
        let sortedClasses = averageDataAllSemesters.keys.sorted { kelas1, kelas2 in
            let index1 = Int(kelas1.replacingOccurrences(of: "Kelas ", with: "")) ?? 0
            let index2 = Int(kelas2.replacingOccurrences(of: "Kelas ", with: "")) ?? 0
            return index1 < index2
        }
        
        // Clear previous data
        studentData.removeAll()
        
        // Loop through the sorted classes and build our new data array
        for (index, className) in sortedClasses.enumerated() {
            let overallAvg = averageDataAllSemesters[className] ?? 0.0
            let semester1Avg = averageDataSemester1And2[className]?["Semester 1"] ?? 0.0
            let semester2Avg = averageDataSemester1And2[className]?["Semester 2"] ?? 0.0
            
            let gradeData = KelasChartModel(
                index: index,
                className: className,
                overallAverage: overallAvg,
                semester1Average: semester1Avg,
                semester2Average: semester2Avg, overallAverageYStart: 0
            )
            studentData.append(gradeData)
        }
    }
    
    /// Mengkalkulasi nilai semua semester di setiap kelas dan mengembalikan nilai Nama Kelas dan Nilai Kelas
    /// - Parameter siswaID: ID Siswa yang diproses
    /// - Returns: Pengembalian nilai semua kelas dan jumlah nilai dari semua semester  yang telah dikalkulasi ke dalam format Array String: Double
    func calculateAverageAllSemesters(forSiswaID siswaID: Int64) -> [String: Double] {
        var averageByClass: [String: Double] = [:]
        
        let allClasses: [[KelasModels]] = [kelas1data, kelas2data, kelas3data, kelas4data, kelas5data, kelas6data]
        
        for (index, kelasModel) in allClasses.enumerated() {
            let siswaData = kelasModel.filter { $0.siswaID == siswaID }
            // ---- PERUBAHAN UTAMA DI SINI ----
            // Periksa apakah ada data sebelum menghitung rata-rata
            guard !siswaData.isEmpty else {
                // Jika tidak ada data, anggap rata-ratanya 0 untuk kelas ini
                averageByClass["Kelas \(index + 1)"] = 0.0
                continue // Lanjut ke kelas berikutnya
            }
            // --------------------------------
            let totalNilai = siswaData.reduce(0) { $0 + $1.nilai }
            let average = Double(totalNilai) / Double(siswaData.count)
            
            averageByClass["Kelas \(index + 1)"] = average // Nama Kelas dan Jumlah Nilai Kelas
        }
        
        return averageByClass
    }
    
    /// Mengkalkulasi nilai rata-rata semester 1 dan 2 di setiap kelas dan mengembalikan nilai dari setiap semester.
    /// - Parameter siswaID: ID Siswa yang diproses
    /// - Returns: Pengembalian nilai dalam Dictionary dengan format [Kelas: [Semester 1: Nilai], [Semester 2: Nilai]]
    func calculateAverageSemester1And2(forSiswaID siswaID: Int64) -> [String: [String: Double]] {
        var averageByClassAndSemester: [String: [String: Double]] = [:]
        let allClasses: [[KelasModels]] = [kelas1data, kelas2data, kelas3data, kelas4data, kelas5data, kelas6data]

        for (index, kelasModel) in allClasses.enumerated() {
            let semester1Data = getSemesterData(for: kelasModel, siswaID: siswaID, semester: "1")
            let semester2Data = getSemesterData(for: kelasModel, siswaID: siswaID, semester: "2")

            let averageSemester1 = calculateAverage(from: semester1Data)
            let averageSemester2 = calculateAverage(from: semester2Data)

            averageByClassAndSemester["Kelas \(index + 1)"] = [
                "Semester 1": averageSemester1,
                "Semester 2": averageSemester2,
            ]
        }

        return averageByClassAndSemester
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
