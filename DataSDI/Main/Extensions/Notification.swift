//
//  Notification.swift
//  Data SDI
//
//  Created by Bismillah on 01/12/23.
//

import Foundation

extension Notification.Name {
    // MARK: - SISWAVIEWCONTROLLER

    /// Notifikasi yang diposting ketika data siswa dihapus di ``SiswaViewController``
    static let siswaDihapus = Notification.Name("SiswaDihapus")
    /// Notifikasi yang diposting ketika data siswa diurungkan dihapus di ``SiswaViewController``
    static let undoSiswaDihapus = Notification.Name("UndoSiswaDihapus")

    // MARK: - DETAILSISWACONTROLLER

    /// Notifikasi yang diposting ketika data siswa di ``DetailSiswaController`` dihapus.
    static let findDeletedData = NSNotification.Name("FindDeletedData")
    /// Notifikasi yang diposting ketika data siswa diedit di ``DetailSiswaController``.
    static let editDataSiswa = Notification.Name("EditDataSiswa")
    /// Notifikasi yang diposting ketika pembaruan data di ``DetailSiswaController`` telah disimpan.
    static let dataSaved = NSNotification.Name("DataSaved")
    /// Notifikasi yang posting ketika data dimasukkan ke tabel ``DetailSiswaController``.
    static let updateRedoInDetilSiswa = NSNotification.Name("UpdateRedoInDetilSiswa")

    // MARK: - KELASVC

    /// Notifikasi yang diposting ketika data dihapus di ``KelasVC``..
    static let kelasDihapus = NSNotification.Name("KelasDihapus")
    /// Notifikasi yang diposting ketika menjalankan `redo paste` dari ``KelasVC``.
    static let undoKelasDihapus = NSNotification.Name("UndoKelasDihapus")
    /// Notifikasi yang diposting ketika siswa naik kelas.
    static let naikKelas = NSNotification.Name("NaikKelas")

    /// Notifikasi yang diposting ketika data di ``KelasVC`` diperbarui.
    static let updateDataKelas = Notification.Name("UpdateDataSiswaDiKelas")

    // MARK: KELASVIEWMODEL

    /// Notifikasi yang diposting ketika nama guru di kelas diperbarui.
    static let editNamaGuruKelas = NSNotification.Name("EditNamaGuruKelas")
    /// Notifikasi yang diposting ketika data kelas diperbarui.
    static let editDataSiswaKelas = NSNotification.Name("EditDataSiswaKelas")

    // MARK: - MENAMBAHKAN DATA KELAS

    /// Notifikasi yang dikirim ketika menambahkan data ke tabel database kelas.
    /// Notifikasi ini digunakan untuk menambahkan data ke  tabel ``DetailSiswaController`` setelah data ditambahkan ke database.
    static let addDetil = NSNotification.Name("addDetil")

    /// Notifikasi yang dikirim ketika menambahkan data ke tabel database kelas.
    /// Notifikasi ini digunakan untuk menambahkan data ke  tabel ``DetailSiswaController``..
    static let updateTableNotificationDetilSiswa = NSNotification.Name("UpdateTableNotificationDetilSiswa")

    static let addDetilSiswaUITertutup = Notification.Name("AddDetilSiswaUITertutup")

    static let updateGuruMapel = NSNotification.Name("updateGuruMapel")

    static let dataSiswaDiEdit = NSNotification.Name("dataSiswaDiEdit")

    static let windowControllerBecomeKey = Notification.Name("WindowControllerBecomeKey")
    static let windowControllerResignKey = Notification.Name("windowcontrollerResignKey")
    static let windowControllerClose = Notification.Name("WindowControllerclose")
    static let popupDismissed = Notification.Name("popupDismissed")
    static let popupDismissedKelas = Notification.Name("popupDismissedKelas")
    static let saveData = Notification.Name("simpanSemua")
    static let hapusCacheFotoKelasAktif = Notification.Name("cacheFotoKelasAktifDihapus")

    // dari SiswaView ke KelasVC
    static let dataSiswaDiEditDiSiswaView = NSNotification.Name("dataSiswaDiEditDiSiswaView")

    // MARK: - JUMLAHSISWA

    static let jumlahSiswa = NSNotification.Name("tglBerhentiProcessed")

    // MARK: - TRANSAKSI VIEW

    static let popUpDismissedTV = NSNotification.Name("popUpDismissedKeTV")
    static let perubahanData = NSNotification.Name("perubahanData")
    static let didAssignUUID = Notification.Name("didAssignUUID")

    // MARK: - WINDOW

    // MARK: - SISWAVIEWMODEL

    static let undoActionNotification = Notification.Name("undoActionNotification")
    static let updateEditSiswa = Notification.Name("editedDataSiswa")

    // MARK: - UPDATE FOTO DI TOOLBAR

    static let bisaUndo = Notification.Name("bisaUndo")

    // MARK: - KELASAKTIF DAN STATUS BERUBAH

    /// Notifikasi ini dikirim ketika pendaftaran (enrollment) aktif seorang siswa berubah.
    /// `userInfo` akan berisi ["siswaID": Int64].
    static let didChangeStudentEnrollment = Notification.Name("didChangeStudentEnrollment")

    // MARK: - PENAMBAHAN DATA BARU KE DATABASE DAN TABLEVIEW
}
