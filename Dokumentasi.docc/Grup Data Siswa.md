# Grup Data Siswa

``GroupedSiswaData`` yang mengimplementasikan ``SiswaDataSource`` untuk menyimpan dan mengelola data siswa dalam bentuk array terkelompok (grouped).

## Overview

Gunakan ``GroupedSiswaData`` ketika Anda ingin menampilkan daftar siswa yang dikelompokkan berdasarkan kelas.
`GroupedSiswaData` menyimpan data dalam array 2 dimensi `[[ModelSiswa]]` dan menghitung indeks absolut untuk mendukung tampilan tabel dengan header grup.

## Mengambil Data

Gunakan fungsi ini untuk mendapatkan objek ``ModelSiswa`` yang sesuai di dalam ``GroupedSiswaData/groups``.

- ``GroupedSiswaData/currentFlatData()``
- ``GroupedSiswaData/siswa(at:)``
- ``SiswaDataSource/siswa(in:)``
- ``GroupedSiswaData/siswa(for:)``
- ``SiswaDataSource/siswaIDs(in:)``
- ``GroupedSiswaData/getIdNamaFoto(row:)``

## Memodifikasi Data

Gunakan fungsi ini untuk memodifikasi ``GroupedSiswaData/groups``.

- ``GroupedSiswaData/insert(_:comparator:)``
- ``GroupedSiswaData/removeSiswa(_:)``
- ``GroupedSiswaData/relocateSiswa(_:comparator:columnIndex:)``
- ``GroupedSiswaData/update(siswa:)``

## Filter

Gunakan fungsi ini untuk memfilter ``GroupedSiswaData/groups``.

- ``GroupedSiswaData/cariSiswa(_:)
- ``GroupedSiswaData/filterSiswaBerhenti(_:comparator:)``
- ``GroupedSiswaData/filterSiswaLulus(_:comparator:)``

## Undo/Redo

Gunakan fungsi ini untuk undo/redo setelah mengedit kolom tertentu.

- ``GroupedSiswaData/undoAction(originalModel:)``
- ``GroupedSiswaData/redoAction(originalModel:)``

## Mengambil Indeks

Gunakan fungsi ini untuk mendapatkan indeks objek ``ModelSiswa`` di dalam array ``GroupedSiswaData/groups``.

- ``SiswaDataSource/indexSet(for:)``
- ``GroupedSiswaData/indexSiswa(for:)``
- ``GroupedSiswaData/getIdNamaFoto(row:)``

## Mengurutkan Data

Gunakan fungsi ini untuk mengurutkan ``GroupedSiswaData/groups``.

- ``GroupedSiswaData/sort(by:)``
