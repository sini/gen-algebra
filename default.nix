# gen-algebra is pure — zero dependencies (builtins + its own algebra). Zero deps, so
# the standalone (non-flake) entry is the lib value itself, not a function.
# The module-system tier (identity/strict/validators/refs) relocated to gen-schema.
import ./lib
