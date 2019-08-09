# Update for https://github.com/Leu-Gim/Nim-modules/blob/master/justforfun.nim

# So, we want to deal with the infinite... even if not really.
# But to look convincing. :) Just for fun.

# We special name the base class, so that you can easily change it, if desired.
type InfinitesRepr* = int
type Infinite* = distinct InfinitesRepr
const ∞* = Infinite(1)
# Yes, you may have larger infinities, if this seems not enough for your needs.
# Say you ventured to count dots in a line...
proc `-`*(inf: Infinite): Infinite = Infinite(-InfinitesRepr(inf))
# Now we have "-∞"
const Fuzzy* = Infinite(0)
type FiniteOrdinal* = SomeInteger
type Finite* = SomeNumber
type Cardinal = Finite | Infinite

# Helpers.
template def(value): type(value) = default(value.type)

# For cases when a procedure doesn't know in advance, whether it will
# return only finites or only infinites, and can in fact return both.
type SomeFinite = Finite | FiniteOrdinal
type PossiblyInfinite*[T: SomeFinite] = object
  case isFinite: bool
  of false:
    infValue: Infinite
  of true:
    finValue: T
converter toInf*(num: PossiblyInfinite): Infinite =
  if num.isFinite: default(Infinite)
  else: num.infValue
converter toFin*(num: PossiblyInfinite): SomeFinite =
  if num.isFinite: num.finValue
  else: raise newException(ArithmeticError,
                            "Tried to embrace the unembraceable.")
proc `$`*(num: PossiblyInfinite): string =
  if num.isFinite: $num.finValue
  else: $num.infValue
template finNumber*[T: SomeFinite](n: T): PossiblyInfinite[T] =
  PossiblyInfinite[T](isFinite: true, finValue: n)
template infNumber*[T: SomeFinite](inf: Infinite): PossiblyInfinite[T] =
  PossiblyInfinite[T](isFinite: false, infValue: inf)

# Then we need to breathe some life into them.
# We want to be able to do usual things with them, like comparing.
# It's boring to borrow much, so just for example...
proc `==`*(inf1, inf2: Infinite): bool {.borrow.}
proc `<`*(inf1, inf2: Infinite): bool {.borrow.}
proc `<=`*(inf1, inf2: Infinite): bool {.borrow.}
proc abs*(inf: Infinite): Infinite {.borrow.}

# And some of its own. Again, extend it as needed.
proc `<`*(inf: Infinite, n: Finite): bool =
  if inf == default(Infinite): n > 0
  else: inf < default(Infinite)
proc `<=`*(inf: Infinite, n: Finite): bool =
  if inf == default(Infinite): n >= 0
  else: inf < default(Infinite)
proc `<`*(n: Finite, inf: Infinite): bool =
  if inf == default(Infinite): n < 0
  else: inf > default(Infinite)
proc `<=`*(n: Finite, inf: Infinite): bool =
  if inf == default(Infinite): n <= 0
  else: inf > default(Infinite)

proc isNegative*(c: Cardinal): bool = c < c.def
proc isPositive*(c: Cardinal): bool = c > c.def
proc order*(inf: Infinite): InfinitesRepr = abs(InfinitesRepr(inf))
proc sign*(c: Cardinal): InfinitesRepr =
  InfinitesRepr( if c > c.def: 1 elif c < c.def: -1 else: 0 )

# We may do special infinites arithmetics...
proc `+`*(inf1, inf2: Infinite): Infinite =
  if inf1 == -inf2: Infinite(0)
  elif abs(inf1) < abs(inf2): inf2
  else: inf1
proc `*`*(inf1, inf2: Infinite): Infinite =
  if inf1 == default(Infinite) or inf2 == default(Infinite): Infinite(0)
  elif abs(inf1) < abs(inf2): inf2
  else: inf1
proc `-`*(inf1, inf2: Infinite): Infinite = inf1 + -inf2
proc `+`*(inf: Infinite, n: Finite): Infinite = inf
proc `+`*(n: Finite, inf: Infinite): Infinite = inf
proc `-`*(inf: Infinite, n: Finite): Infinite = inf
proc `-`*(n: Finite, inf: Infinite): Infinite = -inf
# We need ``PossiblyInfinite here``, because of multiplying by zero.
# It is not fuzzy: from anything however large one gets exactly nothing
# by taking absolutely nothing of it.
proc `*`*(inf: Infinite, n: Finite): PossiblyInfinite[n.type] =
  if n == n.def: finNumber(n.def)
  elif n < n.def: infNumber[n.type](-inf)
  else: infNumber[n.type](inf)
