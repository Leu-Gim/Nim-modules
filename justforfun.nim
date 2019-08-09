# Further developed version is at
# https://github.com/Leu-Gim/Nim-modules/blob/master/yetmorefun.nim
# (in this same repo).

# So, we want to deal with the infinite... even if not really.
# But to look convincing. :) Just for fun.
type Infinite* = distinct int
const ∞* = Infinite(1)
proc `-`*(inf: Infinite): Infinite = Infinite(-int(inf))
# Now we have "-∞"

# Then we need to breathe some life into them.
# We want to be able to do usual things with them, like comparing.
# It's boring to borrow much, so just for example...
proc `==`*(inf1, inf2: Infinite): bool {.borrow.}
proc `<`*(inf1, inf2: Infinite): bool {.borrow.}
proc `<=`*(inf1, inf2: Infinite): bool {.borrow.}
proc abs*(inf: Infinite): Infinite {.borrow.}
# And some of its own. Again, extend it as need.
proc `<`*(inf: Infinite, n: SomeNumber): bool =
  if inf == default(Infinite): n > 0
  else: inf < default(Infinite)
proc `<=`*(inf: Infinite, n: SomeNumber): bool =
  if inf == default(Infinite): n >= 0
  else: inf < default(Infinite)
proc `<`*(n: SomeNumber, inf: Infinite): bool =
  if inf == default(Infinite): n < 0
  else: inf > default(Infinite)
proc `<=`*(n: SomeNumber, inf: Infinite): bool =
  if inf == default(Infinite): n <= 0
  else: inf > default(Infinite)
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
proc `+`*(inf: Infinite, n: SomeNumber): Infinite = inf
proc `+`*(n: SomeNumber, inf: Infinite): Infinite = inf
proc `-`*(inf: Infinite, n: SomeNumber): Infinite = inf
proc `-`*(n: SomeNumber, inf: Infinite): Infinite = -inf
proc `*`*(inf: Infinite, n: SomeNumber): Infinite =
  if n == default(n.type): Infinite(0)
  elif n < default(n.type): -inf
  else: inf
proc `*`*(n: SomeNumber, inf: Infinite): Infinite =
  if n == default(n.type): Infinite(0)
  elif n < default(n.type): -inf
  else: inf
# And we want to show them somehow to users.
proc `$`*(inf: Infinite): string =
  if inf == ∞: "∞"
  elif inf == -∞: "-∞"
  #elif int(inf) == 0: "0"
  else: "inf(" & $int(inf) & ")"

# And the most interesting... we want to count to infinity.
iterator items*[T: not Infinite](s: HSlice[T, Infinite]): T =
  if int(s.b) > 0:
    var n = s.a
    while true:
      yield n
      inc n
  elif int(s.b) < 0:
    var n = s.a
    while true:
      yield n
      dec n
  elif s.a < 0:
    for n in countup(s.a, 0):
      yield n
  else:
    for n in countdown(s.a, 0):
      yield n
iterator items*[T: not Infinite](s: HSlice[Infinite, T]): Infinite =
  if int(s.a) == 0:
    if s.b < 0:
      for n in countdown(0, s.b):
        yield Infinite(0) # It should be `n`, but result type cannot depend
                          # on arguments (static typing), and `Inifinite`
                          # is certainly the general case here, and all
                          # finites correspond to `Infinite(0)`
    else:
      for n in countup(0, s.b):
        yield Infinite(0) # same as above
  else:
    while true:
      yield s.a
#iterator items*(s: HSlice[Infinite, Infinite]): Infinite =
iterator `..`*(a, b: Infinite): Infinite =
  if int(a) == 0 and int(b) == 0:
    yield Infinite(0)
  else:
    while true:
      yield a


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
    echo "for i in " & $s.a & " .. " & $s.b & ":"
    var c = 0
    for i in s.a .. s.b:
      echo i
      when inf:
        inc c
        if c > 3 and rand(40..50) == 42:
          echo "Oh, well, that's not going to stop, let's quit it..."
          break
    echo ""
  template test4(s: HSlice): untyped = test3(s, false)

  echo "\n Iterators \n"
  test3 0 .. ∞
  test4 3 .. Infinite(0)
  test3 0 .. -∞
  test3 -∞ .. ∞
  test3 -∞ .. 7
  test3 ∞ .. -∞ # we don't even need `countdown`, `..` works in both directions
  echo ""

  # ================================================
  # If you're on Windows, you may have the Infinity sign not displayed /
  # wrongly displayed in console.
  # To output into file instead: ``nim c -r justforfun > out.txt & out.txt``.
  # To display as UTF-8 in console, run ``chcp 65001`` in it.
  # But even with that I have some of "∞" not displayed in console.
