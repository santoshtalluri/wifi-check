//
//  EnterpriseBanner.swift
//  WiFi Check
//

import SwiftUI

/// Indigo/purple non-dismissible banner for enterprise networks
struct EnterpriseBanner: View {

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "building.2")
                .font(.system(size: 16))
                .foregroundColor(.enterprise)

            Text("Enterprise network detected. Some diagnostics may be restricted by your network policy. Results may be limited.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.enterprise)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.enterprise.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.enterprise.opacity(0.28), lineWidth: 1)
                )
        )
    }
}
