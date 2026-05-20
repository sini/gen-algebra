{
  description = "gen demo: search monad, intensional dedup, validation";

  inputs = {
    gen.url = "github:vic/gen";
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
    };
}
