import SwiftUI
import MapKit

enum Brand {
    static let navy = Color(red: 0.04, green: 0.12, blue: 0.22)
    static let blue = Color(red: 0.0, green: 0.42, blue: 0.90)
    static let pale = Color(red: 0.93, green: 0.96, blue: 0.99)
}

extension Airport {
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude, (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension FlightStatus {
    var color: Color {
        switch self {
        case .scheduled, .landed, .arrived: .green
        case .delayed: .orange
        case .cancelled: .red
        case .inAir, .taxiing: Brand.blue
        case .diverted: .orange
        }
    }
}

struct DemoLabel: View {
    var isDemo = true
    var body: some View {
        Label(isDemo ? "DATOS DE DEMOSTRACIÓN" : "DATOS DEL PROVEEDOR", systemImage: isDemo ? "flask" : "antenna.radiowaves.left.and.right")
            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityLabel(isDemo ? "Datos ficticios de demostración. No hay seguimiento en vivo." : "Datos obtenidos del proveedor. Actualización manual.")
    }
}

struct RouteMapView: View {
    let flights: [Flight]
    var body: some View {
        if !flights.isEmpty && airports.isEmpty {
            ContentUnavailableView("Mapa no disponible", systemImage: "map", description: Text("El proveedor no incluyó coordenadas para esta ruta."))
                .background(Brand.pale)
        } else {
        Map {
            ForEach(flights) { flight in
                if let origin = flight.origin.coordinate, let destination = flight.destination.coordinate {
                MapPolyline(coordinates: [origin, destination])
                    .stroke(Brand.blue.opacity(0.8), lineWidth: 3)
                }
            }
            ForEach(airports, id: \.code) { airport in
                if let coordinate = airport.coordinate {
                Annotation(airport.code, coordinate: coordinate) {
                    Text(airport.code).font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(7).foregroundStyle(.white).background(Brand.blue, in: Capsule())
                }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .accessibilityLabel("Mapa de rutas")
        }
    }

    private var airports: [Airport] {
        Array(Set(flights.flatMap { [$0.origin, $0.destination] })).filter { $0.coordinate != nil }.sorted { $0.code < $1.code }
    }
}

struct FlightRow: View {
    let flight: Flight
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(flight.number, systemImage: "airplane")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                Spacer()
                Text(flight.status.title).font(.caption.weight(.semibold)).foregroundStyle(flight.status.color)
            }
            HStack(alignment: .firstTextBaseline) {
                routeAirport(flight.origin, date: flight.departure)
                Spacer(minLength: 8)
                VStack(spacing: 5) {
                    Image(systemName: "airplane").font(.caption)
                    Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                    Text("\(flight.durationMinutes / 60) h \(flight.durationMinutes % 60) m").font(.system(size: 10))
                }.foregroundStyle(.secondary).frame(width: 82)
                Spacer(minLength: 8)
                routeAirport(flight.destination, date: flight.arrival)
            }
            HStack {
                Text(flight.scheduledDeparture, format: .dateTime.day().month(.abbreviated))
                Spacer()
                Text(flight.airline)
            }.font(.caption).foregroundStyle(.secondary)
            Text(flight.isDemo ? "DEMOSTRACIÓN · Datos ficticios" : "\(flight.providerDisplayName.uppercased()) · Actualización manual")
                .font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
        }
        .padding(20).background(.background, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.quaternary, lineWidth: 1))
        .contentShape(Rectangle())
    }

    private func routeAirport(_ airport: Airport, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(airport.code).font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(Brand.navy)
            Text(airport.city).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(flight.localTime(date, at: airport)).font(.system(.title3, design: .rounded).weight(.semibold)).foregroundStyle(Brand.navy)
        }
    }
}
