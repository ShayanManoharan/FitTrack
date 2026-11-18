import XCTest

final class IntegratedJourneyTests: XCTestCase {
    @MainActor
    func testAuthenticatedWorkoutJourney() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["FITTRACK_TEST_EMAIL"], let password = environment["FITTRACK_TEST_PASSWORD"] else {
            throw XCTSkip("Provide disposable Firebase test credentials to exercise the live journey.")
        }
        guard email.hasPrefix("fittrack-integration-"), email.hasSuffix("@example.com") else {
            throw XCTSkip("Only disposable integration accounts may run this destructive CRUD journey.")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        // Finish the previous launch configuration before rotating and relaunching.
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        if app.buttons["mainTab3"].waitForExistence(timeout: 5) {
            app.buttons["mainTab3"].tap()
            tap(app.buttons["profile.signout"], in: app)
            tap(app.buttons["confirmSignOut"], in: app)
        }
        try login(app, email: email, password: password)

        app.buttons["findGyms"].tap()
        app.buttons["useGymLocation"].tap()
        let rpac = app.buttons["gym-rpac"]
        let distance = NSPredicate(format: "label CONTAINS %@", "<0.1 mi")
        expectation(for: distance, evaluatedWith: rpac)
        waitForExpectations(timeout: 30)
        let gyms = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "gym-")).allElementsBoundByIndex.sorted { $0.frame.minY < $1.frame.minY }
        XCTAssertEqual(gyms.first?.identifier, "gym-rpac")
        app.buttons["gym-north-recreation"].tap()
        XCTAssertTrue(app.staticTexts["North Recreation Center"].firstMatch.waitForExistence(timeout: 5))

        let name = "Integration " + String(UUID().uuidString.prefix(6))
        let revised = name + " Revised"
        let renamed = name + " Cloud"
        tap(app.buttons["createWorkoutPlan"], in: app)
        replace(app.textFields["planName"], with: name)
        app.textFields["planName"].typeText("\n")
        app.buttons["Bench Press"].tap()
        app.buttons["Seated Cable Row"].tap()
        tap(app.buttons["saveWorkoutPlan"], in: app)
        tap(app.buttons["View all →"], in: app)
        planButton(name, in: app).tap()
        app.buttons["EDIT PLAN"].tap()
        replace(app.textFields["planName"], with: revised)
        app.textFields["planName"].typeText("\n")
        tap(app.buttons["saveWorkoutPlan"], in: app)
        XCTAssertTrue(app.staticTexts[revised].firstMatch.waitForExistence(timeout: 5))
        app.buttons["BackButton"].tap()
        app.buttons["Close"].tap()

        app.buttons["mainTab2"].tap()
        app.buttons["scheduleWorkout"].tap()
        planButton(revised, in: app).tap()
        tap(app.buttons["confirmScheduleWorkout"], in: app)
        app.buttons["makeRestDay"].tap()
        app.alerts.buttons["Make rest day"].tap()
        XCTAssertTrue(app.buttons["Remove rest day"].waitForExistence(timeout: 5))
        app.buttons["Remove rest day"].tap()
        app.alerts.buttons["Remove"].tap()
        app.buttons["scheduleWorkout"].tap()
        planButton(revised, in: app).tap()
        tap(app.buttons["confirmScheduleWorkout"], in: app)

        app.buttons["mainTab0"].tap()
        tap(app.buttons["startWorkout"], in: app)
        XCTAssertTrue(app.staticTexts["currentExercise"].waitForExistence(timeout: 5))
        app.buttons["rerouteExercise"].tap()
        app.staticTexts["Dumbbell Bench Press"].firstMatch.tap()
        XCTAssertEqual(app.staticTexts["currentExercise"].label, "Dumbbell Bench Press")
        app.buttons["editSetTargets"].tap()
        replace(app.textFields["Reps"].firstMatch, with: "11")
        tap(app.buttons["SAVE CHANGES"], in: app)
        app.buttons["set-0"].tap()
        app.buttons["set-1"].tap()
        app.buttons["set-2"].tap()
        tap(app.buttons["completeExercise"], in: app)
        tap(app.buttons["skipExercise"], in: app)
        app.alerts.buttons["Skip exercise"].tap()
        tap(app.buttons["saveFinishedWorkout"], in: app)
        XCTAssertTrue(app.staticTexts["Workout saved."].waitForExistence(timeout: 30))
        tap(app.buttons["workoutBackHome"], in: app)

        app.buttons["mainTab2"].tap()
        XCTAssertTrue(app.staticTexts[revised].firstMatch.waitForExistence(timeout: 20))
        app.buttons["mainTab0"].tap()
        tap(app.buttons["openSavedWorkouts"], in: app)
        XCTAssertTrue(app.staticTexts[revised].firstMatch.waitForExistence(timeout: 20))
        app.buttons["Rename workout"].firstMatch.tap()
        replace(app.textFields["Workout name"], with: renamed)
        app.buttons["Save changes"].tap()
        XCTAssertTrue(app.staticTexts[renamed].firstMatch.waitForExistence(timeout: 20))
        app.buttons["Close"].tap()
        app.buttons["mainTab2"].tap()
        XCTAssertTrue(app.staticTexts[renamed].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts[revised].exists)
        app.buttons["mainTab0"].tap()
        tap(app.buttons["openSavedWorkouts"], in: app)
        app.buttons["Delete workout"].firstMatch.tap()
        app.alerts.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts[renamed].firstMatch.waitForNonExistence(timeout: 20))
        app.buttons["Close"].tap()
        app.buttons["mainTab2"].tap()
        XCTAssertFalse(app.staticTexts[renamed].exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["mainTab0"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["North Recreation Center"].firstMatch.exists)
        tap(app.buttons["View all →"], in: app)
        planButton(revised, in: app).tap()
        app.buttons["EDIT PLAN"].tap()
        tap(app.buttons["Delete workout plan"], in: app)
        app.alerts.buttons["Delete plan"].tap()
        XCTAssertTrue(planButton(revised, in: app).waitForNonExistence(timeout: 10))
        app.buttons["Close"].tap()
        app.buttons["mainTab3"].tap()
        tap(app.buttons["profile.signout"], in: app)
        tap(app.buttons["confirmSignOut"], in: app)
        try login(app, email: email, password: password)
        XCTAssertTrue(app.staticTexts["North Recreation Center"].firstMatch.exists)
        app.buttons["mainTab2"].tap()
        XCTAssertFalse(app.staticTexts[renamed].exists)
        app.buttons["mainTab3"].tap()
        tap(app.buttons["profile.signout"], in: app)
        tap(app.buttons["confirmSignOut"], in: app)
        XCTAssertTrue(app.textFields["loginEmail"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func login(_ app: XCUIApplication, email: String, password: String) throws {
        XCTAssertTrue(app.textFields["loginEmail"].waitForExistence(timeout: 10))
        replace(app.textFields["loginEmail"], with: email)
        app.textFields["loginEmail"].typeText("\n")
        app.secureTextFields["loginPassword"].typeText(password + "\n")
        let opened = app.buttons["mainTab0"].waitForExistence(timeout: 30)
        let error = app.staticTexts["loginError"]
        XCTAssertTrue(opened, "Authenticated Home did not open; error: \(error.exists ? error.label : "none"); Home visible: \(app.staticTexts["Current gym"].exists)")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["mainTab0"].waitForExistence(timeout: 20), "Firebase session did not survive relaunch")
    }

    @MainActor
    private func planButton(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    @MainActor
    private func replace(_ field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let keyboard = XCUIApplication().keyboards.firstMatch
        if !keyboard.waitForExistence(timeout: 3) {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let current = field.value as? String ?? ""
        // Placeholder text is not editable content.
        let content = current == field.placeholderValue ? "" : current
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: content.count) + text)
        XCTAssertEqual(field.value as? String, text, "The text field did not retain the exact entered value")
    }

    @MainActor
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        for _ in 0..<4 {
            let identifier = element.identifier.isEmpty ? element.label : element.identifier
            let scroll = app.scrollViews.containing(.any, identifier: identifier).firstMatch
            let visible = scroll.exists ? scroll.frame.intersection(app.frame) : app.frame
            let keyboard = app.keyboards.firstMatch
            let top = visible.minY + 20
            let bottom = min(visible.maxY, keyboard.exists ? keyboard.frame.minY : visible.maxY) - 20
            if element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { break }
            // Keep drag gestures inside the content, never across the software keyboard.
            // A drag starting on the keyboard enters QuickPath text instead of scrolling.
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let upper = origin.withOffset(CGVector(dx: visible.minX + 8 - app.frame.minX, dy: top - app.frame.minY))
            let lower = origin.withOffset(CGVector(dx: visible.minX + 8 - app.frame.minX, dy: bottom - app.frame.minY))
            if element.frame.midY < (top + bottom) / 2 {
                upper.press(forDuration: 0.01, thenDragTo: lower)
            } else {
                lower.press(forDuration: 0.01, thenDragTo: upper)
            }
        }
        XCTAssertTrue(element.isHittable, "The requested control could not be scrolled into view: \(app.debugDescription)")
        XCTAssertTrue(element.isEnabled)
        element.tap()
    }
}
