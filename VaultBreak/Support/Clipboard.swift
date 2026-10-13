import AppKit
import Foundation

/// Abstraction over pasteboard write/clear for unit tests.
protocol PasteboardProviding: AnyObject {
    func setString(_ value: String)
    func clearString()
    func currentString() -> String?
}

final class SystemPasteboard: PasteboardProviding {
    func setString(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

    func clearString() {
        NSPasteboard.general.clearContents()
    }

    func currentString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}

/// Schedules delayed work (e.g. clipboard clear). Injectable for tests.
protocol ClipboardClearScheduling: AnyObject {
    func schedule(after delay: TimeInterval, block: @escaping () -> Void)
    func cancelScheduled()
}

final class DispatchClipboardClearScheduler: ClipboardClearScheduling {
    private var pending: DispatchWorkItem?

    func schedule(after delay: TimeInterval, block: @escaping () -> Void) {
        cancelScheduled()
        let item = DispatchWorkItem(block: block)
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancelScheduled() {
        pending?.cancel()
        pending = nil
    }
}

/// Copies a string to the pasteboard and clears it after a delay. Reschedules on repeat copy.
final class ClipboardClearService {
    let pasteboard: PasteboardProviding
    let scheduler: ClipboardClearScheduling
    let clearAfterSeconds: TimeInterval

    init(
        pasteboard: PasteboardProviding = SystemPasteboard(),
        scheduler: ClipboardClearScheduling = DispatchClipboardClearScheduler(),
        clearAfterSeconds: TimeInterval = 30
    ) {
        self.pasteboard = pasteboard
        self.scheduler = scheduler
        self.clearAfterSeconds = clearAfterSeconds
    }

    func copyWithTimedClear(_ value: String) {
        pasteboard.setString(value)
        scheduler.schedule(after: clearAfterSeconds) { [weak self] in
            self?.pasteboard.clearString()
        }
    }

    func cancelPendingClear() {
        scheduler.cancelScheduled()
    }
}
