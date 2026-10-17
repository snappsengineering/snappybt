import SnappyBT
import SwiftUI

// MARK: - PeripheralDemoView

struct PeripheralDemoView: View {
    @State private var status = "Create a peripheral with SnappyBTPeripheral.live(config:) and call startAdvertising()."

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(status)
                .font(.body)
            Text("Use two devices or a mock driver in unit tests; the simulator has no Bluetooth radio.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Peripheral")
        .onAppear {
            let service = "4DF91029-1234-463E-9F48-BAB077BF3EF5"
            if let config = try? SnappyBTPeripheralConfig(serviceUUID: service) {
                status = "Config OK for service \(config.serviceUUID)."
            }
        }
    }
}
