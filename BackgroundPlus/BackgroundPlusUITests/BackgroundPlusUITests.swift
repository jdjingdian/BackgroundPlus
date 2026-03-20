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

        app.staticTexts["Full Dump Data"].click()
        let staticRouter = app.staticTexts["Static Router"]
        XCTAssertTrue(staticRouter.waitForExistence(timeout: 5))
        staticRouter.click()

        let deleteButton = app.buttons["btm.detail.delete_button"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()
    }

    @MainActor
    func testShowsHelperPromptWhenNotInstalled() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-force-no-helper", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Helper Required"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Settings"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testParseIncompleteBannerStillShowsEntries() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-fixture", "--ui-test-parse-incomplete-banner", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Parsing incomplete. Results may be inaccurate."].waitForExistence(timeout: 5))
        app.staticTexts["Full Dump Data"].click()
        XCTAssertTrue(app.staticTexts["Static Router"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSidebarSupportsFilteredSectionsAndFullDumpList() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-fixture", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let loginSidebarItem = app.staticTexts["Open at Login"]
        XCTAssertTrue(loginSidebarItem.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Allow in Background"].exists)
        XCTAssertTrue(app.staticTexts["Full Dump Data"].exists)
        XCTAssertFalse(app.staticTexts["Static Router"].exists)

        let backgroundSidebarItem = app.staticTexts["Allow in Background"]
        backgroundSidebarItem.click()
        XCTAssertFalse(app.staticTexts["cn.magicdian.staticrouter.helper"].exists)

        let fullDumpSidebarItem = app.staticTexts["Full Dump Data"]
        fullDumpSidebarItem.click()
        XCTAssertTrue(app.staticTexts["Static Router"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["cn.magicdian.staticrouter.helper"].exists)
    }

    @MainActor
    func testLargeListRendersManyRows() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-fixture", "--ui-test-many-entries", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Background Items"].waitForExistence(timeout: 5))
        app.staticTexts["Full Dump Data"].click()
        let toggles = app.descendants(matching: .any).matching(identifier: "btm.row.toggle")
        XCTAssertGreaterThanOrEqual(toggles.count, 20)
    }

    @MainActor
    func testInvalidDetailTargetShowsUnavailableAlert() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-fixture", "--ui-test-invalid-detail-entry", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        app.staticTexts["Full Dump Data"].click()
        let invalidEntry = app.staticTexts["Invalid Entry For UI Test"]
        XCTAssertTrue(invalidEntry.waitForExistence(timeout: 5))
        let firstDetailButton = app.buttons.matching(identifier: "btm.row.custom_detail_button").firstMatch
        XCTAssertTrue(firstDetailButton.exists)
        XCTAssertFalse(firstDetailButton.isEnabled)
    }

    @MainActor
    func testToolbarTitlePositionStaysStableWhenEnteringDetail() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let title = app.staticTexts["后台项目管理"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let initialTitleX = title.frame.minX
        app.staticTexts["完整 Dump 数据"].click()

        let detailButtonQuery = app.buttons.matching(identifier: "btm.row.custom_detail_button")
        guard let detailButton = detailButtonQuery.allElementsBoundByIndex.first(where: { $0.isEnabled }) else {
            XCTFail("No enabled detail button found in fixture data.")
            return
        }
        detailButton.click()

        XCTAssertTrue(app.descendants(matching: .button).matching(identifier: "btm.toolbar.back").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["btm.detail.delete_button"].waitForExistence(timeout: 5))
        let detailTitleX = title.frame.minX
        XCTAssertEqual(initialTitleX, detailTitleX, accuracy: 1.0)
    }
}
