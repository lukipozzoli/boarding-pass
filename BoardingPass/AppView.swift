import SwiftUI

enum AppTab: Hashable { case flights, friends, passport, search }

enum AppSheet: Identifiable {
    case flight(Flight)
    case settings
    var id: String {
        switch self {
        case .flight(let flight): "flight-\(flight.id)"
        case .settings: "settings"
        }
    }
}

struct AppView: View {
    @Environment(FlightStore.self) private var store
    @State private var selectedTab: AppTab = .flights
    @State private var presentedSheet: AppSheet?

    var body: some View {
        @Bindable var store = store
        TabView(selection: $selectedTab) {
            FlightsHomeView(forFriends: false, openFlight: openFlight, openSearch: { selectedTab = .search }, openSettings: { presentedSheet = .settings })
                .tabItem { Label("Mis vuelos", systemImage: "airplane") }.tag(AppTab.flights)
            FlightsHomeView(forFriends: true, openFlight: openFlight, openSearch: { selectedTab = .search }, openSettings: { presentedSheet = .settings })
                .tabItem { Label("Amigos", systemImage: "person.2") }.tag(AppTab.friends)
            PassportView(openFlight: openFlight)
                .tabItem { Label("Pasaporte", systemImage: "book.closed") }.tag(AppTab.passport)
            FlightSearchView(openFlight: openFlight)
                .tabItem { Label("Buscar", systemImage: "magnifyingglass") }.tag(AppTab.search)
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .flight(let flight): FlightDetailView(originalFlight: flight)
            case .settings: SettingsView()
            }
        }
        .alert("No se completó la operación", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("Entendido") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .preferredColorScheme(.light)
    }

    private func openFlight(_ flight: Flight) { presentedSheet = .flight(flight) }
}

