//
//  Vehicle.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import Foundation
import SwiftUI

enum VehicleStatus: String, Codable, CaseIterable, Hashable {
    case active = "Active"
    case inShop = "In Shop"
    case recall = "Recall"
    case outOfService = "Out of Service"

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .inShop: return "In Shop"
        case .recall: return "Recall"
        case .outOfService: return "Out of Service"
        }
    }

    var color: Color {
        switch self {
        case .active: return .green
        case .inShop: return .orange
        case .recall: return .red
        case .outOfService: return .gray
        }
    }
}

struct Vehicle: Codable, Identifiable, Hashable {
    var id: String
    var make: String
    var model: String
    var year: Int
    var vin: String
    var licensePlate: String
    var addedBy: String
    var serviceInterval: Int?
    var status: VehicleStatus?

    var effectiveStatus: VehicleStatus { status ?? .active }
}
