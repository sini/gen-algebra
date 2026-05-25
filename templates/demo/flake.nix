{
  description = "gen demo: search monad, intensional dedup, record algebra, validation";

  inputs = {
    gen.url = "github:sini/gen";
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    { gen, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      g = gen { inherit lib; };
      inherit (g) search mkIntensional mkValidator runValidators;
    in
    {
      # Pure tier: search monad workflow
      # Insert users, register continuation that derives greetings, converge.
      searchResult =
        let
          s0 = search.insert "users" "alice" search.empty;
          s1 = search.insert "users" "bob" s0;
          s2 = search.on "users" (name: s: search.emit [ "hello:${name}" ] s) s1;
          final = search.converge s2;
        in
        final.results;
      # → [ "hello:alice" "hello:bob" ]

      # Pure tier: intensional continuation dedup
      # Two mkIntensional fns with same key registered — only one fires.
      dedupResult =
        let
          counter = mkIntensional "my-counter" { } (v: s: search.emit [ "counted:${v}" ] s);
          s0 = search.insert "k" "v" search.empty;
          s1 = search.on "k" counter s0;
          s2 = search.on "k" counter s1;
          final = search.converge s2;
        in
        final.results;
      # → [ "counted:v" ]

      # Module tier: validation pass
      validationPass =
        let
          validators = [
            (mkValidator "has-name" (x: x ? name && x.name != "") "must have a name")
            (mkValidator "positive-age" (x: x ? age && x.age > 0) "age must be positive")
          ];
          instances = {
            alice = {
              name = "Alice";
              age = 30;
            };
            bob = {
              name = "Bob";
              age = 25;
            };
          };
        in
        runValidators "person" validators instances;
      # → { right = { alice = { ... }; bob = { ... }; }; }

      # Module tier: validation fail
      validationFail =
        let
          validators = [
            (mkValidator "has-name" (x: x ? name && x.name != "") "must have a name")
            (mkValidator "positive-age" (x: x ? age && x.age > 0) "age must be positive")
          ];
          instances = {
            alice = {
              name = "Alice";
              age = 30;
            };
            broken = {
              name = "";
              age = -1;
            };
          };
        in
        runValidators "person" validators instances;
      # → { left = [ { kind = "person"; name = "broken"; validator = "has-name"; message = "must have a name"; } ... ]; }

      # Record algebra: scoped labels (Leijen 2005)
      # Duplicate labels form a stack — restriction exposes previous values.
      scopedLabels =
        let
          R = g.pure.record;
          base = R.fromAttrs { level = "info"; port = 8080; };
          env = R.extend base "level" "warn";
          user = R.extend env "level" "debug";
        in
        {
          current = R.select user "level";                                           # → "debug"
          previous = R.select (R.restrict user "level") "level";                     # → "warn"
          original = R.select (R.restrict (R.restrict user "level") "level") "level"; # → "info"
          depth = R.depth user "level";                                              # → 3
          emitted = R.emit user;                                                     # → { level = "debug"; port = 8080; }
        };

      # Record algebra: combination and composition (Bracha 1990)
      # combine is left-biased (⊕), mixin is Smalltalk direction.
      recordComposition =
        let
          R = g.pure.record;
          base = R.fromAttrs { port = 8080; hostname = "localhost"; };
          overlay = R.fromAttrs { port = 9090; debug = true; };

          # Left-biased combination: overlay wins on port
          combined = R.combine overlay base;

          # Smalltalk mixin: delta receives parent, delta's values win
          delta = parent: R.fromAttrs {
            metricsPort = (R.select parent "port") + 1000;
            debug = false;
          };
          mixed = R.mixin delta base;

          # emitAll: full stacks for listed labels, heads for rest
          stacked = R.combine (R.fromAttrs { tags = ["prod"]; }) (R.fromAttrs { tags = ["base"]; port = 80; });
        in
        {
          combinedPort = R.select combined "port";            # → 9090
          combinedHostname = R.select combined "hostname";    # → "localhost"
          combinedHasDebug = R.has combined "debug";          # → true
          mixedMetrics = R.select mixed "metricsPort";        # → 9080
          mixedDebug = R.select mixed "debug";                # → false (delta wins)
          labelOrder = R.labels combined;                     # → [ "port" "debug" "hostname" ]
          fullStacks = R.emitAll stacked [ "tags" ];          # → { tags = [ ["prod"] ["base"] ]; port = 80; }
        };

      # Record algebra: row compatibility (Leijen §3.1)
      rowCompatibility =
        let
          R = g.pure.record;
          r = R.fromAttrs { port = 8080; hostname = "localhost"; protocol = "tcp"; };
        in
        {
          hasRequired = R.satisfies r [ "port" "hostname" ];     # → true
          missingField = R.satisfies r [ "port" "nonexistent" ]; # → false
          emptyReqs = R.satisfies r [ ];                         # → true
        };

      # Either: pipe (short-circuit) and collectErrors (accumulate)
      eitherDemo =
        let
          E = g.pure.either;

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
          pipeSuccess = pipeResult;       # → { right = 10; }
          pipeFailure = pipeFail;         # → { left = "must be positive"; }
          allErrors = collected;          # → { left = [ "must be positive" "must be > -3" ]; }
          mappedResult = mapped;          # → { right = 42; }
          chainedResult = chained;        # → { right = 30; }
        };
    };
}