proc `*`*(n: Finite, inf: Infinite): PossiblyInfinite[n.type] =
  if n == n.def: finNumber(n.def)
  elif n < n.def: infNumber[n.type](-inf)
  else: infNumber[n.type](inf)
proc `/`*(inf: Infinite, n: Finite): Infinite = 
  if n != n.def:
    if n.isNegative: -inf else: inf
  else:
    # No way. Otherwise by reverting it one could get something from nothing.
    # And one cannot.
    raise newException(DivByZeroError, "You cannot!")
proc `/`*(inf1, inf2: Infinite): Infinite = 
  # By reversing it, seems so...
  if inf1.order >= inf2.order:
    if inf2.isNegative: -inf1
    else: inf1
  else: default(Infinite)
# And so on.

# And we want to show them somehow to users.
proc `$`*(inf: Infinite): string =
  if inf == ∞: "∞"
  elif inf == -∞: "-∞"
  elif inf == default(Infinite): "Fuzzy"
  # You may add here other `elif`s for other symbols, like subscripted alephs
  else: "inf(" & $InfinitesRepr(inf) & ")"

# And the most interesting... we want to count to infinity.

# • From finite to infinite.
# Accepting fuzziness of ``Infinite(0)``, we need here `PossiblyInifinite`.
# Because for the case of ``s.b`` of ``Infinite(0)`` the actual sequence
# is undefined, and though it's not actually infinite, that fits better,
# than any finite sequence (any of which would be just arbitrary).
# More in the comment below.
iterator items*[T: FiniteOrdinal](s: HSlice[T, Infinite]): PossiblyInfinite[T] =
  if s.b > default(Infinite):
    var n = s.a
    while true:
      yield finNumber(n)
      inc n
  elif s.b < default(Infinite):
    var n = s.a
    while true:
      yield finNumber(n)
      dec n
  else:
    # So here ``s.b`` is ``Fuzzy`` — it is of the order of finite numbers,
    # but smeared/spread over all the finites set.
    # So we cannot determine, whether it's larger or smaller, than ``s.a``
    # — in a sense it's around it. So we cannot determine the direction
    # to change ``s.a`` (increase/decrease).
    # It gets itself fuzzy after the first step.
    yield finNumber(s.a)
    while true:
      yield infNumber[InfinitesRepr](default(Infinite))
# • From infinite to finite.
iterator items*(s: HSlice[Infinite, FiniteOrdinal]): Infinite =
  while true:
    yield s.a
# • Between two infinites.
# It's the same as above, but this way looks simpler.
iterator items*(s: Slice[Infinite]): Infinite =
  while true:
    yield s.a
#iterator `..`*(a, b: Infinite): Infinite =
#  while true:
#    yield a


