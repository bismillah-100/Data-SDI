# Indikator Data

Indikator yang menampilkan proses pemuatan data dan proses pembaruan data dengan umpan balik yang informatif, serta notifikasi overlay ketika pengaturan atau data telah berhasil diperbarui.

## Overview

### Inisialisasi Data
- ``InitProgress``: → menampilkan jendela kecil dengan indikator spinner yang berputar, memberi tahu pengguna bahwa aplikasi sedang memuat data awal.

### Penyimpanan atau Pembaruan Data
- ``ProgressBarVC``: → indikator progress bar dengan status kemajuan sesuai dengan jumlah data, menampilkan sejauh mana proses pembaruan telah berjalan (misalnya 45 dari 100 item).

### Notifikasi Event Tertentu
- ``AlertWindow`` → overlay sederhana (misalnya ✅ sukses, ⚠️ peringatan, ❌ gagal) yang muncul sebentar untuk mengonfirmasi status proses terkini.

### Contoh Penggunaan
- ``InitProgress``:
```swift
let progressVC = InitProgress(nibName: "InitProgress", bundle: nil)
progressVC.loadView()
progressVC.view.wantsLayer = true
progressVC.view.layer?.cornerRadius = 10.0
guard let window = progressVC.view.window else { return }
window.backingType = .buffered
window.level = .normal
window.hasShadow = false
window.isOpaque = false
window.backgroundColor = .clear
window.titlebarAppearsTransparent = false
window.isReleasedWhenClosed = true

// Menampilkan sebagai jendela modal
let progressWindowController = NSWindowController(window: window)
```

- ``AlertWindow``:
```swift
let progressVC = AlertWindow(nibName: "AlertWindow", bundle: nil)
progressVC.loadView()
progressVC.configure(with: pesan, image: image)

guard let window = progressVC.view.window else { return }

window.level = .floating
window.hasShadow = false
window.isOpaque = false
window.backgroundColor = .clear

// Menyembunyikan title bar
window.titlebarAppearsTransparent = false

window.isMovableByWindowBackground = false
window.styleMask.remove(.titled)
window.titleVisibility = .hidden
window.isReleasedWhenClosed = true

// Mengatur posisi jendela di tengah layar
let alertWindowController = NSWindowController(window: window)
```

## Topics

### Pemuatan Data
- ``InitProgress``
- ``ITProgressIndicator``

### Pembaruan Data
- ``ProgressBarVC``
- ``ProgressBarWindow``

### Notifikasi Overlay
- ``AlertWindow``
