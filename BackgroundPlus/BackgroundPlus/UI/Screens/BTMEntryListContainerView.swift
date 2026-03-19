import SwiftUI

struct BTMEntryListContainerView: View {
    @ObservedObject var viewModel: BTMViewModel

    var body: some View {
        List(selection: $viewModel.selectedEntryID) {
            ForEach(viewModel.filteredEntries) { entry in
                BTMEntryListRowView(entry: entry)
                    .tag(entry.id)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: Text("btm.list.search_placeholder"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.load()
                } label: {
                    Label("btm.list.refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    viewModel.openBackupFolder()
                } label: {
                    Label("btm.result.button.open_backup", systemImage: "folder")
                }

                SettingsLink {
                    Label("btm.settings.button", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle(Text("btm.list.title"))
        .accessibilityIdentifier("btm.list.title")
    }
}
