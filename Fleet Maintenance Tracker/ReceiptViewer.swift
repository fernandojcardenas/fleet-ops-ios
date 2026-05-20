//
//  ReceiptViewer.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI

struct ReceiptViewer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    ContentUnavailableView(
                        "Couldn't Load Receipt",
                        systemImage: "photo",
                        description: Text("The image could not be downloaded.")
                    )
                @unknown default:
                    EmptyView()
                }
            }
            .navigationTitle("Receipt")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
