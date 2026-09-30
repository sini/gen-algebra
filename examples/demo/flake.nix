{
  description = "gen-algebra demo: record algebra, either";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    { nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      g = import ../.. { };
    in
    {
      # Record algebra: scoped labels (Leijen 2005)
      # Duplicate labels form a stack — restriction exposes previous values.
      scopedLabels =
        let
          R = g.record;
          base = R.fromAttrs {
            level = "info";
            port = 8080;
          };
          env = R.extend "level" "warn" base;
          user = R.extend "level" "debug" env;
        in
        {
          current = R.select "level" user; # → "debug"
          previous = R.select "level" (R.restrict "level" user); # → "warn"
          original = R.select "level" (R.restrict "level" (R.restrict "level" user)); # → "info"
          depth = R.depth "level" user; # → 3
          emitted = R.emit user; # → { level = "debug"; port = 8080; }
        };

      # Record algebra: combination and composition (Bracha 1990)
      # combine is left-biased (⊕), mixin is Smalltalk direction.
      recordComposition =
        let
          R = g.record;
          base = R.fromAttrs {
            port = 8080;
            hostname = "localhost";
          };
          overlay = R.fromAttrs {
            port = 9090;
            debug = true;
          };

          # Left-biased combination: overlay wins on port
          combined = R.combine {
            left = overlay;
            right = base;
          };

          # Smalltalk mixin: delta receives parent, delta's values win
          delta =
            parent:
            R.fromAttrs {
              metricsPort = (R.select "port" parent) + 1000;
              debug = false;
            };
          mixed = R.mixin delta base;

          # emitAll: full stacks for listed labels, heads for rest
          stacked = R.combine {
            left = R.fromAttrs { tags = [ "prod" ]; };
            right = R.fromAttrs {
              tags = [ "base" ];
              port = 80;
            };
          };
        in
        {
          combinedPort = R.select "port" combined; # → 9090
          combinedHostname = R.select "hostname" combined; # → "localhost"
          combinedHasDebug = R.has "debug" combined; # → true
          mixedMetrics = R.select "metricsPort" mixed; # → 9080
          mixedDebug = R.select "debug" mixed; # → false (delta wins)
          labelOrder = R.labels combined; # → [ "debug" "port" "hostname" ]
          fullStacks = R.emitAll [ "tags" ] stacked; # → { tags = [ ["prod"] ["base"] ]; port = 80; }
        };

      # Record algebra: row compatibility (Leijen §3.1)
      rowCompatibility =
        let
          R = g.record;
          r = R.fromAttrs {
            port = 8080;
            hostname = "localhost";
            protocol = "tcp";
          };
        in
        {
          hasRequired = R.satisfies [
            "port"
            "hostname"
          ] r; # → true
          missingField = R.satisfies [
            "port"
            "nonexistent"
          ] r; # → false
          emptyReqs = R.satisfies [ ] r; # → true
        };

      # Either: pipe (short-circuit) and collectErrors (accumulate)
      eitherDemo =
        let
          E = g.either;

          # Pipe: first failure stops the chain
          pipeResult = E.pipe [
            (x: if x > 0 then E.right (x * 2) else E.left "must be positive")
            (x: if x < 100 then E.right x else E.left "too large")
          ] 5;

          pipeFail = E.pipe [
            (x: if x > 0 then E.right (x * 2) else E.left "must be positive")
            (x: if x < 100 then E.right x else E.left "too large")
          ] (-1);

          # collectErrors: all errors accumulated
          collected = E.collectErrors [
            (x: if x > 0 then E.right x else E.left "must be positive")
            (x: if x > -3 then E.right x else E.left "must be > -3")
          ] (-5);

          # mapR / chain
          mapped = E.mapR (x: x + 1) (E.right 41);
          chained = E.chain (x: if x > 0 then E.right (x * 10) else E.left "neg") (E.right 3);
        in
        {
          pipeSuccess = pipeResult; # → { right = 10; }
          pipeFailure = pipeFail; # → { left = "must be positive"; }
          allErrors = collected; # → { left = [ "must be positive" "must be > -3" ]; }
          mappedResult = mapped; # → { right = 42; }
          chainedResult = chained; # → { right = 30; }
        };
    };
}
