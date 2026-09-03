#!/bin/bash
# Headless script compilation check for Godot 4.x
# Tries to locate godot binary and run headless script check
set -e

# Try common godot binary locations
GODOT=""
for candidate in "godot4" "godot" "/Applications/Godot.app/Contents/MacOS/Godot" "/Applications/Godot4.app/Contents/MacOS/Godot"; do
    if command -v "$candidate" &>/dev/null; then
        GODOT="$candidate"
        break
    fi
    if [ -x "$candidate" ]; then
        GODOT="$candidate"
        break
    fi
done

if [ -z "$GODOT" ]; then
    echo "WARN: No godot binary found — skipping headless check"
    exit 0
fi

echo "Using godot: $GODOT"
PROJECT_PATH="$(cd "$(dirname "$0")/../.." && pwd)"

# Run headless — just load and quit to check for script errors
"$GODOT" --headless --path "$PROJECT_PATH" --quit 2>&1 || {
    echo "FAIL: Godot headless run produced errors"
    exit 1
}

echo "PASS: Godot headless run completed without fatal errors"
exit 0
