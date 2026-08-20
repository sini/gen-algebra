{
  description = "gen-algebra demo: search monad, intensional dedup, record algebra, either";

  inputs = {
    gen-algebra.url = "github:sini/gen-algebra";
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      lib = nixpkgs.lib;
      g = inputs.gen-algebra.lib;
      inherit (g)
        search
        mkIntensional
        ;

      # mkIntensional is an ENCODER: it takes the minting authority and a registry,
      # then a constructor name and an inert argument value. The author supplies
      # (ctor, args) and nothing else — there is no closure argument to under-supply.
      #
      # THE MINT IS INJECTED because gen-schema's `hashIdentity`, the substrate's one
      # minting authority, lives downstream of gen-algebra; importing it would close a
      # flake dependency cycle. A real consumer passes `genSchema.hashIdentity` here.
      # This demo stands one in so it stays what gen-algebra itself is: dependency-free.
      mintStub =
        kind: labels: valueOf:
        "${kind}:"
        + builtins.toJSON (
          map (l: [
            l
            (valueOf l)
          ]) labels
        );

      # `members` maps a constructor name to a builder over the inert argument value —
      # the builder is where the behaviour lives. `revision` is required and total: a
      # registry declaring none is refused by name at construction, never defaulted.
      registry = {
        revision = "demo-r1";
        members.counter = args: (v: s: search.emit [ "${args.tag}:${v}" ] s);
      };
      mk = mkIntensional mintStub registry;
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
      # TWO INDEPENDENTLY CONSTRUCTED continuations sharing one coordinate — same ctor,
      # same args — mint ONE identity, so the dedup key is exact and only one fires.
      # Give the second a different `tag` and both fire: they are then two behaviours,
      # and the relation that used to compare program-point names alone merged them.
      dedupResult =
        let
          s0 = search.insert "k" "v" search.empty;
          s1 = search.on "k" (mk "counter" { tag = "counted"; }) s0;
          s2 = search.on "k" (mk "counter" { tag = "counted"; }) s1;
          final = search.converge s2;
        in
        final.results;
      # → [ "counted:v" ]

      # Record algebra: scoped labels (Leijen 2005)
      # Duplicate labels form a stack — restriction exposes previous values.
      scopedLabels =
        let
          R = g.record;
          base = R.fromAttrs {
            level = "info";
            port = 8080;
          };
          env = R.extend base "level" "warn";
          user = R.extend env "level" "debug";
        in
        {
          current = R.select user "level"; # → "debug"
          previous = R.select (R.restrict user "level") "level"; # → "warn"
          original = R.select (R.restrict (R.restrict user "level") "level") "level"; # → "info"
          depth = R.depth user "level"; # → 3
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
          combined = R.combine overlay base;

          # Smalltalk mixin: delta receives parent, delta's values win
          delta =
            parent:
            R.fromAttrs {
              metricsPort = (R.select parent "port") + 1000;
              debug = false;
            };
          mixed = R.mixin delta base;

          # emitAll: full stacks for listed labels, heads for rest
          stacked = R.combine (R.fromAttrs { tags = [ "prod" ]; }) (
            R.fromAttrs {
              tags = [ "base" ];
              port = 80;
            }
          );
        in
        {
          combinedPort = R.select combined "port"; # → 9090
          combinedHostname = R.select combined "hostname"; # → "localhost"
          combinedHasDebug = R.has combined "debug"; # → true
          mixedMetrics = R.select mixed "metricsPort"; # → 9080
          mixedDebug = R.select mixed "debug"; # → false (delta wins)
          labelOrder = R.labels combined; # → [ "debug" "port" "hostname" ]
          fullStacks = R.emitAll stacked [ "tags" ]; # → { tags = [ ["prod"] ["base"] ]; port = 80; }
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
          hasRequired = R.satisfies r [
            "port"
            "hostname"
          ]; # → true
          missingField = R.satisfies r [
            "port"
            "nonexistent"
          ]; # → false
          emptyReqs = R.satisfies r [ ]; # → true
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
