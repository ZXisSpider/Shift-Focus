import AppKit
import CoreGraphics

struct Display {
    let id: CGDirectDisplayID
    let bounds: CGRect
}

enum DisplayDirection {
    case left
    case right
}

enum DisplayManager {

    /// All active displays sorted left-to-right by x-origin.
    static func allDisplays() -> [Display] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else { return [] }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }

        let displays = ids.map { Display(id: $0, bounds: CGDisplayBounds($0)) }
        return displays.sorted { $0.bounds.origin.x < $1.bounds.origin.x }
    }

    /// The display whose bounds contain the given point (in Quartz coordinates), or nil.
    static func displayContaining(point: CGPoint) -> Display? {
        allDisplays().first { $0.bounds.contains(point) }
    }

    /// The next display in the given direction, wrapping around.
    static func nextDisplay(after current: Display, direction: DisplayDirection) -> Display {
        let displays = allDisplays()
        guard displays.count > 1,
              let idx = displays.firstIndex(where: { $0.id == current.id }) else {
            return current
        }

        switch direction {
        case .right:
            return displays[(idx + 1) % displays.count]
        case .left:
            return displays[(idx - 1 + displays.count) % displays.count]
        }
    }

    /// The nth display (1-based), or nil.
    static func display(forNumber num: Int) -> Display? {
        let displays = allDisplays()
        guard num >= 1 && num <= displays.count else { return nil }
        return displays[num - 1]
    }

    /// The NSScreen matching a given Display, for NSWindow positioning.
    static func nsScreen(for display: Display) -> NSScreen? {
        NSScreen.screens.first { screen in
            let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            return num == display.id
        }
    }

    /// Log the current display layout.
    static func logLayout() {
        let displays = allDisplays()
        Logger.info("Detected \(displays.count) display(s):")
        for (i, d) in displays.enumerated() {
            Logger.info("  Display \(i + 1): frame=\(d.bounds) size=\(Int(d.bounds.width))x\(Int(d.bounds.height))")
        }
    }
}
