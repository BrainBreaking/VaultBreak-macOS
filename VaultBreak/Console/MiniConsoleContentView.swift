import SwiftUI

struct MiniConsoleContentView: View {
    @ObservedObject var sessionModel: AppSessionModel
    @ObservedObject var lockState: VaultLockState
    @ObservedObject var secretsViewModel: ConsoleSecretsViewModel
    @ObservedObject var handoffsViewModel: ConsoleHandoffsViewModel

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                SecretsListView(viewModel: secretsViewModel, lockState: lockState)
                    .tabItem {
                        Label("Secrets", systemImage: "key")
                    }
                HandoffsListView(viewModel: handoffsViewModel, lockState: lockState)
                    .tabItem {
                        Label("Handoffs", systemImage: "arrow.left.arrow.right")
                    }
            }
            statusStrip
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 12) {
            Text(SessionDisplay.consoleEmail(from: sessionModel.session))
                .lineLimit(1)
                .truncationMode(.middle)
            Text("·")
                .foregroundStyle(.secondary)
            Text(apiHostLabel)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("·")
                .foregroundStyle(.secondary)
            Text(lockState.isLocked ? "Locked" : "Unlocked")
                .foregroundStyle(lockState.isLocked ? .secondary : .primary)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .separatorColor).opacity(0.15))
    }

    private var apiHostLabel: String {
        guard let session = sessionModel.session else {
            return SessionDisplay.placeholder
        }
        return SessionDisplay.apiURLHost(from: session.apiUrl)
    }
}
