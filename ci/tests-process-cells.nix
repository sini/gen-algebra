# The process plane's cells, one evaluation per `arm`, each in its own evaluator process (the runner
# is ./tests-process.nix). A cell's value is pinned by the runner; its thunk count is read from
# NIX_SHOW_STATS by the runner, never here.
{
  libSrc,
  identitySrc,
  arm,
  label ? "",
}:
let
  A = import (/. + libSrc);
  R = A.record;

  # A spy over the real mint: every mint traces the run's label once.
  spy =
    kind: fields: f:
    builtins.trace label ((import (/. + identitySrc + "/lib")).hashIdentity kind fields f);
  # k components through ONE partial application, as a composite's tags are taken
  tags = map (A.preimageTagOf spy);
  mints = {
    # `{ }` is a constant, so its tag is minted once per partial application, however many
    # components are empty attrsets
    empty-attrs-mints-1 = tags [ { } ];
    empty-attrs-mints-8 = tags (builtins.genList (_: { }) 8);
    # the spy's live control: eight distinct attrsets mint eight times
    distinct-attrs-mints-8 = tags (builtins.genList (i: { a = i; }) 8);
  };

  # A composition fold of m steps over one base record. Every delta adds a label of its own and
  # re-stacks the label every step shares, so each step has a one-label overlap and a growing union.
  base = R.fromAttrs {
    k0 = "base";
    shared = "b";
  };
  delta =
    i: _parent:
    R.fromAttrs {
      "n${toString i}" = i;
      shared = "s${toString i}";
    };
  steps = m: builtins.genList (i: i + 1) m;
  fold = {
    # Smalltalk direction through `mixin`: the delta wins
    mixin = m: builtins.foldl' (acc: i: R.mixin (delta i) acc) base (steps m);
    # Beta direction through the `combine` door: the parent wins
    combine =
      m:
      builtins.foldl' (
        acc: i:
        R.combine {
          left = acc;
          right = delta i acc;
        }
      ) base (steps m);
    # a `compose` chain in the Beta shape (the accumulated mixin outermost), applied to the base
    compose = m: builtins.foldl' (acc: i: R.compose acc (delta i)) (p: p) (steps m) base;
  };
  # Every head is read, so every step's entries are forced; the value is the label count and the
  # shared label's head, which the runner pins per arm.
  read =
    r:
    let
      e = R.emit r;
    in
    builtins.deepSeq e "${toString (builtins.length (builtins.attrNames e))}:${e.shared}";

  # curve-<fold>-<m>
  parts = builtins.match "curve-([a-z]+)-([0-9]+)" arm;
in
if mints ? ${arm} then
  # the tags themselves are forced, so every mint they need runs; the value is their count
  builtins.deepSeq mints.${arm} (builtins.length mints.${arm})
else if parts == null then
  throw "tests-process-cells: unknown arm '${arm}'"
else
  read (fold.${builtins.elemAt parts 0} (builtins.fromJSON (builtins.elemAt parts 1)))
