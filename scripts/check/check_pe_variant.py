#!/usr/bin/env python3
"""Fail if any build or simulation script compiles both definitions of module pe_os.

rtl/pe/pe_os.v                    module pe_os, asynchronous accumulator reset (baseline)
rtl/pe/experimental/pe_os_sync.v  module pe_os, synchronous accumulator reset (shipped)

Both define the same module name on purpose, so the OS arrays can use either one.
A script must compile exactly one of them. Run from the repository root:
    python3 scripts/check/check_pe_variant.py
Comment lines are ignored. Exit code 0 means no unreviewed script references both
files; 1 means at least one does and needs a look.
"""
import re
import sys
from pathlib import Path

ASYNC = re.compile(r"rtl[/\\\s'\"\],]+pe[/\\\s'\"\],]+pe_os\.v")
SYNC = re.compile(r"pe_os_sync\.v")
EXTS = {".tcl", ".ps1", ".py", ".sh", ".f", ".prj"}
SEARCH = ["scripts", "verification", "tb", "fpga"]

# Files that mention both on purpose, after review. Each must still compile only one.
REVIEWED = {
    "scripts/implementation/compare_gemm_ooc.tcl":
        "selects one file into a single pe_file variable per variant",
}


def strip_comments(text):
    keep = []
    for line in text.splitlines():
        t = line.lstrip()
        if t.startswith("#") or t.startswith("//"):
            continue
        keep.append(line)
    return "\n".join(keep)


def main():
    root = Path.cwd()
    if not (root / "rtl" / "pe" / "pe_os.v").is_file():
        print("Run this from the repository root.")
        return 2
    both, sync_only, async_only = [], [], []
    for top in SEARCH:
        for p in sorted((root / top).rglob("*")):
            if p.suffix not in EXTS or not p.is_file():
                continue
            if p.name == "check_pe_variant.py":
                continue
            text = strip_comments(p.read_text(encoding="utf-8", errors="ignore"))
            a, s = bool(ASYNC.search(text)), bool(SYNC.search(text))
            rel = p.relative_to(root).as_posix()
            if a and s and rel in REVIEWED:
                print("reviewed:", rel, "-", REVIEWED[rel])
            elif a and s:
                both.append(rel)
            elif s:
                sync_only.append(rel)
            elif a:
                async_only.append(rel)
    print("Sync PE (pe_os_sync.v, shipped):")
    for f in sync_only:
        print("   ", f)
    print("Async PE (pe_os.v, baseline):")
    for f in async_only:
        print("   ", f)
    if both:
        print("FAIL: these files reference BOTH definitions of module pe_os:")
        for f in both:
            print("   ", f)
        print("Check that each build compiles only one of them.")
        return 1
    print("PASS: no script references both pe_os definitions.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
