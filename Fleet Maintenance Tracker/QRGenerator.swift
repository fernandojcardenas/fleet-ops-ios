//
//  QRGenerator.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import Foundation
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif

enum QRGenerator {
    static let deepLinkScheme = "fleetmaintenance"

    // Standardized QR payload: the raw vehicle document id (UUID).
    // Scanners treat the decoded string as a vehicleId directly.
    static func qrContent(for vehicle: Vehicle) -> String {
        vehicle.id
    }

    // Kept for `onOpenURL` parsing of any legacy deep-link QRs still in circulation.
    static func deepLink(forToken token: String) -> String {
        "\(deepLinkScheme)://vehicle/\(token)"
    }

    static func deepLink(forVehicleID id: String) -> String {
        deepLink(forToken: id)
    }

    #if canImport(UIKit)
    static func image(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    #endif
}
