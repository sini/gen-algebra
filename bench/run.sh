#!/usr/bin/env bash
# gen benchmark runner — xxh64 vs SHA256
# Measures wall-clock nix eval time for each hash benchmark.
#
# Usage:
#   ./bench/run.sh                    # 3 runs per benchmark (median)
#   ./bench/run.sh --quick            # single run
#   ./bench/run.sh --name baseline    # save results to bench/history/

set -euo pipefail
export LC_NUMERIC=C

BENCH_DIR="$(cd "$(dirname "$0")" && pwd)"
GEN_DIR="$(dirname "$BENCH_DIR")"

NAME=""
RUNS=3
while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) NAME="$2"; shift 2 ;;
        --quick) RUNS=1; shift ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

declare -A results

TOTAL=0
DONE=0

run_bench() {
    local target="$1"
    DONE=$((DONE + 1))
    printf "[%d/%d] %-30s" "$DONE" "$TOTAL" "$target" >&2
    local times=()
    for i in $(seq 1 "$RUNS"); do
        local start end ms rc
        start=$(date +%s%N)
        rc=0
        nix eval --impure --expr "(import $BENCH_DIR).$target" >/dev/null 2>&1 || rc=$?
        end=$(date +%s%N)
        if (( rc != 0 )); then
            echo " FAILED (exit $rc)" >&2
            results["$target"]=-1
            return
        fi
        ms=$(( (end - start) / 1000000 ))
        times+=("$ms")
    done
    local median
    if (( RUNS == 1 )); then
        median="${times[0]}"
    else
        median=$(printf '%s\n' "${times[@]}" | sort -n | head -n2 | tail -n1)
    fi
    results["$target"]=$median
    echo " ${median}ms" >&2
}

# Count benchmarks
inputs=(empty tiny short medium long large json-small json-medium)
TOTAL=$(( ${#inputs[@]} * 2 + 6 ))

echo "Running $TOTAL benchmarks ($RUNS runs each)..." >&2
echo "" >&2

# Individual hash benchmarks
echo "--- Individual hashes ---" >&2
for inp in "${inputs[@]}"; do
    run_bench "xxh64.$inp"
done
for inp in "${inputs[@]}"; do
    run_bench "sha256.$inp"
done

# Batch benchmarks
echo "" >&2
echo "--- Batch (N hashes in one eval) ---" >&2
for b in xxh64-10 xxh64-50 xxh64-100 sha256-10 sha256-50 sha256-100; do
    run_bench "batch.$b"
done

# Output
fmt_ms() {
    if (( $1 < 0 )); then printf "FAIL"; else printf "%s" "$1"; fi
}

echo ""
echo "# gen hash benchmark"
echo ""
echo "- **Nix**: $(nix --version)"
echo "- **System**: $(uname -sm)"
echo "- **Runs**: $RUNS (median)"
echo ""
echo "## Individual hashes (includes nix eval startup)"
echo ""
printf "| %-15s | %8s | %8s | %8s |\n" "Input" "xxh64" "sha256" "ratio"
printf "|%-15s-|-%8s:|-%8s:|-%8s:|\n" "---------------" "--------" "--------" "--------"
for inp in "${inputs[@]}"; do
    x="${results[xxh64.$inp]}"
    s="${results[sha256.$inp]}"
    if (( x > 0 && s > 0 )); then
        # ratio as percentage: xxh64_time / sha256_time * 100
        pct=$(( x * 100 / s ))
        ratio="${pct}%"
    else
        ratio="N/A"
    fi
    printf "| %-15s | %7sms | %7sms | %8s |\n" "$inp" "$(fmt_ms "$x")" "$(fmt_ms "$s")" "$ratio"
done

echo ""
echo "## Batch hashes (amortized, no per-eval startup)"
echo ""
printf "| %-15s | %8s | %8s |\n" "Batch" "ms" "per-hash"
printf "|%-15s-|-%8s:|-%8s:|\n" "---------------" "--------" "--------"
for algo in xxh64 sha256; do
    for n in 10 50 100; do
        ms="${results[batch.$algo-$n]}"
        if (( ms > 0 )); then
            per=$(( ms * 1000 / n ))
            printf "| %-15s | %7sms | %5s.%sms |\n" "$algo×$n" "$ms" "$((per / 1000))" "$(printf '%03d' $((per % 1000)))"
        else
            printf "| %-15s | %8s | %8s |\n" "$algo×$n" "$(fmt_ms "$ms")" "N/A"
        fi
    done
done

echo ""
echo "> ratio = xxh64_time / sha256_time (lower = faster xxh64)"
echo "> per-hash = total_ms / N (amortized cost without eval startup)"

# Save if named
if [[ -n "$NAME" ]]; then
    mkdir -p "$BENCH_DIR/history"
    # Save markdown output
    {
        echo "# gen hash benchmark: $NAME"
        echo ""
        echo "- **Timestamp**: $(date -Iseconds)"
        echo "- **Nix**: $(nix --version)"
        echo "- **System**: $(uname -sm)"
        echo ""
        echo "## Raw results (ms)"
        echo ""
        for key in $(printf '%s\n' "${!results[@]}" | sort); do
            echo "- $key: ${results[$key]}"
        done
    } > "$BENCH_DIR/history/${NAME}.md"
    echo "" >&2
    echo "Saved: $BENCH_DIR/history/${NAME}.md" >&2
fi
