# gen-algebra: the intensional ENCODER — its refusals, its coordinate, and conservative equality.
#
# The constructor this file exercises took `name`, `closure` and `fn` from the caller and compared
# on `name` alone. Both halves are gone: the closure is no longer a caller argument, so an
# under-complete one is inexpressible, and the relation dispatches on the identity regime.
{
  lib,
  genAlgebra,
  genIdentity,
  ...
}:
let
  inherit (genAlgebra) mkIntensional conservativeEq;

  admits = e: (builtins.tryEval e).success;
  refuses = e: !(builtins.tryEval e).success;

  # ── the injected mint, and it is the REAL one ──
  #
  # `hashIdentity` lives DOWNSTREAM of this library, which is exactly why the constructor takes the
  # minting authority as a PARAMETER rather than reaching for it — importing it from `lib/` would
  # close a flake dependency cycle.
  #
  # ★ THE SUITE MAY TAKE IT ANYWAY, AND THAT IS A RULING. The zero-inputs contract binds the
  # LIBRARY, not this directory: what it protects is a consumer's closure, and a consumer resolves
  # `../lib` and never ci's lock (owner, 2026-08-20, den-hoag-soa1 — "ci/ has its own flake").
  #
  # ★ WHAT THAT BUYS, stated because the stand-in it replaces was honest about its own limits: a
  # stub could carry the CONSTRUCTOR's arms and nothing else, so the composition of encoder and
  # constructor was untested by construction — the one thing no suite on either side could reach.
  # These cells now run against the authority itself.

  # ── the registry ──
  #
  # `members` maps a constructor name to a builder over the INERT argument value. The builder is
  # where the behaviour lives, so two values sharing a `ctor` and differing in `args` are two
  # substitutions at one program point — Palmer's §5.1 example, which is the pair the shipped
  # relation called equal.
  registry = {
    revision = "r1";
    members = {
      addN = args: (x: x + args.n);
      mulN = args: (x: x * args.n);
    };
  };
  mk = mkIntensional genIdentity.hashIdentity registry;

  # A second registry differing ONLY in its declared revision, and a third differing only in its
  # member set. Both exist to show the coordinate covers the registry instance and not just
  # `(ctor, args)`.
  registryR2 = registry // {
    revision = "r2";
  };
  registryWiderMembers = registry // {
    members = registry.members // {
      subN = args: (x: x - args.n);
    };
  };
