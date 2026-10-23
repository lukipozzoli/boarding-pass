import Foundation

struct FlightSearchResult: Sendable {
    let flights: [Flight]
    let hasMoreResults: Bool
    let omittedFlights: Int
    let isDemo: Bool
}

protocol FlightService: Sendable {
    func search(number: String, on date: Date) async throws -> FlightSearchResult
    func refresh(_ flight: Flight) async throws -> Flight
}

enum FlightServiceError: LocalizedError {
    case invalidServer, invalidNumber, unavailable, missingKey, rateLimited, unsupportedDate, invalidResponse, flightNotFound, planUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidServer: "Ingrese una dirección HTTPS válida, o http://localhost:8765 para el simulador."
        case .invalidNumber: "Busque por número de vuelo, por ejemplo AR1490 o ARG1490."
        case .unavailable: "El servidor no está disponible. Sus vuelos guardados siguen en el dispositivo."
        case .missingKey: "El proveedor no aceptó la clave configurada en el servidor."
        case .rateLimited: "Se alcanzó el límite de consultas. Espere antes de volver a intentar."
        case .unsupportedDate: "La fecha no está disponible en su plan. Aviationstack gratuito admite vuelos de hoy."
        case .planUnavailable: "El plan del proveedor no permite esta consulta. No se hicieron reintentos."
        case .invalidResponse: "El servidor devolvió datos que no pudimos interpretar."
        case .flightNotFound: "No se encontró una actualización inequívoca para este vuelo. Se conservan sus datos anteriores."
        }
    }
}

struct RemoteFlightService: FlightService {
    let baseURL: URL
    let session: URLSession

    init(serverAddress: String, session: URLSession = .shared) throws {
        guard let components = URLComponents(string: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)),
              let url = components.url, let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil, components.query == nil, components.fragment == nil,
              components.scheme == "https" || (components.scheme == "http" && ["localhost", "127.0.0.1"].contains(host))
        else { throw FlightServiceError.invalidServer }
        baseURL = url
        self.session = session
    }

    func search(number: String, on date: Date) async throws -> FlightSearchResult {
        let normalized = number.uppercased().replacingOccurrences(of: " ", with: "")
        guard normalized.range(of: "^[A-Z0-9]{2,3}[0-9]{1,4}[A-Z]?$", options: .regularExpression) != nil else {
            throw FlightServiceError.invalidNumber
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let response = try await fetch(path: "v1/flights", queryItems: [URLQueryItem(name: "number", value: normalized), URLQueryItem(name: "date", value: formatter.string(from: date))])
        let mapped = response.mappedFlights()
        return FlightSearchResult(flights: mapped.flights, hasMoreResults: response.links?.next != nil, omittedFlights: mapped.omitted, isDemo: response.mode == "fixture")
    }

    func refresh(_ flight: Flight) async throws -> Flight {
        guard let providerID = flight.providerID else { throw FlightServiceError.flightNotFound }
        let response = try await fetch(path: "v1/flight", queryItems: [URLQueryItem(name: "id", value: providerID)])
        let candidates = response.mappedFlights().flights.filter { $0.id == flight.id && !$0.isDemo }
        guard candidates.count == 1, let updated = candidates.first else { throw FlightServiceError.flightNotFound }
        return updated.preservingTravelDetails(from: flight)
    }

    private func fetch(path: String, queryItems: [URLQueryItem]) async throws -> AeroAPIResponse {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch {
            if Task.isCancelled { throw CancellationError() }
            throw FlightServiceError.unavailable
        }
        guard let httpResponse = response as? HTTPURLResponse else { throw FlightServiceError.invalidResponse }
        switch httpResponse.statusCode {
        case 200: break
        case 400: throw FlightServiceError.invalidNumber
        case 401, 403, 503: throw FlightServiceError.missingKey
        case 402: throw FlightServiceError.planUnavailable
        case 422: throw FlightServiceError.unsupportedDate
        case 429: throw FlightServiceError.rateLimited
        default: throw FlightServiceError.unavailable
        }
        guard let decoded = try? JSONDecoder().decode(AeroAPIResponse.self, from: data),
              ["flightaware", "aviationstack", "fixture"].contains(decoded.mode) else { throw FlightServiceError.invalidResponse }
        return decoded
    }
}
