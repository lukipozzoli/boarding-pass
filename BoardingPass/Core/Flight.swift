import Foundation

struct Airport: Codable, Hashable, Sendable {
    let code: String
    let city: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let timeZoneIdentifier: String?
}

enum FlightStatus: String, Codable, CaseIterable, Sendable {
    case scheduled, delayed, landed, cancelled, inAir, taxiing, arrived, diverted

    var title: String {
        switch self {
        case .scheduled: "Programado"
        case .delayed: "Demorado"
        case .landed: "Aterrizó"
        case .cancelled: "Cancelado"
        case .inAir: "En vuelo"
        case .taxiing: "Rodaje"
        case .arrived: "Llegó a puerta"
        case .diverted: "Desviado"
        }
    }
}

// Horarios oficiales y estimados se conservan por separado.
struct Flight: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let number: String
    let airline: String
    let origin: Airport
    let destination: Airport
    let scheduledDeparture: Date
    let scheduledArrival: Date
    var estimatedDeparture: Date?
    var estimatedArrival: Date?
    var status: FlightStatus
    let gate: String?
    let terminal: String?
    let aircraft: String?
    let distanceKilometers: Int?
    var bookingCode = ""
    var seat = ""
    var isFriend = false
    var providerID: String? = nil
    var providerName: String? = nil
    var timeBasis: String? = nil
    var providerDisplayName: String { providerName ?? (isDemo ? "Demostración" : "FlightAware") }
    var lastUpdated: Date? = nil
    var actualDeparture: Date? = nil
    var actualArrival: Date? = nil
    var arrivalGate: String? = nil
    var arrivalTerminal: String? = nil
    var isDemo: Bool { providerID == nil }

    var departure: Date { actualDeparture ?? estimatedDeparture ?? scheduledDeparture }
    var arrival: Date { actualArrival ?? estimatedArrival ?? scheduledArrival }
    var durationMinutes: Int { max(0, Int(scheduledArrival.timeIntervalSince(scheduledDeparture) / 60)) }
    var delayMinutes: Int { max(0, Int(departure.timeIntervalSince(scheduledDeparture) / 60)) }
    var countsTowardHistory: Bool { (status == .landed || status == .arrived) && !isFriend }

    // Una actualización operativa no debe borrar los datos personales del viaje.
    func preservingTravelDetails(from savedFlight: Flight) -> Flight {
        var updated = self
        updated.bookingCode = savedFlight.bookingCode
        updated.seat = savedFlight.seat
        updated.isFriend = savedFlight.isFriend
        return updated
    }

    func localTime(_ date: Date, at airport: Airport) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        let timeZone = airport.timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
        formatter.timeZone = timeZone ?? TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date) + (timeZone == nil ? " UTC" : "")
    }
}

struct FlightStatistics {
    let flights: [Flight]
    private var completed: [Flight] { flights.filter(\.countsTowardHistory) }
    var count: Int { completed.count }
    var distance: Int { completed.compactMap(\.distanceKilometers).reduce(0, +) }
    var missingDistances: Int { completed.filter { $0.distanceKilometers == nil }.count }
    var minutes: Int { completed.reduce(0) { $0 + $1.durationMinutes } }
    var airports: Int { Set(completed.flatMap { [$0.origin.code, $0.destination.code] }).count }
    var airlines: Int { Set(completed.map(\.airline)).count }
    var delayMinutes: Int { completed.reduce(0) { $0 + $1.delayMinutes } }
}
