import CryptoKit
import SnappyBT
import SwiftUI

// MARK: - EncryptionDemoView

struct EncryptionDemoView: View {
    @State private var message = "Hello over BLE"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Payload", text: $message)
            if let sealed = sealedSample {
                Text("AES-GCM sealed length: \(sealed.count) bytes")
                    .font(.caption.monospaced())
            }
            Text("Use the same Encryption key on central and peripheral configs so payloads match SnappyDB ciphertext.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Encryption")
    }

    private var sealedSample: Data? {
        let enc = Encryption(keyString: "demo-shared-secret")
        return try? enc.encrypt(Data(message.utf8))
    }
}
