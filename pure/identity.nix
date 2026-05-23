# Standalone identity hash — Palmer §2.2 program point + closure → stable hash.
# No module system dependency. For module-system identity, see module/identity.nix.
let
  inherit (import ./xxh64.nix) xxh64;
in
{
  # name: program point (definition site identifier)
  # fields: serializable closure contents (attrset of primitives)
  # Returns: "${name}:${xxh64(toJSON(fields))}"
  mkIdentity =
    {
      name,
      fields ? { },
    }:
    "${name}:${xxh64 (builtins.toJSON fields)}";
}
