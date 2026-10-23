import Foundation

// Solo decodifica campos documentados; no convierte datos ausentes en puntualidad.
struct AeroAPIResponse: Decodable {
    struct Links: Decodable { let next: String? }
    let flights: [AeroAPIFlight]
    let links: Links?
    let mode: String
    let retrieved_at: String
    let omitted_records: Int?

    func mappedFlights() -> (flights: [Flight], omitted: Int) {
        let timestamp = AeroAPIFlight.parseDate(retrieved_at)
        let mapped = flights.compactMap { $0.flight(isDemo: mode == "fixture", timestamp: timestamp, provider: mode) }
        // Una operación puede aparecer repetida por códigos comerciales.
        var identities = Set<String>()
        return (mapped.filter { identities.insert($0.id).inserted }, flights.count - mapped.count + max(0, omitted_records ?? 0))
    }
}

struct AeroAPIFlight: Decodable {
    struct AirportReference: Decodable {
        let code: String?
        let code_iata: String?
        let city: String?
        let name: String?
        let timezone: String?

        var airport: Airport? {
            guard let identifier = code_iata ?? code, !identifier.isEmpty else { return nil }
            return Airport(code: identifier, city: city ?? identifier, name: name ?? identifier, latitude: nil, longitude: nil, timeZoneIdentifier: timezone)
        }
    }

    let fa_flight_id: String
    let ident: String
    let ident_iata: String?
    let operator_iata: String?
    let origin: AirportReference?
    let destination: AirportReference?
    let scheduled_out: String?
    let scheduled_in: String?
    let estimated_out: String?
    let estimated_in: String?
    let actual_out: String?
    let actual_in: String?
    let actual_off: String?
    let actual_on: String?
    let cancelled: Bool?
    let diverted: Bool?
    let gate_origin: String?
    let gate_destination: String?
    let terminal_origin: String?
    let terminal_destination: String?
    let aircraft_type: String?
    let route_distance: Int?
    let operator_name: String?
    let normalized_status: FlightStatus?
    let time_basis: String?

    func flight(isDemo: Bool, timestamp: Date?, provider: String = "flightaware") -> Flight? {
        guard let origin = origin?.airport, let destination = destination?.airport,
              let departure = Self.parseDate(scheduled_out), let arrival = Self.parseDate(scheduled_in), arrival >= departure,
              !fa_flight_id.isEmpty else { return nil }
        let estimatedDeparture = Self.parseDate(estimated_out)
        let actualDeparture = Self.parseDate(actual_out)
        let actualArrival = Self.parseDate(actual_in)
        let status: FlightStatus
        if let normalized_status { status = normalized_status }
        else if cancelled == true { status = .cancelled }
        else if diverted == true { status = .diverted }
        else if actualArrival != nil { status = .arrived }
        else if Self.parseDate(actual_on) != nil { status = .landed }
        else if Self.parseDate(actual_off) != nil { status = .inAir }
        else if actualDeparture != nil { status = .taxiing }
        else if let estimatedDeparture, estimatedDeparture > departure { status = .delayed }
        else { status = .scheduled }
        var flight = Flight(
            id: "\(isDemo ? "server-demo" : provider):\(fa_flight_id):\(origin.code):\(destination.code)",
            number: ident_iata ?? ident, airline: operator_name ?? operator_iata ?? "Operador no informado", origin: origin, destination: destination,
            scheduledDeparture: departure, scheduledArrival: arrival,
            estimatedDeparture: estimatedDeparture, estimatedArrival: Self.parseDate(estimated_in), status: status,
            gate: gate_origin, terminal: terminal_origin, aircraft: aircraft_type,
            distanceKilometers: route_distance.flatMap { $0 >= 0 ? Int((Double($0) * 1.609344).rounded()) : nil })
        flight.providerID = isDemo ? nil : fa_flight_id
        flight.providerName = isDemo ? nil : (provider == "aviationstack" ? "Aviationstack" : "FlightAware")
        flight.timeBasis = time_basis
        flight.lastUpdated = timestamp
        flight.actualDeparture = actualDeparture
        flight.actualArrival = actualArrival
        flight.arrivalGate = gate_destination
        flight.arrivalTerminal = terminal_destination
        return flight
    }

    static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }
}
