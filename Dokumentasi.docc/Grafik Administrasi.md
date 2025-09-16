# Grafik Administrasi

Grafik ini menampilkan data transaksi administrasi, termasuk pengeluaran, pemasukan, dan lainnya, dalam bentuk diagram point. Pengguna dapat memfilter data berdasarkan bulan dan tahun.

## Overview
![Grafik Administrasi.](AdminChart)

## Alur Tampilan dan Pemicu

Grafik administrasi diimplementasikan dalam  ``AdminChart`` yang menggunakan **`SwiftUI`** di dalam `NSHostingView`, memungkinkan integrasi modern SwiftUI dengan lingkungan AppKit. Tampilan ini dipicu oleh tombol di bilah alat ``WindowController/jumlahToolbar`` dan muncul dalam sebuah jendela popover (`NSPopOver`).

### Fitur Jendela

* **Jendela Popover:** Grafik awalnya muncul sebagai popover kecil yang dapat diperluas.
* **Jendela Baru:** Pengguna dapat membuka grafik di jendela terpisah dengan tombol **`AdminChart/bukaJendela`**.
* **Manajemen Jendela:**
    * Aplikasi memastikan hanya satu jendela `AdminChart` yang bisa dibuka.
    * Jika jendela sudah ada, tombol akan memfokuskan jendela yang sudah terbuka tersebut.
    * Saat jendela ditutup, `observer` akan menghapus state jendela yang disimpan di ``AppDelegate/openedAdminChart``, memungkinkan jendela baru untuk dibuka.

---

## Manajemen Data dan Implementasi

Grafik ini menggunakan arsitektur MVVM (Model-View-ViewModel) dengan ``AdminChartViewModel`` sebagai `@ObeservableObject` untuk mengelola data.

### **1. Sumber Data**

* **ViewModel:** ``AdminChartViewModel`` bertugas mengambil, memproses, dan menyediakan data untuk tampilan.
* **Pembaruan Otomatis:** ViewModel mendengarkan notifikasi dari `NotificationCenter` (`.perubahanData`, ``DataManager/dataDieditNotif`` dan ``DataManager/dataDidChangeNotification``) untuk mereset *cache* dan memperbarui grafik secara otomatis.

### **2. Filter Data**

Grafik ini mendukung filter data berdasarkan bulan dan tahun, yang ditentukan oleh `enum ChartPeriod`.
* **Data Bulanan:** Diproses oleh ``AdminChartViewModel/prepareMonthlyData(_:tahun:)``.
* **Data Tahunan:** Diproses oleh ``AdminChartViewModel/prepareYearlyData(_:)``.

### **3. Struktur Kode**

| Komponen | Deskripsi |
| :--- | :--- |
| **Model** | ``ChartDataPoint``: Model data untuk setiap point pada grafik. |
| **ViewModel** | ``AdminChartViewModel``: Mengelola logika bisnis dan data. |
| **View SwiftUI** | ``AdminLineChartView``: Tampilan grafik utama. |
| **Fetch Data** | ``AdminChartViewModel/fetchMonthlyData(_:tahun:)`` dan ``AdminChartViewModel/fetchYearRange()``: Metode untuk mengambil data dari CoreData. |
| **UI Filter** | ``AdminChart/filterJenis(_:)`` dan ``AdminChart/filterTahun(_:)``: Tombol dan menu untuk mengubah filter. |
| **Export** | ``AdminChart/shareMenu(_:)``: Menyimpan grafik sebagai gambar. |
| **Enum** | ``ChartPeriod``: Mengelola state filter (per bulan atau per tahun). |
