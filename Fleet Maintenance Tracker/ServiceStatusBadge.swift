//
//  ServiceStatusBadge.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI

struct ServiceStatusBadge: View {
    let status: ServiceStatus

    var body: some View {
        switch status {
        case .overdue:
            ServiceOverdueBadge()
        case .dueSoon:
            ServiceSoonBadge()
        case .ok, .unknown:
            EmptyView()
        }
    }
}

struct ServiceSoonBadge: View {
    var body: some View {
        Text("SERVICE SOON")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.yellow, in: Capsule())
            .foregroundStyle(.black)
    }
}

struct ServiceOverdueBadge: View {
    @State private var pulse = false

    var body: some View {
        Text("SERVICE OVERDUE")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red, in: Capsule())
            .foregroundStyle(.white)
            .scaleEffect(pulse ? 1.08 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
