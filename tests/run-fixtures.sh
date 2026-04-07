#!/usr/bin/env bash
# tests/run-fixtures.sh — semi-automated fixture runner for the methodology
#
# Usage:
#   bash tests/run-fixtures.sh                    # run all fixtures, semi-auto
#   bash tests/run-fixtures.sh fixture-01-saas-clinic   # run one
#   bash tests/run-fixtures.sh --check            # only check existing outputs (no claude invocation)
#
# Status: this is a SMOKE runner. Full automation requires Claude Code SDK
# non-interactive mode, which is not yet stable as of v1.2.0. Until then,
# this script:
#   1. For each fixture, prints the idea.md content
#   2. Asks the user to invoke /kickstart or /blueprint manually in another
#      Claude Code session pointing at the output/ directory
#   3. After the user confirms completion, checks expected-files.txt against
#      actual files in output/
#   4. Reports pass/fail per fixture
#
# When Claude Code SDK gains stable non-interactive mode, replace the
# "manual invocation" loop with an actual SDK call.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES_DIR="$REPO_ROOT/tests/fixtures"

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m"

CHECK_ONLY=false
TARGET=""

for arg in "$@"; do
    case "$arg" in
        --check) CHECK_ONLY=true ;;
        --help|-h)
            sed -n '2,25p' "$0"
            exit 0
            ;;
        *) TARGET="$arg" ;;
    esac
done

run_fixture() {
    local fixture_dir="$1"
    local name
    name="$(basename "$fixture_dir")"

    echo
    echo "=========================================="
    echo "Fixture: $name"
    echo "=========================================="

    if [ ! -f "$fixture_dir/idea.md" ]; then
        echo -e "${RED}✗ Missing idea.md${NC}"
        return 1
    fi

    if [ ! -f "$fixture_dir/expected-files.txt" ]; then
        echo -e "${RED}✗ Missing expected-files.txt${NC}"
        return 1
    fi

    local output_dir="$fixture_dir/output"

    if [ "$CHECK_ONLY" = false ]; then
        echo "Idea:"
        echo "----"
        cat "$fixture_dir/idea.md"
        echo "----"
        echo
        echo "Now in another Claude Code session, run:"
        echo "  cd '$fixture_dir'"
        echo "  mkdir -p output && cd output"
        echo "  # Then invoke: /project   (or /kickstart, or /blueprint)"
        echo "  # paste the idea above"
        echo
        read -r -p "Press Enter when the fixture run completes (or Ctrl-C to abort)..."
    fi

    if [ ! -d "$output_dir" ]; then
        echo -e "${RED}✗ output/ directory not found in $fixture_dir${NC}"
        echo "  Did the fixture actually run? Skipping."
        return 1
    fi

    # Check expected files
    local missing=0
    local found=0
    while IFS= read -r expected; do
        [ -z "$expected" ] && continue
        if [ -f "$output_dir/$expected" ]; then
            echo -e "  ${GREEN}✓${NC} $expected"
            found=$((found + 1))
        else
            echo -e "  ${RED}✗${NC} $expected — MISSING"
            missing=$((missing + 1))
        fi
    done < "$fixture_dir/expected-files.txt"

    echo
    if [ "$missing" -eq 0 ]; then
        echo -e "${GREEN}✓ $name: PASSED ($found files present)${NC}"
        return 0
    else
        echo -e "${RED}✗ $name: FAILED ($missing missing of $((found + missing)))${NC}"
        return 1
    fi
}

main() {
    if [ ! -d "$FIXTURES_DIR" ]; then
        echo "No fixtures directory at $FIXTURES_DIR" >&2
        exit 1
    fi

    local total=0
    local passed=0

    if [ -n "$TARGET" ]; then
        if [ -d "$FIXTURES_DIR/$TARGET" ]; then
            total=1
            run_fixture "$FIXTURES_DIR/$TARGET" && passed=1 || true
        else
            echo "Fixture '$TARGET' not found in $FIXTURES_DIR" >&2
            exit 1
        fi
    else
        for f in "$FIXTURES_DIR"/*/; do
            total=$((total + 1))
            if run_fixture "$f"; then
                passed=$((passed + 1))
            fi
        done
    fi

    echo
    echo "=========================================="
    echo "Summary: $passed/$total fixtures passed"
    echo "=========================================="

    if [ "$passed" -ne "$total" ]; then
        exit 1
    fi
}

main
