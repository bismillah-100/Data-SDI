//
//  UndoRedoManager.swift
//  Data SDI
//
//  Created by MacBook on 16/09/25.
//

import Foundation

/// `UndoRedoManager`
///
/// Kelas singleton yang mengelola sinkronisasi status **Undo** dan **Redo**
/// pada menu bar aplikasi macOS.
///
/// `UndoRedoManager` bertugas:
/// - Mengatur target, action, dan status enable/disable menu item Undo/Redo.
/// - Mengamati perubahan pada `UndoManager` aktif.
/// - Memastikan update menu dilakukan dengan debounce untuk menghindari pembaruan berlebihan.
/// - Memungkinkan penambahan logika tambahan setelah update menu.
///
/// Gunakan `UndoRedoManager.shared` untuk mengakses instance tunggalnya.
final class UndoRedoManager {
    // MARK: - Singleton

    /// Instance tunggal `UndoRedoManager` yang digunakan di seluruh aplikasi.
    static let shared: UndoRedoManager = .init()

    // MARK: - State

    /// Referensi lemah ke target saat ini yang akan menerima aksi Undo/Redo.
    ///
    /// Biasanya adalah `NSViewController` yang sedang aktif.
    private weak var currentTarget: AnyObject?

    /// Referensi lemah ke `UndoManager` yang sedang diamati.
    ///
    /// `UndoManager` ini digunakan untuk menentukan apakah Undo/Redo tersedia.
    private weak var currentUndoManager: UndoManager?

    /// Selector untuk aksi Undo yang akan dipasang ke menu item Undo.
    private var undoSelector: Selector?

    /// Selector untuk aksi Redo yang akan dipasang ke menu item Redo.
    private var redoSelector: Selector?

    // MARK: - Internal

    /// Work item yang digunakan untuk debounce update menu.
    private var workItem: DispatchWorkItem?

    /// Token observer untuk notifikasi perubahan `UndoManager`.
    private var observer: NSObjectProtocol?

    // MARK: - Init

    /// Inisialisasi privat untuk memastikan hanya ada satu instance (`singleton`).
    private init() {}

    // MARK: - Public API

    /// Memperbarui status menu Undo/Redo berdasarkan `UndoManager` yang diberikan.
    ///
    /// - Parameters:
    ///   - target: Objek yang akan menjadi target aksi Undo/Redo.
    ///   - undoManager: `UndoManager` yang digunakan untuk menentukan status Undo/Redo.
    ///   - undoSelector: Selector untuk aksi Undo.
    ///   - redoSelector: Selector untuk aksi Redo.
    ///   - debugName: (Opsional) Nama untuk keperluan debug/log.
    ///   - afterUpdate: (Opsional) Closure yang dipanggil setelah menu diperbarui.
    ///
    /// Panggil fungsi ini setiap kali `UndoManager` aktif berubah atau
    /// saat `ViewController` menjadi aktif.
    func updateUndoRedoState(
        for target: AnyObject,
        undoManager: UndoManager,
        undoSelector: Selector,
        redoSelector: Selector,
        debugName: String? = nil,
        afterUpdate: (() -> Void)? = nil
    ) {
        workItem?.cancel()
        workItem = nil
        currentTarget = target
        currentUndoManager = undoManager
        self.undoSelector = undoSelector
        self.redoSelector = redoSelector

        let canUndo = undoManager.canUndo
        let canRedo = undoManager.canRedo
        applyMenuState(canUndo: canUndo, canRedo: canRedo, target: target)

        if let debugName {
            #if DEBUG
                print("---- UPDATE UNDO REDO (\(debugName)) -----")
                print("canUndo:", canUndo, "canRedo:", canRedo)
            #endif
        }

        afterUpdate?()
    }

    /// Memulai observasi perubahan pada `UndoManager` aktif.
    ///
    /// Observasi dilakukan menggunakan notifikasi `.NSUndoManagerCheckpoint`.
    /// Setiap kali notifikasi diterima, menu Undo/Redo akan diperbarui dengan debounce.
    func startObserving() {
        guard let undoManager = currentUndoManager else { return }

        observer = NotificationCenter.default.addObserver(
            forName: .NSUndoManagerCheckpoint,
            object: undoManager,
            queue: .main
        ) { [weak self] _ in
            self?.handleUndoManagerChange()
        }
    }

    /// Menghentikan observasi perubahan `UndoManager`.
    ///
    /// Juga membatalkan dan membersihkan work item yang tertunda.
    func stopObserving() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    // MARK: - Private

    /// Menangani perubahan pada `UndoManager` yang diamati.
    ///
    /// Perubahan akan memicu pembaruan menu Undo/Redo dengan delay 0.1 detik
    /// untuk menghindari pembaruan berlebihan.
    private func handleUndoManagerChange() {
        guard let target = currentTarget,
              let undoManager = currentUndoManager,
              let undoSel = undoSelector,
              let redoSel = redoSelector
        else { return }
        updateUndoRedoState(
            for: target,
            undoManager: undoManager,
            undoSelector: undoSel,
            redoSelector: redoSel
        )
    }

    /// Menerapkan status menu Undo/Redo ke menu bar.
    ///
    /// - Parameters:
    ///   - canUndo: `true` jika Undo tersedia.
    ///   - canRedo: `true` jika Redo tersedia.
    ///   - target: Target untuk aksi Undo/Redo.
    private func applyMenuState(canUndo: Bool, canRedo: Bool, target: AnyObject) {
        workItem?.cancel()
        workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            ReusableFunc.undoMenuItem?.isEnabled = canUndo
            ReusableFunc.undoMenuItem?.target = canUndo ? target : nil
            ReusableFunc.undoMenuItem?.action = canUndo ? undoSelector : nil

            ReusableFunc.redoMenuItem?.isEnabled = canRedo
            ReusableFunc.redoMenuItem?.target = canRedo ? target : nil
            ReusableFunc.redoMenuItem?.action = canRedo ? redoSelector : nil

            NotificationCenter.default.post(name: .bisaUndo, object: nil)
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.1, execute: workItem!)
    }
}
