{ genAlgebra, ... }:
let
  R = genAlgebra.record;

  # THE REFERENCE COMPOSITION, kept here and nowhere else: the union-rebuilding `combine'` every
  # composition step ran before each step was made to allocate only for the labels both operands
  # carry. It reads the record representation directly, as `rec-primitives` does. The library must
  # build the same records, with the same stacks and the same order, on every workload below.
  refCombine' =
    a: b:
    let
      aSet = builtins.listToAttrs (
        builtins.map (l: {
          name = l;
          value = true;
        }) a.__order
      );
      allLabels = a.__order ++ builtins.filter (l: !(aSet ? ${l})) b.__order;
    in
    {
      __entries = builtins.listToAttrs (
        builtins.map (l: {
          name = l;
          value = (a.__entries.${l} or [ ]) ++ (b.__entries.${l} or [ ]);
        }) allLabels
      );
      __order = allLabels;
    };

  # The library's composition and the reference's, behind one interface; deltas and readers use the
  # library's primitives on both sides, so only composition differs.
  lib' = {
    combine = R.combine;
    mixin = R.mixin;
    mixinBeta = R.mixinBeta;
    compose = R.compose;
  };
  ref = {
    combine = r: refCombine' r.left r.right;
    mixin = delta: parent: refCombine' (delta parent) parent;
    mixinBeta = prefix: suffix: refCombine' (prefix (refCombine' suffix R.empty)) suffix;
    compose =
      m1: m2: i:
      let
        m2i = m2 i;
      in
      refCombine' (m1 (refCombine' m2i i)) m2i;
  };

  # Deltas over a parent p: a new label; a new label that also re-stacks `shared`; a by-value read
  # of the parent; a delta whose labels depend on the parent's labels; an `extend`-built shadow.
  dNew =
    _: i: _p:
    R.fromAttrs { "n${toString i}" = i; };
  dOver =
    _: i: _p:
    R.fromAttrs {
      shared = "s${toString i}";
      "o${toString i}" = i;
    };
  dVal =
    _: i: p:
    R.fromAttrs { shared = "v${toString i}<${toString (R.select "shared" p)}"; };
  dLab =
    _: i: p:
    R.fromAttrs (
      builtins.listToAttrs (
        map (l: {
          name = "L${toString i}-${l}";
          value = l;
        }) (R.labels p)
      )
      // {
        shared = builtins.length (R.labels p);
      }
    );
  dExt =
    _: i: _p:
    R.extend "shared" "x${toString i}" (R.extend "zz${toString i}" i R.empty);

  base = R.extend "shared" "b2" (
    R.fromAttrs {
      shared = "b1";
      zeta = 0;
      alpha = 1;
    }
  );

  at = xs: i: builtins.elemAt xs (i - builtins.length xs * (i / builtins.length xs));
  step =
    C: dir: d: acc:
    if dir == "s" then
      C.mixin d acc
    else
      C.combine {
        left = acc;
        right = d acc;
      };
  # n fold steps, cycling through the directions and the delta kinds
  foldN =
    C: n: dirs: dks: b:
    builtins.foldl' (acc: i: step C (at dirs i) ((at dks i) C i) acc) b (builtins.genList (i: i) n);
  # a `compose` chain, each mixin outermost in the Beta direction and innermost in the Smalltalk one
  composeChain =
    C: dirs: dks: n:
    builtins.foldl' (
      acc: i: if at dirs i == "b" then C.compose acc ((at dks i) C i) else C.compose ((at dks i) C i) acc
    ) (p: p) (builtins.genList (i: i) n);

  # Every observable a reader has: the record itself (stacks and order), its rendering, its full
  # stacks, its heads, its labels, a depth and a pop.
  readings = r: {
    whole = r;
    show = R.show r;
    labels = R.labels r;
    emitAll = R.emitAll (R.labels r) r;
    emit = R.emit r;
    depthShared = R.depth "shared" r;
    popped = if R.has "shared" r then R.restrict "shared" r else r;
  };

  workloads = {
    empty-empty =
      C:
      C.combine {
        left = R.empty;
        right = R.empty;
      };
    empty-left =
      C:
      C.combine {
        left = R.empty;
        right = base;
      };
    empty-right =
      C:
      C.combine {
        left = base;
        right = R.empty;
      };
    self-combine =
      C:
      C.combine {
        left = base;
        right = base;
      };
    disjoint =
      C:
      C.combine {
        left = R.fromAttrs { a = 1; };
        right = R.fromAttrs { b = 2; };
      };
    overlap-stacks =
      C:
      C.combine {
        left = base;
        right = R.extend "shared" "r2" (
          R.fromAttrs {
            shared = "r1";
            alpha = 9;
          }
        );
      };
    single-s = C: foldN C 1 [ "s" ] [ dOver ] base;
    single-b = C: foldN C 1 [ "b" ] [ dOver ] base;
    many-s-new = C: foldN C 12 [ "s" ] [ dNew ] base;
    many-b-new = C: foldN C 12 [ "b" ] [ dNew ] base;
    many-s-over = C: foldN C 12 [ "s" ] [ dOver ] base;
    many-b-over = C: foldN C 12 [ "b" ] [ dOver ] base;
    interleaved = C: foldN C 12 [ "s" "b" "b" "s" ] [ dOver dNew dExt ] base;
    by-value-s = C: foldN C 8 [ "s" ] [ dVal ] base;
    by-value-b = C: foldN C 8 [ "b" ] [ dVal ] base;
    by-value-mixed = C: foldN C 8 [ "b" "s" ] [ dVal dOver ] base;
    by-labels-s = C: foldN C 4 [ "s" ] [ dLab ] base;
    by-labels-b = C: foldN C 4 [ "b" ] [ dLab ] base;
    by-labels-mixed = C: foldN C 5 [ "s" "b" ] [ dLab dOver ] base;
    ext-shadow = C: foldN C 6 [ "b" "s" ] [ dExt ] base;
    mixinBeta = C: C.mixinBeta (p: R.extend "shared" "pre" p) base;
    mixinBeta-over =
      C:
      C.mixinBeta (
        p:
        C.combine {
          left = R.fromAttrs {
            shared = "P";
            q = 1;
          };
          right = p;
        }
      ) base;
    compose-2 = C: C.compose (dOver C 1) (dVal C 2) base;
    compose-assoc-l = C: C.compose (C.compose (dOver C 1) (dVal C 2)) (dLab C 3) base;
    compose-assoc-r = C: C.compose (dOver C 1) (C.compose (dVal C 2) (dLab C 3)) base;
    compose-chain-s = C: composeChain C [ "s" ] [ dOver dVal ] 6 base;
    compose-chain-b = C: composeChain C [ "b" ] [ dOver dVal ] 6 base;
    compose-chain-mixed = C: composeChain C [ "s" "b" ] [ dOver dLab dVal ] 5 base;
    compose-chain-empty = C: composeChain C [ "s" ] [ dNew ] 0 R.empty;
    restrict-after =
      C: R.restrict "shared" (R.restrict "shared" (foldN C 3 [ "s" "b" ] [ dOver ] base));
    upsert-after =
      C: R.upsert "shared" "U" (R.rename "alpha" "omega" (foldN C 3 [ "b" ] [ dOver ] base));
  };

  # Composition forces no stack value: a throwing value is harmless to a reader of another label,
  # of the labels or of a depth.
  bomb = R.fromAttrs { bomb = throw "a stack value was forced"; };
  lazyCases = {
    has-other =
      C:
      R.has "alpha" (
        C.combine {
          left = R.extend "alpha" 1 bomb;
          right = bomb;
        }
      );
    labels = C: R.labels (C.mixin (_: bomb) (R.extend "k" 1 bomb));
    depth =
      C:
      R.depth "bomb" (
        C.combine {
          left = bomb;
          right = bomb;
        }
      );
    select-other =
      C:
      R.select "k" (
        foldN C 4
          [ "s" "b" ]
          [
            (
              _: _: _:
              bomb
            )
          ]
          (R.extend "k" 7 bomb)
      );
  };
  defined = x: (builtins.tryEval (builtins.deepSeq x x)).success;
