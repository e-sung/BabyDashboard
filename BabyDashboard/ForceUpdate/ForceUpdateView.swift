//
//  ForceUpdateView.swift
//  BabyDashboard
//
//  Created by Antigravity on 12/3/25.
//

import SwiftUI

var appDisplayName: String {
    if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !displayName.isEmpty {
        return displayName
    }
    if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty {
        return name
    }
    return "App"
}
struct ForceUpdateView: View {

    private let appStoreURL: URL = {
        // Placeholder: Search for "Baby Dashboard" on App Store
        // Replace with actual App Store URL once app is published
        let appName = appDisplayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://apps.apple.com/us/iphone/search?term=\(appName)")!
    }()
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Update required")
                
                Text("Update Required")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("A new version of \(appDisplayName) is available. Please update to continue using the app.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            Button {
                UIApplication.shared.open(appStoreURL)
            } label: {
                Text("Update Now")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .accessibilityLabel("Update now")
            .accessibilityHint("Opens the App Store to update \(appDisplayName)")
            
            Spacer()
                .frame(height: 60)
        }
        .padding()
    }
}

#Preview {
    ForceUpdateView()
        .preferredColorScheme(.dark)
}
