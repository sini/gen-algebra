{
  # Accepts `{ lib }` for call-compatibility (consumers do
  # `import gen-algebra { inherit lib; }`), but gen-algebra is now fully pure —
  # `lib` is unused. The module-system tier (identity/strict/validators/refs)
  # relocated to gen-schema, its sole consumer. See
  # ~/Documents/papers/den-architecture/gen-specs/gen-algebra/2026-06-26-module-tier-relocation.md
  ...
}:
let
  pure = import ./pure;
in
{ pure = pure; } // pure
