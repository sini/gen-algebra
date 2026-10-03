# (c+) — den-hoag-markof-partial-preimage-znfjq: per-component preimage tags, a composite's
# components to its tags and sealed subjects, and the collision refusal. gen-schema's kind mark and
# gen-aspects' `cnf` identity both call this.
{
  genAlgebra,
  genIdentity,
  ...
}:
let
  inherit (genAlgebra)
    mkIntensional
    preimageTagOf
    componentsPreimage
    sealedMarker
    sealedCollisionEq
    ;
  tag = preimageTagOf genIdentity.hashIdentity;
  its = mkIntensional genIdentity.hashIdentity {
    revision = "r1";
    members.k = a: v: v == a;
  };
  registered = its "k" 1;
  subject = mark: sealed: {
    name = "thing";
    inherit mark sealed;
  };
  shared = {
    f = x: x;
  };
  decides = e: (builtins.tryEval e).success;
  sealedAt = path: value: {
    inherit path value;
    sealed = true;
  };
  # a composite over components, as a door hands it to `sealedCollisionEq`
  composite =
    cs:
    let
      p = componentsPreimage genIdentity.hashIdentity cs;
    in
    {
      name = "thing";
      mark = genIdentity.hashIdentity "c" [ "tags" ] (_: p.tags);
      inherit (p) tags sealed;
    };
