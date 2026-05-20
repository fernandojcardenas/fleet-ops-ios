//
//  OnboardingView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/14/26.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var page: Int = 0

    private let pages: [OnboardingPageData] = [
        OnboardingPageData(
            symbol: "qrcode.viewfinder",
            color: .blue,
            title: "Scan a Car's QR Code",
            description: "Generate a unique QR for every vehicle. From the dashboard, tap Scan and point your camera to jump straight to that car's history."
        ),
        OnboardingPageData(
            symbol: "wrench.and.screwdriver.fill",
            color: .orange,
            title: "Log Maintenance",
            description: "Record every service with date, mileage, cost, and notes — and snap a photo of the receipt so it's stored alongside the log forever."
        ),
        OnboardingPageData(
            symbol: "exclamationmark.triangle.fill",
            color: .red,
            title: "Color-Coded Alerts",
            description: "A yellow SERVICE SOON badge appears within 500 miles of the next interval. A pulsing red SERVICE OVERDUE alert appears once a vehicle is past due."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, data in
                    OnboardingPage(data: data).tag(index)
                }
            }
            #if os(iOS) || os(visionOS) || os(tvOS)
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            #endif

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    isPresented = false
                }
            } label: {
                Text(page < pages.count - 1 ? "Next" : "Get Started")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

private struct OnboardingPageData {
    let symbol: String
    let color: Color
    let title: String
    let description: String
}

private struct OnboardingPage: View {
    let data: OnboardingPageData

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: data.symbol)
                .font(.system(size: 90))
                .foregroundStyle(data.color)
            Text(data.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(data.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
