import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: CardStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appTitle") private var appTitle = "Mes Pass"
    @AppStorage("accentHex") private var accentHex = "3B82F6"
    @AppStorage("theme") private var theme = "system"
    @AppStorage("boostBrightness") private var boostBrightness = true

    @State private var confirmReset = false

    private var accent: Binding<Color> {
        Binding(get: { Color(hex: accentHex) }, set: { accentHex = $0.toHex() })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Personnalisation") {
                    TextField("Titre de l'app", text: $appTitle)
                    ColorPicker("Couleur principale", selection: accent, supportsOpacity: false)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(TransitCard.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay(Circle().stroke(Color.primary, lineWidth: accentHex == hex ? 3 : 0))
                                .onTapGesture { accentHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                    Picker("Thème", selection: $theme) {
                        Text("Auto").tag("system")
                        Text("Clair").tag("light")
                        Text("Sombre").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Luminosité max sur les QR codes", isOn: $boostBrightness)
                } footer: {
                    Text("Aide les portiques à lire ton code.")
                }

                Section("NFC") {
                    LabeledContent("NFC disponible", value: NFCScanner.isAvailable ? "Oui ✅" : "Non ❌")
                    Text("L'iPhone lit l'identifiant (UID) et le type des cartes 13,56 MHz (MIFARE, Calypso, FeliCa, ISO 15693). Le solde et les abonnements sont chiffrés sur la plupart des cartes, et les badges RFID 125 kHz ne sont pas lisibles par un iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Cartes enregistrées", value: "\(store.cards.count)")
                    Button("Tout effacer", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }.bold()
                }
            }
            .confirmationDialog("Effacer toutes les cartes ?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Tout effacer", role: .destructive) { store.cards.removeAll() }
            }
        }
    }
}
