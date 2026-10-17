import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Peripheral (receiver)") {
                    PeripheralDemoView()
                }
                NavigationLink("Central (sender)") {
                    CentralDemoView()
                }
                NavigationLink("Payload encryption") {
                    EncryptionDemoView()
                }
            }
            .navigationTitle("SnappyBT")
        }
    }
}
