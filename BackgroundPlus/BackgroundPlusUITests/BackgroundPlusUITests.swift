//
//  BackgroundPlusUITests.swift
//  BackgroundPlusUITests
//
//  Created by 经典 on 2026/3/19.
//

import XCTest

final class BackgroundPlusUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testListAppearsInEnglish() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-fixture", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Background Items"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testListAppearsInChinese() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        XCTAssertTrue(app.staticTexts["后台项目管理"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDeleteSheetShowsRiskTitle() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-fixture", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()
        XCTAssertTrue(app.staticTexts["Second Confirmation"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