in
{
  flake.tests.intensional-cplus = {
    # Every shape a component can take, each to its own tag.
    test-preimage-tag-covers-every-shape = {
      expr = {
        # a registered construction declares a compared subject and mints nothing (den-hoag-hhki8)
        registeredIsSealed = tag registered;
        unmintable = tag { __mint.unmintable.ctor = "c"; };
        unmigrated = tag {
          name = "n";
          f = x: x;
        };
        lambda = tag (x: x);
        inertIsKept = tag 3 != tag 4 && tag "a" == tag "a";
        inertComposite =
          tag {
            a = [
              1
              2
            ];
          }
          ? inert;
        undefined = tag (throw "no value");
        # Defined at WHNF with one throwing member: content is present, so it is not `undefined`.
        partial = tag { a = throw "no value"; };
      };
      expected = {
        registeredIsSealed = sealedMarker;
        unmintable = sealedMarker;
        unmigrated = sealedMarker;
        lambda = sealedMarker;
        inertIsKept = true;
        inertComposite = true;
        undefined = {
          undefined = true;
        };
        partial = sealedMarker;
      };
    };
    # A constructor-declared sealed component is tagged without trying; only sealed components
    # have subjects; a duplicated path is refused rather than dropped.
    test-components-preimage = {
      expr =
        let
          c = componentsPreimage genIdentity.hashIdentity [
            {
              path = [ "a" ];
              value = 1;
            }
            {
              path = [ "f" ];
              value = shared;
            }
            {
              path = [ "d" ];
              value = 2;
              sealed = true;
            }
          ];
        in
        {
          tags = builtins.mapAttrs (_: t: builtins.attrNames t) c.tags;
          sealed = builtins.attrNames c.sealed;
          duplicate =
            decides
              (componentsPreimage genIdentity.hashIdentity [
                {
                  path = [ "a" ];
                  value = 1;
                }
                {
                  path = [ "a" ];
                  value = 2;
                }
              ]).tags;
        };
      expected = {
        tags = {
          a = [ "inert" ];
          d = [ "sealed" ];
          f = [ "sealed" ];
        };
        sealed = [
          "d"
          "f"
        ];
        duplicate = false;
      };
    };
    # A caller's shape mistake is refused by name, catchably, at both doors.
    test-shape-mistakes-refuse-catchably = {
      expr = {
        notAList =
          decides
            (componentsPreimage genIdentity.hashIdentity {
              path = [ "a" ];
              value = 1;
            }).tags;
        noPath = decides (componentsPreimage genIdentity.hashIdentity [ { value = 1; } ]).tags;
        segmentNotAString =
          decides
            (componentsPreimage genIdentity.hashIdentity [
              {
                path = [ 1 ];
                value = 1;
              }
            ]).tags;
        sealedNotABool =
          decides
            (componentsPreimage genIdentity.hashIdentity [
              {
                path = [ "a" ];
                value = 1;
                sealed = "yes";
              }
            ]).tags;
        operandNotASubject = decides (sealedCollisionEq "s" { name = "n"; } (subject "m" { }));
      };
      expected = {
        notAList = false;
        noPath = false;
        segmentNotAString = false;
        sealedNotABool = false;
        operandNotASubject = false;
      };
    };
    # The decision, both directions, and the collision refused.
    test-sealed-collision-eq = {
      expr = {
        distinctMarks = sealedCollisionEq "s" (subject "m1" { }) (subject "m2" { });
        sameMarkSameSubject = sealedCollisionEq "s" (subject "m" { c = shared; }) (
          subject "m" { c = shared; }
        );
        sameMarkOtherSubject = decides (
          sealedCollisionEq "s" (subject "m" { c = shared; }) (
            subject "m" {
              c = {
                f = x: x;
              };
            }
          )
        );
      };
      expected = {
        distinctMarks = false;
        sameMarkSameSubject = true;
        sameMarkOtherSubject = false;
      };
    };
    # A registered construction enters a composite as a compared component, `{ compared = <its
    # declared subject>; }`, and decides by that subject: twins `true`, a different argument or
    # revision `false` (the evidence clause), never a refusal.
    test-registered-component-decides-by-its-subject = {
      expr =
        let
          r2 = mkIntensional genIdentity.hashIdentity {
            revision = "r2";
            members.k = a: v: v == a;
          };
          one = v: composite [ (sealedAt [ "check" ] v) ];
        in
        {
          entry = builtins.attrNames (one (its "k" 1)).sealed.check;
          twins = sealedCollisionEq "s" (one (its "k" 1)) (one (its "k" 1));
          otherArgument = sealedCollisionEq "s" (one (its "k" 1)) (one (its "k" 2));
          otherRevision = sealedCollisionEq "s" (one (its "k" 1)) (one (r2 "k" 1));
        };
      expected = {
        entry = [ "compared" ];
        twins = true;
        otherArgument = false;
        otherRevision = false;
      };
    };
    # The evidence clause reads a compared subject's inequality as evidence ONLY when the subject is
    # inert on both sides (ADR-0034's regimes): a registered construction whose `args` hold a lambda,
    # built twice, is refused by name, never decided `false`; so is a differing bare lambda.
    test-evidence-needs-an-inert-subject = {
      expr =
        let
          one = v: composite [ (sealedAt [ "check" ] v) ];
          fn1 = x: x;
          fn2 = x: x;
        in
        {
          lambdaArgsTwin = decides (
            sealedCollisionEq "s" (one (its "k" { f = x: x; })) (one (its "k" { f = x: x; }))
          );
          lambdaArgsOneBinding = sealedCollisionEq "s" (one (its "k" { f = fn1; })) (
            one (its "k" { f = fn1; })
          );
          inertArgsDiffer = sealedCollisionEq "s" (one (its "k" { lo = 1; })) (one (its "k" { lo = 2; }));
          bareLambdaDiffers = decides (sealedCollisionEq "s" (one fn1) (one fn2));
        };
      expected = {
        lambdaArgsTwin = false;
        lambdaArgsOneBinding = true;
        inertArgsDiffer = false;
        bareLambdaDiffers = false;
      };
    };
    # PROPAGATION: a minted component carrying a non-empty `__sealed` enters by its mark and hands its
    # `__sealed` to the parent under its path, so two parents over children that share a mark but
    # seal different registered terms decide `false`, and over twins `true`.
    test-sealed-subjects-propagate-to-the-parent = {
      expr =
        let
          child =
            v:
            let
              c = composite [ (sealedAt [ "check" ] v) ];
            in
            {
              __mint.minted = c.mark;
              __sealed = c.sealed;
            };
          parent =
            v:
            composite [
              {
                path = [ "elem" ];
                value = child v;
              }
            ];
        in
        {
          childMarksAgree = (child (its "k" 1)).__mint.minted == (child (its "k" 2)).__mint.minted;
          handedOver = builtins.attrNames (parent (its "k" 1)).sealed;
          tagIsTheMark = (parent (its "k" 1)).tags.elem ? minted;
          different = sealedCollisionEq "s" (parent (its "k" 1)) (parent (its "k" 2));
          twins = sealedCollisionEq "s" (parent (its "k" 1)) (parent (its "k" 1));
        };
      expected = {
        childMarksAgree = true;
        handedOver = [ "elem" ];
        tagIsTheMark = true;
        different = false;
        twins = true;
      };
    };
    # A MARK BESIDE SEALED COMPONENTS IS NOT AN EXACT IDENTITY (landing gate C1): the exported readers
    # put such a value on the compared arm, and `conservativeEq` decides it over the mark and the
    # sealed subjects, so two `typedef "loom"`s over two separately written lambdas are refused, never
    # called equal; `preimageTagOf` still enters it by its mark, for propagation.
    test-a-mark-beside-sealed-components-is-not-exact = {
      expr =
        let
          loom = f: {
            name = "loom";
            __mint.minted = "type:loom";
            __sealed.pred = f;
          };
          gt = v: v > 0;
          lt = v: v < 0;
          a = loom gt;
        in
        {
          exact = genAlgebra.isExact (genAlgebra.identityOf a);
          regime = genAlgebra.regimeTagOf (genAlgebra.identityOf a);
          twoLambdas = decides (genAlgebra.conservativeEq a (loom lt));
          oneBinding = genAlgebra.conservativeEq a (loom gt);
          otherMark = genAlgebra.conservativeEq a (a // { __mint.minted = "type:other"; });
          tagIsTheMark = tag a;
          controlMinted = genAlgebra.isExact (genAlgebra.identityOf { __mint.minted = "type:int"; });
        };
      expected = {
        exact = false;
        regime = "s";
        twoLambdas = false;
        oneBinding = true;
        otherMark = false;
        tagIsTheMark = {
          minted = "type:loom";
        };
        controlMinted = true;
      };
    };
    # A bare function's only identity is its value slot, so `sealed` hands the component's own slot
    # over: one shared lambda sealed twice decides `true` on every evaluator (upstream Nix and
    # Determinate refused it while the copy was a fresh thunk; Lix did not), and a second lambda of
    # the same text is still refused.
    test-sealed-bare-function-keeps-its-slot = {
      expr =
        let
          sealedOf =
            f:
            (componentsPreimage genIdentity.hashIdentity [
              {
                path = [ "f" ];
                value = f;
                sealed = true;
              }
            ]).sealed;
          lambda = x: x;
          otherLambda = x: x;
        in
        {
          shared = sealedCollisionEq "s" (subject "m" (sealedOf lambda)) (subject "m" (sealedOf lambda));
          other = decides (
            sealedCollisionEq "s" (subject "m" (sealedOf lambda)) (subject "m" (sealedOf otherLambda))
          );
        };
      expected = {
        shared = true;
        other = false;
      };
    };
  };
}
