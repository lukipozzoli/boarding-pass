import SwiftUI

struct FlightsHomeView: View {
    @Environment(FlightStore.self) private var store
    let forFriends: Bool
    let openFlight: (Flight) -> Void
    let openSearch: () -> Void
    let openSettings: () -> Void
    @State private var expanded = false

    private var flights: [Flight] { forFriends ? store.friends : store.upcoming }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Brand.pale.ignoresSafeArea()
                VStack(spacing: 0) {
                    RouteMapView(flights: flights)
                        .frame(height: geometry.size.height * 0.54)
                    Spacer(minLength: 0)
                }.ignoresSafeArea(edges: .top)
                VStack {
                    HStack {
                        Label("BOARDING PASS", systemImage: "airplane.departure")
                            .font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(2)
                        Spacer()
                        Button(action: openSettings) { Image(systemName: "person.crop.circle").font(.title2) }
                            .accessibilityLabel("Abrir ajustes")
                    }.padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    DemoLabel(isDemo: flights.allSatisfy(\.isDemo))
                    Spacer()
                }.padding(.horizontal, 20).padding(.top, 10).allowsHitTesting(true)

                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.4)) { expanded.toggle() }
                    } label: {
                        Capsule().fill(.tertiary).frame(width: 38, height: 5).frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 14)
                    }.accessibilityLabel(expanded ? "Contraer vuelos" : "Expandir vuelos")
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(forFriends ? "Vuelos de amigos" : "Sus próximos viajes")
                                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            Text(forFriends ? "Amigos" : "Mis vuelos")
                                .font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(Brand.navy)
                        }
                        Spacer()
                        Button(action: openSearch) { Image(systemName: "plus").font(.title3.weight(.semibold)).frame(width: 44, height: 44).background(Brand.pale, in: Circle()) }
                            .accessibilityLabel("Agregar vuelo")
                    }.padding(.horizontal, 24).padding(.bottom, 18)
                    ScrollView {
                        VStack(spacing: 14) {
                            if flights.isEmpty {
                                ContentUnavailableView(forFriends ? "Acompañe su viaje" : "Su próximo destino lo espera", systemImage: forFriends ? "person.2" : "airplane.departure", description: Text(forFriends ? "Agregue un vuelo de demostración a Amigos desde Buscar. El intercambio automático llegará más adelante." : "Busque un vuelo en el catálogo de demostración."))
                                Button("Buscar un vuelo", action: openSearch).buttonStyle(.borderedProminent)
                            }
                            ForEach(flights) { flight in
                                Button { openFlight(flight) } label: { FlightRow(flight: flight) }.buttonStyle(.plain)
                            }
                            Text(flights.allSatisfy(\.isDemo) ? "Explore con tranquilidad. Estos vuelos son ficticios." : "Cada vuelo indica su fuente. Actualice sus datos desde el detalle.")
                                .font(.caption2).foregroundStyle(.secondary).padding(.vertical, 10)
                        }.padding(.horizontal, 20).padding(.bottom, 20)
                    }
                }
                .frame(height: geometry.size.height * (expanded ? 0.88 : 0.59))
                .background(Brand.pale, in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
            }
        }
    }
}
