# gen-algebra is pure — zero dependencies (builtins + its own algebra). Zero deps do not
# make the standalone (non-flake) entry a bare value: it is a NULLARY FUNCTION, so
# `import ./. { }` is the one call text that answers every roster member alike, leaf or
# not, and gen-algebra gaining a dependency later changes what the empty pattern defaults
# to, never the call text at this root (den-hoag-iev2q). The empty pattern, not `_:` —
# `_:` would silently accept and drop an unexpected argument; `{ }:` refuses one loudly.
# The module-system tier (identity/strict/validators/refs) relocated to gen-schema.
{ }: import ./lib
