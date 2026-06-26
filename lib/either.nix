# Either combinators — { right = value; } | { left = error; }
# Used by gen-algebra's validation pipeline and downstream consumers.
{
  right = value: { right = value; };

  left = value: { left = value; };

  # Short-circuit pipe: first left stops the chain.
  # fns: list of (value -> Either)
  pipe =
    fns: value:
    builtins.foldl' (acc: f: if acc ? left then acc else f acc.right) { right = value; } fns;

  # Accumulate all errors (don't short-circuit).
  # fns: list of (value -> Either)
  collectErrors =
    fns: value:
    let
      results = map (f: f value) fns;
      errors = builtins.filter (r: r ? left) results;
    in
    if errors == [ ] then { right = value; } else { left = map (r: r.left) errors; };

  # Map over right value.
  mapR = f: e: if e ? right then { right = f e.right; } else e;

  # Chain (flatMap on right).
  chain = f: e: if e ? right then f e.right else e;
}
