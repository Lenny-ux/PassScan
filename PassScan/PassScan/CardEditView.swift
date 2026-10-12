import SwiftUI

struct CardEditView: View {
    @State var card: TransitCard
    var onSave: (TransitCard) -> Void
    @Environment(\.dismiss) private var dismiss

    private var color: Binding<Color> {
        Binding(get: { Color(hex: card.colorHex) }, set: { card.colorHex = $0.toHex() })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CardTile(card: card)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Nom") {
                    TextField("Ex : Navigo, Car Jaune, TER…", text: $card.name)
                }

                Section("Couleur") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(TransitCard.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 38, height: 38)
                                .overlay(Circle().stroke(Color.primary, lineWidth: card.colorHex == hex ? 3 : 0))
                                .onTapGesture { card.colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                    ColorPicker("Couleur perso", selection: color, supportsOpacity: false)
                }

                Section("Icône") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(TransitCard.icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 42, height: 42)
                                .background(card.icon == icon ? Color(hex: card.colorHex).opacity(0.25) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { card.icon = icon }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if card.kind == .nfc {
                    Section("Carte NFC") {
                        LabeledContent("UID", value: card.payload)
                        LabeledContent("Type", value: card.tagType)
                    }
                } else {
                    Section("Contenu du code") {
                        TextField("Texte ou numéro du billet", text: $card.payload, axis: .vertical)
                            .lineLimit(1...6)
                            .font(.callout.monospaced())
                        Picker("Format", selection: $card.symbology) {
                            ForEach(CodeRenderer.symbologies, id: \.self) { sym in
                                Text(CodeRenderer.label(sym)).tag(sym)
                            }
                            if card.symbology == "datamatrix" {
                                Text("DataMatrix").tag("datamatrix")
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Abonnement, date d'expiration…", text: $card.notes, axis: .vertical)
                        .lineLimit(1...5)
                }
            }
            .navigationTitle(card.name.isEmpty ? "Nouvelle carte" : card.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        if card.name.trimmingCharacters(in: .whitespaces).isEmpty {
                            card.name = card.kind == .nfc ? "Carte NFC" : "Billet"
                        }
                        onSave(card)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