in
{
  # Every workload's readings equal the reference's: the names of the workloads that differ.
  flake.tests.rec-composition-reference.test-composition-equals-the-reference = {
    expr = builtins.filter (n: readings (workloads.${n} lib') != readings (workloads.${n} ref)) (
      builtins.attrNames workloads
    );
    expected = [ ];
  };
  # The comparison discriminates: the reference against itself one step short differs, and so do the
  # two directions on an overlap (so the precedence workloads can see a swapped stack).
  flake.tests.rec-composition-reference.test-reference-comparison-discriminates = {
    expr = [
      (
        readings (foldN ref 12 [ "s" "b" "b" "s" ] [ dOver dNew dExt ] base)
        == readings (foldN ref 11 [ "s" "b" "b" "s" ] [ dOver dNew dExt ] base)
      )
      (foldN ref 3 [ "s" ] [ dOver ] base == foldN ref 3 [ "b" ] [ dOver ] base)
      (builtins.length (builtins.attrNames workloads))
    ];
    expected = [
      false
      false
      31
    ];
  };
  flake.tests.rec-composition-reference.test-composition-forces-no-stack-value = {
    expr = map (n: [
      (defined (lazyCases.${n} lib'))
      (defined (lazyCases.${n} ref))
    ]) (builtins.attrNames lazyCases);
    expected = [
      [
        true
        true
      ]
      [
        true
        true
      ]
      [
        true
        true
      ]
      [
        true
        true
      ]
    ];
  };
}
