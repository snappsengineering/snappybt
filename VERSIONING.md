# Versioning

snappyBT uses **one branch** (`develop`) and **OS-floor tags** for shipping.

## History (lean)

| Commit | Contents | Tag |
|--------|----------|-----|
| `Init` | CI harness, docs shell — no library | — |
| `snappyBT N.0 \| …` (pipe title) | `Sources/`, `Tests/`, Example (if any), full manifest at **minimum line** (buildable) | **`N.0`** |
| Pipe deployment titles | Manifest-only bumps for higher lines | higher **`N.0`** tags, … |

Each commit is **buildable** at its floor. Higher-line commits only change manifests (Package, README, CONTRIBUTING, Example pbxproj when present), not library sources.

## Swift Package Manager

```swift
.package(url: "https://github.com/snappsengineering/snappyBT.git", exact: "26.0.0")
```

| Tag | Minimum platforms |
|-----|-------------------|
| `16.0` | iOS 16, macOS 13 |
| `18.0` | iOS 18, macOS 15 |
| `26.0` | iOS 26, macOS 26 |


## Bleeding edge

- **`branch: "develop"`**

## Patches

Create **`release/N.x`** from tag **`N.0`** when a line needs fixes; consumers stay on **`exact:`** until a new patch tag policy exists.
