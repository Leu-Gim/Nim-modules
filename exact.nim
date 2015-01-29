# rational arithmetics
# author: Miguel (LeuGim)
## This module contains "lazy" rational arithmetics,
## in the sence that no multiplying/division is applied until necessary,
## just summing is involved when possible.
## Rationals are stored unreduced (e.g. it can be 2/4),
## they are reduced when outputed (via `$`), or explicitly with `reduce`.
## To do: reduce when otherwise an overflow may occur.
## The module is intended to handle rationals with any size of fields
## (int8, int16, int32, int64), but for now result type inference from
## arguments types (so that it is of type of argument of the biggest size)
## doesn't work, so operations on 2 rationals (like `+`)
## return value of the 1st of their arguments.

import macros, typetraits

type
  Exact*[T] = object
    numerator*: T
    denominator*: T

template max[T1,T2: typedesc[Ordinal]](t1: T1, t2: T2): T1|T2 =
  #if sizeof(t1) >= sizeof(t2): t1 else: t2
  # I've found no way to make it work so far, so it's just the 1st type for now
  t1

proc `%`*[T: Ordinal](x, y: T): Exact[T]      {.inline, noInit, noSideEffect.} =
  result.numerator   = x
  result.denominator = y

## has highest precedence, so that ``5 * 3 ^/ 7`` is ``5 * (3 % 7)``
template `^/`*[T: Ordinal](x, y: T): Exact[T] =
  x % y

converter unexact*(e: Exact): float           {.inline, noInit, noSideEffect.} =
  result = e.numerator / e.denominator

## greatest common divisor (e.g. gcd(24,18) == 6)
## optimized for big numbers
## doesn't use `mod`
proc gcd*[T: Ordinal](x, y: T): T             {.noInit, noSideEffect.} =
  if x == y: return x
  if x == 0: return y
  if y == 0: return x
  var
    shift: T = 0
    x = x.abs
    y = y.abs
  while ((x or y) and 1) == 0: # both are even
    x = x shr 1
    y = y shr 1
    inc shift
  while (x and 1) == 0: x = x shr 1
  while (y and 1) == 0: y = y shr 1
  # Euclidean algorithm from here
  while x != y:
    if y > x: swap x, y
    x -= y
    while (x and 1) == 0: x = x shr 1
  result = x shl shift

## least common multiple (e.g. lcm(24,18) == 72)
proc lcm*[T: Ordinal](x, y : T): T            {.noInit, noSideEffect.} =
  # first deviding, then multiplying, to overcome possible overflows
  result = x div gcd(x, y) * y

## reduct to a common denominator (e.g. rcd(1%24,1%18) -> (3%72,4%72))
proc rcd*(x, y: var Exact)                    {.noInit, noSideEffect.} =
  if x.denominator == y.denominator:
    return
  let m = lcm(x.denominator, y.denominator)
  x.numerator *= m div x.denominator
  x.denominator = m
  y.numerator *= m div y.denominator
  y.denominator = m

# private version; reducts 1st arg, and returns numerator for the 2nd arg
proc rcd1[T1,T2: Ordinal](x: var Exact[T1], y: Exact[T2]): max(T1,T2)
                                              {.noInit, noSideEffect.} =
  if x.denominator == y.denominator:
    return y.numerator
  let m = lcm(x.denominator, y.denominator)
  x.numerator *= m div x.denominator
  x.denominator = m
  result = y.numerator * (m div y.denominator)

proc `+`*[T: Ordinal](x: Exact[T]): Exact[T]  {.noInit, noSideEffect, inline.} =
  x

proc `-`*[T: Ordinal](x: Exact[T]): Exact[T]  {.noInit, noSideEffect, inline.} =
  result.numerator   = -x.numerator
  result.denominator = x.denominator

proc `+`*[T1,T2: Ordinal](x: Exact[T1], y: Exact[T2]): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect.} =
  result.numerator   = x.numerator
  result.denominator = x.denominator
  let yNumerator     = rcd1(result, y)
  result.numerator  += yNumerator

proc `-`*[T1,T2: Ordinal](x: Exact[T1], y: Exact[T2]): Exact[T1]
                                              {.noInit, noSideEffect.} =
  result = x
  let yNumerator     = rcd1(result, y)
  result.numerator  -= yNumerator

proc reciprocal*[T: Ordinal](x: Exact[T]): Exact[T]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.denominator
  result.denominator = x.numerator

proc `*`*[T1,T2: Ordinal](x: Exact[T1], y: Exact[T2]): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator   * y.numerator
  result.denominator = x.denominator * y.denominator

proc `/`*[T1,T2: Ordinal](x: Exact[T1], y: Exact[T2]): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result = x * y.reciprocal

proc abs*[T: Ordinal](x: Exact[T]): Exact[T]{.noInit, noSideEffect.} =
  result.numerator   = abs(x.numerator)
  result.denominator = abs(x.denominator)

proc `$`*(x: Exact): string                   {.noInit, noSideEffect.} =
  let x = x.reduce
  result = $x.numerator & '/' & $x.denominator

proc repr*(x: Exact): string =
  "Exact(" & $x.numerator & "/" & $x.denominator & ")"

proc `+=`*(x: var Exact, y: Exact) =
  let yNumerator     = rcd1(x, y)
  x.numerator  += yNumerator

proc `-=`*(x: var Exact, y: Exact) =
  let yNumerator     = rcd1(x, y)
  x.numerator  -= yNumerator

