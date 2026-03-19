import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BTMViewModel()

    var body: some View {
        BTMShellView(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
