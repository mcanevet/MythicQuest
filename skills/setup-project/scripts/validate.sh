#!/bin/bash
# Setup-project validation — operates on cwd (project root)
# Usage: ./scripts/validate.sh
# Exit codes: 0 = pass, 1 = fail
set -e

echo "=== Setup-Project Validation ==="

# Check 1: project.godot exists with correct format
if [ ! -f "project.godot" ]; then
    echo "❌ FAIL: project.godot missing" >&2
    exit 1
fi

if ! grep -q "config_version=5" project.godot; then
    echo "❌ FAIL: project.godot not Godot 4.x format (missing config_version=5)" >&2
    exit 1
fi

if ! grep -q "run/main_scene" project.godot; then
    echo "❌ FAIL: project.godot missing run/main_scene configuration" >&2
    exit 1
fi

echo "✓ OK: project.godot (Godot 4.x format, main_scene configured)"

# Check 2: icon.svg exists
if [ ! -f "icon.svg" ]; then
    echo "⚠️  WARN: icon.svg missing (optional)" >&2
else
    echo "✓ OK: icon.svg exists"
fi

# Check 3: test harness autoload exists (created by Step 3b — playtest depends on it)
if [ ! -f "scripts/test_player.gd" ]; then
    echo "❌ FAIL: scripts/test_player.gd missing (test harness copy — see Step 3b)" >&2
    exit 1
fi
echo "✓ OK: scripts/test_player.gd (test harness)"

echo ""
echo "✓ Setup-project validation PASSED"
exit 0