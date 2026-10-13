import XCTest
@testable import VaultBreak

private final class MockPasteboard: PasteboardProviding {
    private(set) var string: String?
    private(set) var clearCount = 0

    func setString(_ value: String) {
        string = value
    }

    func clearString() {
        string = nil
        clearCount += 1
    }

    func currentString() -> String? {
        string
    }
}

private final class MockClipboardScheduler: ClipboardClearScheduling {
    private(set) var scheduledDelay: TimeInterval?
    private(set) var scheduledBlock: (() -> Void)?
    private(set) var cancelCount = 0

    func schedule(after delay: TimeInterval, block: @escaping () -> Void) {
        cancelScheduled()
        scheduledDelay = delay
        scheduledBlock = block
    }

    func cancelScheduled() {
        guard scheduledBlock != nil else { return }
        cancelCount += 1
        scheduledBlock = nil
    }
}

final class ClipboardTests: XCTestCase {
    func testCopyWithTimedClearWritesPasteboardAndSchedulesClear() {
        let pasteboard = MockPasteboard()
        let scheduler = MockClipboardScheduler()
        let service = ClipboardClearService(
            pasteboard: pasteboard,
            scheduler: scheduler,
            clearAfterSeconds: 30
        )

        service.copyWithTimedClear("secret-value")

        XCTAssertEqual(pasteboard.string, "secret-value")
        XCTAssertEqual(scheduler.scheduledDelay, 30)
        XCTAssertNotNil(scheduler.scheduledBlock)

        scheduler.scheduledBlock?()
        XCTAssertNil(pasteboard.string)
        XCTAssertEqual(pasteboard.clearCount, 1)
    }

    func testSecondCopyCancelsPreviousScheduledClear() {
        let pasteboard = MockPasteboard()
        let scheduler = MockClipboardScheduler()
        let service = ClipboardClearService(pasteboard: pasteboard, scheduler: scheduler, clearAfterSeconds: 30)

        service.copyWithTimedClear("first")
        XCTAssertEqual(scheduler.cancelCount, 0)

        service.copyWithTimedClear("second")
        XCTAssertEqual(scheduler.cancelCount, 1)
        XCTAssertEqual(pasteboard.string, "second")
    }
}
