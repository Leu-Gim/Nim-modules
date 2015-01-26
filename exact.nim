# rational arithmetics
# author: Miguel (LeuGim)

type
  TExact*[T: typedesc[Ordinal]] = object
    numerator*: T
    denominator*: T

proc `%`*(x, y: int): TExact[int]            {.inline, noInit, noSideEffect.} =
  result.numerator   = x
  result.denominator = y

proc `%`*(x, y: int64): TExact[int64]        {.inline, noInit, noSideEffect.} =
  result.numerator   = x
  result.denominator = y

## for highest priority
template `^/`*[T:int|int64](x, y: T): TExact[T] =
  x % y

converter unexact*(e: TExact): float         {.inline, noInit, noSideEffect.} =
  result = e.numerator / e.denominator

## greatest common divisor
proc gcd*[T: Ordinal](x, y: T): T            {.noInit, noSideEffect.} =
  if x == y: return x
  if x == 0: return y
  if y == 0: return x
  var
    shift = 0
    x = x
    y = y
  while ((x or y) and 1) == 0:  # both are even
    x = x shr 1
    y = y shr 1
    inc shift
  while (x and 1) == 0: x = x shr 1
  while (y and 1) == 0: y = y shr 1
  while x != y:
    if y > x: swap x, y
    x -= y
    while (x and 1) == 0: x = x shr 1
  result = x shl shift

## least common multiple
proc lcm*[T: Ordinal](x, y : T): T           {.noInit, noSideEffect.} =
    result = x * y div gcd(x, y)

## reduct to a common denominator
proc rcd*(x, y: var TExact)                  {.noInit, noSideEffect.} =
  if x.denominator == y.denominator:
    return
  let m = lcm(x.denominator, y.denominator)
  x.numerator *= m div x.denominator
  x.denominator = m
  y.numerator *= m div y.denominator
  y.denominator = m

proc rcd1[T: Ordinal](x: var TExact[T], y: TExact[T]): T {.noInit, noSideEffect.} =
  if x.denominator == y.denominator:
    return y.numerator
  let m = lcm(x.denominator, y.denominator)
  x.numerator *= m div x.denominator
  x.denominator = m
  result = y.numerator * (m div y.denominator)

proc `+`*(x: TExact): TExact                 {.noInit, noSideEffect, inline.} =
  x

proc `-`*(x: TExact): TExact                 {.noInit, noSideEffect, inline.} =
  result.numerator   = -x.numerator
  result.denominator = x.denominator

proc `+`*(x, y: TExact): TExact              {.noInit, noSideEffect.} =
  result = x
  let yNumerator     = rcd1(result, y)
  result.numerator  += yNumerator

proc `-`*(x, y: TExact): TExact              {.noInit, noSideEffect.} =
  result = x
  let yNumerator     = rcd1(result, y)
  result.numerator  -= yNumerator

proc reciprocal*(x: TExact): TExact          {.noInit, noSideEffect, inline.} =
  result.numerator   = x.denominator
  result.denominator = x.numerator

proc `*`*(x, y: TExact): TExact              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator   * y.numerator
  result.denominator = x.denominator * y.denominator

proc `/`*(x, y: TExact): TExact              {.noInit, noSideEffect, inline.} =
  result = x * y.reciprocal

proc abs*(x: TExact): TExact                 {.noInit, noSideEffect.} =
  result.numerator   = abs(x.numerator)
  result.denominator = abs(x.denominator)

# should first optimize the ratio and maybe extract the integer part
proc `$`*(x: TExact): string                 {.noInit, noSideEffect.} =
  result = $x.numerator & '/' & $x.denominator

when isMainModule:
  echo int( (1^/2+6^/4)*10^/2*2 )