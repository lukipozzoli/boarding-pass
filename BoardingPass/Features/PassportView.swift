import SwiftUI

struct PassportView: View {
    @Environment(FlightStore.self) private var store
    let openFlight: (Flight) -> Void
    @State private var showDemo = true
    private var history: [Flight] { store.history.filter { $0.isDemo == showDemo } }
    private var statistics: FlightStatistics { FlightStatistics(flights: history) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DemoLabel(isDemo: showDemo)
                    if store.history.contains(where: { !$0.isDemo }) {
                        Picker("Fuente del historial", selection: $showDemo) {
                            Text("Demostración").tag(true)
                            Text("Proveedor").tag(false)
                        }.pickerStyle(.segmented)
                    }
                    Text("Cada viaje\ncuenta una historia.")
                        .font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(Brand.navy)
                    RouteMapView(flights: history).frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 24))
                    statisticsCard
                    HStack {
                        Text("Vuelos anteriores").font(.title2.bold())
                        Spacer()
                        Text("\(history.count)").font(.headline).foregroundStyle(.secondary)
                    }
                    if history.isEmpty {
                        ContentUnavailableView("Un mundo por recorrer", systemImage: "globe.americas", description: Text("Los vuelos completados aparecerán aquí."))
                    }
                    ForEach(history) { flight in
                        Button { openFlight(flight) } label: { FlightRow(flight: flight) }.buttonStyle(.plain)
                    }
                }.padding(24)
            }.background(Brand.pale).navigationTitle("Pasaporte").navigationBarTitleDisplayMode(.inline)
        }
    }

    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label("SU PASAPORTE", systemImage: "globe.americas.fill").font(.system(.caption, design: .monospaced).weight(.bold)).tracking(2)
                Spacer()
                ShareLink(item: "Mi pasaporte: \(statistics.count) vuelos, \(statistics.distance) km conocidos. \(showDemo ? "Datos ficticios." : "Datos de proveedores de vuelos.") Boarding Pass.") { Image(systemName: "square.and.arrow.up") }
            }
            HStack(alignment: .firstTextBaseline) {
                statistic("VUELOS", value: "\(statistics.count)", large: true)
                Spacer()
                statistic("DISTANCIA", value: "\(statistics.distance.formatted()) km", large: true)
            }
            Divider().overlay(.white.opacity(0.3))
            HStack {
                statistic("TIEMPO", value: "\(statistics.minutes / 60) h \(statistics.minutes % 60) m")
                Spacer()
                statistic("AEROPUERTOS", value: "\(statistics.airports)")
                Spacer()
                statistic("AEROLÍNEAS", value: "\(statistics.airlines)")
            }
            if statistics.missingDistances > 0 {
                Text("Distancia parcial: \(statistics.missingDistances) vuelos sin distancia informada.").font(.caption)
            }
        }
        .padding(24).foregroundStyle(.white)
        .background(LinearGradient(colors: [Brand.navy, Color(red: 0.05, green: 0.30, blue: 0.52)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))
    }

    private func statistic(_ title: String, value: String, large: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1).opacity(0.7)
            Text(value).font(.system(size: large ? 30 : 18, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
        }
    }
}
