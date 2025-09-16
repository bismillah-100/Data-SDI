# Data Historis

KelasHistoris digunakan untuk menampilkan riwayat nilai kelas aktif pada siswa yang telah berhenti/lulus/aktif pada tahun ajaran tertentu.

## Sekilas

* Kelas historis mengimplementasikan:
    * *class* ``KelasTableManager`` sebagai pengelola `tableView`.
    * `NSTextFieldDelegate` untuk input tahun ajaran.
    * ``KelasViewModel`` sebagai pengelola data.

### Tampilan Utama
- ``KelasHistoryVC``

### ViewModel
- ``KelasViewModel``

### Mengubah tahun ajaran
- ``KelasHistoryVC/controlTextDidEndEditing(_:)``

### Mengurutkan data
- ``KelasHistoryVC/setupSortDescriptor()``
- ``KelasHistoryVC/sortData()``

### Memuat data
- ``KelasHistoryVC/muatUlang(_:)``

### Rekap nilai
- ``KelasHistoryVC/rekapNilai(_:)``
