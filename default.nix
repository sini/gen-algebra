{
  # Accepts `{ lib }` for call-compatibility (consumers historically did
  # `import gen-algebra { inherit lib; }`), but gen-algebra is now fully pure —
  # any nixpkgs `lib` passed is unused. The module-system tier
  # (identity/strict/validators/refs) relocated to gen-schema, its sole consumer.
  # See ~/Documents/papers/den-architecture/gen-specs/gen-algebra/2026-06-26-module-tier-relocation.md
  ...
}:
import ./lib
