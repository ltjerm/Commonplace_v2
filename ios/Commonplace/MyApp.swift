import SwiftUI

@main
struct MyApp: App {
    @State private var store = EntryStore.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
