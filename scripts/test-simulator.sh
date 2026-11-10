#!/usr/bin/env bash
# Prints the UDID of an available iPad simulator on the newest iOS
# runtime installed, for `task test`. Fails if there is none.
set -euo pipefail

xcrun simctl list devices available --json | python3 -c '
import json, re, sys

def version(runtime):
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    return (int(match[1]), int(match[2])) if match else None

devices = json.load(sys.stdin)["devices"]
runtimes = sorted((r for r in devices if version(r)), key=version, reverse=True)
for runtime in runtimes:
    pads = [d for d in devices[runtime] if d["name"].startswith("iPad")]
    if pads:
        print(pads[0]["udid"])
        sys.exit(0)
sys.exit("No iPad simulator is installed; add one in Xcode > Settings > Components")
'
