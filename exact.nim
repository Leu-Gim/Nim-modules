# rational arithmetics
# author: Miguel (LeuGim)

import macros, typetraits

type
  TExact*[T: typedesc[Ordinal]] = object
    numerator*: T
    denominator*: T

template max(t1, t2: typedesc): typedesc =#{.compiletime.} =
  #if sizeof(t1) >= sizeof(t2): t1 else: t2
  int

proc `%`*[T: Ordinal](x, y: T): TExact[T]                 {.inline, noInit, noSideEffect.} =
  result.numerator   = x
  result.denominator = y

#proc `%`*(x, y: int64): TExact[int64]        {.inline, noInit, noSideEffect.} =
#  result.numerator   = x
#  result.denominator = y

## for highest priority
template `^/`*[T: Ordinal](x, y: T): TExact[T] =
  x % y

converter unexact*(e: TExact): float         {.inline, noInit, noSideEffect.} =
  result = e.numerator / e.denominator

## greatest common divisor
proc gcd*[T: Ordinal](x, y: T): T            {.noInit, noSideEffect.} =
  echo "gcd for ", x, " and ", y
  if x == y: return x
  if x == 0: return y
  if y == 0: return x
  var
    shift: T = 0
    x = x.abs
    y = y.abs
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
  echo "gcd = ", result

## least common multiple
proc lcm*[T: Ordinal](x, y : T): T         {.noInit, noSideEffect.} =
  # first deviding, then multiplying, to overcome possible overflows
  result = x div gcd(x, y) * y
  echo "lcm for ", x, " and ", y, " is ", result

## reduct to a common denominator
proc rcd*(x, y: var TExact)                  {.noInit, noSideEffect.} =
  echo "before rcd: ", x.repr,  ", ", y.repr
  if x.denominator == y.denominator:
    return
  let m = lcm(x.denominator, y.denominator)
  x.numerator *= m div x.denominator
  x.denominator = m
  y.numerator *= m div y.denominator
  y.denominator = m
  echo "after rcd: ", x.repr,  ", ", y.repr

proc rcd1[T1,T2: Ordinal](x: var TExact[T1], y: TExact[T2]): max(T1,T2) {.noInit, noSideEffect.} =
  echo "before rcd1: ", x.repr,  ", ", y.repr
  if x.denominator == y.denominator:
    return y.numerator
  let m = lcm(x.denominator, y.denominator)
  x.numerator *= m div x.denominator
  x.denominator = m
  result = y.numerator * (m div y.denominator)
  echo "after rcd1: x=", x.repr,  ", result=", result

proc `+`*[T: Ordinal](x: TExact[T]): TExact[T]                 {.noInit, noSideEffect, inline.} =
  x

proc `-`*[T: Ordinal](x: TExact[T]): TExact[T]                 {.noInit, noSideEffect, inline.} =
  result.numerator   = -x.numerator
  result.denominator = x.denominator

proc `+`*[T1,T2: Ordinal](x: TExact[T1], y: TExact[T2]): TExact[max(T1,T2)] {.noInit, noSideEffect.} =
  echo "summing ", x.repr, " and ", y.repr
  result.numerator   = x.numerator
  result.denominator = x.denominator
  let yNumerator     = rcd1(result, y)
  result.numerator  += yNumerator
  echo "sum is ", result.repr, ", ", result

proc `-`*[T1,T2: Ordinal](x: TExact[T1], y: TExact[T2]): TExact[T1]              {.noInit, noSideEffect.} =
  result = x
  let yNumerator     = rcd1(result, y)
  result.numerator  -= yNumerator

proc reciprocal*[T: Ordinal](x: TExact[T]): TExact[T]          {.noInit, noSideEffect, inline.} =
  result.numerator   = x.denominator
  result.denominator = x.numerator

proc `*`*[T1,T2: Ordinal](x: TExact[T1], y: TExact[T2]): TExact[max(T1,T2)]              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator   * y.numerator
  result.denominator = x.denominator * y.denominator

proc `/`*[T1,T2: Ordinal](x: TExact[T1], y: TExact[T2]): TExact[max(T1,T2)]              {.noInit, noSideEffect, inline.} =
  result = x * y.reciprocal

proc abs*[T: Ordinal](x: TExact[T]): TExact[T]                 {.noInit, noSideEffect.} =
  result.numerator   = abs(x.numerator)
  result.denominator = abs(x.denominator)

# should first optimize the ratio and maybe extract the integer part
proc `$`*(x: TExact): string                 {.noInit, noSideEffect.} =
  let x = x.reduce
  result = $x.numerator & '/' & $x.denominator

# ----------- 27.01.2015 --------------

proc repr*(x: TExact): string =
  "TExact(" & $x.numerator & "/" & $x.denominator & ")"

proc `+=`(x: var TExact, y: TExact) =
  let yNumerator     = rcd1(x, y)
  x.numerator  += yNumerator

proc `-=`(x: var TExact, y: TExact) =
  let yNumerator     = rcd1(x, y)
  x.numerator  -= yNumerator

proc `*=`(x: var TExact, y: TExact) =
  x.numerator    *= y.numerator
  x.denominator  *= y.denominator

proc `/=`(x: var TExact, y: TExact) =
  x.numerator    *= y.denominator
  x.denominator  *= y.numerator

## convert to the canonical form, e.g. 4/2 becomes 2/1
proc reduce*[T: Ordinal](x: TExact[T]): TExact[T]             {.noInit, noSideEffect.} =
  let gcd = gcd(x.numerator, x.denominator)
  let neg = (x.numerator xor x.denominator) < 0
  echo T.name, x.repr, ',', gcd
  if gcd == 0: return x
  #static: echo result.numerator.type.name, x.numerator.type.name, gcd.type.name
  result.numerator   = (x.numerator.abs   /% gcd).T
  result.denominator = (x.denominator.abs /% gcd).T
  if neg: result.numerator *= -1
  echo "reduced = ", result.repr

converter intToFrac*[T: Ordinal](x: T): TExact[T] =
#  static: echo callSite().repr
  (x, 1)
#converter fracToInt*[T: Ordinal](x: TExact[T]): T =
##  static: echo callSite().repr
#  x.numerator /% x.denominator

proc `*`*[T1,T2: Ordinal](x: TExact[T1], m: T2): TExact[max(T1,T2)] =
  result.numerator   = x.numerator * m
  result.denominator = x.denominator

proc `/%`*[T1,T2: Ordinal](x: TExact[T1], m: T2): TExact[max(T1,T2)] =
  result.numerator   = x.numerator
  result.denominator = x.denominator * m





when isMainModule:
  let
    a=1'i32
    b=2'i32
    c=6'i32
    d=4'i32
    e=10'i32
    f=2'i32
    i1=a^/b
    i2=c^/d
  #var x = i1+i2 #*e^/f*f
  var x = -1 ^/ 2    +    6 ^/ -4  *  10 ^/ 2  *  2
  #static: echo parseExpr("1^/2+6^/4*10^/2*2").treeRepr
  #echo i1.repr, ' ', i2.repr, ' ', x.repr
  echo x
  x+=3072^/6144
  echo x
  let
    aa = 12 % 48
    bb = 1
    cc = 2 % 3
  #echo a + b - c
