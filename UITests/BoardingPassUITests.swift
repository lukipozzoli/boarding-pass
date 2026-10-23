import XCTest

final class BoardingPassUITests: XCTestCase {
    @MainActor func testGatewaySearchExplicitlyLabelsFixtureResults() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let health: [String: String]
        do {
            let (data, _) = try await session.data(from: URL(string: "http://localhost:8765/health")!)
            health = try JSONDecoder().decode([String: String].self, from: data)
        } catch { throw XCTSkip("La pasarela de demostración no está disponible en localhost:8765.") }
        guard health["mode"] == "fixture" else {
            throw XCTSkip("La prueba solo se ejecuta con la pasarela en modo demostración, para evitar consultas pagas.")
        }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-demo-storage", "--test-flight-server"]
        app.launch()
        app.tabBars.buttons["Buscar"].tap()
        let searchField = app.textFields["flightSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("AR1490\n")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "AR1490")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        XCTAssertTrue(result.label.contains("DEMOSTRACIÓN"))
        app.swipeUp()
        app.buttons["Agregar a Mis vuelos"].tap()
        XCTAssertTrue(app.buttons["Ya está en su lista"].waitForExistence(timeout: 5))
    }

    func testAddEditPersistAndRemoveDemoFlight() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-demo-storage"]
        app.launch()
        XCTAssertTrue(app.buttons["Agregar vuelo"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Buscar"].tap()
        let searchField = app.textFields["flightSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("MDZ\n")
        app.swipeUp()
        let addButton = app.buttons["Agregar a Mis vuelos"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        XCTAssertTrue(app.buttons["Ya está en su lista"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Mis vuelos"].tap()
        app.buttons["Expandir vuelos"].tap()
        let addedFlight = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "AR 1410")).firstMatch
        XCTAssertTrue(addedFlight.waitForExistence(timeout: 5))
        addedFlight.tap()
        app.swipeUp()
        let bookingField = app.textFields["bookingCodeField"]
        if !bookingField.isHittable { app.swipeUp() }
        XCTAssertTrue(bookingField.waitForExistence(timeout: 5))
        bookingField.tap()
        bookingField.typeText("DEMO42")
        let seatField = app.textFields["seatField"]
        seatField.tap()
        seatField.typeText("12A")
        app.buttons["Guardar datos del viaje"].tap()
        XCTAssertTrue(app.buttons["Expandir vuelos"].exists || app.buttons["Contraer vuelos"].exists)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["Expandir vuelos"].tap()
        let persistedFlight = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "AR 1410")).firstMatch
        XCTAssertTrue(persistedFlight.waitForExistence(timeout: 5))
        persistedFlight.tap()
        app.swipeUp()
        XCTAssertEqual(app.textFields["bookingCodeField"].value as? String, "DEMO42")
        XCTAssertEqual(app.textFields["seatField"].value as? String, "12A")
        app.swipeUp()
        app.buttons["Eliminar de mi lista"].tap()
        app.buttons["Eliminar vuelo"].tap()
        let removedFlight = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "AR 1410")).firstMatch
        let removal = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: removedFlight)
        XCTAssertEqual(XCTWaiter.wait(for: [removal], timeout: 5), .completed)
        app.tabBars.buttons["Pasaporte"].tap()
        XCTAssertTrue(app.staticTexts["Vuelos anteriores"].waitForExistence(timeout: 5))
    }
}
