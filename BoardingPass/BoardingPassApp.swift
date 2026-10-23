import SwiftUI

@main
struct BoardingPassApp: App {
    @State private var store: FlightStore

    init() {
        let directory = URL.applicationSupportDirectory.appending(path: "BoardingPass")
        let arguments = ProcessInfo.processInfo.arguments
        let filename = arguments.contains("--ui-testing") ? "ui-test-flights.json" : "flights.json"
        let fileURL = directory.appending(path: filename)
        // Las pruebas usan un archivo separado de los viajes del usuario.
        if arguments.contains("--ui-testing") && arguments.contains("--reset-demo-storage") {
            try? FileManager.default.removeItem(at: fileURL)
        }
        _store = State(initialValue: FlightStore(repository: JSONFlightRepository(fileURL: fileURL)))
    }

    var body: some Scene {
        WindowGroup {
            AppView().environment(store).tint(Brand.blue)
        }
    }
}
