import Foundation
import CoreNFC

struct NFCResult {
    var uid: String
    var type: String
    var details: [String]
}

enum NFCScanError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Le NFC n'est pas disponible. Il faut un iPhone 7 ou plus récent, et l'app doit être signée avec un compte développeur Apple payant (ou installée avec TrollStore)."
    }
}

final class NFCScanner: NSObject, NFCTagReaderSessionDelegate {
    private var session: NFCTagReaderSession?
    private var completion: ((Result<NFCResult, Error>) -> Void)?

    static var isAvailable: Bool { NFCTagReaderSession.readingAvailable }

    static func isCancel(_ error: Error) -> Bool {
        if let e = error as? NFCReaderError {
            return e.code == .readerSessionInvalidationErrorUserCanceled
        }
        return false
    }

    func scan(completion: @escaping (Result<NFCResult, Error>) -> Void) {
        guard NFCTagReaderSession.readingAvailable else {
            completion(.failure(NFCScanError.unavailable))
            return
        }
        self.completion = completion
        session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693, .iso18092], delegate: self, queue: nil)
        session?.alertMessage = "Approche ta carte du haut de l'iPhone"
        session?.begin()
    }

    // MARK: - Delegate

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        finish(.failure(error))
        self.session = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        if tags.count > 1 {
            session.alertMessage = "Plusieurs cartes détectées, garde-en une seule."
            session.restartPolling()
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                session.invalidate(errorMessage: "Connexion impossible, réessaie.")
                self.finish(.failure(error))
                return
            }

            var details: [String] = []
            var uid = "?"
            var type = "Inconnu"
            var ndefTag: NFCNDEFTag?

            switch tag {
            case .miFare(let t):
                uid = t.identifier.hexString
                type = Self.mifareName(t.mifareFamily)
                if let h = t.historicalBytes { details.append("Historical bytes : \(h.hexString)") }
                ndefTag = t
            case .iso7816(let t):
                uid = t.identifier.hexString
                type = "ISO 7816"
                details.append("AID : \(t.initialSelectedAID)")
                if t.initialSelectedAID.uppercased() == "315449432E494341" { type = "Calypso" }
                if let h = t.historicalBytes { details.append("Historical bytes : \(h.hexString)") }
                ndefTag = t
            case .feliCa(let t):
                uid = t.currentIDm.hexString
                type = "FeliCa"
                details.append("System code : \(t.currentSystemCode.hexString)")
                ndefTag = t
            case .iso15693(let t):
                uid = t.identifier.hexString
                type = "ISO 15693"
                details.append("Code fabricant : \(t.icManufacturerCode)")
                ndefTag = t
            @unknown default:
                break
            }

            details.insert("UID : \(uid)", at: 0)
            details.insert("Type : \(type)", at: 1)

            let done: ([String]) -> Void = { ndefLines in
                session.alertMessage = "Carte lue ✅"
                self.finish(.success(NFCResult(uid: uid, type: type, details: details + ndefLines)))
                session.invalidate()
            }

            if let ndefTag = ndefTag {
                Self.readNDEF(ndefTag, done: done)
            } else {
                done([])
            }
        }
    }

    // MARK: - Helpers

    private func finish(_ result: Result<NFCResult, Error>) {
        DispatchQueue.main.async {
            let c = self.completion
            self.completion = nil
            c?(result)
        }
    }

    private static func readNDEF(_ tag: NFCNDEFTag, done: @escaping ([String]) -> Void) {
        tag.queryNDEFStatus { status, _, error in
            guard error == nil, status != .notSupported else { done([]); return }
            tag.readNDEF { message, _ in
                let lines: [String] = message?.records.compactMap { record in
                    if let url = record.wellKnownTypeURIPayload() { return "Lien : \(url.absoluteString)" }
                    let (text, _) = record.wellKnownTypeTextPayload()
                    if let text = text { return "Texte : \(text)" }
                    return nil
                } ?? []
                done(lines)
            }
        }
    }

    private static func mifareName(_ family: NFCMiFareFamily) -> String {
        switch family {
        case .ultralight: return "MIFARE Ultralight"
        case .plus: return "MIFARE Plus"
        case .desfire: return "MIFARE DESFire"
        case .unknown: return "MIFARE / ISO 14443"
        @unknown default: return "MIFARE"
        }
    }
}
