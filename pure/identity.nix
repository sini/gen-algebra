# Standalone identity hash — Palmer §2.2 program point + fields → stable hash.
# No module system dependency. For module-system identity, see module/identity.nix.
{
  # name: program point (definition site identifier)
  # fields: serializable closure contents (attrset of primitives)
  # Returns: "${name}:${sha256(toJSON(fields))}"
  mkIdentity =
    {
      name,
      fields ? { },
    }:
    "${name}:${builtins.hashString "sha256" (builtins.toJSON fields)}";
}
