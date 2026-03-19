import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: BTMViewModel

    var body: some View {
        BTMShellView(viewModel: viewModel)
    }
}

#Preview {
    ContentView(viewModel: BTMViewModel())
}
