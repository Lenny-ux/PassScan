import SwiftUI
import UIKit

enum CardKind: String, Codable, CaseIterable, Identifiable {
    case nfc
    case code
    case manual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nfc: return "NFC / RFID"
        case .code: return "QR / Code"
        case .manual: return "Manuel"
        }
    }
}

struct TransitCard: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var kind: CardKind
    var colorHex: String
    var icon: String
    /// UID pour une carte NFC, contenu pour un QR / code-barres
    var payload: String
    /// "qr", "aztec", "pdf417", "code128"… (vide pour le NFC)
    var symbology: String = ""
    var tagType: String = ""
    var details: [String] = []
    var notes: String = ""
    var createdAt: Date = Date()

    var subtitle: String {
        switch kind {
        case .nfc: return tagType.isEmpty ? payload : "\(tagType) · \(payload)"
        case .code: return symbology.uppercased()
        case .manual: return payload
        }
    }

    var hasCode: Bool {
        (kind == .code || kind == .manual) && !payload.isEmpty
    }

    static let palette = ["3B82F6", "EF4444", "10B981", "F59E0B", "8B5CF6", "EC4899", "14B8A6", "F97316", "111827", "6366F1"]

    static let icons = ["tram.fill", "bus.fill", "train.side.front.car", "tram", "ferry.fill", "bicycle",
                        "car.fill", "airplane", "ticket.fill", "creditcard.fill", "building.2.fill", "figure.walk",
                        "qrcode", "wave.3.right", "star.fill", "heart.fill"]

    static func newDraft(kind: CardKind) -> TransitCard {
        TransitCard(name: "",
                    kind: kind,
                    colorHex: palette.randomElement() ?? "3B82F6",
                    icon: kind == .nfc ? "wave.3.right" : (kind == .code ? "qrcode" : "ticket.fill"),
                    payload: "",
                    symbology: kind == .nfc ? "" : "qr")
    }
}

final class CardStore: ObservableObject {
    @Published var cards: [TransitCard] = [] {
        didSet { save() }
    }

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("cards.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([TransitCard].self, from: data) {
            cards = decoded
        }
    }

    func upsert(_ card: TransitCard) {
        if let i = cards.firstIndex(where: { $0.id == card.id }) {
            cards[i] = card
        } else {
            cards.insert(card, at: 0)
        }
    }

    func delete(_ card: TransitCard) {
        cards.removeAll { $0.id == card.id }
    }

    func card(id: UUID) -> TransitCard? {
        cards.first { $0.id == id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cards) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if s.count != 6 { s = "3B82F6" }
        let v = UInt64(s, radix: 16) ?? 0x3B82F6
        self.init(red: Double((v >> 16) & 0xFF) / 255.0,
                  green: Double((v >> 8) & 0xFF) / 255.0,
                  blue: Double(v & 0xFF) / 255.0)
    }

    func toHex() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ x: CGFloat) -> Int { Int((max(0, min(1, x)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", c(r), c(g), c(b))
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}
