import SwiftUI

struct HandoffsListView: View {
    @ObservedObject var viewModel: ConsoleHandoffsViewModel
    @ObservedObject var lockState: VaultLockState

    private static let expiresFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Group {
            if lockState.isLocked {
                lockedContent
            } else {
                unlockedContent
            }
        }
        .frame(minWidth: 400, minHeight: 280)
        .task(id: lockState.isLocked) {
            guard !lockState.isLocked else { return }
            await viewModel.loadHandoffs()
        }
    }

    @ViewBuilder
    private var lockedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Unlock the vault to view handoffs")
                .font(.headline)
            if lockState.isUnlocking {
                ProgressView()
            } else {
                Button("Unlock") {
                    Task { await lockState.unlock() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var unlockedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Handoffs")
                    .font(.title2.bold())
                Spacer()
                Button("Open in browser") {
                    viewModel.openHandoffsInBrowser()
                }
            }

            if let loadError = viewModel.loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let actionError = viewModel.actionError {
                Text(actionError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.handoffs.isEmpty {
                Text("No handoffs")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.handoffs) { handoff in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(handoff.title)
                                .lineLimit(2)
                            Text(handoff.status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Expires \(Self.expiresFormatter.string(from: handoff.expiresAt))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        if viewModel.isPending(handoff) {
                            Button("Revoke") {
                                Task { await viewModel.revokeHandoff(id: handoff.id) }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
    }
}
