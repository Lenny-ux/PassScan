import SwiftUI

struct CardDetailView: View {
    let cardID: UUID
    @EnvironmentObject var store: CardStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("boostBrightness") private var boostBrightness = true

    @State private var editing: TransitCard?
    @State private var confirmDelete = false
    @State private var verifyMessage: String?
    @State private var nfc = NFCScanner()
    @State private var savedBrightness: CGFloat?

    var body: some View {
        Group {
            if let card = store.card(id: cardID) {
                content(card)
            } else {
                Text("Carte supprimée").foregroundStyle(.secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { card in
            CardEditView(card: card) { store.upsert($0) }
        }
        .onAppear {
            if boostBrightness, store.card(id: cardID)?.hasCode == true {
                savedBrightness = UIScreen.main.brightness
                UIScreen.main.brightness = 1.0
            }
        }
        .onDisappear {
            if let b = savedBrightness { UIScreen.main.brightness = b }
        }
    }

    @ViewBuilder
    private func content(_ card: TransitCard) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                CardTile(card: card)

                if card.hasCode, let img = CodeRenderer.image(for: card.payload, symbology: card.symbology) {
                    VStack(spacing: 8) {
                        Image(uiImage: img)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: card.symbology == "code128" || card.symbology == "pdf417" ? 140 : 280)
                            .padding(20)
                            .background(.white, in: RoundedRectangle(cornerRadius: 18))
                        if card.symbology == "datamatrix" {
                            Text("Code d'origine DataMatrix, affiché ici en QR code.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                if card.kind == .nfc {
                    Button {
                        verify(card)
                    } label: {
                        Label("Vérifier en approchant la carte", systemImage: "wave.3.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: card.colorHex))

                    if let msg = verifyMessage {
                        Text(msg).font(.headline)
                    }
                }

                infoSection(card)

                HStack {
                    Button { editing = card } label: {
                        Label("Personnaliser", systemImage: "paintbrush").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Supprimer", systemImage: "trash").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle(card.name)
        .confirmationDialog("Supprimer cette carte ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                store.delete(card)
                dismiss()
            }
        }
    }

    private func infoSection(_ card: TransitCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Infos").font(.headline)
            if card.kind == .nfc {
                ForEach(card.details, id: \.self) { line in
                    Text(line).font(.callout.monospaced()).textSelection(.enabled)
                }
            } else {
                Text(card.payload)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(8)
            }
            if !card.notes.isEmpty {
                Divider()
                Text(card.notes)
            }
            Text("Ajoutée le \(card.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func verify(_ card: TransitCard) {
        verifyMessage = nil
        nfc.scan { result in
            switch result {
            case .success(let res):
                verifyMessage = res.uid == card.payload
                    ? "✅ C'est bien « \(card.name) »"
                    : "❌ Autre carte (UID \(res.uid))"
            case .failure(let error):
                if !NFCScanner.isCancel(error) { verifyMessage = error.localizedDescription }
            }
        }
    }
}
