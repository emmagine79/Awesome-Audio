import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            Text("Sidebar")
        } detail: {
            Text("Awesome Audio")
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}
