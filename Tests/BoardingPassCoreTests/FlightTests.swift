import Foundation
import Testing
@testable import BoardingPassCore

@Test func repositoryPreservesTravelDetailsAndEmptyLists() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = JSONFlightRepository(fileURL: directory.appendingPathComponent("flights.json"))
    #expect(try repository.loadFlights() == nil)
    var flight = DemoFlightCatalog.flights()[0]
    flight.bookingCode = "ABC123"
    flight.seat = "12A"
    try repository.saveFlights([flight])
    #expect(try repository.loadFlights() == [flight])
    try repository.saveFlights([])
    #expect(try repository.loadFlights() == [])
}

@Test func corruptStorageIsReportedWithoutOverwriting() throws {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let bytes = Data("invalid".utf8)
    try bytes.write(to: fileURL)
    let repository = JSONFlightRepository(fileURL: fileURL)
    #expect(throws: (any Error).self) { try repository.loadFlights() }
    #expect(try Data(contentsOf: fileURL) == bytes)
}

@Test func friendsAndCancelledFlightsDoNotCountTowardPassport() {
    let flights = DemoFlightCatalog.flights()
    var friend = flights.first { $0.status == .landed }!
    friend.isFriend = true
    var cancelled = friend
    cancelled.isFriend = false
    cancelled.status = .cancelled
    let statistics = FlightStatistics(flights: flights + [friend, cancelled])
    #expect(statistics.count == 3)
    #expect(statistics.distance == 3595)
    #expect(statistics.airports == 4)
    #expect(statistics.airlines == 2)
}

@Test func estimatesDoNotReplaceScheduledTimes() {
    let delayed = DemoFlightCatalog.flights().first { $0.status == .delayed }!
    #expect(delayed.delayMinutes == 35)
    #expect(delayed.departure != delayed.scheduledDeparture)
    #expect(delayed.durationMinutes == 115)
}

@Test func timeFormattingUsesAirportZoneInsteadOfDeviceZone() {
    let flight = DemoFlightCatalog.flights()[0]
    let airport = Airport(code: "TEST", city: "UTC", name: "UTC", latitude: 0, longitude: 0, timeZoneIdentifier: "UTC")
    #expect(flight.localTime(Date(timeIntervalSince1970: 0), at: airport) == "00:00")
    #expect(flight.localTime(Date(timeIntervalSince1970: 0), at: flight.origin) == "21:00")
}
