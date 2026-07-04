//
//  ClipPocketTests.swift
//  ClipPocketTests
//
//  Created by Shaneen on 10/11/24.
//

import Testing
@testable import ClipPocket

struct ClipPocketTests {

    @Test func effectiveHistoryLimitHonorsUserToggle() {
        // Toggle off means unlimited, regardless of the stored slider value.
        #expect(SettingsManager.effectiveHistoryLimit(enableHistoryLimit: false, maxHistoryItems: 100) == .max)
        #expect(SettingsManager.effectiveHistoryLimit(enableHistoryLimit: false, maxHistoryItems: 1) == .max)

        // Toggle on honors the user-selected value, including values above the old 500 cap.
        #expect(SettingsManager.effectiveHistoryLimit(enableHistoryLimit: true, maxHistoryItems: 100) == 100)
        #expect(SettingsManager.effectiveHistoryLimit(enableHistoryLimit: true, maxHistoryItems: 800) == 800)
        #expect(SettingsManager.effectiveHistoryLimit(enableHistoryLimit: true, maxHistoryItems: 1000) == 1000)

        // Guard against nonsense values without silently dropping items.
        #expect(SettingsManager.effectiveHistoryLimit(enableHistoryLimit: true, maxHistoryItems: 0) == 1)
        #expect(SettingsManager.effectiveHistoryLimit(enableHistoryLimit: true, maxHistoryItems: -5) == 1)
    }
}
