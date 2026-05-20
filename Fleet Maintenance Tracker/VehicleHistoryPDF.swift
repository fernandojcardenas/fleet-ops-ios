//
//  VehicleHistoryPDF.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
typealias PlatformImage = UIImage
#endif

struct VehicleHistoryPDFView: View {
    let companyName: String
    let vehicle: Vehicle
    let logs: [MaintenanceLog]
    #if canImport(UIKit)
    let receiptImages: [String: UIImage]
    let companyLogo: UIImage?
    #endif

    private var totalCost: Double { logs.reduce(0) { $0 + $1.cost } }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                #if canImport(UIKit)
                if let companyLogo {
                    Image(uiImage: companyLogo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                }
                #endif
                VStack(alignment: .leading, spacing: 2) {
                    Text(companyName.isEmpty ? "Fleet Maintenance" : companyName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                    Text("Service History Report")
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.7))
                }
                Spacer(minLength: 0)
            }

            Divider().background(Color.black)

            VStack(alignment: .leading, spacing: 6) {
                row("Make", vehicle.make)
                row("Model", vehicle.model)
                row("Year", String(vehicle.year))
                row("VIN", vehicle.vin)
                row("License Plate", vehicle.licensePlate)
                row("Status", vehicle.effectiveStatus.displayName)
                if let interval = vehicle.serviceInterval {
                    row("Service Interval", "\(interval) mi")
                }
            }

            HStack {
                Text("Total Maintenance Spend")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(totalCost, format: .currency(code: "USD"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.black)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.black.opacity(0.05))

            Divider().background(Color.black)

            Text("Maintenance History")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)

            if logs.isEmpty {
                Text("No maintenance logs recorded.")
                    .foregroundStyle(.black.opacity(0.6))
            } else {
                tableHeader
                ForEach(logs) { log in
                    logRow(log)
                    Divider().background(Color.black.opacity(0.2))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(36)
        .frame(width: 612, alignment: .leading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private var tableHeader: some View {
        HStack(spacing: 8) {
            Text("Date").frame(width: 80, alignment: .leading)
            Text("Service").frame(maxWidth: .infinity, alignment: .leading)
            Text("Mileage").frame(width: 70, alignment: .trailing)
            Text("Cost").frame(width: 80, alignment: .trailing)
            Text("Receipt").frame(width: 70, alignment: .center)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.black.opacity(0.7))
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func logRow(_ log: MaintenanceLog) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(log.date, format: .dateTime.month(.abbreviated).day().year())
                    .frame(width: 80, alignment: .leading)
                Text(log.serviceType)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(log.mileage) mi")
                    .frame(width: 70, alignment: .trailing)
                Text(log.cost, format: .currency(code: "USD"))
                    .frame(width: 80, alignment: .trailing)
                receiptCell(for: log).frame(width: 70, alignment: .center)
            }
            .font(.system(size: 11))
            .foregroundStyle(.black)
            if !log.notes.isEmpty {
                Text(log.notes)
                    .font(.system(size: 10))
                    .foregroundStyle(.black.opacity(0.7))
                    .padding(.leading, 88)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func receiptCell(for log: MaintenanceLog) -> some View {
        #if canImport(UIKit)
        if let urlString = log.receiptURL, let image = receiptImages[urlString] {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else if log.receiptURL != nil {
            Text("Attached")
                .font(.system(size: 10))
                .foregroundStyle(.black.opacity(0.6))
        } else {
            Text("—")
                .foregroundStyle(.black.opacity(0.4))
        }
        #else
        if log.receiptURL != nil {
            Text("Attached")
                .font(.system(size: 10))
                .foregroundStyle(.black.opacity(0.6))
        } else {
            Text("—")
                .foregroundStyle(.black.opacity(0.4))
        }
        #endif
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.black)
        }
    }
}

#if canImport(UIKit)
@MainActor
func fetchReceiptImages(for logs: [MaintenanceLog]) async -> [String: UIImage] {
    var results: [String: UIImage] = [:]
    for log in logs {
        guard let urlString = log.receiptURL,
              let url = URL(string: urlString) else { continue }
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let image = UIImage(data: data) {
            results[urlString] = image
        }
    }
    return results
}
#endif

@MainActor
func generateVehiclePDF(companyName: String,
                        vehicle: Vehicle,
                        logs: [MaintenanceLog],
                        receiptImages: [String: AnyObject] = [:]) -> URL? {
    #if canImport(UIKit)
    let images = receiptImages as? [String: UIImage] ?? [:]
    let logo = CompanyProfile.loadLogo() ?? UIImage(named: "AppLogo")
    let pdfView = VehicleHistoryPDFView(
        companyName: companyName,
        vehicle: vehicle,
        logs: logs,
        receiptImages: images,
        companyLogo: logo
    )
    #else
    let pdfView = VehicleHistoryPDFView(
        companyName: companyName,
        vehicle: vehicle,
        logs: logs
    )
    #endif

    let renderer = ImageRenderer(content: pdfView)
    renderer.scale = 2.0

    let safeMake = vehicle.make.replacingOccurrences(of: "/", with: "-")
    let safeModel = vehicle.model.replacingOccurrences(of: "/", with: "-")
    let filename = "\(safeMake)-\(safeModel)-Service-History.pdf"
    let url = URL.temporaryDirectory.appending(path: filename)

    var didSucceed = false
    renderer.render { size, drawIn in
        var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
        pdfContext.beginPDFPage(nil)
        drawIn(pdfContext)
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        didSucceed = true
    }
    return didSucceed ? url : nil
}

#if canImport(UIKit)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
