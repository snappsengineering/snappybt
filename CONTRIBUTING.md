# Contributing

## Setup

```bash
swift build
swift test --enable-code-coverage
```

Toolchain depends on the OS floor of the commit you are on — see [VERSIONING.md](VERSIONING.md). The `27.0` tag expects Swift 6.4+ and Xcode 27+.

Integration branch **`develop`** stays on shipped tags until a floor bump merges. **`feature/os-27`** holds Swift **6.4**, **`.v27`** platforms, passive source updates when touched, and **`RUNNER=xcode-27`** CI — merge only after a green **`xcode-27`** Actions run (no `27.0` tag until runner gate passes).

## Rules

- **100% line coverage.** CI fails below 100.00% of `Sources/SnappyBT`. Add tests with every change; never lower the gate.
- **No warnings.** `swift build -Xswiftc -warnings-as-errors` must pass.
- **Platforms.** iOS and macOS per CI (`PLATFORMS` / `SIM_TESTS` in `.snappy-ci.env`). Do not use APIs above the floor of the commit you are on.
- **Hygiene check.** CI runs `.github/scripts/hygiene_check.py` (personal emails, home paths, secrets, agent attribution lines). Run `python3 .github/scripts/hygiene_check.py tree` locally.
- **Tests use synthetic data only.** No real user, financial, or personal data in fixtures.
- **Additive API on a tag line.** Do not break public API within an OS-floor release series; note user-visible changes in [GitHub Releases](https://github.com/snappsengineering/snappyBT/releases).
- Keep changes focused; commit titles in the imperative (`Add batch delete`).

## Commit identity

Use your GitHub noreply address (`<id>+<user>@users.noreply.github.com`). Do not commit
personal emails, local paths (`/Users/...`), or secrets.

## Versions

Integration branch is **`develop`**. Shipping pins use OS-floor tags (`16.0`, `18.0`, `26.0`, …). Lazy **`release/N.x`** branches appear only when a line needs patch tags.

See [VERSIONING.md](VERSIONING.md) for SPM pins.

## Pull requests

Optional — maintainers may push directly when CI is green. If you open a PR, describe the change and how you tested it.
