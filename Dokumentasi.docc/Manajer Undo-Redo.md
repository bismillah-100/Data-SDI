# Undo-Redo Manager

Manajer global untuk sinkronisasi status **Undo** dan **Redo** pada menu bar aplikasi macOS.

## Overview

`UndoRedoManager` adalah singleton yang bertugas:
- Mengatur target, action, dan status enable/disable menu item Undo/Redo.
- Mengamati perubahan pada `UndoManager` aktif.
- Memastikan update menu dilakukan dengan debounce untuk menghindari pembaruan berlebihan.
- Memungkinkan penambahan logika tambahan setelah update menu.

## Multi Window

Pada aplikasi macOS dengan banyak `ViewController` atau multi-window, status menu Undo/Redo di menu bar harus selalu sinkron dengan konteks yang sedang aktif.  
`UndoRedoManager` menyederhanakan proses ini dengan menyediakan API tunggal untuk:

1. **Mendaftarkan konteks aktif** (`updateUndoRedoState`)
2. **Mengamati perubahan** pada `UndoManager` (`startObserving`)
3. **Menghentikan observasi** saat konteks tidak lagi aktif (`stopObserving`)

## Diagram Alur

```mermaid
flowchart TD
    A[Window jadi key] --> B{VC eligible Undo/Redo?}
    B -- Ya --> C[updateUndoRedoState()]
    C --> D[startObserving()]
    D --> E[UndoManager berubah]
    E --> F[handleUndoManagerChange()]
    F --> G[applyMenuState()]
    B -- Tidak --> H[resetMenuItems()]
```

## Manajemen State

### Mengatur Status Undo/Redo

- ``UndoRedoManager/updateUndoRedoState(for:undoManager:undoSelector:redoSelector:debugName:afterUpdate:updateToolbar:)``

Panggil ini setiap kali `ViewController` menjadi aktif atau `UndoManager` berubah.  
Metode ini akan langsung memperbarui menu Undo/Redo dan menyimpan konteks untuk observasi selanjutnya.

### Mengamati Perubahan UndoManager

- ``UndoRedoManager/startObserving()``

Memulai observasi pada `UndoManager` aktif.  
Setiap perubahan akan memicu pembaruan menu dengan debounce 0.1 detik.

- ``UndoRedoManager/stopObserving()``

Menghentikan observasi dan membatalkan pembaruan tertunda.

## Contoh Penggunaan

### Integrasi di ViewController

```swift
override func viewDidAppear() {
    super.viewDidAppear()
    UndoRedoManager.shared.updateUndoRedoState(
        for: self,
        undoManager: myUndoManager,
        undoSelector: #selector(performUndo(_:)),
        redoSelector: #selector(performRedo(_:)),
        debugName: "MyViewController"
    ) { [weak self] in
        self?.updateSaveButtonState()
    }
    UndoRedoManager.shared.startObserving()
}

override func viewWillDisappear() {
    super.viewWillDisappear()
    UndoRedoManager.shared.stopObserving()
}
```


### Integrasi di Multi-Window (AppDelegate)

```swift
@objc func windowDidBecomeKeyNotification(_ notification: Notification) {
    guard let activeWindow = NSApp.keyWindow else { return }

    if let splitVC = activeWindow.contentViewController as? SplitVC {
        updateUndoRedoMenu(for: splitVC)
    } else if let detailWindow = activeWindow.windowController as? DetilWindow,
              let detailVC = detailWindow.contentViewController as? DetailSiswaController {
        updateUndoRedoMenu(for: detailVC)
    } else {
        ReusableFunc.resetMenuItems()
    }
}
```

### Best Practices

- Gunakan `weak` untuk menyimpan referensi target dan `UndoManager` agar tidak menahan `ViewController` atau window yang sudah ditutup.
- Selalu panggil `stopObserving()` saat `ViewController` tidak lagi aktif untuk mencegah update yang tidak relevan.
- Gunakan parameter `afterUpdate` untuk menambahkan logika khusus (misalnya update ikon simpan) tanpa mencampur logika global menu.

## Topics

### Class
- ``UndoRedoManager``

### Reset Menu
- ``ReusableFunc/resetMenuItems()``
