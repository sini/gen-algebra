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
  minted = its "k" 1;
  subject = mark: sealed: {
    name = "thing";
    inherit mark sealed;
  };
  shared = {
    f = x: x;
  };
  decides = e: (builtins.tryEval e).success;
in
{
  flake.tests.intensional-cplus = {
    # Every shape a component can take, each to its own tag.
    test-preimage-tag-covers-every-shape = {
      expr = {
        mintedIsItsDigest = tag minted == { minted = minted.__mint.minted; };
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
        mintedIsItsDigest = true;
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
  };
}
