//
//  Data_SDIUITests.swift
//  Data SDIUITests
//
//  Created by Ays on 13/05/25.
//

import XCTest

class Data_SDIUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}


final class GuruUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testTambahGuruScenario() throws {
        let toolbar = app.toolbars.firstMatch
        print("Toolbar ditemukan: \(toolbar.exists)")
        let tambahSiswaButton = toolbar.buttons["Catat"]
        print("Tombol 'add' ditemukan: \(tambahSiswaButton.exists)")
        print("Label tombol 'add': \(tambahSiswaButton.label)")
        print("Identifier tombol 'add': \(tambahSiswaButton.identifier)")
        // 3. Verifikasi keberadaan tombol dan ketuk jika ditemukan
        
        XCTAssertTrue(tambahSiswaButton.waitForExistence(timeout: 5))
        tambahSiswaButton.tap()


        let namaTextField = app.textFields["ketik nama guru"]
        namaTextField.tap()
        namaTextField.typeText("Guru Baru")

        let alamatTextField = app.textFields["ketik alamat guru"]
        alamatTextField.tap()
        alamatTextField.typeText("Alamat Baru")

        let mapelTextField = app.textFields["ketik mata pelajaran"]
        mapelTextField.tap()
        mapelTextField.typeText("Mapel Baru")

        let strukturTextField = app.textFields["ketik jabatan guru"]
        strukturTextField.tap()
        strukturTextField.typeText("Jabatan Baru")

        let simpanButton = app.buttons["simpan"]
        simpanButton.tap()
        
        print("\n--- Hierarki Aksesibilitas Aplikasi ---")
        print(app.debugDescription)
        print("--- Akhir Hierarki ---")

        // 3. Tekan tombol "Hapus"
        let hapusButton = toolbar.buttons["Hapus"]
        XCTAssertTrue(hapusButton.waitForExistence(timeout: 5))
        hapusButton.tap()
        

