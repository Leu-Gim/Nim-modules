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

#import macros, typetraits



# =============================== T Y P E S ================================== #

type
  ## Rational number
  Exact*[T] = object
    numerator*: T
    denominator*: T
  ## Rational number with integer part stored apart.
  ## It can be got from `Exact` with `apart` proc.
  ## It can be implicitly or explicitly converted to an `Exact`
  ## for further processing, and it can be converted to string.
  MixedFraction*[T] = object
    intPart*: T
    fraction*: Exact[T]



# ===== T E M P L A T E S  A N D  C O N S T S  F O R  I N N E R  U S E ======= #

template max[T1,T2: typedesc[Ordinal]](t1: T1, t2: T2): T1|T2 =
  #if sizeof(t1) >= sizeof(t2): t1 else: t2
  # I've found no way to make it work so far, so it's just the 1st type for now
  t1

# if sum of 2 values is greater than this constant's item
# with their byte-size as index, then their product can overflow
# these values are: sqrt(1 shl (8 * sizeof(val) -1)) * 2
const DoubleSqrtOfMaxSignedVal = [
  0'i64, 22'i64,                                  # 22 for 1-byte (`i8)
  362'i64,                                        # 362 for 2-byte (`i16)
  362'i64, 92680'i64,                             # 92680 for 4-byte (`i32)
  92680'i64, 92680'i64, 92680'i64, 6074000999'i64 # 6074000999 for 8-byte ('i64)
  ]

template canOverflow(x, y: Ordinal, size: int): bool =
  const retSize = DoubleSqrtOfMaxSignedVal[size]
  x + y > retSize

template handlePossibleOverflows(x, y: Exact): stmt =
  var
    x {.inject.} = x
    y {.inject.} = y
  if  canOverflow(x.numerator, y.numerator, sizeof(result.numerator)) or
      canOverflow(x.denominator, y.denominator, sizeof(result.denominator)):
    x = x.reduce
    y = y.reduce
    rcd(x, y)

template handlePossibleOverflows(x: (var Exact){lvalue}, y: Exact): stmt =
  var
    y {.inject.} = y
  if  canOverflow(x.numerator, y.numerator, sizeof(x.numerator)) or
      canOverflow(x.denominator, y.denominator, sizeof(x.denominator)):
    x = x.reduce
    y = y.reduce
    rcd(x, y)



# ============================= C R E A T O R S ============================== #

proc `%`*[T: Ordinal](x, y: T): Exact[T]      {.inline, noInit, noSideEffect.} =
  result.numerator   = x
  result.denominator = y

## has highest precedence, so that ``5 * 3 ^/ 7`` is ``5 * (3 % 7)``
template `^/`*[T: Ordinal](x, y: T): Exact[T] =
  x % y



# =========== C O M M O N  A R I T H M E T I C  A L G O R I T H M S ========== #

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
# overflow check needed
proc lcm*[T: Ordinal](x, y : T): T            {.noInit, noSideEffect.} =
  # first deviding, then multiplying, to overcome possible overflows
  result = x div gcd(x, y) * y



# =========== T R A N S F O R M A T I O N S  O F  R A T I O N A L S ========== #

## reduce to a common denominator (e.g. rcd(1%24,1%18) -> (3%72,4%72))
proc rcd*(x, y: var Exact)                    {.noInit, noSideEffect.} =
  if x.denominator == y.denominator:
    return
  let m = lcm(x.denominator, y.denominator)
  x.numerator *= m div x.denominator
  x.denominator = m
  y.numerator *= m div y.denominator
  y.denominator = m

# private version; reduces 1st arg, and returns numerator for the 2nd arg
proc rcd1[T1,T2: Ordinal](x: var Exact[T1], y: Exact[T2]): max(T1,T2)
                                              {.noInit, noSideEffect.} =
  if x.denominator == y.denominator:
    return y.numerator
  let m = lcm(x.denominator, y.denominator)
  x.numerator *= m div x.denominator
  x.denominator = m
  result = y.numerator * (m div y.denominator)

