{
  description = "gen-algebra: pure Nix algebra — search monad, records, intensional functions, either";
  outputs = _: {
    __functor = _: import ./.;
    lib = import ./lib;
  };
}
