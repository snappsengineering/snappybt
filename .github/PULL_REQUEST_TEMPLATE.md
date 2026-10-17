## Summary

<!-- What changed and why -->

## Checklist

- [ ] `swift test --enable-code-coverage` passes, coverage still 100% (protocol layer; CoreBluetooth excluded)
- [ ] OS-floor / manifest changes: green **GitHub Actions** on the target runner (e.g. `xcode-27` for `.v27`); record run URL in `tools/snappykit/research/os-floor-N.md` before merge
- [ ] Public API changes are additive; note user-visible changes in a [GitHub Release](https://github.com/snappsengineering/snappyBT/releases) when shipping
- [ ] README / PROTOCOL.md updated if public API or GATT contract changed
- [ ] No personal emails, local paths, or real data in code, tests, or commit messages
