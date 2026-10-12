import SwiftUI
import AVFoundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Scanner caméra

struct CodeScannerView: UIViewControllerRepresentable {
    var onFound: (String, String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onFound = onFound
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onFound: ((String, String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var found = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        let wanted: [AVMetadataObject.ObjectType] = [.qr, .aztec, .pdf417, .dataMatrix, .code128, .code39, .ean13, .ean8]
        output.metadataObjectTypes = wanted.filter { output.availableMetadataObjectTypes.contains($0) }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        preview = layer

        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let s = session
        DispatchQueue.global(qos: .userInitiated).async {
            if s.isRunning { s.stopRunning() }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !found,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        found = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onFound?(value, Self.symbology(obj.type))
    }

    static func symbology(_ type: AVMetadataObject.ObjectType) -> String {
        if type == .aztec { return "aztec" }
        if type == .pdf417 { return "pdf417" }
        if type == .qr { return "qr" }
        if type == .dataMatrix { return "datamatrix" }
        return "code128"
    }
}

// MARK: - Import depuis une photo / capture d'écran

enum PhotoCodeReader {
    static func detect(in image: UIImage) -> (String, String)? {
        guard let cg = image.cgImage else { return nil }
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])
        guard let obs = request.results?.first(where: { $0.payloadStringValue != nil }),
              let value = obs.payloadStringValue else { return nil }
        let sym: String
        switch obs.symbology {
        case .aztec: sym = "aztec"
        case .pdf417: sym = "pdf417"
        case .qr: sym = "qr"
        case .dataMatrix: sym = "datamatrix"
        default: sym = "code128"
        }
        return (value, sym)
    }
}

// MARK: - Génération de l'image du code (pour le montrer aux portiques)

enum CodeRenderer {
    static let symbologies = ["qr", "aztec", "pdf417", "code128"]

    static func label(_ symbology: String) -> String {
        switch symbology {
        case "aztec": return "Aztec"
        case "pdf417": return "PDF417"
        case "code128": return "Code 128"
        case "datamatrix": return "DataMatrix"
        default: return "QR code"
        }
    }

    static func image(for text: String, symbology: String) -> UIImage? {
        let data = Data(text.utf8)
        let filter: CIFilter
        switch symbology {
        case "aztec":
            let f = CIFilter.aztecCodeGenerator()
            f.message = data
            filter = f
        case "pdf417":
            let f = CIFilter.pdf417BarcodeGenerator()
            f.message = data
            filter = f
        case "code128":
            let f = CIFilter.code128BarcodeGenerator()
            f.message = text.data(using: .ascii) ?? data
            f.quietSpace = 7
            filter = f
        default:
            let f = CIFilter.qrCodeGenerator()
            f.message = data
            f.correctionLevel = "M"
            filter = f
        }
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
