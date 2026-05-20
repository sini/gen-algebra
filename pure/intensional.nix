# Palmer §2.2-2.3: intensional function constructor and conservative equality.
{
  # Program point identity. closure is inspect-only data, not hashed.
  mkIntensional = name: closure: fn: {
    inherit name fn closure;
    key = name;
    __functor = self: self.fn;
  };

  # Conservative equality by program point.
  intensionalEq = a: b: a.key == b.key;
}
