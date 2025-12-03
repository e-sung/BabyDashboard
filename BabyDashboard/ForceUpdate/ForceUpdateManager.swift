//
//  ForceUpdateManager.swift
//  BabyDashboard
//
//  Created by Antigravity on 12/3/25.
//

import Foundation

final class ForceUpdateManager: ObservableObject {
    @Published var updateRequired = false
    
    private let configURL = URL(string: "https://raw.githubusercontent.com/e-sung/Configs/main/babyDashboardMinimumAppVersion.json")!
    
    func checkForUpdate() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: configURL)
            let config = try JSONDecoder().decode(Config.self, from: data)
            
            guard let currentVersionString = Bundle.main.marketingVersion,
                  let currentVersion = AppVersion(currentVersionString),
                  let minimumVersion = AppVersion(config.minimum_app_version) else {
                return
            }

            DispatchQueue.main.async {
                self.updateRequired = currentVersion < minimumVersion
            }
        } catch {
            // Fail gracefully - allow app access on network/parse errors
            print("Force update check failed: \(error)")
            updateRequired = false
        }
    }
}

// MARK: - Models

private struct Config: Decodable {
    let minimum_app_version: String
}

private struct AppVersion: Comparable {
    let major: Int
    let minor: Int
    let patch: Int
    
    init?(_ versionString: String) {
        let components = versionString.split(separator: ".").compactMap { Int($0) }
        guard components.count == 3 else { return nil }
        self.major = components[0]
        self.minor = components[1]
        self.patch = components[2]
    }
    
    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

// MARK: - Bundle Extension

private extension Bundle {
    var marketingVersion: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