## convert to the canonical form, e.g. 4/2 becomes 2/1
proc reduce*[T: Ordinal](x: Exact[T]): Exact[T]
                                              {.noInit, noSideEffect.} =
  let gcd = gcd(x.numerator, x.denominator)
  if gcd == 0: return x
  let neg = (x.numerator xor x.denominator) < 0
  result.numerator   = (x.numerator.abs   /% gcd).T
  result.denominator = (x.denominator.abs /% gcd).T
  if neg: result.numerator *= -1



# ===== A R I T H M E T I C  O P E R A T I O N S  O N  R A T I O N A L S ===== #

proc `+`*[T: Ordinal](x: Exact[T]): Exact[T]  {.noInit, noSideEffect, inline.} =
  x

proc `-`*[T: Ordinal](x: Exact[T]): Exact[T]  {.noInit, noSideEffect, inline.} =
  result.numerator   = -x.numerator
  result.denominator = x.denominator

proc `+`*[T1,T2: Ordinal](x: Exact[T1], y: Exact[T2]): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect.} =
  result             = x
  let yNumerator     = rcd1(result, y)
  result.numerator  += yNumerator

proc `-`*[T1,T2: Ordinal](x: Exact[T1], y: Exact[T2]): Exact[T1]
                                              {.noInit, noSideEffect.} =
  result             = x
  let yNumerator     = rcd1(result, y)
  result.numerator  -= yNumerator

proc abs*[T: Ordinal](x: Exact[T]): Exact[T]  {.noInit, noSideEffect.} =
  result.numerator   = abs(x.numerator)
  result.denominator = abs(x.denominator)

## e.g. 2/3 -> -2/3, -2/3 -> 2/3
## only numerator may be negative in result
proc neg*[T: SomeSignedInt](x: Exact[T]): Exact[T]  {.noInit, noSideEffect.} =
  if x.denominator < 0:
    result.numerator   = x.numerator
    result.denominator = x.denominator.abs
  else:
    result.numerator   = - x.numerator
    result.denominator = x.denominator

## e.g. 2/3 -> 3/2
proc reciprocal*[T: Ordinal](x: Exact[T]): Exact[T]
                                              {.noInit, noSideEffect, inline.} =
#  result.numerator   = x.denominator
#  result.denominator = x.numerator
  result = x
  swap(result.numerator, result.denominator)

proc `*`*[T1,T2: Ordinal](x: Exact[T1], y: Exact[T2]): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  handlePossibleOverflows(x, y)
  result.numerator   = x.numerator   * y.numerator
  result.denominator = x.denominator * y.denominator

proc `/`*[T1,T2: Ordinal](x: Exact[T1], y: Exact[T2]): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result = x * y.reciprocal



# =================== S T R I N G  F O R M A T T E R S ======================= #

proc `$`*(x: Exact): string                   {.noInit, noSideEffect.} =
  let x = x.reduce
  result = $x.numerator & '/' & $x.denominator

proc repr*(x: Exact): string =
  "Exact(" & $x.numerator & "/" & $x.denominator & ")"



# ======== A R G U M E N T - M O D I F Y I N G  O P E R A T I O N S ========== #

proc `+=`*(x: var Exact, y: Exact) =
  let yNumerator     = rcd1(x, y)
  x.numerator  += yNumerator

proc `-=`*(x: var Exact, y: Exact) =
  let yNumerator     = rcd1(x, y)
  x.numerator  -= yNumerator

proc `*=`*[T1,T2: Ordinal](x: var Exact[T1], y: Exact[T2]) =
  handlePossibleOverflows(x, y)
  x.numerator    *= y.numerator
  x.denominator  *= y.denominator

proc `/=`*[T1,T2: Ordinal](x: var Exact[T1], y: Exact[T2]) =
  handlePossibleOverflows(x, y)
  x.numerator    *= y.denominator
  x.denominator  *= y.numerator



# ========================== C O N V E R T E R S ============================= #

converter intToFrac*[T: Ordinal](x: T): Exact[T] =
  result.numerator   = x
  result.denominator = 1

