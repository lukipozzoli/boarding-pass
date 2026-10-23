import SwiftUI

private struct FlightSearchRequest: Equatable {
    let id = UUID()
    let number: String
    let date: Date
}

struct FlightSearchView: View {
    @Environment(FlightStore.self) private var store
    let openFlight: (Flight) -> Void
    @State private var query = ""
    @State private var selectedDate = Date.now
    @State private var forFriend = false
    @State private var submittedRequest: FlightSearchRequest?
    @State private var remoteResult: FlightSearchResult?
    @State private var searchError: String?
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool

    private var matches: [Flight] {
        if store.usesServer { return remoteResult?.flights ?? [] }
        return store.catalog.filter { flight in
            guard Calendar.current.isDate(flight.scheduledDeparture, inSameDayAs: selectedDate) else { return false }
            let searchable = "\(flight.number) \(flight.airline) \(flight.origin.code) \(flight.origin.city) \(flight.destination.code) \(flight.destination.city)"
            return query.isEmpty || searchable.localizedStandardContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !store.usesServer || remoteResult != nil {
                        DemoLabel(isDemo: remoteResult?.isDemo ?? true)
                    } else {
                        Label("CONEXIÓN CON SERVIDOR", systemImage: "network").font(.caption.monospaced())
                    }
                    Text("El próximo viaje\nempieza acá.")
                        .font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(Brand.navy)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(store.usesServer ? "Número de vuelo, por ejemplo AR1490" : "Vuelo, ciudad o aeropuerto", text: $query)
                            .autocorrectionDisabled().accessibilityIdentifier("flightSearchField")
                            .focused($searchFocused).submitLabel(.search)
                            .onSubmit { submitSearch() }
                    }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16))
                    DatePicker("Fecha del vuelo", selection: $selectedDate, displayedComponents: .date)
                    if store.usesServer {
                        Button(action: submitSearch) {
                            HStack {
                                if isSearching { ProgressView().tint(.white) }
                                Text(isSearching ? "Buscando…" : "Consultar vuelo")
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).disabled(isSearching || query.isEmpty)
                        Text("La consulta se envía al pulsar Buscar. Aviationstack gratuito admite vuelos de hoy; otros proveedores pueden admitir fechas recientes.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Picker("Agregar a", selection: $forFriend) {
                        Text("Mis vuelos").tag(false)
                        Text("Amigos").tag(true)
                    }.pickerStyle(.segmented)
                    HStack {
                        Text(store.usesServer ? "RESULTADOS" : "CATÁLOGO DEMO").font(.system(.caption, design: .monospaced).weight(.bold)).tracking(2)
                        Spacer()
                        Text("\(matches.count) resultados").font(.caption).foregroundStyle(.secondary)
                    }
                    if let searchError {
                        ContentUnavailableView("No se pudo consultar", systemImage: "wifi.exclamationmark", description: Text(searchError))
                    } else if matches.isEmpty && !isSearching {
                        if store.usesServer && remoteResult == nil {
                            ContentUnavailableView("Busque su vuelo", systemImage: "airplane", description: Text("Ingrese un número y una fecha para consultar el servidor configurado en Ajustes."))
                        } else {
                            ContentUnavailableView.search(text: query)
                            if !store.usesServer {
                                Text("El catálogo de muestra contiene vuelos de hoy, dentro de tres días y algunos viajes pasados.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if remoteResult?.hasMoreResults == true {
                        Text("Resultados parciales. Hay más páginas disponibles en el proveedor; no se consultaron para limitar el consumo.").font(.caption).foregroundStyle(.orange)
                    }
                    if let omitted = remoteResult?.omittedFlights, omitted > 0 {
                        Text("Se omitieron \(omitted) registros sin aeropuertos u horarios de puerta completos.").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(matches) { flight in
                        VStack(spacing: 0) {
                            Button { openFlight(flight) } label: { FlightRow(flight: flight) }.buttonStyle(.plain)
                            Button { store.add(flight, forFriend: forFriend) } label: {
                                Label(store.contains(flight) ? "Ya está en su lista" : "Agregar a \(forFriend ? "Amigos" : "Mis vuelos")", systemImage: store.contains(flight) ? "checkmark.circle.fill" : "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(14)
                            }.disabled(store.contains(flight))
                        }.background(.white, in: RoundedRectangle(cornerRadius: 22))
                    }
                }.padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Brand.pale).navigationTitle("Buscar vuelo").navigationBarTitleDisplayMode(.inline)
            .onChange(of: query) { invalidateSearch() }
            .onChange(of: selectedDate) { invalidateSearch() }
            .onChange(of: store.usesServer) { invalidateSearch() }
            .onChange(of: store.serverAddress) { invalidateSearch() }
            .task(id: submittedRequest) { await performSearch() }
        }
    }

    private func submitSearch() {
        searchFocused = false
        guard store.usesServer else { return }
        remoteResult = nil
        searchError = nil
        submittedRequest = FlightSearchRequest(number: query, date: selectedDate)
    }

    private func invalidateSearch() {
        submittedRequest = nil
        remoteResult = nil
        searchError = nil
        isSearching = false
    }

    private func performSearch() async {
        guard let request = submittedRequest else { return }
        isSearching = true
        do {
            let result = try await store.searchRemote(number: request.number, date: request.date)
            guard !Task.isCancelled, submittedRequest == request else { return }
            remoteResult = result
        } catch {
            guard !Task.isCancelled, submittedRequest == request else { return }
            searchError = error.localizedDescription
        }
        if submittedRequest == request { isSearching = false }
    }
}
