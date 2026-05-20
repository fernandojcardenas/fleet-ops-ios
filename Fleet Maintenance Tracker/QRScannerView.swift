//
//  QRScannerView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

#if canImport(UIKit)
import SwiftUI
import AVFoundation
import UIKit

struct QRScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isTorchOn = false

    var body: some View {
        NavigationStack {
            ZStack {
                QRScannerRepresentable(isTorchOn: $isTorchOn) { value in
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onScan(value)
                    dismiss()
                }
                .ignoresSafeArea()

                ViewfinderOverlay()
                    .allowsHitTesting(false)

                VStack {
                    Spacer()
                    Text("Align the QR code inside the frame")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(.bottom, 40)
                }
                .allowsHitTesting(false)
            }
            .navigationTitle("Scan Vehicle QR")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isTorchOn.toggle()
                    } label: {
                        Label(
                            isTorchOn ? "Turn Off Flashlight" : "Turn On Flashlight",
                            systemImage: isTorchOn ? "bolt.fill" : "bolt.slash.fill"
                        )
                    }
                }
            }
        }
    }
}

struct ViewfinderOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white, lineWidth: 3)
            .frame(width: 260, height: 260)
            .shadow(color: .black.opacity(0.5), radius: 8)
    }
}

struct QRScannerRepresentable: UIViewControllerRepresentable {
    @Binding var isTorchOn: Bool
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        uiViewController.setTorch(on: isTorchOn)
    }
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    var onScan: ((String) -> Void)?
    private var hasReportedScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasReportedScan = false
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        setTorch(on: false)
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            showFailure()
            return
        }
        captureSession.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(output) else {
            showFailure()
            return
        }
        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.layer.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("[QRScanner] torch error: \(error.localizedDescription)")
        }
    }

    private func showFailure() {
        let label = UILabel()
        label.text = "Camera unavailable."
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasReportedScan,
              let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = metadata.stringValue else { return }
        hasReportedScan = true
        captureSession.stopRunning()
        onScan?(value)
    }
}
#endif
