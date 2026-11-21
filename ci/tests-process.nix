# THE PER-PROCESS RUNNER — evaluates each cell in `tests-process-cells.nix` in its OWN evaluator
# process and asserts on the exit status, the printed value and the evaluator's counters. gen-schema's
# `ci/tests-process.nix` is the precedent (its depth and merge-collection curves): a count is evidence
# only for the evaluator that computed it, so it is not a nix-unit output and not a sandboxed check. As
# `apps.<system>.tests-process` its cells call the `nix-instantiate` on PATH, and gen-harness's
# `ci --tests-process` runs it in every column of `evaluators.yml`. Locally:
#   nix develop ./ci --command ci --tests-process
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      apps.tests-process.program = pkgs.writeShellScriptBin "tests-process" ''
        set -e
        # The tools the body calls, declared rather than ambient — and never an evaluator.
        export PATH=${
          pkgs.lib.makeBinPath [
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.gnused
          ]
        }:$PATH
        cells=${./tests-process-cells.nix}
        TMPDIR=$(mktemp -d)
        export TMPDIR
        trap 'rm -rf "$TMPDIR"' EXIT
        cd "$TMPDIR"
        export NIX_STATE_DIR=$TMPDIR/nix-state NIX_LOG_DIR=$TMPDIR/nix-log
        echo "evaluator: $(nix-instantiate --version | sed -n 1p)"
        # A count is defined only for a serial run, so every cell here is serial (gen-harness
        # `lib.serialEval`).
        # shellcheck disable=SC1091
        source ${inputs.gen-harness.lib.serialEval { inherit pkgs; }}
        serialEvalOptions "$(command -v nix-instantiate)" || {
          echo "tests-process: CONTROL FAILED: the serial options of $(command -v nix-instantiate) could not be resolved" >&2
          exit 2
        }
        echo "tests-process: serial options: ''${SERIAL_EVAL[*]:-(none)}"
        ran=0
        # The spy's trace label, generated fresh per run and never written down, so no text a cell
        # or a document carries can be mistaken for a firing.
        label="spy-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
        die() {
          echo "tests-process: FAILED at cell $1: $2" >&2
          exit 1
        }
        args=(--argstr label "$label" --argstr libSrc ${../lib} --argstr identitySrc ${inputs.gen-identity})
        # spyArm <arm>: one evaluation under the column's own evaluator; leaves val and n (the spy's count) set.
        spyArm() {
          rc=0
          val=$(nix-instantiate --eval --strict --readonly-mode "''${args[@]}" --argstr arm "$1" "$cells" 2> "$TMPDIR/err") || rc=$?
          n=$(grep -c "trace: $label\$" "$TMPDIR/err" || true)
          ran=$((ran + 1))
          [ "$rc" -eq 0 ] || die "$1" "expected exit 0, got $rc: $(tail -n 3 "$TMPDIR/err")"
        }

        # den-hoag-9gjv6 · `{ }` is a constant component, so its tag is minted once per partial
        # application of `preimageTagOf`, as `null`'s and `[ ]`'s are (den-hoag-a7c9r): eight empty
        # attrsets through one application mint once. A tag minted per component mints eight times.
        spyArm empty-attrs-mints-1
        [ "$val" = "1" ] || die empty-attrs-mints-1 "expected value 1, got '$val'"
        e1=$n
        spyArm empty-attrs-mints-8
        [ "$val" = "8" ] || die empty-attrs-mints-8 "expected value 8, got '$val'"
        e8=$n
        [ "$e1" = "1" ] && [ "$e8" = "1" ] ||
          die empty-attrs-mints-8 "expected one mint for one empty attrset and one for eight, counted $e1 and $e8"
        # The spy's live control: eight distinct attrsets mint eight times.
        spyArm distinct-attrs-mints-8
        [ "$val" = "8" ] || die distinct-attrs-mints-8 "expected value 8, got '$val'"
        [ "$n" = "8" ] || die distinct-attrs-mints-8 "the spy's control expected 8 mints, counted $n"
        control=$n

        # cellCount <arm>: one counted evaluation; leaves val, thunks, envs (envs.bytes) and calls set.
        cellCount() {
          rm -f "$TMPDIR/stats"
          rc=0
          val=$(NIX_SHOW_STATS=1 NIX_SHOW_STATS_PATH="$TMPDIR/stats" nix-instantiate "''${SERIAL_EVAL[@]}" \
            --eval --strict --readonly-mode "''${args[@]}" --argstr arm "$1" "$cells" 2> "$TMPDIR/err") || rc=$?
          ran=$((ran + 1))
          [ "$rc" -eq 0 ] || die "$1" "expected exit 0, got $rc: $(tail -n 3 "$TMPDIR/err")"
          stats=$(tr -d ' \n' < "$TMPDIR/stats")
          thunks=$(printf '%s' "$stats" | grep -o '"nrThunks":[0-9]*' | cut -d: -f2 || true)
          calls=$(printf '%s' "$stats" | grep -o '"nrFunctionCalls":[0-9]*' | cut -d: -f2 || true)
          envs=$(printf '%s' "$stats" | grep -o '"envs":{[^}]*}' | grep -o '"bytes":[0-9]*' | cut -d: -f2 || true)
          [ -n "$thunks" ] && [ -n "$calls" ] && [ -n "$envs" ] ||
            die "$1" "the evaluator wrote no nrThunks, nrFunctionCalls or envs.bytes to $TMPDIR/stats: cannot measure"
        }

        # A composition step's entries cost the labels its two operands share, not their union: one
        # record folded over 8, 16, 32 and 64 steps, each adding a label and re-stacking one shared
        # label, in each composition (`mixin`, the `combine` door, a `compose` chain in each
        # direction). The per-step slope of each doubling is at most 1.30 times the previous one, for
        # thunks and for environment bytes (`envs.bytes`). A step rebuilding the union doubles the
        # slope per doubling (1.5 to 1.9 measured); a step mapping over the whole accumulator keeps
        # thunks flat and allocates one environment per mapped label, so both are read. Function calls
        # are printed beside them and bound nothing: a call's environment is already in the bytes.
        # Scope: the cells read the entries (`emit`), never `labels`, whose list copy grows with the
        # record on every arm; and the copies `//` and `++` make (set and list bytes) are not bound,
        # since the representation copies on every step. The value, not the counts, is pinned:
        # counts may differ by evaluator.
        summary=""
        for c in mixin:s combine:b compose:s1 composes:s; do
          fold=''${c%%:*}
          head=''${c#*:}
          t=""
          e=""
          k=""
          for m in 8 16 32 64; do
            cellCount "curve-$fold-$m"
            if [ "$head" = s ]; then want="\"$((m + 2)):s$m\""; else want="\"$((m + 2)):$head\""; fi
            [ "$val" = "$want" ] || die "curve-$fold-$m" "expected value $want, got '$val'"
            t="$t $thunks"
            e="$e $envs"
            k="$k $calls"
          done
          for counter in thunks envs calls; do
            case $counter in
              thunks) set -- $t ;;
              envs) set -- $e ;;
              calls) set -- $k ;;
            esac
            s1=$((($2 - $1) / 8))
            s2=$((($3 - $2) / 16))
            s3=$((($4 - $3) / 32))
            [ "$s1" -gt 0 ] || die "curve-$fold-16" "the $counter slope from 8 to 16 is $s1 per step: cannot measure"
            if [ "$counter" != calls ]; then
              [ $((s2 * 100)) -le $((s1 * 130)) ] && [ $((s3 * 100)) -le $((s2 * 130)) ] ||
                die "curve-$fold-64" "a $fold step's $counter grow with the record: $s1 / $s2 / $s3 per step from 8 to 64 steps, a doubling ratio over 1.30"
            fi
            summary="$summary $fold $counter $s1/$s2/$s3;"
          done
        done

        # 0/0 is a false pass: the runner must have executed every cell above.
        [ "$ran" = "19" ] || die runner "expected 19 evaluations, ran $ran"
        echo "tests-process: 19 cells, every exit read unpiped; empty-attrset mints $e1 for 1 and $e8 for 8, spy control $control; per-step slopes at 8/16/32/64 steps (thunks and envs bytes bound, calls reported):$summary"
      '';
    };
}
