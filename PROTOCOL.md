# SnappyBT wire contract

SnappyBT speaks plain Bluetooth LE GATT, so it interoperates with Android, embedded boards and any other BLE device. There is no custom framing in 1.x: one write is one message.

| Item | Value |
|---|---|
| Service UUID | Yours. The peripheral advertises it; the central scans for it. |
| Characteristic | One **write** characteristic (default `3B66D024-2336-4F22-A980-8095F4898C42`, configurable on both sides) |
| Write type | Write **with response** |
| Payload | Opaque bytes (`write(text:)` sends UTF-8). Empty writes are rejected. |
| Size | Must fit one ATT write: MTU minus 3 bytes. The default MTU is 23 (20 bytes); iOS and modern Android negotiate larger (up to 512). Keep messages small or negotiate the MTU. |
| Security | None by default. Opt in: payload AES-GCM (`Encryption`) and/or an encrypted link (`requireEncryptedLink`). |

## Roles and topologies

| Topology | How |
|---|---|
| One-to-one | Default. One central connects to one peripheral. |
| One-to-many | One central, `maxConnections` > 1: connect to several peripherals, write to one (`write(_:to:)`) or all (`write(_:)`). |
| Many-to-one | Any number of centrals write to one peripheral. `onMessage` reports which central sent each write. |

## Mixed platforms

**SnappyBT central writes to a non-SnappyBT peripheral** (Android GATT server, ESP32, etc.): expose the service UUID, advertise it, and add a writable characteristic with the UUID you pass as `receiveCharacteristicUUID`. Nothing else is required.

**SnappyBT peripheral receives from a non-SnappyBT central** (Android phone, other apps): scan for the service UUID, connect, discover services, then write to the characteristic with response.

Android central sketch (Kotlin):

```kotlin
// scan: ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE)).build()
gatt = device.connectGatt(context, false, callback)          // then:
// onConnectionStateChange(CONNECTED) -> gatt.requestMtu(185); gatt.discoverServices()
// onServicesDiscovered -> characteristic = gatt.getService(SERVICE).getCharacteristic(RX)
characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT   // with response
characteristic.value = payload
gatt.writeCharacteristic(characteristic)
```

Android peripheral sketch: open a `BluetoothGattServer`, add a primary service with one `PROPERTY_WRITE` / `PERMISSION_WRITE` characteristic, answer `onCharacteristicWriteRequest` with `GATT_SUCCESS` when `responseNeeded`, and advertise the service UUID with `BluetoothLeAdvertiser`.

## Platform notes

- iOS peripherals advertise the service UUID only while the app is foregrounded or in a permitted background mode; the local name is not advertised in the background.
- tvOS and watchOS are not supported in 1.x.
- Larger payloads need chunking (not in 1.x). For bulk data use Wi-Fi or MultipeerConnectivity and keep BLE for discovery.

## Encryption

**Payload.** When `Encryption` is set, each write is one AES-GCM sealed box (CryptoKit combined format: 12-byte nonce + ciphertext + 16-byte tag). Same algorithm and key shape as SnappyDB, so a key created for one works in the other. The receiver must use the same key; a mismatch is rejected (`writeFailed`).

**Link.** `requireEncryptedLink` on the peripheral sets the characteristic permission to `writeEncryptionRequired`. The first write triggers OS pairing. Android centrals must pair (or bond) before writing. Both sides should set the flag; the peripheral is what enforces it.

**Not in 1.x:** replay protection, forward secrecy, per-message sequence numbers.
