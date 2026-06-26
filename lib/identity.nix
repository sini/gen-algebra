# Standalone identity hash — Palmer §2.2 program point + fields → stable hash.
# No module system dependency. For module-system identity (mkIdentityModule), see
# gen-schema (nix/lib/identity.nix) — the module tier relocated there.
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
