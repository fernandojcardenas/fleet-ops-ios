//
//  MaintenanceLog.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import Foundation

struct MaintenanceLog: Codable, Identifiable, Hashable {
    var id: String
    var vehicleID: String
    var serviceType: String
    var date: Date
    var mileage: Int
    var cost: Double
    var notes: String
    var receiptURL: String?
    var isSkipped: Bool? = false

    var effectiveIsSkipped: Bool { isSkipped ?? false }
}
