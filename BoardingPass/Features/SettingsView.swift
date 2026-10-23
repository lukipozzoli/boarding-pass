import SwiftUI

struct SettingsView: View {
    @Environment(FlightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var usesServer = false
    @State private var serverAddress = ""
    @State private var configurationError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Fuente de vuelos") {
                    Picker("Conexión", selection: $usesServer) {
                        Text("Demostración local").tag(false)
                        Text("Servidor de vuelos").tag(true)
                    }
                    if usesServer {
                        TextField("Dirección del servidor", text: $serverAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                            .accessibilityIdentifier("serverAddressField")
                        Text("En el simulador puede usar http://localhost:8765. Las claves del proveedor se configuran en el servidor, nunca en esta app.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let configurationError { Text(configurationError).foregroundStyle(.red) }
                    Button("Guardar conexión") {
                        do {
                            try store.configureServer(enabled: usesServer, address: serverAddress)
                            dismiss()
                        } catch { configurationError = error.localizedDescription }
                    }
                }
                Section("Sus datos") {
                    Text("Cambiar de conexión conserva los vuelos, reservas y asientos guardados. Cada vuelo indica si es de demostración o del proveedor.")
                    Text("Las consultas al proveedor pueden consumir saldo. No hay consultas automáticas en segundo plano.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Próximas etapas") {
                    Label("Alertas y eventos operativos", systemImage: "bell")
                    Label("Calendario, correo y TripIt", systemImage: "calendar")
                    Label("Live Activities y widgets", systemImage: "rectangle.badge.bolt")
                    Label("Sincronización entre amigos", systemImage: "person.2")
                }
            }
            .navigationTitle("Ajustes")
            .onAppear { usesServer = store.usesServer; serverAddress = store.serverAddress }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
        }
    }
}
