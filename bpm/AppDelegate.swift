//
//  AppDelegate.swift
//  bpm
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!

    let tapper = BPMTapper()

    /// `UserDefaults` key recording that the welcome / instructions popup has
    /// been auto-shown at least once. Once `true`, the popup never auto-fires
    /// again — but ⌥-click still opens it manually on demand. There is no UI
    /// to flip this back to `false`; "first-launch only" is the contract.
    static let hasShownInstructionsKey = "hasShownInstructionsOnFirstLaunch"

    /// Last numeric BPM string displayed in the menu bar. Cleared back to nil
    /// whenever we drop out of the "showing a measured BPM" state, so ⌘-click
    /// has an unambiguous signal for "is there anything to copy?".
    var lastBPMString: String?

    /// One point smaller than the default menu bar font. The status item is
    /// sized for this font specifically (see `fixedStatusItemLength`), so changing
    /// the size here will change the item's width as well.
    let menuBarFont: NSFont = {
        let defaultFont = NSFont.menuBarFont(ofSize: 0)
        return NSFont.menuBarFont(ofSize: defaultFont.pointSize - 1)
    }()

    /// Fixed width sized to the widest possible 3-digit BPM string ("888") in
    /// `menuBarFont`. The default `NSStatusItem` behavior is `variableLength`,
    /// which makes the item width follow the title text and causes the menu bar
    /// to jitter as BPM digits change (e.g. 90 → 100 → 99). Pinning to "888"
    /// keeps the layout stable regardless of the current reading.
    lazy var fixedStatusItemLength: CGFloat = {
        let width = ("888" as NSString).size(withAttributes: [.font: menuBarFont]).width
        return ceil(width)
    }()

    /// SF Symbol used as the idle/"ready" indicator instead of literal "bpm" text.
    /// Marked as a template image so AppKit tints it to match the current menu bar
    /// appearance (light/dark mode, increased-contrast, etc.). The point size and
    /// weight are tuned by eye to read at roughly the same visual weight as native
    /// system glyphs in the menu bar.
    lazy var placeholderImage: NSImage? = {
        let image = NSImage(systemSymbolName: "music.quarternote.3", accessibilityDescription: "BPM")
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let configured = image?.withSymbolConfiguration(config)
        configured?.isTemplate = true
        return configured
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusBarItem = NSStatusBar.system.statusItem(withLength: fixedStatusItemLength)

        // Route both left- and right-mouse-up events through `handleClick`; the
        // modifier keys and event type are inspected there to pick an action.
        if let button = statusBarItem.button {
            button.action = #selector(self.handleClick(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.keyEquivalent = ""
        }

        updateButton(withString: tapper.placeholderString)

        // We're a menu-bar-only app: no dock icon, no main window.
        NSApplication.shared.setActivationPolicy(.accessory)

        // First-ever launch only: auto-show the instructions popup so a new
        // user has any hope of discovering the click-modifier controls. The
        // flag is flipped immediately and persists across launches, so this
        // never fires again — manual ⌥-click remains the way back in.
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: AppDelegate.hasShownInstructionsKey) {
            defaults.set(true, forKey: AppDelegate.hasShownInstructionsKey)
            aboutApp()
        }
    }

    /// Single entry point for every interaction with the menu bar item.
    /// Modifier keys and click type are decoded here into one of:
    ///   ⌃-click             → quit
    ///   ⌥-click             → show the instructions popup
    ///   ⌘-click (left only) → copy the current BPM to the clipboard
    ///   right-click         → reset (delegated to `BPMTapper`)
    ///   plain left-click    → register a tap
    @objc func handleClick(sender: NSStatusItem?) {
        // `currentEvent` is normally non-nil during a click, but action methods
        // can also be invoked programmatically (accessibility, scripting), in
        // which case there's no event to inspect. Bail safely instead of
        // force-unwrapping and crashing.
        guard let clickEvent = NSApp.currentEvent else { return }

        let wasRightClick = clickEvent.type == NSEvent.EventType.rightMouseUp
        let modifiers = clickEvent.modifierFlags

        if modifiers.contains(.control) {
            NSApplication.shared.terminate(self)

        } else if modifiers.contains(.option) {
            aboutApp()

        } else if modifiers.contains(.command) && !wasRightClick {
            // ⌘-right-click would be ambiguous (copy AND reset); we honor the
            // right-click reset in that case and ignore the ⌘ modifier.
            copyCurrentBPMToPasteboard()

        } else {
            updateButton(
                withString: tapper.click(
                    withResetCallback: updateButton(withString:),
                    andWasRightClick: wasRightClick
                )
            )
        }
    }

    /// Render whatever string `BPMTapper` produced (or the idle placeholder)
    /// into the menu bar item. Three visual states:
    ///   • placeholder       → SF Symbol, no text, nothing copyable
    ///   • "..." (1 tap)     → text, no copyable BPM yet
    ///   • numeric BPM (2+)  → text, copyable via ⌘-click
    /// Tooltip is updated alongside the visuals so a hover always documents
    /// what the user can currently do.
    @objc func updateButton(withString string: String) {
        guard let button = statusBarItem.button else { return }

        if string == tapper.placeholderString {
            // Clear both title and attributedTitle — AppKit will fall back to
            // displaying nothing for either, but leaving a stale attributedTitle
            // around can occasionally re-render on appearance changes.
            button.attributedTitle = NSAttributedString(string: "")
            button.title = ""
            button.image = placeholderImage
            lastBPMString = nil
            button.toolTip = "BPM Tapper — click to tap"

        } else if string == tapper.waitingForSecondString {
            button.image = nil
            button.attributedTitle = NSAttributedString(
                string: string,
                attributes: [.font: menuBarFont]
            )
            lastBPMString = nil
            button.toolTip = "Keep tapping…"

        } else {
            button.image = nil
            button.attributedTitle = NSAttributedString(
                string: string,
                attributes: [.font: menuBarFont]
            )
            lastBPMString = string
            button.toolTip = "\(string) BPM — ⌘-click to copy"
        }
    }

    /// Copy the most recently displayed BPM number to the system pasteboard.
    /// Beeps if there's nothing to copy (placeholder state or only one tap
    /// registered so far) — silently doing nothing would feel like a bug.
    func copyCurrentBPMToPasteboard() {
        guard let bpm = lastBPMString else {
            NSSound.beep()
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(bpm, forType: .string)
    }

    /// Show the in-app instructions popup. With no dock icon, menu, or
    /// preferences pane, this alert is the only place the click-modifier
    /// behaviors are documented. Auto-shown once on first launch
    /// (gated by `hasShownInstructionsKey`); thereafter reachable only via
    /// ⌥-click on the menu bar item.
    ///
    /// The controls table is rendered in an `accessoryView` so we can use a
    /// real tab-stop column alignment in the system font rather than padding
    /// with spaces (which only lines up under a monospaced font).
    func aboutApp() {
        let intro = "BPM is a lightweight beats-per-minute tapper that lives in your menu bar. Click the icon in time with the beat and it reports the average BPM."

        let controls: [(String, String)] = [
            ("Click",       "tap in time with the beat"),
            ("Right-click", "reset"),
            ("⌘-Click",     "copy the current BPM to the clipboard"),
            ("⌥-Click",     "show this window again"),
            ("⌃-Click",     "quit the app"),
        ]

        let popup = NSAlert()
        popup.messageText = "BPM"
        popup.informativeText = intro
        popup.alertStyle = .informational
        popup.addButton(withTitle: "OK")
        popup.accessoryView = makeControlsAccessoryView(controls: controls,
                                                        footnote: "The display auto-resets after ~1.5 seconds without a tap.")
        popup.runModal()
    }

    /// Build the controls table for `aboutApp()`. Uses a left-aligned tab stop
    /// at a fixed point offset so the second column (descriptions) aligns
    /// regardless of the width of the first column (control name) in the
    /// system font. `headIndent` matches the tab stop so a description that
    /// wraps onto a second line hangs under itself rather than wrapping all
    /// the way back to the left margin.
    private func makeControlsAccessoryView(controls: [(String, String)], footnote: String) -> NSView {
        // Keep `preferredWidth` at or below NSAlert's standard right-of-icon
        // text column width (~290pt). Going wider forces the alert into its
        // "wide" layout, which moves the app icon from the left to the top.
        let columnGap: CGFloat = 90           // x-coord where column 2 begins
        let preferredWidth: CGFloat = 285     // accessory view target width

        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)

        let tableParagraph = NSMutableParagraphStyle()
        tableParagraph.tabStops = [NSTextTab(textAlignment: .left, location: columnGap, options: [:])]
        tableParagraph.defaultTabInterval = columnGap
        tableParagraph.headIndent = columnGap

        let body = NSMutableAttributedString()

        // "Controls:" heading, slightly heavier for visual structure.
        body.append(NSAttributedString(string: "Controls:\n", attributes: [.font: boldFont]))

        // Table rows: "<name>\t<description>" with the tab stop doing the alignment.
        for (name, desc) in controls {
            body.append(NSAttributedString(
                string: "\(name)\t\(desc)\n",
                attributes: [.font: font, .paragraphStyle: tableParagraph]
            ))
        }

        // Blank line, then the footnote.
        body.append(NSAttributedString(string: "\n\(footnote)", attributes: [.font: font]))

        let label = NSTextField(labelWithAttributedString: body)
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = preferredWidth
        label.frame = NSRect(x: 0, y: 0, width: preferredWidth, height: 0)
        label.sizeToFit()
        return label
    }
}
