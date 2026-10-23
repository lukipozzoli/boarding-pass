import SwiftUI
import Observation

@MainActor @Observable
final class FlightStore {
    private(set) var flights: [Flight] = []
    private(set) var catalog: [Flight]
    var errorMessage: String?
    private(set) var usesServer = false
    private(set) var serverAddress = "http://localhost:8765"
    private let repository: any FlightRepository
    private var storageAvailable = true

    init(repository: any FlightRepository) {
        self.repository = repository
        catalog = DemoFlightCatalog.flights()
        if !ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            usesServer = UserDefaults.standard.bool(forKey: "usesFlightServer")
            serverAddress = UserDefaults.standard.string(forKey: "flightServerAddress") ?? serverAddress
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") && ProcessInfo.processInfo.arguments.contains("--test-flight-server") {
            usesServer = true
        }
        do {
            if let savedFlights = try repository.loadFlights() {
                flights = savedFlights
            } else {
                flights = catalog.filter { $0.id == "demo-brc" || $0.countsTowardHistory }
                try repository.saveFlights(flights)
            }
        } catch {
            // No sobrescribir un archivo que no se pudo leer.
            storageAvailable = false
            errorMessage = "No se pudieron cargar sus vuelos. \(error.localizedDescription)"
        }
    }

    var upcoming: [Flight] { flights.filter { !$0.isFriend && ![.landed, .arrived].contains($0.status) }.sorted { $0.departure < $1.departure } }
    var history: [Flight] { flights.filter(\.countsTowardHistory).sorted { $0.departure > $1.departure } }
    var friends: [Flight] { flights.filter(\.isFriend) }
    var statistics: FlightStatistics { FlightStatistics(flights: flights) }

    func contains(_ flight: Flight) -> Bool { flights.contains { $0.id == flight.id } }
    func configureServer(enabled: Bool, address: String) throws {
        if enabled { _ = try RemoteFlightService(serverAddress: address) }
        usesServer = enabled
        serverAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(enabled, forKey: "usesFlightServer")
        UserDefaults.standard.set(serverAddress, forKey: "flightServerAddress")
    }

    func searchRemote(number: String, date: Date) async throws -> FlightSearchResult {
        try await RemoteFlightService(serverAddress: serverAddress).search(number: number, on: date)
    }

    func refreshFlight(id: String) async throws {
        guard let original = flight(id: id), !original.isDemo else { return }
        let updated = try await RemoteFlightService(serverAddress: serverAddress).refresh(original)
        try Task.checkCancellation()
        // Tomar los datos personales actuales por si cambiaron durante la consulta.
        guard let current = flight(id: id) else { return }
        commit(flights.map { $0.id == id ? updated.preservingTravelDetails(from: current) : $0 })
    }
    func flight(id: String) -> Flight? { flights.first { $0.id == id } }
    func add(_ flight: Flight, forFriend: Bool = false) {
        guard !contains(flight) else { return }
        var savedFlight = flight
        savedFlight.isFriend = forFriend
        commit(flights + [savedFlight])
    }
    func remove(id: String) { commit(flights.filter { $0.id != id }) }
    func updateTravelDetails(id: String, bookingCode: String, seat: String) {
        let updatedFlights = flights.map { flight in
            guard flight.id == id else { return flight }
            var updated = flight
            updated.bookingCode = bookingCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            updated.seat = seat.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return updated
        }
        commit(updatedFlights)
    }

    // Actualizar la pantalla solo después de guardar correctamente.
    private func commit(_ updatedFlights: [Flight]) {
        guard storageAvailable else {
            errorMessage = "El archivo local no se pudo leer. Los cambios están deshabilitados para conservar sus datos."
            return
        }
        do {
            try repository.saveFlights(updatedFlights)
            flights = updatedFlights
        } catch { errorMessage = "No se pudieron guardar los cambios. \(error.localizedDescription)" }
    }
}
