import SnappyBT
import SwiftUI

// MARK: - CentralDemoView

struct CentralDemoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scan with SnappyBTCentral.live(config:), connect in onDiscover, then write when onReadyToWrite fires.")
            Text("Queued writes are sent in order once the link is ready.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Central")
    }
}
