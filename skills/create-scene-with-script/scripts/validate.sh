#!/bin/bash
# Unified validator for create-scene-with-script skill
# Usage: ./scripts/validate.sh <scene_path> [<script_path1> <script_path2> ...]
# Exit codes: 0 = success, 1 = failure
set -e

SCENE_PATH="$1"
if [ $# -gt 0 ]; then shift; fi
SCRIPT_PATHS="$@"

if [ -z "$SCENE_PATH" ]; then
    echo "❌ FAIL: No scene path provided" >&2
    echo "Usage: ./scripts/validate.sh <scene_path> [<script_path1> ...]" >&2
    exit 1
fi

echo "=== Create-Scene-With-Script Validation ==="
echo "Scene: $SCENE_PATH"
echo ""

errors=0

# === VALIDATION 1: Scene file existence ===
if [ ! -f "$SCENE_PATH" ]; then
    echo "❌ FAIL: Scene file missing: $SCENE_PATH" >&2
    exit 1
fi
echo "✓ Scene file exists"

# === VALIDATION 2: Scene content size ===
lines=$(wc -l < "$SCENE_PATH")
if [ "$lines" -lt 10 ]; then
    echo "❌ FAIL: Scene file too small ($lines lines) — likely incomplete" >&2
    exit 1
fi
echo "✓ Scene file has content ($lines lines)"

# === VALIDATION 3: Root node present ===
if ! grep -q '^\[node name=' "$SCENE_PATH"; then
    echo "❌ FAIL: No node definitions found in scene" >&2
    exit 1
fi

if ! grep '^\[node name=' "$SCENE_PATH" | grep -vq 'parent='; then
    echo "❌ FAIL: No root node found (all nodes have a parent)" >&2
    exit 1
fi
echo "✓ Root node present"

# === VALIDATION 4: Attached scripts exist ===
for script in $SCRIPT_PATHS; do
    if [ -n "$script" ]; then
        if [ ! -f "$script" ]; then
            echo "❌ FAIL: Script file missing: $script" >&2
            exit 1
        fi
        echo "✓ Script exists: $script"
        
        # Quick syntax check
        if ! grep -q "extends" "$script"; then
            echo "⚠️  WARN: Script may be invalid (no extends statement): $script" >&2
        fi
    fi
done

# === VALIDATION 5: Scene references scripts ===
if [ -n "$SCRIPT_PATHS" ]; then
    for script in $SCRIPT_PATHS; do
        if [ -n "$script" ]; then
            script_name=$(basename "$script")
            if grep -q "$script_name" "$SCENE_PATH"; then
                echo "✓ Scene references script: $script_name"
            else
                echo "❌ FAIL: Scene does not reference script: $script_name" >&2
                errors=$((errors+1))
            fi
        fi
    done
fi

# === VALIDATION 6: CollisionShape2D nodes have shapes ===
col_nodes=$(grep -c '\[node name=".*" type="CollisionShape2D"' "$SCENE_PATH" || true)
if [ "$col_nodes" -gt 0 ]; then
    unshaped=0
    line_nums=$(grep -n '\[node name="[^"]*" type="CollisionShape2D"' "$SCENE_PATH" | cut -d: -f1)
    
    while IFS= read -r line_num; do
        [ -z "$line_num" ] && continue
        
        has_shape=false
        cur_line=$((line_num + 1))
        total_lines=$(wc -l < "$SCENE_PATH")
        while [ "$cur_line" -le "$total_lines" ]; do
            cur_content=$(sed -n "${cur_line}p" "$SCENE_PATH")
            case "$cur_content" in
                \[node\ *|\[sub_resource\ *|\[connection\ *)
                    break
                    ;;
                *shape\ *=*)
                    has_shape=true
                    break
                    ;;
            esac
            cur_line=$((cur_line + 1))
        done
        if ! $has_shape; then
            unshaped=$((unshaped + 1))
            echo "❌ FAIL: CollisionShape2D node at line $line_num has no shape property" >&2
        fi
    done <<< "$line_nums"
    
    if [ "$unshaped" -gt 0 ]; then
        echo "❌ FAIL: $unshaped CollisionShape2D node(s) missing shape property" >&2
        errors=$((errors+unshaped))
    else
        echo "✓ All $col_nodes CollisionShape2D node(s) have shapes"
    fi
fi

# === FINAL RESULT ===
echo ""
if [ "$errors" -gt 0 ]; then
    echo "❌ Validation FAILED ($errors errors)" >&2
    echo "Fix all errors before marking task complete." >&2
    exit 1
else
    echo "✓ Validation PASSED"
    exit 0
fi