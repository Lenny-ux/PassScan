import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject var store: CardStore
    @AppStorage("appTitle") private var appTitle = "Mes Pass"

    @State private var nfc = NFCScanner()
    @State private var draft: TransitCard?
    @State private var showCodeScanner = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showSettings = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.cards.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(store.cards) { card in
                            NavigationLink {
                                CardDetailView(cardID: card.id)
                            } label: {
                                CardTile(card: card)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { draft = card } label: { Label("Modifier", systemImage: "pencil") }
                                Button(role: .destructive) { store.delete(card) } label: { Label("Supprimer", systemImage: "trash") }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(appTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "paintpalette") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    addMenu
                }
            }
            .sheet(item: $draft) { card in
                CardEditView(card: card) { saved in store.upsert(saved) }
            }
            .sheet(isPresented: $showCodeScanner) {
                scannerSheet
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { item in
                guard let item = item else { return }
                Task { await importPhoto(item) }
            }
            .alert("Oups", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sous-vues

    private var addMenu: some View {
        Menu {
            Button { scanNFC() } label: { Label("Scanner une carte NFC", systemImage: "wave.3.right") }
            Button { showCodeScanner = true } label: { Label("Scanner un QR / code", systemImage: "qrcode.viewfinder") }
            Button { showPhotoPicker = true } label: { Label("Importer depuis une photo", systemImage: "photo") }
            Button { draft = TransitCard.newDraft(kind: .manual) } label: { Label("Ajouter à la main", systemImage: "square.and.pencil") }
        } label: {
            Image(systemName: "plus.circle.fill").font(.title2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Aucune carte pour l'instant").font(.title3.bold())
            Text("Appuie sur + pour scanner une carte NFC, un QR code de billet ou importer une capture d'écran.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button { showCodeScanner = true } label: {
                Label("Scanner un QR code", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button { scanNFC() } label: {
                Label("Scanner une carte NFC", systemImage: "wave.3.right").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
        .padding(.top, 60)
    }

    private var scannerSheet: some View {
        NavigationStack {
            ZStack {
                CodeScannerView { value, sym in
                    showCodeScanner = false
                    var card = TransitCard.newDraft(kind: .code)
                    card.payload = value
                    card.symbology = sym
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { draft = card }
                }
                .ignoresSafeArea()
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 260, height: 260)
            }
            .navigationTitle("Vise le code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showCodeScanner = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func scanNFC() {
        nfc.scan { result in
            switch result {
            case .success(let res):
                var card = TransitCard.newDraft(kind: .nfc)
                card.payload = res.uid
                card.tagType = res.type
                card.details = res.details
                if let existing = store.cards.first(where: { $0.kind == .nfc && $0.payload == res.uid }) {
                    var updated = existing
                    updated.details = res.details
                    store.upsert(updated)
                    errorMessage = "Cette carte est déjà enregistrée sous « \(existing.name) » ✅"
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { draft = card }
                }
            case .failure(let error):
                if !NFCScanner.isCancel(error) {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "Impossible d'ouvrir l'image."
            return
        }
        if let found = PhotoCodeReader.detect(in: image) {
            var card = TransitCard.newDraft(kind: .code)
            card.payload = found.0
            card.symbology = found.1
            draft = card
        } else {
            errorMessage = "Aucun QR code ou code-barres trouvé sur cette image."
        }
    }
}

// MARK: - Tuile de carte

struct CardTile: View {
    let card: TransitCard

    var body: some View {
        let color = Color(hex: card.colorHex)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: card.icon).font(.title2)
                Spacer()
                Text(card.kind.label)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.22), in: Capsule())
            }
            Spacer()
            Text(card.name.isEmpty ? "Sans nom" : card.name)
                .font(.title3.bold())
                .lineLimit(1)
            Text(card.subtitle)
                .font(.caption.monospaced())
                .opacity(0.85)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
        .background(
            LinearGradient(colors: [color, color.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: color.opacity(0.35), radius: 10, y: 6)
    }
}
