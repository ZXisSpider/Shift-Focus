import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    private static let moveCursorWithFocusKey = "moveCursorWithFocus"

    private var statusItem: NSStatusItem!
    private let hotKeyManager = HotKeyManager()

    private var moveCursorWithFocus: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.moveCursorWithFocusKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.moveCursorWithFocusKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.moveCursorWithFocusKey)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.info("Shift-Focus launched — log at \(Logger.logFilePath)")
        DisplayManager.logLayout()
        checkAccessibilityPermissions()
        setupStatusBar()
        registerHotKeys()
    }

    // MARK: - Accessibility

    private func checkAccessibilityPermissions() {
        // Temporarily switch to regular mode so TCC dialog can appear
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            let trusted = AXIsProcessTrustedWithOptions(options)
            // Restore accessory mode (hidden from Dock)
            NSApp.setActivationPolicy(.accessory)
            if trusted {
                Logger.info("Accessibility access granted")
            } else {
                Logger.warn("Accessibility not granted")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    if !AXIsProcessTrusted() {
                        self?.showAccessibilityGuide()
                    }
                }
            }
        }
    }

    private func showAccessibilityGuide() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Grant Accessibility Permission"
        alert.informativeText = """
        To use Shift-Focus, add it to Accessibility permissions:

        1. Click \"Open System Settings\" below
        2. Click the \"+\" button at the bottom of the list
        3. Navigate to /Applications/
        4. Select Shift-Focus.app and enable it
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = ""
            button.image = statusBarIcon()
            button.imagePosition = .imageOnly
        }
        statusItem.behavior = .terminationOnRemoval

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About Shift-Focus", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        let moveCursorItem = NSMenuItem(
            title: "Move Cursor with Focus",
            action: #selector(toggleMoveCursorWithFocus),
            keyEquivalent: ""
        )
        moveCursorItem.state = moveCursorWithFocus ? .on : .off
        menu.addItem(moveCursorItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        Logger.debug("Status bar item created")
    }

    private func statusBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 18, height: 18).fill()

        NSColor.labelColor.setFill()

        let upper = NSBezierPath()
        upper.move(to: NSPoint(x: 4.1, y: 11.0))
        upper.curve(to: NSPoint(x: 14.2, y: 10.8), controlPoint1: NSPoint(x: 6.7, y: 14.0), controlPoint2: NSPoint(x: 12.0, y: 14.2))
        upper.curve(to: NSPoint(x: 14.2, y: 5.7), controlPoint1: NSPoint(x: 15.6, y: 8.7), controlPoint2: NSPoint(x: 15.3, y: 6.1))
        upper.curve(to: NSPoint(x: 11.7, y: 8.3), controlPoint1: NSPoint(x: 12.8, y: 5.2), controlPoint2: NSPoint(x: 13.0, y: 7.0))
        upper.curve(to: NSPoint(x: 4.5, y: 10.4), controlPoint1: NSPoint(x: 10.0, y: 10.0), controlPoint2: NSPoint(x: 6.8, y: 10.9))
        upper.curve(to: NSPoint(x: 4.1, y: 11.0), controlPoint1: NSPoint(x: 3.7, y: 10.2), controlPoint2: NSPoint(x: 3.5, y: 11.0))
        upper.close()
        upper.fill()

        let lower = NSBezierPath()
        lower.move(to: NSPoint(x: 5.4, y: 4.2))
        lower.curve(to: NSPoint(x: 10.3, y: 8.5), controlPoint1: NSPoint(x: 7.3, y: 6.8), controlPoint2: NSPoint(x: 8.3, y: 8.1))
        lower.curve(to: NSPoint(x: 12.7, y: 5.5), controlPoint1: NSPoint(x: 12.0, y: 8.8), controlPoint2: NSPoint(x: 13.5, y: 7.0))
        lower.curve(to: NSPoint(x: 5.6, y: 3.2), controlPoint1: NSPoint(x: 11.7, y: 3.6), controlPoint2: NSPoint(x: 9.3, y: 3.1))
        lower.curve(to: NSPoint(x: 5.4, y: 4.2), controlPoint1: NSPoint(x: 4.0, y: 3.2), controlPoint2: NSPoint(x: 4.5, y: 5.3))
        lower.close()
        lower.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Shift-Focus"
        alert.informativeText = """
        Switch keyboard focus between displays.

        Ctrl+Option+Right Arrow → next display (right)
        Ctrl+Option+Left Arrow  → previous display (left)
        Ctrl+Option+1/2/3       → jump to display 1/2/3

        Requires Accessibility permission.
        """
        alert.runModal()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                sender.state = .off
                Logger.info("Launch at Login disabled")
            } else {
                try SMAppService.mainApp.register()
                sender.state = .on
                Logger.info("Launch at Login enabled")
            }
        } catch {
            Logger.error("Launch at Login toggle failed: \(error)")
        }
    }

    @objc private func toggleMoveCursorWithFocus(_ sender: NSMenuItem) {
        moveCursorWithFocus.toggle()
        sender.state = moveCursorWithFocus ? .on : .off
        Logger.info("Move Cursor with Focus \(moveCursorWithFocus ? "enabled" : "disabled")")
    }

    // MARK: - HotKeys

    private func registerHotKeys() {
        hotKeyManager.register { [weak self] action in
            self?.handleAction(action)
        }
    }

    private func handleAction(_ action: HotKeyAction) {
        guard AXIsProcessTrusted() else {
            Logger.warn("Accessibility not trusted — showing prompt")
            promptForAccessibility()
            return
        }

        switch action {
        case .direction(let direction):
            shiftFocus(direction: direction)
        case .displayNumber(let num):
            jumpToDisplay(number: num)
        }
    }

    private func shiftFocus(direction: DisplayDirection) {
        let displays = DisplayManager.allDisplays()
        Logger.debug("Shift direction: \(direction), displays: \(displays.count)")

        // Determine current display
        let currentDisplay: Display
        if let (_, bounds) = WindowManager.getCurrentFocusedWindow() {
            currentDisplay = DisplayManager.displayContaining(point: CGPoint(x: bounds.midX, y: bounds.midY))
                ?? displays.first!
        } else {
            currentDisplay = displays.first!
        }
        Logger.debug("Current display: id=\(currentDisplay.id) frame=\(currentDisplay.bounds)")

        // Target display
        let targetDisplay = DisplayManager.nextDisplay(after: currentDisplay, direction: direction)
        Logger.debug("Target display: id=\(targetDisplay.id) frame=\(targetDisplay.bounds)")

        // Single display: cycle windows on same display
        if displays.count == 1 || targetDisplay.id == currentDisplay.id {
            Logger.debug("Same display — cycling windows")
            let currentPID = WindowManager.getCurrentFocusedWindow()?.pid
            let focusedWindow = WindowManager.focusBestWindow(on: currentDisplay, excludingPID: currentPID)
                ?? WindowManager.focusBestWindow(on: currentDisplay, excludingPID: nil)
            if let focusedWindow {
                moveCursorIfNeeded(to: focusedWindow)
                FocusIndicator.show(on: currentDisplay)
            }
            return
        }

        if let focusedWindow = WindowManager.focusBestWindow(on: targetDisplay) {
            Logger.info("Focus shifted to display \(targetDisplay.id)")
            moveCursorIfNeeded(to: focusedWindow)
            FocusIndicator.show(on: targetDisplay)
        } else {
            Logger.warn("No windows on display \(targetDisplay.id)")
            moveCursorIfNeeded(to: targetDisplay)
            FocusIndicator.show(on: targetDisplay)
        }
    }

    private func jumpToDisplay(number: Int) {
        let displays = DisplayManager.allDisplays()
        Logger.debug("Jump to display number: \(number), displays: \(displays.count)")

        guard let targetDisplay = DisplayManager.display(forNumber: number) else {
            Logger.warn("Display number \(number) not available")
            NSSound.beep()
            return
        }

        let currentPID = WindowManager.getCurrentFocusedWindow()?.pid
        if let focusedWindow = WindowManager.focusBestWindow(on: targetDisplay, excludingPID: currentPID) {
            Logger.info("Jumped to display \(number) (id=\(targetDisplay.id))")
            moveCursorIfNeeded(to: focusedWindow)
            FocusIndicator.show(on: targetDisplay)
        } else {
            Logger.warn("No windows on display \(number)")
            moveCursorIfNeeded(to: targetDisplay)
            FocusIndicator.show(on: targetDisplay)
        }
    }

    private func moveCursorIfNeeded(to window: WindowManager.WindowInfo) {
        guard moveCursorWithFocus else { return }
        let center = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
        FocusIndicator.moveCursor(to: center)
    }

    private func moveCursorIfNeeded(to display: Display) {
        guard moveCursorWithFocus else { return }
        FocusIndicator.moveCursor(to: display)
    }

    private func promptForAccessibility() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = """
        Shift-Focus needs Accessibility access to move focus between displays.

        1. Click \"Open System Settings\" below
        2. Click the \"+\" button at the bottom of the list
        3. Navigate to /Applications/
        4. Select Shift-Focus.app and enable it
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }
}
