# snappyBT

[![Swift](https://img.shields.io/badge/Swift-6.4-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2027%20%7C%20macOS%2027-lightgrey.svg)](https://github.com/snappsengineering/snappyBT/releases)
[![CI](https://github.com/snappsengineering/snappyBT/actions/workflows/ci.yml/badge.svg)](https://github.com/snappsengineering/snappyBT/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Small-payload Bluetooth LE: a **peripheral** (advertise and receive) and a **central** (scan, connect, send). Protocol logic is separate from CoreBluetooth, so the stack is unit-tested without a radio.

## Get set up in 60 seconds

**1. Add the package** — in `Package.swift` or Xcode (**File → Add Package Dependencies**), pin the tag for your minimum OS ([VERSIONING.md](VERSIONING.md)):

```swift
.package(url: "https://github.com/snappsengineering/snappyBT.git", exact: "27.0.0")
```

Prefer `exact:` for reproducible builds. For bleeding edge, use `branch: "develop"`.

**2. Pick a role** — use the same service UUID on both sides; the other role mirrors this setup.

*Peripheral*

```swift
import SnappyBT

let service = "4DF91029-1234-463E-9F48-BAB077BF3EF5"
let peripheral = try SnappyBTPeripheral.live(config: SnappyBTPeripheralConfig(serviceUUID: service))
peripheral.onReceiveText = { print($0) }
peripheral.startAdvertising()
```

*Central*

```swift
import SnappyBT

let service = "4DF91029-1234-463E-9F48-BAB077BF3EF5"
let central = try SnappyBTCentral.live(config: SnappyBTCentralConfig(serviceUUIDs: [service]))
central.onDiscover = { central.connect(to: $0.identifier) }
central.startScanning()
central.write(text: "hello")
```

Scanning and advertising start when Bluetooth powers on. Callbacks run on `callbackQueue` (default main).

## Which role should I use?

| Type | Use when |
|------|----------|
| `SnappyBTPeripheral` | Your device advertises a service and accepts writes (GATT server role). |
| `SnappyBTCentral` | Your device scans, connects, and writes (GATT client role). |

Use mock drivers in tests; `.live(config:)` uses CoreBluetooth on device.

## Usage notes

**Privacy** — Add `NSBluetoothAlwaysUsageDescription` to your app (macOS needs the Bluetooth entitlement).

**Topologies** — One-to-one (default), one-to-many (`maxConnections`, `write(text:to:)`), many-to-one (`onMessage` with sender id). See [PROTOCOL.md](PROTOCOL.md) for GATT layout and Android interop.

**Encryption** — Optional AES-GCM on the payload (`encryption:` on either config). Optional link encryption (`requireEncryptedLink` on peripheral). `Encryption` matches SnappyDB’s type; share a key in your app if you use both packages.

**Soft-fail** — Errors surface via `onError` and `lastError`; `clearError()` resets. Invalid UUID strings throw at construction.

**Writes** — Queued until the link is ready; dropped on disconnect. Small payloads only (discovery / control / QR-sized data).

**Testing** — Inject `SnappyBTCentralDriver` / `SnappyBTPeripheralDriver` instead of `.live` and drive events from your mock.

**Coverage** — 100% line coverage on the protocol layer in CI. `Sources/SnappyBT/CoreBluetooth` adapters are thin mapping only and excluded from the gate.

**Demo** — `Example/SnappyBTDemo.xcodeproj`.

[CONTRIBUTING.md](CONTRIBUTING.md) · [VERSIONING.md](VERSIONING.md) · [SECURITY.md](SECURITY.md) · MIT

