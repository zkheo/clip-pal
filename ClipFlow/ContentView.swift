import SwiftUI

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    var body: some View {
        MenuBarView()
            .environmentObject(clipboardManager)
    }
}

#Preview {
    ContentView()
        .environmentObject(ClipboardManager())
}
