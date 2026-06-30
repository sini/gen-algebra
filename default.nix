# gen-algebra is pure — zero dependencies (builtins + its own algebra). Zero deps, so
# the standalone (non-flake) entry is the lib value itself, not a function.
# The module-system tier (identity/strict/validators/refs) relocated to gen-schema.
# See ~/Documents/papers/den-architecture/gen-specs/gen-algebra/2026-06-26-module-tier-relocation.md
import ./lib
