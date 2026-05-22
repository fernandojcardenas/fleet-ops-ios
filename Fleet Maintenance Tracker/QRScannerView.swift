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
    @State private var permissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            ZStack {
                switch permissionStatus {
                case .authorized:
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

                case .notDetermined:
                    Color.black.ignoresSafeArea()
                    ProgressView("Requesting camera access…")
                        .tint(.white)
                        .foregroundStyle(.white)

                case .denied, .restricted:
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.white)
                        Text("Camera Access Denied")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Enable camera access for FAJ Fleet Maintenance in Settings to scan vehicle QR codes.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                @unknown default:
                    Color.black.ignoresSafeArea()
                }
            }
            .navigationTitle("Scan Vehicle QR")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if permissionStatus == .authorized {
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
            .task {
                await requestCameraAccessIfNeeded()
            }
        }
    }

    private func requestCameraAccessIfNeeded() async {
        guard permissionStatus == .notDetermined else { return }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            permissionStatus = granted ? .authorized : .denied
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
    private let sessionQueue = DispatchQueue(label: "com.faj.qrscanner.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    var onScan: ((String) -> Void)?
    private var hasReportedScan = false
    private var isConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasReportedScan = false
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.isConfigured && !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
        setTorch(on: false)
    }

    private func configureSession() {
        let preferredDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)

        guard let device = preferredDevice,
              let input = try? AVCaptureDeviceInput(device: device) else {
            DispatchQueue.main.async { [weak self] in self?.showFailure() }
            return
        }

        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }

        guard captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            DispatchQueue.main.async { [weak self] in self?.showFailure() }
            return
        }
        captureSession.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(output) else {
            captureSession.commitConfiguration()
            DispatchQueue.main.async { [weak self] in self?.showFailure() }
            return
        }
        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        captureSession.commitConfiguration()
        isConfigured = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            layer.videoGravity = .resizeAspectFill
            layer.frame = self.view.layer.bounds
            self.view.layer.addSublayer(layer)
            self.previewLayer = layer
        }

        if !captureSession.isRunning {
            captureSession.startRunning()
        }
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
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
        onScan?(value)
    }
}
#endif
