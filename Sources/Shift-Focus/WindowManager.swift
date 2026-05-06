import AppKit
import ApplicationServices

enum WindowManager {

    struct WindowInfo {
        let pid: pid_t
        let appName: String
        let bounds: CGRect
    }

    // MARK: - Current Window

    static func getCurrentFocusedWindow() -> (pid: pid_t, bounds: CGRect)? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            Logger.debug("No frontmost application found")
            return nil
        }

        let pid = frontApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success, let window = focusedWindow else {
            Logger.debug("No focused window for app pid=\(pid) (\(frontApp.localizedName ?? "?"))")
            return nil
        }

        guard CFGetTypeID(window) == AXUIElementGetTypeID() else {
            Logger.debug("Focused window attribute was not an AXUIElement for pid=\(pid)")
            return nil
        }

        return (pid, bounds(of: window as! AXUIElement))
    }

    // MARK: - Windows on Display

    static func windowsOnDisplay(_ display: Display, excludingPID: pid_t? = nil) -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            Logger.warn("CGWindowListCopyWindowInfo returned nil")
            return []
        }

        let screenFrame = display.bounds
        let excludedOwners = Set([
            "Window Server", "SystemUIServer", "NotificationCenter",
            "Control Center", "Spotlight", "System Events"
        ])

        var results: [WindowInfo] = []
        var seenPIDs = Set<pid_t>()

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let layerNumber = window[kCGWindowLayer as String] as? NSNumber,
                  let boundsObject = window[kCGWindowBounds as String] else {
                continue
            }

            let layer = layerNumber.int32Value
            guard layer >= 0 && layer <= Int32(kCGFloatingWindowLevel) else { continue }
            guard !excludedOwners.contains(ownerName) else { continue }

            var bounds = CGRect.zero
            guard CFGetTypeID(boundsObject as CFTypeRef) == CFDictionaryGetTypeID(),
                  CGRectMakeWithDictionaryRepresentation(boundsObject as! CFDictionary, &bounds) else {
                continue
            }

            // Reject windows that are too narrow or too short (toolbars, popups, etc.)
            guard bounds.width >= 200 && bounds.height >= 200 else { continue }

            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            guard screenFrame.contains(center) else { continue }

            if let excludePID = excludingPID, ownerPID == excludePID { continue }

            guard !seenPIDs.contains(ownerPID) else { continue }
            seenPIDs.insert(ownerPID)

            results.append(WindowInfo(pid: ownerPID, appName: ownerName, bounds: bounds))
        }

        Logger.debug("Found \(results.count) window(s) on display \(display.id)")
        return results
    }

    // MARK: - Focus

    @discardableResult
    static func focusBestWindow(on display: Display, excludingPID: pid_t? = nil) -> WindowInfo? {
        let windows = windowsOnDisplay(display, excludingPID: excludingPID)

        guard let best = windows.first else {
            if excludingPID != nil {
                let all = windowsOnDisplay(display, excludingPID: nil)
                if let fallback = all.first {
                    Logger.debug("Fallback: activating app \(fallback.appName) (pid=\(fallback.pid))")
                    return activateAndRaise(pid: fallback.pid, bounds: fallback.bounds) ? fallback : nil
                }
            }
            Logger.warn("No activatable windows on display \(display.id)")
            return nil
        }

        Logger.debug("Activating: \(best.appName) (pid=\(best.pid)) bounds=\(best.bounds)")
        return activateAndRaise(pid: best.pid, bounds: best.bounds) ? best : nil
    }

    // MARK: - Activation + Window Raising

    private static func activateAndRaise(pid: pid_t, bounds: CGRect) -> Bool {
        guard let runningApp = NSRunningApplication(processIdentifier: pid) else {
            Logger.warn("No NSRunningApplication for pid=\(pid)")
            return false
        }

        let activated = runningApp.activate(options: [.activateIgnoringOtherApps])
        if !activated {
            Logger.warn("activate() returned false for \(runningApp.localizedName ?? "?") (pid=\(pid))")
            return false
        }

        if let windowAX = findWindowAXElement(pid: pid, near: bounds) {
            let result = AXUIElementPerformAction(windowAX, kAXRaiseAction as CFString)
            if result == .success {
                Logger.debug("Raised window at bounds=\(bounds)")
            } else {
                Logger.debug("kAXRaiseAction failed: \(result.rawValue)")
            }
        } else {
            Logger.debug("Could not find AX window near bounds=\(bounds)")
        }

        return true
    }

    private static func findWindowAXElement(pid: pid_t, near targetBounds: CGRect) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)

        var windowList: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList) == .success,
              let windows = windowList as? [AXUIElement] else {
            return nil
        }

        let targetCenter = CGPoint(x: targetBounds.midX, y: targetBounds.midY)
        var bestWindow: AXUIElement?
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for window in windows {
            let wBounds = bounds(of: window)
            guard wBounds != .zero else { continue }

            let wCenter = CGPoint(x: wBounds.midX, y: wBounds.midY)
            let distance = hypot(targetCenter.x - wCenter.x, targetCenter.y - wCenter.y)

            if distance < bestDistance {
                bestDistance = distance
                bestWindow = window
            }
        }

        if let best = bestWindow, bestDistance < 100 {
            return best
        }
        return nil
    }

    // MARK: - Helpers

    private static func bounds(of window: AXUIElement) -> CGRect {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return .zero
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard let positionRef,
              let sizeRef,
              CFGetTypeID(positionRef) == AXValueGetTypeID(),
              CFGetTypeID(sizeRef) == AXValueGetTypeID() else {
            return .zero
        }

        let pos = positionRef as! AXValue
        let sz = sizeRef as! AXValue

        guard
              AXValueGetType(pos) == .cgPoint,
              AXValueGetType(sz) == .cgSize else {
            return .zero
        }

        AXValueGetValue(pos, .cgPoint, &position)
        AXValueGetValue(sz, .cgSize, &size)

        return CGRect(origin: position, size: size)
    }
}
