import SwiftUI

@main
struct PassScanApp: App {
    @StateObject private var store = CardStore()
    @AppStorage("accentHex") private var accentHex = "3B82F6"
    @AppStorage("theme") private var theme = "system"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(Color(hex: accentHex))
                .preferredColorScheme(theme == "light" ? .light : (theme == "dark" ? .dark : nil))
        }
    }
}
