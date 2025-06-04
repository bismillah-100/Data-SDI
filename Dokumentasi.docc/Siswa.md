# Siswa

Ringkasan Fitur dan Tampilan yang berhubungan dengan manajemen data Siswa.

## Overview

Tampilan siswa memiliki dua tampilan: Grup dan non-grup.
Grup menggunakan NSTableView dengan cell ``GroupTableCellView``, sedangkan non-group menggunakan cell ``CustomTableCellView`` dengan kustomisasi NSDatePicker untuk kolom tahun daftar dan tanggal berhenti.
- Mode Grup dan non-Grup menggunakan class ``EditableTableView`` yang dikelola dalam satu outlet tableView dalam satu class ``SiswaViewController``.
- Data siswa menggunakan kerangka data ``ModelSiswa`` yang dikelola oleh viewModel ``SiswaViewModel``.

## Topics

### Tampilan Utama
- ``SiswaViewController``

### Tampilan Model
- ``SiswaViewModel``

### Model Data
- ``ModelSiswa``

### Menambahkan Data
- ``DataSDI/AddDataViewController``

### Mengedit Data
- ``DataSDI/EditData``

### Mencari dan Mengganti Data pada Kolom
- ``DataSDI/CariDanGanti``

### Konteks Menu (Klik Kanan)
- ``SiswaViewController/updateMenu(_:)``
- ``SiswaViewController/updateTableMenu(_:)``

### Konteks Menu Perubahan Kelas
- ``SiswaViewController/createCustomMenu()``
- ``SiswaViewController/createCustomMenu2()``
- ``SiswaViewController/tagMenuItem``
- ``SiswaViewController/tagMenuItem2``
- ``SiswaViewController/tagClick(_:)``

### Tampilan Rincian Siswa
- ``DataSDI/DetilWindow``
- ``DataSDI/DetailSiswaController``
