//
//  Bundle+Info.swift
//  CodeEditModules/CodeEditUtils
//
//  Created by Lukas Pistrol on 01.05.22.
//

import Foundation

extension Bundle {

    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Unknown App"
    }

    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "Unknown App"
    }

    static var copyrightString: String? {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
    }

    /// Returns the main bundle's version string if available (e.g. 1.0.0)
    static var versionString: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// Returns the main bundle's build string if available (e.g. 123)
    static var buildString: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    static var versionPostfix: String? {
        Bundle.main.object(forInfoDictionaryKey: "CE_VERSION_POSTFIX") as? String
    }

    /// Non-empty only for nightly/pre-release builds, e.g. "Unofficial nightly build".
    /// Release configurations leave this empty, so they present as ordinary builds.
    static var buildIdentity: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "CE_BUILD_IDENTITY") as? String,
              !value.isEmpty else { return nil }
        return value
    }

    /// Where the build identity line links to (build notes / release page).
    static var buildIdentityURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "CE_BUILD_IDENTITY_URL") as? String,
              !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}
