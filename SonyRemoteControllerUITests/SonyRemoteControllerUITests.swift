//
//  SonyRemoteControllerUITests.swift
//  SonyRemoteControllerUITests
//
//  Created by Perry on 2026/4/30.
//

import XCTest

final class SonyRemoteControllerUITests: XCTestCase {

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
    func testExample() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SONY_REMOTE_USE_MOCKS"] = "1"
        app.launch()

        XCTAssertTrue(app.buttons["connectBraviaButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["tvSettingsButton"].exists)
    }

    @MainActor
    func testSettingsFormCanConnectAndSaveWithMocks() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SONY_REMOTE_USE_MOCKS"] = "1"
        app.launch()

        app.buttons["connectBraviaButton"].tap()
        XCTAssertTrue(app.textFields["ipAddressField"].waitForExistence(timeout: 3))

        app.textFields["tvNameField"].tap()
        app.textFields["tvNameField"].typeText("Living Room")
        app.textFields["ipAddressField"].tap()
        app.textFields["ipAddressField"].typeText("192.168.1.2")
        app.secureTextFields["pskField"].tap()
        app.secureTextFields["pskField"].typeText("1234")

        app.buttons["testConnectionButton"].tap()
        XCTAssertTrue(app.staticTexts["Connection succeeded."].waitForExistence(timeout: 3))
        app.buttons["saveDeviceButton"].tap()

        XCTAssertTrue(app.buttons["remoteCommand_Confirm"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["remoteCommand_Confirm"].isEnabled)
    }

    @MainActor
    func testMockConnectionFailureShowsLayeredError() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SONY_REMOTE_USE_MOCKS"] = "1"
        app.launchEnvironment["SONY_REMOTE_MOCK_CONNECTION_FAILURE"] = "1"
        app.launch()

        app.buttons["connectBraviaButton"].tap()
        XCTAssertTrue(app.textFields["ipAddressField"].waitForExistence(timeout: 3))

        app.textFields["ipAddressField"].tap()
        app.textFields["ipAddressField"].typeText("192.168.1.2")
        app.secureTextFields["pskField"].tap()
        app.secureTextFields["pskField"].typeText("bad")

        app.buttons["testConnectionButton"].tap()

        XCTAssertTrue(app.staticTexts["Authentication Failed"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
