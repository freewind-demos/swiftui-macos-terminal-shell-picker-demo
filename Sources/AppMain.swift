import SwiftUI

@main
struct TerminalShellPickerApp: App {
    var body: some Scene {
        Window("Embedded Terminal", id: "main") {
            ContentView()
        }
        .defaultSize(width: 960, height: 640)
    }
}
