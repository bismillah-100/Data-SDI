# Rekap Nilai

Rekap nilai menampilkan nilai-nilai siswa dan mata pelajaran pada kelas tertentu dengan dukungan untuk ekspor data ke file *pdf* dan *xlsx*.

## Overview

Rekap nilai ditampilkan sebagai `NSPopOver` melalui ``WindowController/kalkulasiToolbar``.

### Jendela

Rekap Nilai bisa diperluas menjadi jendela baru melalui ``NilaiKelas/newWindow(_:)``.

- **State Jendela**:
    - ``NilaiKelas/isNewWindow`` set ke **false** jika dari popover.
    - ``NilaiKelas/isNewWindow`` set ke **true** jika dibuka di jendela baru.
    - ``NilaiKelas`` menggunakan protokol `NSWindowDelegate` ketika dibuka di jendela baru.
    - Pembukaan jendela dibatasi ke satu jendela untuk setiap kelas.
    - Pembukaan jendela dari hanya dapat dilakukan jika menampilkan data kelas aktif.
    - Referensi jendela disimpan di ``AppDelegate/openedKelasWindows``.
    - Referensi jendela dihapus ketika jendela ditutup.


### Representasi Data

- Rekap nilai dapat menerima filter sesuai konteks data kelas aktif atau arsip data kelas aktif:
    - ``NilaiKelas/kelasAktif``

- Jika rekap nilai dibuka dari ``KelasVC``:
    - ``NilaiKelas/kelasAktif`` set ke **true**.
    - tableView menampilkan data di ``KelasViewModel/kelasData``.

- Jika rekap nilai dibuka dari ``KelasHistoryVC``:
    - ``NilaiKelas/kelasAktif`` set ke **false**.
    - tableView menampilkan data di ``KelasViewModel/arsipKelasData``


### Tampilan

- ``NilaiKelas``

### ViewModel

- ``KelasViewModel``

### Memuat data

- ``NilaiKelas/muatUlang(_:)``

### Menu ekspor

- ``NilaiKelas/shareButton(_:)``
- ``NilaiKelas/exportToPDF(_:)``
- ``NilaiKelas/exportToExcel(_:)``
- ``NilaiKelas/saveToCSV(header:siswaData:destinationURL:)``

### Menyalin data

- ``NilaiKelas/salinRow(_:header:)``
- ``NilaiKelas/tableView(_:rowActionsForRow:edge:)``

### Menutup jendela

- ``NilaiKelas/windowWillClose(_:)``
