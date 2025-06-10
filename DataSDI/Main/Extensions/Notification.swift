//
//  Notification.swift
//  Data SDI
//
//  Created by Bismillah on 01/12/23.
//

import Foundation

extension Notification.Name {
    static let toggleSidebar = Notification.Name("ToggleSidebarNotification")
    static let editButtonClicked = Notification.Name("EditButtonClicked")
    static let deleteButtonClicked = Notification.Name("DeleteButtonClicked")
    static let addDetil = NSNotification.Name("addDetil")
    static let updateTableNotification = NSNotification.Name("UpdateTableNotification")
    static let updateTableNotificationDetilSiswa = NSNotification.Name("UpdateTableNotificationDetilSiswa")
    static let updateRedoInDetilSiswa = NSNotification.Name("UpdateRedoInDetilSiswa")
    static let undoKelasDihapus = NSNotification.Name("UndoKelasDihapus")
    static let updateUndoArray = NSNotification.Name("UpdateUndoArray")
    static let findDeletedData = NSNotification.Name("FindDeletedData")
    static let editDataSiswaKelas = NSNotification.Name("EditDataSiswaKelas")
    static let updateNilaiTeks = NSNotification.Name("reloadTeks")
    static let editDataSiswa = Notification.Name("EditDataSiswa")
    static let siswaDihapus = Notification.Name("SiswaDihapus")
    static let undoSiswaDihapus = Notification.Name("UndoSiswaDihapus")
    static let addDetilSiswaUITertutup = Notification.Name("AddDetilSiswaUITertutup")
    static let addSiswa = NSNotification.Name("addSiswa")
    static let kelasDihapus = NSNotification.Name("KelasDihapus")
    static let dataSaved = NSNotification.Name("DataSaved")

    static let siswaNaikDariKelasVC = NSNotification.Name("SiswaNaikDariKelasVC")
    static let updateGuruMapel = NSNotification.Name("updateGuruMapel")
    static let dataSiswaDiEdit = NSNotification.Name("dataSiswaDiEdit")
    static let updateNamaGuru = NSNotification.Name("updateNamaGuru")
    static let editNamaGuruKelas = NSNotification.Name("EditNamaGuruKelas")
    static let naikKelas = NSNotification.Name("NaikKelas")
    static let deleteMenu = NSNotification.Name("deleteMenu")
    static let updateSearchField = Notification.Name("updateSearchField")
    static let hapusDataKelas = Notification.Name("HapusDataKelas")
    static let updateDataKelas = Notification.Name("UpdateDataSiswaDiKelas")
    static let hapusDataSiswa = Notification.Name("HapusDataDariDetailSiswa")
    static let windowControllerBecomeKey = Notification.Name("WindowControllerBecomeKey")
    static let windowControllerResignKey = Notification.Name("windowcontrollerResignKey")
    static let windowControllerClose = Notification.Name("WindowControllerclose")
    static let sidebar = Notification.Name("sidebarlayout")
    static let sidebarHiden = Notification.Name("sidebarHiden")
    static let popupDismissed = Notification.Name("popupDismissed")
    static let popupDismissedKelas = Notification.Name("popupDismissedKelas")
    static let popupDismissedDetil = Notification.Name("popupDismissedDetil")
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

    static let windowTabDidChange = Notification.Name("tabGroupWindow")

    // MARK: - SISWAVIEWMODEL

    static let undoActionNotification = Notification.Name("undoActionNotification")
    static let updateEditSiswa = Notification.Name("editedDataSiswa")

    // MARK: - UPDATE FOTO DI TOOLBAR

    static let bisaUndo = Notification.Name("bisaUndo")

    // MARK: - PENAMBAHAN DATA BARU KE DATABASE DAN TABLEVIEW
}
