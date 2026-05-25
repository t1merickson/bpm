//
//  BPMTapper.swift
//  bpm
//

import Foundation

/// Computes a running average BPM from successive tap events.
///
/// The model is "first tap is a free zero" — only the *intervals* between taps
/// are meaningful, so after N taps we have N-1 intervals to average. A reset
/// timer (`resetInterval`) automatically clears state if the user stops
/// tapping, so the app returns to the idle/placeholder state without explicit
/// user intervention.
class BPMTapper {

    /// String shown in the idle state. `AppDelegate` matches on this value to
    /// decide whether to render the SF Symbol vs. text — it's a sentinel as
    /// much as a label.
    let placeholderString = "bpm"

    /// Shown after exactly one tap, before there's enough data to compute a
    /// real BPM. Also used as a sentinel by `AppDelegate`.
    let waitingForSecondString = "..."

    /// Timestamp of the most recent tap. Used to compute the next inter-tap
    /// interval. Kept as `NSDate` for the timezone-agnostic `timeIntervalSince`
    /// API; bridges freely to Swift `Date` if ever needed.
    var lastPress: NSDate = NSDate()

    /// How long to wait after the last tap before auto-resetting back to the
    /// placeholder. 1.5s is short enough that stale readings don't linger but
    /// long enough to accommodate tempos down to ~40 BPM.
    let resetInterval: Double = 1.5
    var resetTimer: Timer = Timer()

    /// Number of taps in the current measurement burst (cleared on reset).
    var nClicks: UInt = 0

    /// Running mean of inter-tap intervals, in seconds. 60 / this = BPM.
    var averageInterval: Double = 0

    /// `averageInterval` formatted as a rounded integer BPM string.
    /// Only meaningful once at least two taps have been recorded; calling
    /// this with `averageInterval == 0` would divide by zero.
    var averageIntervalAsString: String {
        return String(Int(60 / self.averageInterval))
    }

    /// Fold a new inter-tap interval into the running average and return the
    /// string to display.
    ///
    /// First tap: no interval exists yet → returns `waitingForSecondString`.
    /// Subsequent taps: incremental mean update — we rebuild the total from
    /// the previous average × (n-2) intervals, add the new interval, and
    /// divide by (n-1) intervals. This is mathematically equivalent to
    /// summing all intervals and dividing, but avoids keeping the full
    /// history around.
    func recordInterval(withNewInterval newInterval: Double) -> String {
        self.nClicks += 1

        if self.nClicks == 1 {
            self.averageInterval = 0
            return self.waitingForSecondString

        } else {
            let intervalCount = Double(self.nClicks - 1)
            let totalTime = (self.averageInterval * (intervalCount - 1)) + newInterval
            self.averageInterval = totalTime / intervalCount
            return self.averageIntervalAsString
        }
    }

    /// Handle a single click from the menu bar item.
    ///
    /// - Parameters:
    ///   - callback: invoked by the auto-reset timer (1.5s after the last tap)
    ///     with the placeholder string, so `AppDelegate` can restore the idle
    ///     visuals without `BPMTapper` needing a reference back to the UI.
    ///   - rightClick: if `true`, treat this click as a manual reset rather
    ///     than a tap. The reset still arms the auto-reset timer below, but
    ///     `lastPress` is updated to "now" so the next tap measures a fresh
    ///     interval from this moment.
    func click(withResetCallback callback: @escaping (String) -> Void, andWasRightClick rightClick: Bool) -> String {

        if rightClick {
            self.clear()
            self.lastPress = NSDate()
        }

        // Re-arm the auto-reset timer on every click. The previous timer (if
        // any) is invalidated first so we don't accumulate scheduled fires.
        self.resetTimer.invalidate()
        self.resetTimer = Timer.scheduledTimer(withTimeInterval: self.resetInterval, repeats: false) { _ in
            callback(self.reset())
        }

        let thisInterval = NSDate().timeIntervalSince(self.lastPress as Date)
        self.lastPress = NSDate()

        return self.recordInterval(withNewInterval: thisInterval)
    }

    /// Wipe averaging state without touching the reset timer. Used internally
    /// by `reset()` and externally by `click(...)` on a right-click reset.
    func clear() {
        self.nClicks = 0
        self.averageInterval = 0
    }

    /// Full reset: wipe averaging state, cancel the auto-reset timer (since
    /// it's the thing that called us, or we're being called manually and don't
    /// want a stale fire later), and return the placeholder string for the UI
    /// to render.
    func reset() -> String {
        self.clear()
        self.resetTimer.invalidate()
        return self.placeholderString
    }
}
