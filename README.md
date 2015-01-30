# Nim-modules
``exact.nim``
============

Module for rational arithmetics. It's optimized for speed, operations on fractions basically do not involve reducing,
fractions are reduced when it's needed. Rationals are created and used just as usual numbers, with infix operators.
There are `$` (stringify) and `repr` operations defined for both simple and mixed fractions, `$` involves reducing.
