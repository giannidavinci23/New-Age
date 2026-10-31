import SwiftUI

@main
struct AvantPosteApp: App {
    @State private var game = Game()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(game)
        }
    }
}
