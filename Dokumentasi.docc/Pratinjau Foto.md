# Pratinjau Foto

View controller yang bertanggung jawab untuk menampilkan dan mengelola pratinjau foto siswa.

## Overview

![Pratinjau Foto.](PratinjauFoto)

``PratinjauFoto`` digunakan dalam beberapa bagian aplikasi seperti ``DetailSiswaController`` dan ``EditData``.

## Alur Kerja Zoom

### Inisialisasi Zoom
- ``PratinjauFoto/fitInitialImage(_:)`` menghitung magnification awal menggunakan ``PratinjauFoto/calculateInitialMagnification(for:in:)``
- Nilai magnification diklamp antara `scrollView.minMagnification` dan `scrollView.maxMagnification`
- Gambar diposisikan di tengah menggunakan ``PratinjauFoto/centerImageInScrollView()``

### Interaksi Zoom
- Zoom in dilakukan melalui ``PratinjauFoto/increaseSize(_:)`` dengan langkah 0.5x
- Zoom out dilakukan melalui ``PratinjauFoto/decreaseSize(_:)`` dengan langkah 0.5x
- Perubahan zoom dianimasikan menggunakan ``PratinjauFoto/animateZoom(to:)``

## ScrollView Configuration

``PratinjauFoto/scrollView`` dikonfigurasi dengan:
- `allowsMagnification` diaktifkan
- `minMagnification` set ke 0.01 (1%)
- `maxMagnification` set ke 10.0 (1000%)
- Menggunakan custom ``CenteringClipView`` untuk memusatkan gambar

## Pan Gesture Handling

### Gesture Recognition
- `panGesture` ditambahkan ke ``PratinjauFoto/scrollView`` ketika gambar diperbesar
- Gesture dihapus ketika gambar kembali ke ukuran normal

### Handle Logic
- ``PratinjauFoto/handlePanGesture(_:)`` mengatur navigasi manual saat zoom aktif
- Translation disesuaikan dengan faktor zoom current
- Posisi scroll diupdate berdasarkan pergerakan gesture

## Visual Effect Views

- ``PratinjauFoto/visualEffect`` & ``PratinjauFoto/visualEffectShare``
    - Kedua view menggunakan `NSVisualEffectView` dengan corner radius 14pt
    - Ditampilkan ketika gambar dalam keadaan normal (``PratinjauFoto/clampedMagnification``)
    - Disembunyikan ketika gambar diperbesar (zoom aktif)

### Perilaku Visibility
```swift
// Ditampilkan saat zoom normal
if abs(scrollView.magnification - clampedMagnification) < tolerance {
    visualEffect.isHidden = false
    visualEffectShare.isHidden = false
} 
// Disembunyikan saat zoom aktif
else {
    visualEffect.isHidden = true
    visualEffectShare.isHidden = true
}
```

## Metode Utama

- ``PratinjauFoto/setImageView(_:)``
    - Mengatur gambar yang akan ditampilkan dan mengkonfigurasi scrollView untuk fitur zoom.

- ``PratinjauFoto/scrollViewDidChangeBounds(_:)``
    - Merespons perubahan bounds scrollView dan mengatur status drag enable/disable.

- ``PratinjauFoto/shareMenu(_:)``
    - Menangani berbagi foto melalui sharing service picker.

- ``PratinjauFoto/simpanFoto(_:)``
    - Menyimpan foto ke database dengan kompresi kualitas 50%.

- ``PratinjauFoto/simpankeFolder(_:)``
    - Menyimpan foto dari database ke file jpeg.

> Catatan Teknis:
> - File temporary untuk sharing dibuat di direktori temporary sistem
> - Nama file menggunakan nama siswa dengan replacement karakter '/'
> - Zoom animation menggunakan `NSAnimationContext` dengan duration 0.2s
> - Database operations dilakukan melalui ``DatabaseController`` singleton
