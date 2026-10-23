import Foundation
import Testing
@testable import BoardingPassCore

private let sampleProviderFlight = """
{
  "fa_flight_id":"ARG1490-sample", "ident":"ARG1490", "ident_iata":"AR1490", "operator_iata":"AR",
  "origin":{"code":"SABE","code_iata":"AEP","city":"Buenos Aires","name":"Jorge Newbery","timezone":"America/Argentina/Buenos_Aires"},
  "destination":{"code":"SASA","code_iata":"SLA","city":"Salta","name":"Salta","timezone":null},
  "scheduled_out":"2026-10-23T21:00:00Z", "scheduled_in":"2026-10-23T23:10:00Z",
  "estimated_out":"2026-10-23T21:20:00Z", "estimated_in":"2026-10-23T23:30:00Z",
  "actual_out":"2026-10-23T21:22:00Z", "actual_off":"2026-10-23T21:30:00Z",
  "gate_origin":"7", "gate_destination":null, "terminal_origin":"A", "aircraft_type":null, "route_distance":795
}
"""

private func responseData(mode: String = "flightaware", flightJSON: String = sampleProviderFlight, next: Bool = false) -> Data {
    Data("{\"flights\":[\(flightJSON)],\"mode\":\"\(mode)\",\"retrieved_at\":\"2026-10-23T22:00:00.123Z\",\"links\":{\"next\":\(next ? "\"next-page\"" : "null")}}".utf8)
}

@Test func providerMappingPreservesOperationalTimesAndUnknowns() throws {
    let response = try JSONDecoder().decode(AeroAPIResponse.self, from: responseData())
    let flight = try #require(response.mappedFlights().flights.first)
    #expect(flight.status == .inAir)
    #expect(flight.providerID == "ARG1490-sample")
    #expect(flight.departure == AeroAPIFlight.parseDate("2026-10-23T21:22:00Z"))
    #expect(flight.scheduledDeparture != flight.departure)
    #expect(flight.gate == "7")
    #expect(flight.arrivalGate == nil)
    #expect(flight.aircraft == nil)
    #expect(flight.distanceKilometers == 1279)
    #expect(flight.origin.latitude == nil)
    #expect(flight.localTime(flight.arrival, at: flight.destination) == "23:30 UTC")
    #expect(flight.lastUpdated != nil)
}

@Test func refreshedFlightRetainsPersonalDetails() throws {
    let refreshed = try #require(JSONDecoder().decode(AeroAPIResponse.self, from: responseData()).mappedFlights().flights.first)
    var saved = refreshed
    saved.bookingCode = "PRIVATE"
    saved.seat = "12A"
    saved.isFriend = true
    let merged = refreshed.preservingTravelDetails(from: saved)
    #expect(merged.bookingCode == "PRIVATE")
    #expect(merged.seat == "12A")
    #expect(merged.isFriend)
    #expect(merged.actualDeparture == refreshed.actualDeparture)
}

@Test func serverFixturesCannotBePresentedAsLiveFlights() throws {
    let response = try JSONDecoder().decode(AeroAPIResponse.self, from: responseData(mode: "fixture"))
    let flight = try #require(response.mappedFlights().flights.first)
    #expect(flight.isDemo)
    #expect(flight.providerID == nil)
    #expect(flight.id.hasPrefix("server-demo:"))
}

@Test func missingGateTimesOmitFlightInsteadOfInventingValues() throws {
    let incomplete = sampleProviderFlight.replacingOccurrences(of: "\"scheduled_out\":\"2026-10-23T21:00:00Z\"", with: "\"scheduled_out\":null")
    let response = try JSONDecoder().decode(AeroAPIResponse.self, from: responseData(flightJSON: incomplete))
    #expect(response.mappedFlights().flights.isEmpty)
    #expect(response.mappedFlights().omitted == 1)
}

@Test func existingSavedFilesRemainReadable() throws {
    let original = DemoFlightCatalog.flights()
    let encoded = try JSONEncoder().encode(original)
    var oldRecords = try #require(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
    for index in oldRecords.indices {
        for key in ["providerID", "lastUpdated", "actualDeparture", "actualArrival", "arrivalGate", "arrivalTerminal"] { oldRecords[index].removeValue(forKey: key) }
    }
    let decoded = try JSONDecoder().decode([Flight].self, from: JSONSerialization.data(withJSONObject: oldRecords))
    #expect(decoded.count == original.count)
    #expect(decoded.allSatisfy { $0.isDemo })
}

private final class FlightURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let status = request.url?.host == "limited.test" ? 429 : 200
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseData(next: true))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func testSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [FlightURLProtocol.self]
    return URLSession(configuration: configuration)
}

@Test func remoteSearchDecodesResultsAndDeclaresPagination() async throws {
    let session = testSession()
    defer { session.invalidateAndCancel() }
    let service = try RemoteFlightService(serverAddress: "https://flights.test", session: session)
    let result = try await service.search(number: "AR 1490", on: Date())
    #expect(result.flights.count == 1)
    #expect(result.hasMoreResults)
    #expect(!result.isDemo)
    #expect(result.omittedFlights == 0)
}

@Test func remoteRateLimitIsActionable() async throws {
    let session = testSession()
    defer { session.invalidateAndCancel() }
    let service = try RemoteFlightService(serverAddress: "https://limited.test", session: session)
    await #expect(throws: FlightServiceError.self) {
        _ = try await service.search(number: "AR1490", on: Date())
    }
}

@Test func serverConfigurationRejectsEmbeddedCredentialsAndPublicHTTP() {
    for address in ["http://example.com", "https://user:secret@example.com", "https://example.com?key=secret", "file:///tmp/flights"] {
        #expect(throws: FlightServiceError.self) { _ = try RemoteFlightService(serverAddress: address) }
    }
}

@Test func aviationstackFlightsKeepTheirProviderAndAirportTimeSemantics() throws {
    let record = sampleProviderFlight.replacingOccurrences(of: "\"fa_flight_id\":", with: "\"normalized_status\":\"landed\",\"time_basis\":\"airport\",\"operator_name\":\"Aerolíneas Argentinas\",\"fa_flight_id\":")
    let response = try JSONDecoder().decode(AeroAPIResponse.self, from: responseData(mode: "aviationstack", flightJSON: record))
    let flight = try #require(response.mappedFlights().flights.first)
    #expect(flight.providerDisplayName == "Aviationstack")
    #expect(flight.id.hasPrefix("aviationstack:"))
    #expect(flight.timeBasis == "airport")
    #expect(flight.status == .landed)
    #expect(flight.airline == "Aerolíneas Argentinas")
}
