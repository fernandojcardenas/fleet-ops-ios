//
//  ServiceTemplate.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/14/26.
//

import Foundation
import SwiftUI

struct ServiceTemplate: Codable, Identifiable, Hashable {
    var id: String
    var serviceName: String
    var mileageInterval: Int
    var assignedVehicleIDs: [String]
}

enum ServiceHealth: Hashable {
    case green(milesRemaining: Int)
    case yellow(milesRemaining: Int)
    case red(milesRemaining: Int)
    case overdue(milesOver: Int)
    case neverServiced
    case unknown

    var color: Color {
        switch self {
        case .green: return .green
        case .yellow: return .yellow
        case .red, .overdue, .neverServiced: return .red
        case .unknown: return .gray
        }
    }

    var label: String {
        switch self {
        case .green(let m), .yellow(let m), .red(let m):
            return "\(m) mi left"
        case .overdue(let m):
            return "\(m) mi overdue"
        case .neverServiced:
            return "Never serviced"
        case .unknown:
            return "—"
        }
    }
}
