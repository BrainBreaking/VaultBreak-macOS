import XCTest
@testable import VaultBreak

private func sampleHandoff(
    id: String = "ho-1",
    title: String = "Share DB creds",
    status: String = HandoffAttention.pendingStatus
) -> Handoff {
    let date = ISO8601DateFormatter().date(from: "2026-03-01T12:00:00Z")!
    return Handoff(
        id: id,
        title: title,
        message: nil,
        status: status,
        expiresAt: date,
        oneTime: true,
        secretCount: 1,
        secretId: "sec-1",
        createdAt: date,
        viewedAt: nil,
        appliedAt: nil
    )
}

@MainActor
final class HandoffAttentionTests: XCTestCase {
    func testHandoffFixtureDecodesFromJSON() throws {
        let json = """
        {
          "handoffs": [
            {
              "id": "h-abc",
              "title": "Onboarding",
              "message": "Please apply",
              "status": "pending",
              "expiresAt": "2026-04-01T18:30:00Z",
              "oneTime": false,
              "secretCount": 2,
              "secretId": "s-99",
              "createdAt": "2026-03-15T09:00:00Z",
              "viewedAt": null,
              "appliedAt": null
            },
            {
              "id": "h-done",
              "title": "Old",
              "status": "revoked",
              "expiresAt": "2026-02-01T00:00:00Z",
              "oneTime": true,
              "secretCount": 0,
              "createdAt": "2026-01-01T00:00:00Z"
            }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        struct Wrapper: Decodable {
            let handoffs: [Handoff]
        }
        let wrapper = try decoder.decode(Wrapper.self, from: Data(json.utf8))
        XCTAssertEqual(wrapper.handoffs.count, 2)
        XCTAssertEqual(wrapper.handoffs[0].id, "h-abc")
        XCTAssertEqual(wrapper.handoffs[0].status, "pending")
        XCTAssertEqual(wrapper.handoffs[0].message, "Please apply")
        XCTAssertEqual(wrapper.handoffs[1].status, "revoked")
    }

    func testNeedsAttentionWhenPendingExists() {
        let handoffs = [
            sampleHandoff(status: "viewed"),
            sampleHandoff(id: "ho-2", status: HandoffAttention.pendingStatus),
        ]
        XCTAssertTrue(HandoffAttention.needsAttention(handoffs: handoffs))
        XCTAssertEqual(HandoffAttention.pendingHandoffs(from: handoffs).map(\.id), ["ho-2"])
    }

    func testNeedsAttentionFalseWhenNoPending() {
        let handoffs = [
            sampleHandoff(status: "applied"),
            sampleHandoff(id: "ho-2", status: "revoked"),
        ]
        XCTAssertFalse(HandoffAttention.needsAttention(handoffs: handoffs))
        XCTAssertTrue(HandoffAttention.pendingHandoffs(from: handoffs).isEmpty)
    }

    func testHandoffAttentionModelRefreshSetsAttention() async {
        let client = MockHandoffsAPIClient(
            listResult: .success([
                sampleHandoff(),
                sampleHandoff(id: "ho-2", status: "applied"),
            ])
        )
        let model = HandoffAttentionModel(clientFactory: { client })
        model.setPollingActive(true)
        await model.refresh()
        XCTAssertTrue(model.needsAttention)
        XCTAssertEqual(model.pendingHandoffs.count, 1)
        XCTAssertEqual(model.pendingHandoffs[0].id, "ho-1")
    }

    func testStartPollingUsesSixtySecondInterval() {
        let scheduler = MockHandoffPollingScheduler()
        let model = HandoffAttentionModel(
            clientFactory: { MockHandoffsAPIClient(listResult: .success([])) },
            scheduler: scheduler
        )
        model.setPollingActive(true)
        XCTAssertEqual(scheduler.startCount, 1)
        XCTAssertEqual(scheduler.lastInterval, 60)
    }

    func testStopPollingClearsAttentionState() async {
        let client = MockHandoffsAPIClient(listResult: .success([sampleHandoff()]))
        let scheduler = MockHandoffPollingScheduler()
        let model = HandoffAttentionModel(clientFactory: { client }, scheduler: scheduler)
        model.setPollingActive(true)
        await model.refresh()
        XCTAssertTrue(model.needsAttention)
        model.setPollingActive(false)
        XCTAssertFalse(model.needsAttention)
        XCTAssertTrue(model.pendingHandoffs.isEmpty)
        XCTAssertEqual(scheduler.cancelCount, 1)
    }
}

@MainActor
private final class MockHandoffsAPIClient: HandoffsAPIClient, @unchecked Sendable {
    let listResult: Result<[Handoff], Error>
    var revokeResult: Result<Handoff, Error> = .failure(APIClientError.invalidHandoffID)

    init(listResult: Result<[Handoff], Error>) {
        self.listResult = listResult
    }

    func listHandoffs() async throws -> [Handoff] {
        try listResult.get()
    }

    func revokeHandoff(id: String) async throws -> Handoff {
        try revokeResult.get()
    }
}

private final class MockHandoffPollingCancellable: HandoffPollingCancellable {
    private(set) var cancelled = false
    var onCancel: (@Sendable () -> Void)?

    func cancel() {
        cancelled = true
        onCancel?()
    }
}

private final class MockHandoffPollingScheduler: HandoffPollingScheduler {
    private(set) var startCount = 0
    private(set) var cancelCount = 0
    private(set) var lastInterval: TimeInterval?
    private(set) var lastCancellable: MockHandoffPollingCancellable?
    private var tick: (@Sendable () -> Void)?

    func start(interval: TimeInterval, tick: @escaping @Sendable () -> Void) -> any HandoffPollingCancellable {
        startCount += 1
        lastInterval = interval
        self.tick = tick
        let cancellable = MockHandoffPollingCancellable()
        cancellable.onCancel = { [weak self] in
            self?.cancelCount += 1
        }
        lastCancellable = cancellable
        return cancellable
    }
}
