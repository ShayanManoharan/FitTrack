//
//  FitTrackUITestsLaunchTests.swift
//  FitTrackUITests
//
//  Created by Shayan Manoharan on 10/1/26.
//

import XCTest

final class FitTrackUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
