# Flat Data Siswa

``DataSDI/PlainSiswaData`` mengimplementasikan ``SiswaDataSource`` untuk menyimpan dan mengelola data siswa dalam bentuk array datar.

## Overview

Gunakan ``DataSDI/PlainSiswaData`` ketika Anda ingin menampilkan daftar siswa dalam satu tampilan daftar seperti AppKit `NSTableView` tanpa menggunakan section atau SwiftUI `ListView`.
`PlainSiswaData` menyimpan data dalam array tunggal `[ModelSiswa]` dan menyediakan fungsi pencarian, filter, pengurutan, serta sinkronisasi dengan database.

### Mengambil Data

Gunakan fungsi ini untuk mendapatkan objek ``ModelSiswa`` yang sesuai di dalam ``PlainSiswaData/data``.

- ``PlainSiswaData/currentFlatData()``
- ``PlainSiswaData/siswa(at:)``
- ``SiswaDataSource/siswa(in:)``
- ``PlainSiswaData/siswa(for:)``
- ``SiswaDataSource/siswaIDs(in:)``
- ``PlainSiswaData/getIdNamaFoto(row:)``

## Memodifikasi Data

Gunakan fungsi ini untuk memodifikasi ``PlainSiswaData/data``.

- ``PlainSiswaData/insert(_:comparator:)``
- ``PlainSiswaData/removeSiswa(_:)``
- ``PlainSiswaData/relocateSiswa(_:comparator:columnIndex:)``
- ``PlainSiswaData/update(siswa:)``

## Filter

Gunakan fungsi ini untuk memfilter ``PlainSiswaData/data``.

- ``PlainSiswaData/cariSiswa(_:)``
- ``PlainSiswaData/filterSiswaBerhenti(_:comparator:)``
- ``PlainSiswaData/filterSiswaLulus(_:comparator:)``

## Undo/Redo

Gunakan fungsi ini untuk undo/redo setelah mengedit kolom tertentu.

- ``PlainSiswaData/undoAction(originalModel:)``
- ``PlainSiswaData/redoAction(originalModel:)``

## Mengambil Indeks

Gunakan fungsi ini untuk mendapatkan indeks objek ``ModelSiswa`` di dalam array ``PlainSiswaData/data``.

- ``PlainSiswaData/indexSiswa(for:)``
- ``SiswaDataSource/indexSet(for:)``

## Mengurutkan Data

Gunakan fungsi ini untuk mengurutkan ``PlainSiswaData/data``.

- ``PlainSiswaData/sort(by:)``
