{
  description = "gen-algebra: pure Nix algebra — search monad, records, intensional functions, either";

  # Zero dependencies — builtins plus gen-algebra's own domain algebra. The flake declares
  # no inputs, so consumers gain no transitive dependency. The entry is a bare value.
  outputs =
    { ... }:
    {
      lib = import ./lib;
    };
}
