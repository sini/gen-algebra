# gen benchmarks: xxh64 vs SHA256 hash comparison.
#
# Pure expressions evaluated externally via `nix eval` with wall-clock timing.
# Parameterized by input size to show scaling behavior.
#
# Usage:
#   nix eval --file ./bench xxh64.empty        # single benchmark
#   ./bench/run.sh                              # full suite
#   ./bench/run.sh --quick                      # single run per benchmark
let
  gen = import ../. { };
  inherit (gen) xxh64;

  # Generate test strings of various lengths
  mkString = n: builtins.concatStringsSep "" (builtins.genList (_: "x") n);

  inputs = {
    empty = "";
    tiny = "abc";                   # 3 bytes
    short = mkString 16;            # 16 bytes
    medium = mkString 64;           # 64 bytes — 2 stripes
    long = mkString 256;            # 256 bytes — 8 stripes
    large = mkString 1024;          # 1 KB
    json-small = builtins.toJSON { hostname = "igloo"; user = "tux"; };
    json-medium = builtins.toJSON {
      hostname = "igloo";
      user = "tux";
      domain = "example.com";
      role = "server";
      enabled = true;
      priority = 42;
      tags = [ "nix" "gen" "xxhash" ];
    };
  };

  # xxh64 benchmarks — force evaluation by checking string length
  xxh64Bench = builtins.mapAttrs (
    _: input: builtins.stringLength (xxh64 input)
  ) inputs;

  # SHA256 benchmarks — same inputs, using builtins.hashString
  sha256Bench = builtins.mapAttrs (
    _: input: builtins.stringLength (builtins.hashString "sha256" input)
  ) inputs;

  # Batch: hash N different strings to amortize nix eval startup
  mkBatch = hashFn: n:
    let
      strings = builtins.genList (i: mkString (i + 1)) n;
    in
    builtins.foldl' (acc: s: acc + builtins.stringLength (hashFn s)) 0 strings;

  batch = {
    xxh64-10 = mkBatch xxh64 10;
    xxh64-50 = mkBatch xxh64 50;
    xxh64-100 = mkBatch xxh64 100;
    sha256-10 = mkBatch (builtins.hashString "sha256") 10;
    sha256-50 = mkBatch (builtins.hashString "sha256") 50;
    sha256-100 = mkBatch (builtins.hashString "sha256") 100;
  };
in
{
  xxh64 = xxh64Bench;
  sha256 = sha256Bench;
  inherit batch;
}
