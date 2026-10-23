import Foundation

protocol FlightRepository {
    func loadFlights() throws -> [Flight]?
    func saveFlights(_ flights: [Flight]) throws
}

// La escritura atómica evita dejar un archivo parcial si la app se interrumpe.
struct JSONFlightRepository: FlightRepository {
    let fileURL: URL

    func loadFlights() throws -> [Flight]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode([Flight].self, from: Data(contentsOf: fileURL))
    }

    func saveFlights(_ flights: [Flight]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(flights).write(to: fileURL, options: .atomic)
    }
}
