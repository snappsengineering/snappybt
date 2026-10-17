#!/usr/bin/env python3
"""Apply OS-floor manifest via snappykit (Package, README, CONTRIBUTING, Example)."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT.parent / "tools" / "snappykit"
if not KIT.is_dir():
    KIT = Path.home() / "Documents/Apps/tools/snappykit"
sys.path.insert(0, str(KIT))

from apply_floor import apply  # noqa: E402
from repos import repo_for_path  # noqa: E402


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: apply_os_floor.py 16|18|26|27")
    floor = sys.argv[1]
    spec = repo_for_path(ROOT.name)
    slug = spec.slug if spec else ROOT.name
    apply(ROOT, slug, floor)
    print(f"Applied floor {floor} for {slug}")


if __name__ == "__main__":
    main()
