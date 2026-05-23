//
//  VehicleQRView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct VehicleQRView: View {
    let vehicle: Vehicle
    @Environment(\.dismiss) private var dismiss

    #if canImport(UIKit)
    @State private var qrImage: UIImage? = nil
    @State private var showingShare = false
    #endif

    private var qrPayload: String {
        QRGenerator.qrContent(for: vehicle)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                #if canImport(UIKit)
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300, maxHeight: 300)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ProgressView()
                        .frame(width: 300, height: 300)
                }
                #endif

                VStack(spacing: 4) {
                    Text("\(vehicle.make) \(vehicle.model)")
                        .font(.headline)
                    Text(vehicle.licensePlate)
                        .foregroundStyle(.secondary)
                }

                Text(qrPayload)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                #if canImport(UIKit)
                Button {
                    showingShare = true
                } label: {
                    Label("Share QR Code", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(qrImage == nil)
                #endif

                Spacer()
            }
            .padding()
            .navigationTitle("Vehicle QR")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if canImport(UIKit)
            .onAppear {
                if qrImage == nil {
                    qrImage = QRGenerator.image(from: qrPayload)
                }
            }
            .sheet(isPresented: $showingShare) {
                if let qrImage {
                    ActivityView(activityItems: [qrImage])
                }
            }
            #endif
        }
    }
}
