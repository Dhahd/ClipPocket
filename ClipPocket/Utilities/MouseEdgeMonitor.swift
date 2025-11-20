//
//  MouseEdgeMonitor.swift
//  ClipPocket
//
//  Created for auto-show/hide functionality
//

import AppKit
import Foundation

class MouseEdgeMonitor {
    private var pollTimer: Timer?
    private var hideTimer: Timer?
    private let edgeThreshold: CGFloat = 10.0  // Pixels from edge to trigger (accounts for Dock)
    private let hideDelay: TimeInterval = 0.5  // Delay before hiding when mouse leaves
    private let pollInterval: TimeInterval = 0.05  // Check mouse position 20 times per second

    var onEdgeEntered: (() -> Void)?
    var onEdgeExited: (() -> Void)?

    private var isNearEdge = false
    private var isWindowVisible = false

    func startMonitoring() {
        guard pollTimer == nil else { return }

        // Use a timer to continuously poll mouse position for immediate response
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkMousePosition()
        }

        print("🖱️ Mouse edge monitoring started")
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        hideTimer?.invalidate()
        hideTimer = nil
        isNearEdge = false
        print("🖱️ Mouse edge monitoring stopped")
    }

    func setWindowVisible(_ visible: Bool) {
        isWindowVisible = visible

        // If window just became visible, cancel any pending hide
        if visible {
            hideTimer?.invalidate()
            hideTimer = nil
        }
    }

    private func checkMousePosition() {
        guard let screen = NSScreen.main else { return }

        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = screen.frame  // Use full frame, not visibleFrame

        // Check if mouse is AT the very bottom edge of the screen
        // NSEvent.mouseLocation gives us coordinates where (0,0) is bottom-left
        let distanceFromBottom = mouseLocation.y - screenFrame.minY
        let atBottomEdge = distanceFromBottom <= edgeThreshold

        if atBottomEdge && !isNearEdge {
            // Mouse hit the bottom edge - show immediately
            isNearEdge = true
            hideTimer?.invalidate()
            hideTimer = nil

            if !isWindowVisible {
                print("🖱️ Mouse at bottom edge (y=\(mouseLocation.y)) - showing window")
                onEdgeEntered?()
            }
        } else if !atBottomEdge && isNearEdge {
            // Mouse left the bottom edge
            isNearEdge = false

            // Only schedule hide if the window is visible and mouse is not over it
            if isWindowVisible && !isMouseOverWindow() {
                scheduleHide()
            }
        } else if !atBottomEdge && isWindowVisible && !isMouseOverWindow() {
            // Mouse is away from edge and not over window - ensure hide is scheduled
            if hideTimer == nil && !isNearEdge {
                scheduleHide()
            }
        } else if isWindowVisible && isMouseOverWindow() {
            // Mouse is over the window - cancel any pending hide
            hideTimer?.invalidate()
            hideTimer = nil
        }
    }

    private func scheduleHide() {
        // Don't schedule if already scheduled
        guard hideTimer == nil else { return }

        hideTimer = Timer.scheduledTimer(withTimeInterval: hideDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Final check: hide only if mouse is away from edge and not over window
            if !self.isNearEdge && !self.isMouseOverWindow() {
                print("🖱️ Mouse away from edge - hiding window")
                self.onEdgeExited?()
                self.hideTimer = nil
            }
        }
    }

    private func isMouseOverWindow() -> Bool {
        let mouseLocation = NSEvent.mouseLocation

        // Check if mouse is over any visible ClipPocket window
        for window in NSApp.windows {
            if window.isVisible {
                // Expand the window frame slightly to include a small buffer zone
                let expandedFrame = window.frame.insetBy(dx: -10, dy: -10)
                if expandedFrame.contains(mouseLocation) {
                    return true
                }
            }
        }

        return false
    }
}