in
{
  ## The record, and the shape every shipped guard reads.

  flake.tests.intensional.test-mkIntensional-is-callable = {
    expr = (mk "addN" { n = 1; }) 5;
    expected = 6;
  };

  # `name` is the PROGRAM POINT and it is now DERIVED from the constructor rather than supplied by
  # the caller — which is what closes Def 5.7(3)'s hole, where two bodies could share one point.
  flake.tests.intensional.test-name-is-the-constructor = {
    expr = (mk "addN" { n = 1; }).name;
    expected = "addN";
  };

  # The reified closure IS `args`. It keeps its field name so every shipped shape guard still
  # admits the value, and there is no second thing a caller could under-supply.
  flake.tests.intensional.test-closure-is-the-argument-value = {
    expr =
      (mk "mulN" {
        n = 2;
        note = "kept";
      }).closure;
    expected = {
      n = 2;
      note = "kept";
    };
  };

  # ADMISSION, against the shipped shape guards written VERBATIM. An encoder-built value must pass
  # every one of them, or it is inadmissible everywhere the substrate reads an intensional value.
  # CONTROL, in the same cell: a record with no `name` fails all of them, so a run in which the
  # field-less arm passes has not tested this.
  flake.tests.intensional.test-shipped-shape-guards-admit = {
    expr =
      let
        v = mk "addN" { n = 1; };
        fieldless = {
          ctor = "addN";
          __functor = self: self;
        };
        # gen-dispatch/lib/core/rule.nix and gen-select/lib/constructors.nix, same predicate.
        isIntensional = x: builtins.isAttrs x && x ? name && x ? __functor && x ? closure;
        # gen-select/lib/constructors.nix, the `when`-selector limb of `isIdentified`.
        isIdentifiedFn = x: builtins.isAttrs x && x ? name && x ? __functor && x ? closure;
        # gen-algebra/lib/search.nix, the dedup loop's own guard.
        classifiable = x: x ? name && x ? closure;
      in
      {
        encoderBuilt = isIntensional v && isIdentifiedFn v && classifiable v;
        controlFieldless = isIntensional fieldless || isIdentifiedFn fieldless || classifiable fieldless;
      };
    expected = {
      encoderBuilt = true;
      controlFieldless = false;
    };
  };

  ## The refusals — each by name, each catchable.

  flake.tests.intensional.test-refuses-unknown-constructor = {
    expr = refuses (mk "notDeclared" { n = 1; });
    expected = true;
  };

  # `revision` is REQUIRED AND TOTAL. A registry without one is refused at construction rather than
  # defaulted, because a default would silently mean "no constraint" at the one place the constraint
  # does work — two registries with the same member names and different builder bodies are
  # indistinguishable to every builtin, so nothing else can catch the collapse.
  flake.tests.intensional.test-refuses-registry-without-revision = {
    expr = refuses (
      mkIntensional genIdentity.hashIdentity { inherit (registry) members; } "addN" { n = 1; }
    );
    expected = true;
  };

  flake.tests.intensional.test-refuses-registry-without-members = {
    expr = refuses (
      mkIntensional genIdentity.hashIdentity { inherit (registry) revision; } "addN" { n = 1; }
    );
    expected = true;
  };

  # CONTROL on the instrument: `tryEval` catches a named `throw` in this very run, so a `refuses`
  # cell above reports a refusal rather than an unrelated evaluation failure.
  flake.tests.intensional.test-control-tryEval-catches-a-named-throw = {
    expr = refuses (throw "boom") && admits "fine";
    expected = true;
  };

  ## The coordinate — what the mint is total over.

  # ★ THE CELL THAT REVERSES. Two values at ONE program point under differing substitutions behave
  # differently — `addN {n=1;} 5` is 6 and `addN {n=2;} 5` is 7 — and the shipped relation called
  # them EQUAL, which is Palmer's own §5.1 counterexample arriving in gen's own tree.
  #
  # RED CONTROL, in the same cell and required: comparing `name` alone STILL merges them. That is
  # what shows the pair is the witness and the new relation is what separates it, rather than the
  # pair having quietly stopped colliding.
  flake.tests.intensional.test-conservativeEq-separates-differing-args = {
    expr =
      let
        a = mk "addN" { n = 1; };
        b = mk "addN" { n = 2; };
      in
      {
        relation = conservativeEq a b;
        behavioursDiffer = (a 5) != (b 5);
        controlNameOnlyStillMerges = a.name == b.name;
      };
    expected = {
      relation = false;
      behavioursDiffer = true;
      controlNameOnlyStillMerges = true;
    };
  };

  flake.tests.intensional.test-conservativeEq-separates-different-constructors = {
    expr = conservativeEq (mk "addN" { n = 1; }) (mk "mulN" { n = 1; });
    expected = false;
  };

  # CONTROL: the relation is not false everywhere. Two INDEPENDENTLY CONSTRUCTED values with the
  # same coordinate mint one identity and compare equal — which a relation resting on allocation
  # identity could not deliver, and without which every splitting cell above passes vacuously.
  flake.tests.intensional.test-control-equal-coordinates-merge = {
    expr = conservativeEq (mk "addN" { n = 1; }) (mk "addN" { n = 1; });
    expected = true;
  };

  # ★ THE REGISTRY INSTANCE IS IN THE COORDINATE, and these are the two arms that show it. Nix has
  # no linking, so a builder's free variables include its registry module instance's whole lexical
  # scope; without that term two pins of the substrate would give one identity to two behaviours.
  # `revision` is the declared half and the member set is the derived half.
  flake.tests.intensional.test-registry-coordinate-discriminates = {
    expr =
      let
        base = mk "addN" { n = 1; };
        otherRevision = mkIntensional genIdentity.hashIdentity registryR2 "addN" { n = 1; };
        widerMembers = mkIntensional genIdentity.hashIdentity registryWiderMembers "addN" { n = 1; };
      in
      {
        revisionSeparates = conservativeEq base otherRevision;
        memberSetSeparates = conservativeEq base widerMembers;
      };
    expected = {
      revisionSeparates = false;
      memberSetSeparates = false;
    };
  };

  ## Cost — the mint is lazy, and demanding it forces.

  # An intensional value nobody compares hashes nothing: constructing one whose `args` carry a
  # throwing thunk succeeds, and reading its `name` and calling it both succeed. Forcing the mint is
  # what reaches the thunk — so the cost is paid by the consumer that DEMANDS an identity, and a
  # lazily-failing leaf fails at mint time rather than at first read.
  flake.tests.intensional.test-mint-is-lazy-and-forces-when-demanded = {
    expr =
      let
        v = mk "addN" {
          n = 1;
          rotten = throw "leaf";
        };
      in
      {
        constructing = admits v.name;
        callable = admits (v 5);
        demandingTheMintForces = refuses v.__mint.minted;
      };
    expected = {
      constructing = true;
      callable = true;
      demandingTheMintForces = true;
    };
  };

  ## The non-exact arm — unmigrated and sealed values, which the encoder cannot produce.
  #
  # Both are hand-built records of the shape every shipped guard admits. Each pair shares ONE base
  # and overrides ONE key, because Nix `==` compares an attrset's values in name order with a
  # pointer fast path: two independently built records differ at `__functor` before any payload is
  # reached, and a cell built that way would measure the ordering accident, not the comparison.

  # ★ THE UNMIGRATED REGIME DECIDES ON CONTENT, NOT ON THE NAME (ADR-0034, den-hoag-3f39). Two
  # values at one program point with differing closures and differing behaviour used to compare
  # EQUAL on `name` alone — the coarsening Fig. 5 forbids. They now fall through to the reified
  # comparison, which separates them.
  #
  # CONTROLS in the same cell: the pair still shares its name, so the name cannot be what separates
  # it; a value against itself and an inert equal-shaped rebound pair still identify, so the
  # relation is not constant-false; distinct names still separate, so it is not constant-true. The
  # `closureOnly` pair shares the `fn` cell and differs in `closure` alone, so allocation cannot
  # separate it: it is the row that reds when `closure` leaves the comparison subject. The
  # rebound LAMBDA-carrying pair is the priced loss — separately allocated lambdas compare unequal,
  # which merges strictly less than Fig. 5 and never more.
  flake.tests.intensional.test-unmigrated-decides-on-content-not-name =
    let
      base = {
        name = "counter";
        closure = {
          k = 1;
        };
        fn = v: "${toString base.closure.k}:${v}";
        __functor = self: self.fn;
      };
      u1 = base;
      u7 = base // {
        closure = {
          k = 7;
        };
        fn = v: "7:${v}";
      };
      lambdaCarrying = _: {
        name = "counter";
        closure = { };
        fn = v: v;
        __functor = self: self.fn;
      };
    in
    {
      expr = {
        differingClosures = conservativeEq u1 u7;
        closureOnly = conservativeEq u1 (base // { closure.k = 7; });
        behavioursDiffer = (u1 "x") != (u7 "x");
        regime = genAlgebra.regimeTagOf (genAlgebra.identityOf u1);
        controlNamesEqual = u1.name == u7.name;
        controlSelf = conservativeEq u1 u1;
        controlDistinctNames = conservativeEq u1 (base // { name = "other"; });
        inertReboundEqual = conservativeEq (base // { closure.k = 1; }) (base // { closure.k = 1; });
        lambdaCarryingRebound = conservativeEq (lambdaCarrying 1) (lambdaCarrying 2);
      };
      expected = {
        differingClosures = false;
        closureOnly = false;
        behavioursDiffer = true;
        regime = "u";
        controlNamesEqual = true;
        controlSelf = true;
        controlDistinctNames = false;
        inertReboundEqual = true;
        lambdaCarryingRebound = false;
      };
    };

  # ★ THE DOMAIN BOUNDARY ON THE NON-EXACT ARM. `comparisonSubject` excludes `__id` and NOTHING ELSE,
  # so it discharges the one refusal ADR-0034 requires a sealed producer to carry and no other: a
  # refusal one key over surfaces as its own named, catchable throw. The same boundary gen-select
  # rules at `selectorEq` and pins with `test-structural-fallthrough-forces-its-payload`, whose four
  # arms this cell mirrors, driven in BOTH non-exact regimes.
  #
  # The ordinary-key arm is the cell's other half, not a nicety: without it the cell is green on a
  # build that excludes every key and on one that excludes none. A self-referential payload sits on
  # the same boundary but aborts the evaluator uncatchably, so no cell can hold it; it is written at
  # `conservativeEq`'s binding instead.
  flake.tests.intensional.test-non-exact-arm-forces-its-payload =
    let
      decides = e: (builtins.tryEval e).success;
      shaped =
        regime:
        {
          name = "counter";
          closure = { };
          fn = v: v;
          __functor = self: self.fn;
        }
        // regime;
      arms =
        regime:
        let
          base = shaped regime;
          eqOn = a: b: conservativeEq (base // a) (base // b);
        in
        {
          withRefusingAccessor = decides (
            eqOn { __id = throw "identity: no mintable identity"; } {
              __id = throw "identity: no mintable identity";
            }
          );
          withOrdinaryKey = decides (eqOn { zz = throw "plain"; } { zz = throw "plain"; });
          withNoRefusal = eqOn { zz = "v"; } { zz = "v"; };
          withNoRefusalDiffering = eqOn { zz = "v"; } { zz = "w"; };
        };
      boundary = {
        withRefusingAccessor = true;
        withOrdinaryKey = false;
        withNoRefusal = true;
        withNoRefusalDiffering = false;
      };
    in
    {
      expr = {
        unmigrated = arms { };
        sealed = arms {
          __mint.unmintable = {
            reason = "a lambda in an identity position";
            ctor = "counter";
          };
        };
      };
      expected = {
        unmigrated = boundary;
        sealed = boundary;
      };
    };
}
