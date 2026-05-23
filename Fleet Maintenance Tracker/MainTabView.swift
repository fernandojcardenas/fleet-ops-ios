//
//  MainTabView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/14/26.
//

import SwiftUI

struct MainTabView: View {
    @State private var fleetViewModel = FleetViewModel()

    var body: some View {
        TabView {
            HomeView(fleetViewModel: fleetViewModel)
                .tabItem { Label("Fleet", systemImage: "car.2") }
            MaintenanceTabView(fleetViewModel: fleetViewModel)
                .tabItem { Label("Maintenance", systemImage: "wrench.and.screwdriver") }
            TripsTabView(fleetViewModel: fleetViewModel)
                .tabItem { Label("Trips", systemImage: "road.lanes.curved.right") }
            AnalyticsTabView(fleetViewModel: fleetViewModel)
                .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }
        }
    }
}
