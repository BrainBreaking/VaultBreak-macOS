import AppKit
import Combine
import Foundation

/// Schedules periodic handoff refresh (injectable for tests).
protocol HandoffPollingScheduler: Sendable {
    func start(interval: TimeInterval, tick: @escaping @Sendable () -> Void) -> any HandoffPollingCancellable
}

protocol HandoffPollingCancellable: Sendable {
    func cancel()
}

struct DefaultHandoffPollingScheduler: HandoffPollingScheduler {
    func start(interval: TimeInterval, tick: @escaping @Sendable () -> Void) -> any HandoffPollingCancellable {
        HandoffPollingTask(interval: interval, tick: tick)
    }
}

private final class HandoffPollingTask: HandoffPollingCancellable, @unchecked Sendable {
    private let task: Task<Void, Never>?

    init(interval: TimeInterval, tick: @escaping @Sendable () -> Void) {
        task = Task {
            let nanos = UInt64(max(interval, 1) * 1_000_000_000)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: nanos)
                if Task.isCancelled { break }
                tick()
            }
        }
    }

    func cancel() {
        task?.cancel()
    }
}

@MainActor
final class HandoffAttentionModel: ObservableObject {
    static let defaultPollInterval: TimeInterval = 60

    @Published private(set) var pendingHandoffs: [Handoff] = []
    @Published private(set) var needsAttention: Bool = false
    @Published private(set) var lastError: String?

    private let clientFactory: () throws -> any HandoffsAPIClient
    private let pollInterval: TimeInterval
    private let scheduler: any HandoffPollingScheduler
    private var pollCancellable: (any HandoffPollingCancellable)?
    private var shouldPoll = false

    init(
        clientFactory: @escaping () throws -> any HandoffsAPIClient,
        pollInterval: TimeInterval = HandoffAttentionModel.defaultPollInterval,
        scheduler: any HandoffPollingScheduler = DefaultHandoffPollingScheduler()
    ) {
        self.clientFactory = clientFactory
        self.pollInterval = pollInterval
        self.scheduler = scheduler
    }

    convenience init(sessionModel: AppSessionModel, pollInterval: TimeInterval = HandoffAttentionModel.defaultPollInterval) {
        self.init(clientFactory: { try sessionModel.makeAPIClient() }, pollInterval: pollInterval)
    }

    func setPollingActive(_ active: Bool) {
        shouldPoll = active
        if active {
            startPollingIfNeeded()
            Task { await refresh() }
        } else {
            stopPolling()
        }
    }

    func refresh() async {
        guard shouldPoll else { return }
        do {
            let client = try clientFactory()
            let handoffs = try await client.listHandoffs()
            pendingHandoffs = HandoffAttention.pendingHandoffs(from: handoffs)
            needsAttention = HandoffAttention.needsAttention(handoffs: handoffs)
            lastError = nil
        } catch APIClientError.unauthorized {
            pendingHandoffs = []
            needsAttention = false
            lastError = "Session expired — sign in again"
        } catch {
            lastError = "Could not load handoffs"
        }
    }

    func revokeHandoff(id: String) async {
        do {
            let client = try clientFactory()
            _ = try await client.revokeHandoff(id: id)
            await refresh()
        } catch {
            lastError = "Revoke failed"
        }
    }

    func openHandoffsInBrowser() {
        NSWorkspace.shared.open(HandoffAttention.handoffsWebURL)
    }

    private func startPollingIfNeeded() {
        guard pollCancellable == nil else { return }
        pollCancellable = scheduler.start(interval: pollInterval) { [weak self] in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    private func stopPolling() {
        pollCancellable?.cancel()
        pollCancellable = nil
        pendingHandoffs = []
        needsAttention = false
        lastError = nil
    }
}
