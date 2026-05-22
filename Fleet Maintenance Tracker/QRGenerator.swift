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

    // Encodes the vehicle's persistent QR token (UUID at creation, or legacy id) into a deep link.
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
