import Foundation

// Catálogo ficticio: no consulta servicios ni representa operaciones reales.
struct DemoFlightCatalog {
    static let buenosAires = Airport(code: "AEP", city: "Buenos Aires", name: "Jorge Newbery", latitude: -34.5592, longitude: -58.4156, timeZoneIdentifier: "America/Argentina/Buenos_Aires")
    static let bariloche = Airport(code: "BRC", city: "Bariloche", name: "Teniente Luis Candelaria", latitude: -41.1512, longitude: -71.1575, timeZoneIdentifier: "America/Argentina/Buenos_Aires")
    static let salta = Airport(code: "SLA", city: "Salta", name: "Martín Miguel de Güemes", latitude: -24.856, longitude: -65.486, timeZoneIdentifier: "America/Argentina/Salta")
    static let mendoza = Airport(code: "MDZ", city: "Mendoza", name: "El Plumerillo", latitude: -32.8317, longitude: -68.7929, timeZoneIdentifier: "America/Argentina/Mendoza")

    static func flights(referenceDate: Date = .now) -> [Flight] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        let start = calendar.startOfDay(for: referenceDate)
        func make(_ id: String, _ number: String, _ airline: String, _ origin: Airport, _ destination: Airport, _ days: Int, _ hour: Int, _ duration: Int, _ distance: Int, _ status: FlightStatus = .scheduled) -> Flight {
            let departure = calendar.date(byAdding: .day, value: days, to: start)!.addingTimeInterval(Double(hour * 3600))
            return Flight(id: id, number: number, airline: airline, origin: origin, destination: destination, scheduledDeparture: departure, scheduledArrival: departure.addingTimeInterval(Double(duration * 60)), status: status, gate: "5", terminal: "A", aircraft: "Airbus A320", distanceKilometers: distance)
        }
        var delayed = make("demo-mdz", "AR 1410", "Aerolíneas Argentinas", buenosAires, mendoza, 0, 20, 115, 980, .delayed)
        delayed.estimatedDeparture = delayed.scheduledDeparture.addingTimeInterval(35 * 60)
        delayed.estimatedArrival = delayed.scheduledArrival.addingTimeInterval(35 * 60)
        return [
            make("demo-brc", "JA 3053", "JetSMART", buenosAires, bariloche, 0, 18, 145, 1335),
            make("demo-return", "AR 1663", "Aerolíneas Argentinas", bariloche, buenosAires, 3, 8, 125, 1335),
            delayed,
            make("demo-sla", "AR 1490", "Aerolíneas Argentinas", buenosAires, salta, 0, 22, 130, 1280),
            make("past-sla", "AR 1493", "Aerolíneas Argentinas", salta, buenosAires, -9, 14, 125, 1280, .landed),
            make("past-brc", "FO 5243", "Flybondi", bariloche, buenosAires, -30, 10, 125, 1335, .landed),
            make("past-mdz", "AR 1411", "Aerolíneas Argentinas", mendoza, buenosAires, -60, 16, 110, 980, .landed)
        ]
    }
}