        // 5. Lakukan Undo menggunakan Command + Z
        app.typeKey("z", modifierFlags: .command)
        app.typeKey("z", modifierFlags: [.shift, .command])
        app.typeKey("z", modifierFlags: .command)
        app.typeKey("z", modifierFlags: [.shift, .command])
    }

    func testEditGuruScenario() throws {
        // Asumsikan sudah ada guru dengan nama "Guru Awal" di outlineView
        
        let app = XCUIApplication()
        let mainwindowWindow = app/*@START_MENU_TOKEN@*/.windows["MainWindow"]/*[[".windows[\"Data Guru\"]",".windows[\"MainWindow\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        mainwindowWindow/*@START_MENU_TOKEN@*/.outlines.staticTexts["Muhammad Badruttamam"]/*[[".splitGroups",".scrollViews.outlines",".outlineRows",".cells.staticTexts[\"Muhammad Badruttamam\"]",".staticTexts[\"Muhammad Badruttamam\"]",".outlines"],[[[-1,5,2],[-1,1,2],[-1,0,1]],[[-1,5,2],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0,0]]@END_MENU_TOKEN@*/.click()
        XCUIElement.perform(withKeyModifiers: .shift) {
            mainwindowWindow/*@START_MENU_TOKEN@*/.outlines.staticTexts["Muhammad Khoirudduha Iii"]/*[[".splitGroups",".scrollViews.outlines",".outlineRows",".cells.staticTexts[\"Muhammad Khoirudduha Iii\"]",".staticTexts[\"Muhammad Khoirudduha Iii\"]",".outlines"],[[[-1,5,2],[-1,1,2],[-1,0,1]],[[-1,5,2],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0,0]]@END_MENU_TOKEN@*/.click()
        }
        XCUIElement.perform(withKeyModifiers: .shift) {
            mainwindowWindow/*@START_MENU_TOKEN@*/.outlines.staticTexts["Bahasa Indonesia"]/*[[".splitGroups",".scrollViews.outlines",".outlineRows",".cells.staticTexts[\"Bahasa Indonesia\"]",".staticTexts[\"Bahasa Indonesia\"]",".outlines"],[[[-1,5,2],[-1,1,2],[-1,0,1]],[[-1,5,2],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0,0]]@END_MENU_TOKEN@*/.click()
        }
        
        let namaguruOutlinesQuery = mainwindowWindow/*@START_MENU_TOKEN@*/.outlines.containing(.tableColumn, identifier:"NamaGuru")/*[[".splitGroups",".scrollViews",".outlines.containing(.tableColumn, identifier:\"Struktural\")",".outlines.containing(.tableColumn, identifier:\"TahunAktif\")",".outlines.containing(.tableColumn, identifier:\"AlamatGuru\")",".outlines.containing(.tableColumn, identifier:\"NamaGuru\")"],[[[-1,5],[-1,4],[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,5],[-1,4],[-1,3],[-1,2],[-1,1,2]],[[-1,5],[-1,4],[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/
        namaguruOutlinesQuery.children(matching: .outlineRow).element(boundBy: 4).cells.containing(.disclosureTriangle, identifier:"NSOutlineViewDisclosureButtonKey").children(matching: .textField).element.rightClick()
        mainwindowWindow/*@START_MENU_TOKEN@*/.outlines.menuItems["edit"]/*[[".splitGroups",".scrollViews.outlines",".menus",".menuItems[\"Edit (2 guru dan 1 mapel)\"]",".menuItems[\"edit\"]",".outlines"],[[[-1,5,2],[-1,1,2],[-1,0,1]],[[-1,5,2],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0,0]]@END_MENU_TOKEN@*/.click()
        
        let cell = mainwindowWindow/*@START_MENU_TOKEN@*/.outlines.containing(.tableColumn, identifier:"DaftarColumn")/*[[".splitGroups",".scrollViews.outlines.containing(.tableColumn, identifier:\"DaftarColumn\")",".outlines.containing(.tableColumn, identifier:\"DaftarColumn\")"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.children(matching: .outlineRow).element(boundBy: 0).children(matching: .cell).element
        cell.typeText("\t\t\tTes")
        
        let sheetsQuery = mainwindowWindow.sheets
        let simpanButton = sheetsQuery/*@START_MENU_TOKEN@*/.buttons["simpan"]/*[[".buttons[\"Simpan\"]",".buttons[\"simpan\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        simpanButton.click()
        
        let menuBarsQuery2 = app.menuBars
        let editMenuBarItem = menuBarsQuery2/*@START_MENU_TOKEN@*/.menuBarItems["edit"]/*[[".menuBarItems[\"Edit\"]",".menuBarItems[\"edit\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        editMenuBarItem.click()
        
        let menuBarsQuery = menuBarsQuery2
        let undoMenuItem = menuBarsQuery/*@START_MENU_TOKEN@*/.menuItems["undo"]/*[[".menuBarItems[\"Edit\"]",".menus",".menuItems[\"Urung Mengetik\"]",".menuItems[\"undo\"]",".menuBarItems[\"edit\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,4,1],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/
        undoMenuItem.click()
        editMenuBarItem.click()
        
        let redoMenuItem = menuBarsQuery/*@START_MENU_TOKEN@*/.menuItems["redo"]/*[[".menuBarItems[\"Edit\"]",".menus",".menuItems[\"Ulang\"]",".menuItems[\"redo\"]",".menuBarItems[\"edit\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,4,1],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/
        redoMenuItem.click()
        editMenuBarItem.click()
        undoMenuItem.click()
        editMenuBarItem.click()
        redoMenuItem.click()
        mainwindowWindow/*@START_MENU_TOKEN@*/.outlines.containing(.tableColumn, identifier:"NamaGuru").children(matching: .outlineRow).element(boundBy: 6).staticTexts["Tes"]/*[[".splitGroups",".scrollViews",".outlines.containing(.tableColumn, identifier:\"Struktural\").children(matching: .outlineRow).element(boundBy: 6)",".cells.staticTexts[\"Tes\"]",".staticTexts[\"Tes\"]",".outlines.containing(.tableColumn, identifier:\"TahunAktif\").children(matching: .outlineRow).element(boundBy: 6)",".outlines.containing(.tableColumn, identifier:\"AlamatGuru\").children(matching: .outlineRow).element(boundBy: 6)",".outlines.containing(.tableColumn, identifier:\"NamaGuru\").children(matching: .outlineRow).element(boundBy: 6)"],[[[-1,7,3],[-1,6,3],[-1,5,3],[-1,2,3],[-1,1,2],[-1,0,1]],[[-1,7,3],[-1,6,3],[-1,5,3],[-1,2,3],[-1,1,2]],[[-1,7,3],[-1,6,3],[-1,5,3],[-1,2,3]],[[-1,4],[-1,3]]],[0,0]]@END_MENU_TOKEN@*/.click()
        namaguruOutlinesQuery.children(matching: .outlineRow).element(boundBy: 6).children(matching: .cell).element(boundBy: 0).children(matching: .textField).element.rightClick()
        mainwindowWindow/*@START_MENU_TOKEN@*/.outlines.menuItems["edit"]/*[[".splitGroups",".scrollViews.outlines",".menus",".menuItems[\"Edit Tes\"]",".menuItems[\"edit\"]",".outlines"],[[[-1,5,2],[-1,1,2],[-1,0,1]],[[-1,5,2],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0,0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery.textFields["ketik mata pelajaran"].doubleClick()
        cell.typeText("s\r")
        cell.typeText("\t")
        simpanButton.click()
        editMenuBarItem.click()
        
        let undoMenuItem2 = menuBarsQuery/*@START_MENU_TOKEN@*/.menuItems["undo"]/*[[".menuBarItems[\"Edit\"]",".menus",".menuItems[\"Urung\"]",".menuItems[\"undo\"]",".menuBarItems[\"edit\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,4,1],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/
        undoMenuItem2.click()
        editMenuBarItem.click()
        undoMenuItem2.click()
        editMenuBarItem.click()
        redoMenuItem.click()
        editMenuBarItem.click()
        redoMenuItem.click()
        mainwindowWindow/*@START_MENU_TOKEN@*/.outlines.staticTexts["Shorrof"]/*[[".splitGroups",".scrollViews.outlines",".outlineRows",".cells.staticTexts[\"Shorrof\"]",".staticTexts[\"Shorrof\"]",".outlines"],[[[-1,5,2],[-1,1,2],[-1,0,1]],[[-1,5,2],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0,0]]@END_MENU_TOKEN@*/.click()
        mainwindowWindow/*@START_MENU_TOKEN@*/.outlines.staticTexts["Nahwu"]/*[[".splitGroups",".scrollViews.outlines",".outlineRows",".cells.staticTexts[\"Nahwu\"]",".staticTexts[\"Nahwu\"]",".outlines"],[[[-1,5,2],[-1,1,2],[-1,0,1]],[[-1,5,2],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0,0]]@END_MENU_TOKEN@*/.click()
        mainwindowWindow.toolbars.buttons["Hapus"].click()
        app.dialogs["peringatan"].buttons["Hapus"].click()
        editMenuBarItem.click()
        undoMenuItem2.click()
        editMenuBarItem.click()
        undoMenuItem2.click()
        editMenuBarItem.click()
        redoMenuItem.click()
        editMenuBarItem.click()
        redoMenuItem.click()
        mainwindowWindow/*@START_MENU_TOKEN@*/.toolbars.containing(.button, identifier:"Simpan").element/*[[".toolbars.containing(.button, identifier:\"Statistik\").element",".toolbars.containing(.button, identifier:\"Jumlah\").element",".toolbars.containing(.button, identifier:\"Nilai\").element",".toolbars.containing(.button, identifier:\"Hapus\").element",".toolbars.containing(.button, identifier:\"Edit\").element",".toolbars.containing(.button, identifier:\"Catat\").element",".toolbars.containing(.button, identifier:\"Sidebar\").element",".toolbars.containing(.button, identifier:\"Simpan\").element"],[[[-1,7],[-1,6],[-1,5],[-1,4],[-1,3],[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        editMenuBarItem.click()
        undoMenuItem2.click()
        editMenuBarItem.click()
        undoMenuItem2.click()
        editMenuBarItem.click()
        undoMenuItem2.click()
        editMenuBarItem.click()
        redoMenuItem.click()
        editMenuBarItem.click()
        undoMenuItem2.click()
        editMenuBarItem.click()
        editMenuBarItem.click()
        mainwindowWindow/*@START_MENU_TOKEN@*/.outlines.staticTexts["Muhammad Mubasyir"]/*[[".splitGroups",".scrollViews.outlines",".outlineRows",".cells.staticTexts[\"Muhammad Mubasyir\"]",".staticTexts[\"Muhammad Mubasyir\"]",".outlines"],[[[-1,5,2],[-1,1,2],[-1,0,1]],[[-1,5,2],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0,0]]@END_MENU_TOKEN@*/.click()
        
    }
    
    func testRowSelection() {
        XCUIApplication()/*@START_MENU_TOKEN@*/.windows["MainWindow"]/*[[".windows[\"Data Guru\"]",".windows[\"MainWindow\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.toolbars.buttons["Catat"].click()
        
        _ = XCUIApplication()/*@START_MENU_TOKEN@*/.windows["MainWindow"].toolbars.menuButtons["Tindakan"]/*[[".windows[\"Data Guru\"].toolbars",".groups.menuButtons[\"Tindakan\"]",".menuButtons[\"Tindakan\"]",".windows[\"MainWindow\"].toolbars"],[[[-1,3,1],[-1,0,1]],[[-1,2],[-1,1]]],[0,0]]@END_MENU_TOKEN@*/
        
        let menuBarsQuery = XCUIApplication().menuBars
        // let editMenuBarItem = menuBarsQuery/*@START_MENU_TOKEN@*/.menuBarItems["edit"]/*[[".menuBarItems[\"Edit\"]",".menuBarItems[\"edit\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        menuBarsQuery/*@START_MENU_TOKEN@*/.menuItems["undo"]/*[[".menuBarItems[\"Edit\"]",".menus",".menuItems[\"Urung\"]",".menuItems[\"undo\"]",".menuBarItems[\"edit\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,4,1],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()
        menuBarsQuery/*@START_MENU_TOKEN@*/.menuItems["redo"]/*[[".menuBarItems[\"Edit\"]",".menus",".menuItems[\"Ulang\"]",".menuItems[\"redo\"]",".menuBarItems[\"edit\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,4,1],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()
        

    }
    
    func testEditRecentAdded() {
        
        let mainwindowWindow = app/*@START_MENU_TOKEN@*/.windows["MainWindow"]/*[[".windows[\"Data Guru\"]",".windows[\"MainWindow\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        let catatButton = mainwindowWindow.toolbars.buttons["Catat"]
        catatButton.click()
        catatButton.click()
        
        let cell = mainwindowWindow/*@START_MENU_TOKEN@*/.outlines.containing(.tableColumn, identifier:"DaftarColumn")/*[[".splitGroups",".scrollViews.outlines.containing(.tableColumn, identifier:\"DaftarColumn\")",".outlines.containing(.tableColumn, identifier:\"DaftarColumn\")"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.children(matching: .outlineRow).element(boundBy: 0).children(matching: .cell).element
        cell.typeText("Tes\r")
        mainwindowWindow.outlines.containing(.tableColumn, identifier:"NamaGuru").children(matching: .outlineRow).element(boundBy: 5).children(matching: .cell).element(boundBy: 1).children(matching: .staticText).element.click()
        cell.typeText("vv\r")
        
        let app2 = app
        let app = app2
        let menuBarsQuery = app!.menuBars
        let editMenuBarItem = menuBarsQuery/*@START_MENU_TOKEN@*/.menuBarItems["edit"]/*[[".menuBarItems[\"Edit\"]",".menuBarItems[\"edit\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        editMenuBarItem.click()
        
        let menuBarsQuery2 = app2!.menuBars
        let undoMenuItem = menuBarsQuery2/*@START_MENU_TOKEN@*/.menuItems["undo"]/*[[".menuBarItems[\"Edit\"]",".menus",".menuItems[\"Urung Mengetik\"]",".menuItems[\"undo\"]",".menuBarItems[\"edit\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,4,1],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/
        undoMenuItem.click()
        editMenuBarItem.click()
        undoMenuItem.click()
        editMenuBarItem.click()
        
        let redoMenuItem = menuBarsQuery2/*@START_MENU_TOKEN@*/.menuItems["redo"]/*[[".menuBarItems[\"Edit\"]",".menus",".menuItems[\"Ulang\"]",".menuItems[\"redo\"]",".menuBarItems[\"edit\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,4,1],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/
        redoMenuItem.click()
        editMenuBarItem.click()
        redoMenuItem.click()
        editMenuBarItem.click()
        undoMenuItem.click()
        editMenuBarItem.click()
        undoMenuItem.click()
        menuBarsQuery/*@START_MENU_TOKEN@*/.menuBarItems["app"]/*[[".menuBarItems[\"Data SDI\"]",".menuBarItems[\"app\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        menuBarsQuery2/*@START_MENU_TOKEN@*/.menuItems["Keluar Data SDI"]/*[[".menuBarItems[\"Data SDI\"]",".menus.menuItems[\"Keluar Data SDI\"]",".menuItems[\"Keluar Data SDI\"]",".menuBarItems[\"app\"]"],[[[-1,2],[-1,1],[-1,3,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        cell.typeText("\r")
        
    }
    
    func testEditUndoDeleteRedoSequence() {
        let mainWindow = app.windows["MainWindow"]

        // Tambah dua baris data
        let catatButton = mainWindow.toolbars.buttons["Catat"]
        catatButton.click()

        // Ambil outlineView dari GuruViewController
        let guruOutline = mainWindow.outlines.matching(identifier: "GuruViewController").firstMatch
        XCTAssertTrue(guruOutline.waitForExistence(timeout: 2), "Guru outline view tidak ditemukan")

        // Hitung jumlah baris dan pilih satu secara acak
        let rowCount = guruOutline.children(matching: .outlineRow).count
        XCTAssertTrue(rowCount > 0, "Tidak ada baris di outline view")

        let randomIndex = Int.random(in: 0..<rowCount)
        let randomRowCell = guruOutline.children(matching: .outlineRow)
            .element(boundBy: randomIndex)
            .children(matching: .cell)
            .element(boundBy: 0)

        randomRowCell.click()
        randomRowCell.typeText("EditPertama\r")

        // Undo edit (Cmd+Z)
        mainWindow.typeKey("z", modifierFlags: [.command])

        // Delete baris (tekan tombol delete)
        randomRowCell.click()
        randomRowCell.typeKey(.delete, modifierFlags: [])

        // Undo delete (Cmd+Z)
        mainWindow.typeKey("z", modifierFlags: [.command])

        // Redo delete (Cmd+Shift+Z)
        mainWindow.typeKey("Z", modifierFlags: [.command, .shift])

        // Undo redo delete (Cmd+Z)
        mainWindow.typeKey("z", modifierFlags: [.command])

        // Edit ulang
        randomRowCell.click()
        randomRowCell.typeText("EditLagi\r")

        // Undo edit (Cmd+Z)
        mainWindow.typeKey("z", modifierFlags: [.command])

        // Redo edit (Cmd+Shift+Z)
        mainWindow.typeKey("Z", modifierFlags: [.command, .shift])

        // Redo lagi (Cmd+Shift+Z)
        mainWindow.typeKey("Z", modifierFlags: [.command, .shift])
    }
    
    func testAll() {
        XCUIApplication()/*@START_MENU_TOKEN@*/.windows["MainWindow"].outlines.staticTexts["Transaksi"]/*[[".windows[\"Data Guru\"]",".splitGroups",".scrollViews.outlines",".outlineRows",".cells.staticTexts[\"Transaksi\"]",".staticTexts[\"Transaksi\"]",".outlines",".windows[\"MainWindow\"]"],[[[-1,7,1],[-1,0,1]],[[-1,6,3],[-1,2,3],[-1,1,2]],[[-1,6,3],[-1,2,3]],[[-1,5],[-1,4],[-1,3,4]],[[-1,5],[-1,4]]],[0,0,0]]@END_MENU_TOKEN@*/.click()
        XCUIApplication()/*@START_MENU_TOKEN@*/.windows["MainWindow"].collectionViews/*[[".windows[\"Transaksi\"]",".splitGroups",".scrollViews.collectionViews",".collectionViews",".windows[\"MainWindow\"]"],[[[-1,4,1],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0,0]]@END_MENU_TOKEN@*/.otherElements.children(matching: .group).element(boundBy: 1).staticTexts["Pemasukan"].click()
        XCUIApplication()/*@START_MENU_TOKEN@*/.windows["MainWindow"].collectionViews/*[[".windows[\"Transaksi\"]",".splitGroups",".scrollViews.collectionViews",".collectionViews",".windows[\"MainWindow\"]"],[[[-1,4,1],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0,0]]@END_MENU_TOKEN@*/.otherElements.children(matching: .group).element(boundBy: 0).click()
    }

}
