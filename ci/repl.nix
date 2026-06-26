# gen-algebra REPL — all exports in scope.
let
  nixpkgs = import (builtins.getFlake "nixpkgs") { };
  genAlgebra = import ./.. { inherit (nixpkgs) lib; };
in
{ inherit (nixpkgs) lib; } // genAlgebra // { lib = genAlgebra.lib; }