proc `*=`*(x: var Exact, y: Exact) =
  x.numerator    *= y.numerator
  x.denominator  *= y.denominator

proc `/=`*(x: var Exact, y: Exact) =
  x.numerator    *= y.denominator
  x.denominator  *= y.numerator

## convert to the canonical form, e.g. 4/2 becomes 2/1
proc reduce*[T: Ordinal](x: Exact[T]): Exact[T]
                                              {.noInit, noSideEffect.} =
  let gcd = gcd(x.numerator, x.denominator)
  let neg = (x.numerator xor x.denominator) < 0
  if gcd == 0: return x
  result.numerator   = (x.numerator.abs   /% gcd).T
  result.denominator = (x.denominator.abs /% gcd).T
  if neg: result.numerator *= -1

converter intToFrac*[T: Ordinal](x: T): Exact[T] =
  result.numerator   = x
  result.denominator = 1

#converter fracToInt*[T: Ordinal](x: Exact[T]): T =
#  x.numerator /% x.denominator

# --- operations on rationals and ordinals, like 5 + 1/2 ---

proc `*`*[T1,T2: Ordinal](x: Exact[T1], n: T2): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator * n
  result.denominator = x.denominator

proc `*`*[T1,T2: Ordinal](n: T1, x: Exact[T2]): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator * n
  result.denominator = x.denominator

# integer division
proc `/%`*[T1,T2: Ordinal](x: Exact[T1], n: T2): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator
  result.denominator = x.denominator * n

proc `/%`*[T1,T2: Ordinal](n: T1, x: Exact[T2]): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator
  result.denominator = x.denominator * n

proc `+`*[T1,T2: Ordinal](x: Exact[T1], n: T2): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator + x.denominator * n
  result.denominator = x.denominator

proc `+`*[T1,T2: Ordinal](n: T1, x: Exact[T2]): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator + x.denominator * n
  result.denominator = x.denominator

proc `-`*[T1,T2: Ordinal](x: Exact[T1], n: T2): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator - x.denominator * n
  result.denominator = x.denominator

proc `-`*[T1,T2: Ordinal](n: T1, x: Exact[T2]): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator - x.denominator * n
  result.denominator = x.denominator

# --- comparison procedures ---

proc `<`*(x: Exact, y: Exact): bool =
  if x.numerator == y.numerator:
    result = x.denominator > y.denominator
  elif x.denominator == y.denominator:
    result = x.numerator < y.numerator
  else:
    result = x.numerator * y.denominator < y.numerator * x.denominator

proc `<=`*(x: Exact, y: Exact): bool =
  if x.numerator == y.numerator:
    result = x.denominator >= y.denominator
  elif x.denominator == y.denominator:
    result = x.numerator <= y.numerator
  else:
    result = x.numerator * y.denominator <= y.numerator * x.denominator

proc `==`*(x: Exact, y: Exact): bool =
  result =
    x.numerator == y.numerator and
    x.denominator == y.denominator or
    x.numerator * y.denominator == y.numerator * x.denominator

## These procedures allow to apply some proc to a rational, like `map` for seqs.
## The proc that is applied should take 1 or 2 arguments,
## both ordinal or both float, return the same type, and be `nimcall`.
## For the 2nd argument of applied proc is the 3rd argument of `apply`.
#  Example with applying `pow` to a rational is at the tests section.

proc apply*[T: Ordinal](x: Exact[T], f: proc(n: T): T {.nimcall.}):   Exact[T] =
  result.numerator   = f(x.numerator)
  result.denominator = f(x.denominator)

proc apply*[T: Ordinal](x: Exact[T], f: proc(n: float): float {.nimcall.}):
                                                                      Exact[T] =
  result.numerator   = f(x.numerator.float).T
  result.denominator = f(x.denominator.float).T

proc apply*[T: Ordinal](x: Exact[T], f: proc(n, m: T): T {.nimcall.}, n: T):
                                                                      Exact[T] =
  result.numerator   = f(x.numerator)
  result.denominator = f(x.denominator)

proc apply*[T: Ordinal](x: Exact[T],
                        f: proc(n, m: float): float {.nimcall},
                        n: T):
                                                                      Exact[T] =
  result.numerator   = f(x.numerator.float, n.float).T
  result.denominator = f(x.denominator.float, n.float).T





when isMainModule:
  # spaces here are according to precedence
  var x = -1 ^/ 2    +    6 ^/ -4  *  10 ^/ 2  *  2
  echo x                          # -31/2
  x += 3072 ^/ 6144
  echo x                          # -15/1
  let
    a = 12 % 48
    b = 1
    c = 2 % 3
  echo a + b - c                  # 7/12
  echo( (323 % 5327) * 5327   )   # 323/1
  echo( (323 % 5327) * 5327.0 )   # 323.0

  proc pow*(x, y: float): float {.importc: "pow", header: "<math.h>".}
  # (2/3)**2
  echo c.apply(pow,2)             # 4/9

  # or we can define `pow` for rationals
  proc pow(x: Exact[int], n: int): Exact[int] =
    pow(x.numerator.float, n.float).int % pow(x.denominator.float, n.float).int
  echo c.pow(2)                   # 4/9

  echo 2 % 3 < 4 % 5
  x = 2 % 10
  echo x <= 3 % 15
  echo x == 3 % 15
  # here `x` is converted to float and then compared
  echo x == 0.2