#converter fracToInt*[T: Ordinal](x: Exact[T]): T =
#  x.numerator div x.denominator

converter unexact*(e: Exact): float           {.inline, noInit, noSideEffect.} =
  result = e.numerator / e.denominator



# === O P E R A T I O N S  O N  R A T I O N A L S  A N D  O R D I N A L S ==== #

proc `*`*[T1,T2: Ordinal](x: Exact[T1], n: T2): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator * n
  result.denominator = x.denominator

proc `*`*[T1,T2: Ordinal](n: T1, x: Exact[T2]): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator * n
  result.denominator = x.denominator

# integer division
proc `div`*[T1,T2: Ordinal](x: Exact[T1], n: T2): Exact[max(T1,T2)]
                                              {.noInit, noSideEffect, inline.} =
  result.numerator   = x.numerator
  result.denominator = x.denominator * n

proc `div`*[T1,T2: Ordinal](n: T1, x: Exact[T2]): Exact[max(T1,T2)]
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



# =============== C O M P A R I S O N  P R O C E D U R E S =================== #

proc `<`*(x: Exact, y: Exact): bool           {.noInit, noSideEffect, inline.} =
  if x.numerator == y.numerator:
    result = x.denominator > y.denominator
  elif x.denominator == y.denominator:
    result = x.numerator < y.numerator
  else:
    result = x.numerator * y.denominator < y.numerator * x.denominator

proc `<=`*(x: Exact, y: Exact): bool          {.noInit, noSideEffect, inline.} =
  if x.numerator == y.numerator:
    result = x.denominator >= y.denominator
  elif x.denominator == y.denominator:
    result = x.numerator <= y.numerator
  else:
    result = x.numerator * y.denominator <= y.numerator * x.denominator

proc `==`*(x: Exact, y: Exact): bool          {.noInit, noSideEffect, inline.} =
  result =
    x.numerator == y.numerator and
    x.denominator == y.denominator or
    x.numerator * y.denominator == y.numerator * x.denominator



# ================ E X P L I C I T  C O N V E R S I O N S  =================== #

proc intPart[T: Ordinal](x: Exact): T =
  x.numerator div x.denominator

proc apart*[T: Ordinal](x: Exact[T]): MixedFraction[T] =
  var x = x.reduce
  result.intPart = x.numerator div x.denominator
  result.fraction.numerator = x.numerator - result.intPart * x.denominator
  result.fraction.denominator = x.denominator



# ============== F U N C T I O N  A P P L I C A T I O N S ==================== #

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



# ========== O P E R A T I O N S  O N  M I X E D  F R A C T I O N S ========== #

proc `$`*(x: MixedFraction): string                   {.noInit, noSideEffect.} =
  let f = x.fraction.reduce
  result = $x.intPart & '&' &
    $f.numerator & '/' & $f.denominator

proc repr*(x: MixedFraction): string =
  "MixedFraction(" $x.intPart & "," &
    $x.fraction.numerator & "/" & $x.fraction.denominator & ")"

converter unmix*[T: Ordinal](x: MixedFraction[T]): Exact[T] = 
  result.numerator = x.intPart * x.fraction.denominator + x.fraction.numerator
  result.denominator = x.fraction.denominator






# ================================= T E S T S ================================ #

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

  echo 2 % 3 < 4 % 5              # true
  x = 2 % 10
  echo x <= 3 % 15                # true
  echo x == 3 % 15                # true
  # here `x` is converted to float and then compared
  echo x == 0.2                   # true

  x += 3                          # = 32/10
  echo x                          # 16/5
  let m = x.apart
  echo m                          # 3&1/5
  echo m * 1 ^/ 5                 # 16/25
  echo x.intPart                  # 3

  # overflow check for int32
  var y = 1_000_000'i32 % 100'i32
  var z = 3_000'i32 % 500'i32
  y = y * z
  echo y.repr                     # Exact(60000/1)

  y /= 3_000
  echo y                          # 20/1
  y *= 1 % 10
  echo y                          # 2/1

