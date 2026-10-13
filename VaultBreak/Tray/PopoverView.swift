import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: PopoverSecretsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search secrets", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let loadError = viewModel.loadError {
                Text(loadError)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            if let copyError = viewModel.copyError {
                Text(copyError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            List(viewModel.filteredSecrets) { item in
                HStack {
                    Text(item.name)
                        .lineLimit(1)
                    Spacer()
                    if viewModel.copiedSecretID == item.id {
                        Text("Copied")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Copy") {
                        Task { await viewModel.copySecret(id: item.id) }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .listStyle(.plain)
            .frame(minWidth: 280, minHeight: 160, maxHeight: 320)
        }
        .padding(12)
        .task {
            await viewModel.loadSecrets()
        }
    }
}
