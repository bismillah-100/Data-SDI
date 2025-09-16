# Grafik Nilai

Grafik nilai menampilkan representasi visual data nilai kelas, baik untuk kelas aktif maupun data historis.

## Overview

Ada dua jenis grafik utama yang tersedia: **Jumlah Nilai** dan **Rata-rata Nilai**.

* **Grafik Jumlah Nilai:** Menampilkan total nilai menggunakan diagram batang.
* **Grafik Rata-rata Nilai:** Menampilkan rata-rata nilai menggunakan kombinasi diagram batang dan garis & point yang dilengkapi opsi untuk filter kategori.

**Jumlah Nilai**
![Grafik Jumlah Nilai.](JumlahNilai)

**Rata-rata Nilai**
![Grafik Rata-rata Nilai.](RataRataNilai)

## Alur Tampilan & Logika

Tampilan grafik nilai diatur berdasarkan konteks pemicu yang membukanya.

| Pemicu | Kondisi | Perilaku |
| :--- | :--- | :--- |
| **Dari Panel Sisi** | Membuka dari sidebar navigasi. | Tahun ajaran akan dikosongkan. |
| **Dari Toolbar** | Menampilkan kelas aktif. | Tahun ajaran selalu dikosongkan. |
| **Dari Toolbar** | Menampilkan riwayat nilai. | Tahun ajaran akan disesuaikan dengan arsip data. |

---

## Implementasi Teknis

### 3.1. Grafik Jumlah Nilai

Logika untuk grafik jumlah nilai diimplementasikan di dalam kelas ``StatistikKelas``.

* **Penentuan Data:** Menggunakan ``StatistikKelas/arsipKelas`` untuk menentukan sumber data.
* **Data yang Ditampilkan:** Data untuk grafik disimpan dalam ``StatistikKelas/kelasChartData``.
* **Manajemen Tahun Ajaran:** Properti ``StatistikKelas/tahunAjaran`` mengelola tahun ajaran yang sedang ditampilkan.
* **Memproses Data:** Data grafik diproses melalui metode ``StatistikKelas/prepareChartData()``.
* **Judul Popover:** Judul popover ditentukan oleh properti ``StatistikKelas/title``.

### 3.2. Grafik Rata-rata Nilai

Grafik rata-rata nilai dikelola oleh ``Stats``, yang menggunakan `SwiftUI` di dalam `NSHostingView` untuk menampilkan ``StudentCombinedChartView``. ``Stats`` juga mengimplementasikan protokol `NSTextFieldDelegate` untuk mengelola input tahun ajaran.

**Diagram yang Tersedia:**
1. **Diagram Batang** (``Stats/barstats``):
    * Menggunakan pemilih ``Stats/pilihan`` dengan ``Stats/pilihanSemuaNilai(_:)`` sebagai aksi.
    * Data diproses oleh ``Stats/displayBarChart()``.
2. **Diagram Garis & Poin (Semester 1)** (``Stats/stats``):
    * Menggunakan pemilih ``Stats/pilihanSmstr1`` dengan ``Stats/pilihanSemester1(_:)`` sebagai aksi.
    * Data diproses oleh ``Stats/createPieChart()``.
3. **Diagram Garis & Poin (Semester 2)** (``Stats/stats2``):
    * Menggunakan pemilih ``Stats/pilihanSmstr2`` dengan ``Stats/pilihanSemester2(_:)`` sebagai aksi.
    * Data diproses oleh ``Stats/createPieChartSemester2()``.

**Fungsionalitas Utama:**
* **ViewModel:** ``ChartKelasViewModel``
* **Model Data:** ``KelasChartModel``
* **Memproses Semua Data:** Semua data diproses ulang melalui metode ``Stats/muatUlang(_:)``.
* **Memproses Tampilan:** Tampilan dirender ulang melalui metode ``Stats/updateUI()``, ``Stats/updateKategoriTextField(with:)``.
* **Filter Tahun Ajaran:** ``Stats/tahunAjaranTextField1``, ``Stats/tahunAjaranTextField2``, dan ``Stats/tahunAjaran`` dikelola oleh ``Stats/controlTextDidEndEditing(_:)``.
* **Filter Diagram Batang:** Menggunakan ``Stats/pilihan`` dan ``Stats/pilihanSemuaNilai(_:)``.
* **Filter Kategori:** Dikelola oleh ``Stats/pilihanSmstr1``, ``Stats/selectedSemester1``, ``Stats/pilihanSmstr2``, dan ``Stats/selectedSemester2``.
* **Menyimpan Gambar:**
    * Diagram Batang: ``Stats/simpanchart(_:)``
    * Diagram Garis & Poin Semester 1: ``Stats/smstr1(_:)``
    * Diagram Garis & Poin Semester 2: ``Stats/smstr2(_:)``
