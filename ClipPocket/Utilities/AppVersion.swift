//
//  AppVersion.swift
//  ClipPocket
//
//  Centralized version management
//

import Foundation

struct AppVersion {
    /// The current version of the app
    /// This is read from the bundle's Info.plist which is set by MARKETING_VERSION in Xcode
    static var current: String {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return version
        }
        return "2.0.0" // Fallback version
    }

    /// The build number of the app
    static var build: String {
        if let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            return build
        }
        return "1" // Fallback build
    }

    /// Full version string (version + build)
    static var fullVersion: String {
        return "\(current) (\(build))"
    }
}
