{
  description = "gen: generic Nix infrastructure — search, identity, validation";
  outputs = _: {
    __functor = _: import ./.;
    lib = import ./pure;
  };
}
