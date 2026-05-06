import AppKit

private final class IndicatorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class FocusIndicator {
    private static var currentWindow: NSWindow?
    private static var timer: Timer?
    private static var generation = 0

    /// Show a small focus HUD on the target display.
    static func show(on display: Display) {
        DispatchQueue.main.async {
            generation += 1
            let request = generation

            dismissCurrentWindow()

            // App/window activation can finish a beat after AXRaise returns.
            // Show the indicator after that reorder has settled, then bring it forward again.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                guard request == generation else { return }
                showNow(on: display, request: request)
            }
        }
    }

    private static func showNow(on display: Display, request: Int) {
        guard let screen = DisplayManager.nsScreen(for: display) else {
            Logger.debug("No NSScreen for display \(display.id)")
            return
        }

        let screenFrame = screen.frame
        let indicatorSize = NSSize(width: 58, height: 58)
        let indicatorFrame = NSRect(
            x: screenFrame.midX - indicatorSize.width / 2,
            y: screenFrame.midY - indicatorSize.height / 2,
            width: indicatorSize.width,
            height: indicatorSize.height
        )
        Logger.debug("Showing indicator display=\(display.id) cgBounds=\(display.bounds) nsFrame=\(screenFrame) indicatorFrame=\(indicatorFrame)")

        let window = IndicatorPanel(
            contentRect: indicatorFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.title = "Shift-Focus Indicator \(display.id)"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        window.ignoresMouseEvents = true
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .transient,
            .ignoresCycle
        ]
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = false

        let view = NSView(frame: NSRect(origin: .zero, size: indicatorSize))
        view.wantsLayer = true
        guard let rootLayer = view.layer else { return }
        rootLayer.cornerRadius = 17
        rootLayer.cornerCurve = .continuous
        rootLayer.backgroundColor = NSColor.black.withAlphaComponent(0.76).cgColor
        rootLayer.borderWidth = 0.7
        rootLayer.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        rootLayer.shadowColor = NSColor.black.cgColor
        rootLayer.shadowOpacity = 0.34
        rootLayer.shadowRadius = 18
        rootLayer.shadowOffset = NSSize(width: 0, height: -7)

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        let symbol = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: "Shift focus")?
            .withSymbolConfiguration(symbolConfig)
        let imageView = NSImageView(frame: NSRect(x: 14, y: 14, width: 30, height: 30))
        imageView.image = symbol
        imageView.symbolConfiguration = symbolConfig
        imageView.contentTintColor = .white
        imageView.imageScaling = .scaleProportionallyUpOrDown
        view.addSubview(imageView)
        window.contentView = view

        window.alphaValue = 0
        window.setFrame(indicatorFrame, display: true)
        window.orderFrontRegardless()
        currentWindow = window

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0.92
        }

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.92
        scale.toValue = 1
        scale.duration = 0.18
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        rootLayer.add(scale, forKey: "scaleIn")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard request == generation, currentWindow === window else { return }
            window.orderFrontRegardless()
            Logger.debug("Indicator ordered display=\(display.id) actualFrame=\(window.frame) level=\(window.level.rawValue)")
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.58, repeats: false) { _ in
            DispatchQueue.main.async {
                guard request == generation, currentWindow === window else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.16
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    window.animator().alphaValue = 0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    guard request == generation, currentWindow === window else { return }
                    dismissCurrentWindow()
                }
            }
        }
    }

    private static func dismissCurrentWindow() {
        timer?.invalidate()
        timer = nil
        currentWindow?.orderOut(nil)
        currentWindow?.contentView = nil
        currentWindow = nil
    }

    /// Move the mouse cursor to the center of the given display.
    /// Used as fallback when the display has no windows to focus.
    static func moveCursor(to display: Display) {
        let center = CGPoint(x: display.bounds.midX, y: display.bounds.midY)
        moveCursor(to: center)
        Logger.debug("Cursor moved to display \(display.id) center=\(center)")
    }

    static func moveCursor(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        Logger.debug("Cursor moved to point \(point)")
    }
}
