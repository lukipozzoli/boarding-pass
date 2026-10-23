import SwiftUI

struct FlightDetailView: View {
    @Environment(FlightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let originalFlight: Flight
    @State private var bookingCode = ""
    @State private var seat = ""
    @State private var confirmDeletion = false
    @State private var isRefreshing = false
    @State private var refreshError: String?

    private var flight: Flight { store.flight(id: originalFlight.id) ?? originalFlight }
    private var saved: Bool { store.contains(originalFlight) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RouteMapView(flights: [flight]).frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(alignment: .topLeading) { DemoLabel(isDemo: flight.isDemo).padding(12) }
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(flight.airline.uppercased()).font(.system(.caption, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
                            Text(flight.scheduledDeparture, format: .dateTime.day().month(.wide).year()).font(.caption).foregroundStyle(.secondary)
                            Text("\(flight.origin.city)\na \(flight.destination.city)")
                                .font(.system(size: 29, weight: .bold, design: .rounded)).foregroundStyle(Brand.navy)
                        }
                        Spacer()
                        Image(systemName: "airplane").font(.title).foregroundStyle(Brand.blue).rotationEffect(.degrees(-35))
                    }
                    Label(flight.status.title, systemImage: flight.status == .delayed ? "clock.badge.exclamationmark" : "checkmark.circle.fill")
                        .font(.headline).foregroundStyle(flight.status.color)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(flight.status.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    if !flight.isDemo {
                        VStack(alignment: .leading, spacing: 8) {
                            if let updated = flight.lastUpdated {
                                Text("Última consulta: \(updated.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                            } else { Text("Sin fecha de actualización disponible").font(.caption) }
                            Button {
                                Task { await refresh() }
                            } label: {
                                Label(isRefreshing ? "Actualizando…" : "Actualizar vuelo", systemImage: "arrow.clockwise")
                            }.disabled(isRefreshing)
                            if let refreshError { Text(refreshError).font(.caption).foregroundStyle(.red) }
                        }
                    }
                    VStack(spacing: 24) {
                        airportTime(flight.origin, date: flight.departure, title: flight.actualDeparture == nil ? "SALIDA" : "SALIDA REAL", gate: flight.gate, terminal: flight.terminal)
                        HStack {
                            Image(systemName: "clock")
                            Text("\(flight.durationMinutes / 60) h \(flight.durationMinutes % 60) min")
                            Rectangle().frame(height: 1)
                            Text(flight.distanceKilometers.map { "\($0.formatted()) km" } ?? "Distancia no informada")
                        }.font(.caption).foregroundStyle(.secondary)
                        airportTime(flight.destination, date: flight.arrival, title: flight.actualArrival == nil ? "LLEGADA" : "LLEGADA REAL", gate: flight.arrivalGate, terminal: flight.arrivalTerminal)
                    }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 22))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Su viaje").font(.title2.bold())
                        if saved {
                            TextField("Código de reserva", text: $bookingCode).textInputAutocapitalization(.characters).autocorrectionDisabled()
                                .accessibilityIdentifier("bookingCodeField")
                            Divider()
                            TextField("Asiento", text: $seat).textInputAutocapitalization(.characters).autocorrectionDisabled()
                                .accessibilityIdentifier("seatField")
                            Button("Guardar datos del viaje") {
                                store.updateTravelDetails(id: flight.id, bookingCode: bookingCode, seat: seat)
                                if store.errorMessage == nil { dismiss() }
                            }.buttonStyle(.borderedProminent).padding(.top, 8)
                        } else {
                            Button("Agregar a Mis vuelos") { store.add(flight) }.buttonStyle(.borderedProminent)
                        }
                    }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 22))
                    VStack(spacing: 12) {
                        LabeledContent("Aeronave", value: flight.aircraft ?? "No informada")
                        LabeledContent("Salida programada", value: flight.localTime(flight.scheduledDeparture, at: flight.origin))
                        LabeledContent("Llegada programada", value: flight.localTime(flight.scheduledArrival, at: flight.destination))
                        Text(flight.timeBasis == "airport" ? "Horarios de aeropuerto informados por Aviationstack; no confirman eventos de puerta. Se muestran en la zona local del aeropuerto cuando está disponible." : "Los horarios se muestran en la zona local de cada aeropuerto.").font(.caption).foregroundStyle(.secondary)
                    }.font(.subheadline).padding(20).background(.white, in: RoundedRectangle(cornerRadius: 22))
                    Text(flight.isDemo ? "Datos de demostración. No hay seguimiento en vivo." : "Los datos se actualizan al consultar. Clima, avión entrante, predicciones y alertas todavía no están conectados.")
                        .font(.caption).foregroundStyle(.secondary)
                    if saved {
                        Button("Eliminar de mi lista", role: .destructive) { confirmDeletion = true }.frame(maxWidth: .infinity)
                    }
                }.padding(20)
            }
            .background(Brand.pale).navigationTitle(flight.number).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: "\(flight.number): \(flight.origin.code) → \(flight.destination.code). \(flight.isDemo ? "Datos ficticios de demostración." : "Datos de \(flight.providerDisplayName); actualización manual.") Boarding Pass.") { Image(systemName: "square.and.arrow.up") }
                }
            }
            .onAppear { bookingCode = flight.bookingCode; seat = flight.seat }
            .confirmationDialog("¿Eliminar este vuelo de la lista local?", isPresented: $confirmDeletion, titleVisibility: .visible) {
                Button("Eliminar vuelo", role: .destructive) {
                    store.remove(id: flight.id)
                    if store.errorMessage == nil { dismiss() }
                }
            }
        }
    }

    private func refresh() async {
        isRefreshing = true
        refreshError = nil
        defer { isRefreshing = false }
        do { try await store.refreshFlight(id: flight.id) }
        catch { refreshError = error.localizedDescription }
    }

    private func airportTime(_ airport: Airport, date: Date, title: String, gate: String?, terminal: String?) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(title) · \(airport.code)").font(.system(.caption, design: .monospaced).weight(.bold)).foregroundStyle(.secondary)
                Text(flight.localTime(date, at: airport)).font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(Brand.navy)
                Text(airport.name).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 5) {
                Text(gate ?? "—").font(.title2.bold()).frame(minWidth: 52, minHeight: 46).background(.yellow.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                Text(gate == nil ? "Sin puerta" : "Puerta").font(.caption2).foregroundStyle(.secondary)
                if let terminal { Text("Terminal \(terminal)").font(.caption2).foregroundStyle(.secondary) }
            }
        }
    }
}