# ========== testing ========= #
when isMainModule:

  # Comparisons/arithmetic tests. Template is just to show
  # the expression being tested before its result.

  template test1(expr: untyped, pad = "  "): untyped = 
    var ex = astToStr(expr)
    for i in ex.len .. 18: ex &= " "
    echo ex & pad & "      =>      " & $expr
  template test2(expr: untyped): untyped = test1(expr, "")

  echo "\n Comparison / arithmetic \n"
  test1 ∞ == -∞
  test1 ∞ == ∞
  test1 -∞ < ∞
  test2 ∞ >= 42
  test1 ∞ + -∞
  test1 ∞ - ∞
  test1 ∞ + ∞
  test2 ∞ + Infinite(2)
  test2 ∞ - Infinite(2)
  test2 -Infinite(2) + ∞
  test2 -Infinite(2) - ∞
  test2 ∞ + 777
  test2 ∞ - int.high
  test2 -∞ * 3.14
  test2 -∞ * -1'i8
  test2 -∞ * 0
  test2 -∞ * Fuzzy
  test1 -∞ / -∞
  test2 -∞ / 3.14
  test2 -∞ / Infinite(2)
  test2 -∞ / Infinite(0)
  test2 -∞ / -1
  echo ""

  # ================================================
  # Iterators tests. They will do things like
  # ```nim
  #   for i in 0 .. ∞:
  #     echo i
  # but so that you'll need not to wait for them infinitely
  # to see the result — they'll stop as they get a bit tired.
  # Tested loops' statements are printed before results.

  import random
  randomize()
  template test3(s: HSlice, inf = true): untyped =
    echo "for i in ", s, ":"
    var c = 0
    for i in s:
      echo i
      when inf:
        inc c
        if c > 3 and rand(40..50) == 42:
          echo "Oh, well, that's not going to stop, let's quit it..."
          break
    echo ""
  template test4(s: HSlice): untyped = test3(s, true)

  echo "\n Iterators \n"
  test3 0 .. ∞
  test4 3 .. Infinite(0)
  test3 0 .. -∞
  test3 -∞ .. ∞
  test3 -∞ .. 7
  test3 ∞ .. -∞ # we don't even need `countdown`, `..` works in both directions
  test3 Infinite(0) .. ∞
  test4 5 .. Infinite(0)
  test4 Infinite(0) .. 17
  echo ""

  # ================================================
  # If you're on Windows, you may have the Infinity sign not displayed /
  # wrongly displayed in console.
  # To output into file instead: ``nim c -r justforfun > out.txt & out.txt``.
  # To display as UTF-8 in console, run ``chcp 65001`` in it.
  # But even with that I have some of "∞" not displayed in console.




# These treat ``Infinite(0)`` as ``0``,
# not as a fuzzy number, from which by finite increments/decrements
# we can get only to the same fuzzy number of the same order,
# not distinguishable from the initial one,
# as it's treated in ``items`` iterators
# (that behaviour is more conceptually correct and more useful,
# but these ones still remain here, as it's for fun).
# You'll get with these ``Infinite(0) ..! 3`` => 0, 1, 2, 3.

# • From finite to infinite.
# This one always returns finites, so we don't need `PossiblyInifinite`.
iterator `..!`*[T: FiniteOrdinal](a: T, b: Infinite): T =
  if b > default(Infinite):
    var n = a
    while true:
      yield n
      inc n
  elif b < default(Infinite):
    var n = a
    while true:
      yield n
      dec n
  elif a < default(T):
    for n in countup(a, default(T)):
      yield n
  else:
    for n in countdown(a, default(T)):
      yield n
# • From infinite to finite.
iterator `..!`*[T: FiniteOrdinal](a: Infinite, b: T): PossiblyInfinite[T] =
  if a == default(Infinite):
    if b < default(Infinite):
      for n in countdown(default(Infinite), b):
        yield finNumber(n)
    else:
      for n in countup(default(Infinite), b):
        yield finNumber(n) # same as above
  else:
    while true:
      yield infNumber[InfinitesRepr](a)
# • Between two infinites.
iterator `..!`*(a, b: Infinite): PossiblyInfinite[InfinitesRepr] =
  if a == default(Infinite):
    if b == default(Infinite):
      yield infNumber[InfinitesRepr](b)
    else:
      for n in default(InfinitesRepr) ..! b:
        yield finNumber(n)
  else:
    while true:
      yield infNumber[InfinitesRepr](a)


# Further considerations, for even more fun:
#
# If it makes sense to consider fuzzy numbers (as is represented in the module
# by ``Infinite(0)`` for fuzzy over exclusive range -∞ .. ∞) and
# infinite numbers (yet of different orders), does it make sense then
# to consider fuzzy numbers over larger ranges?
#
# Then fuzzies have orders, the same as infinites.
# May they be asymmetrical? (seems yes, say for ``x = Fuzzy``,
# i.e. ``Infinite(0)``, i.e. ``fuzzy(-∞ >..< ∞)``,
# shouldn't ``x * x == fuzzy(0 ..< ∞)``, the same for ``abs(x)``?)
# (this kitten-face ``>..<`` being for exclusive-at-both-ends range)
#
# Should it be considered ``∞ / ∞ == Fuzzy``?
# Should it be considered ``Infinite(2) / Infinite(2) == fuzzy(2)``
# (the latter as a shortcut for ``fuzzy(Infinite(2) >..< Infinite(2))``)?
#
# How are they to be represented?
