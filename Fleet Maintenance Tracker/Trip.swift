//
//  Trip.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/22/26.
//

import Foundation

struct Trip: Codable, Identifiable, Hashable {
    var id: String
    var vehicleID: String
    var dateStart: Date?
    var dateEnd: Date?
    var mileageStart: Int?
    var mileageEnd: Int?
    var status: String
    var notes: String?
    var isOngoing: Bool?

    static let statusActive = "Active"
    static let statusCompleted = "Completed"

    // Source of truth for "in-flight" trips. Falls back to the legacy
    // status string for documents written before isOngoing existed.
    var effectiveIsOngoing: Bool {
        if let isOngoing { return isOngoing }
        return status.caseInsensitiveCompare(Trip.statusActive) == .orderedSame
    }
}
