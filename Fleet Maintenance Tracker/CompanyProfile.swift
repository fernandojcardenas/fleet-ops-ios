//
//  CompanyProfile.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/14/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum CompanyProfile {
    static var logoURL: URL {
        URL.documentsDirectory.appending(path: "company-logo.png")
    }

    #if canImport(UIKit)
    static func saveLogo(_ image: UIImage) {
        guard let data = image.pngData() else { return }
        try? data.write(to: logoURL, options: .atomic)
    }

    static func loadLogo() -> UIImage? {
        guard let data = try? Data(contentsOf: logoURL) else { return nil }
        return UIImage(data: data)
    }
    #endif

    static func deleteLogo() {
        try? FileManager.default.removeItem(at: logoURL)
    }
}
