import std/unittest

import std/[sequtils, strutils, tables, re]
import std/json


import libsway_cases



suite "creating valid criteria":

  template testCriteria(fun: typed; e: CriteriaKind; value: typed; body: untyped) =
    for keys in [
                 @["a"],
                 @["a", "b"],
                 @["a", "b", "c_"],
                ]:
      let c {.inject.} = fun(value, keys)
      check:
        c.keys == keys
        c.kind == e
      body

  template testCriteria(e: CriteriaKind; value: typed; body: untyped) =
    testCriteria(initCriteria, e, value):
      check not c.optional
      body
    testCriteria(initOptCriteria, e, value):
      check c.optional
      body

  test "null criteria":
    let c = initNullCriteria("a", "b")
    check:
      c.keys == @["a", "b"]
      c.kind == ckNull

  test "bool criteria":
    for b in [false, true]:
      testCriteria(ckBool, b, check c.bval == b)

  test "int criteria":
    for i in (-2'i8, -2'i64, 2'u8, 2'u64).fields:
      testCriteria(ckInt, i, check c.num == BiggestInt(i))

  test "float criteria":
    for f in (2.0'f, 2.0).fields:
      testCriteria(ckFloat, f, check c.fnum == BiggestFloat(f))

  test "string criteria":
    for s in ["", "a", "ab"]:
      testCriteria(ckString, s, check c.str == s)

  test "regex criteria":
    for r in [re"", re"a", re"ab"]:
      testCriteria(ckRegex, r, check c.reg == r)


suite "creating invalid criteria":

  test "0 keys":
    expect AssertionDefect:
      discard initNullCriteria()
      discard initCriteria(false)
      discard initCriteria(0)
      discard initCriteria(0.0)
      discard initCriteria("")
      discard initCriteria(re"")

  test "empty string keys":
    expect AssertionDefect:
      discard initNullCriteria("")
      discard initCriteria(false, "")
      discard initCriteria(0, "")
      discard initCriteria(0.0, "")
      discard initCriteria("", "")
      discard initCriteria(re"", "")

  test "non JSON keys":
    for key in ["1", " ", "a1", "a "]:
      expect AssertionDefect:
        discard initNullCriteria(key)
        discard initCriteria(false, key)
        discard initCriteria(0, key)
        discard initCriteria(0.0, key)
        discard initCriteria("", key)
        discard initCriteria(re"", key)




suite "matching criteria":

  let node = parseJson("""
                       {
                         "n": null,
                         "b": true,
                         "i": 2,
                         "f": 2.0,
                         "s": "s",
                         "o": {
                           "a": 1,
                           "b": 2,
                         },
                         "a": [1, 2],
                         "r": "abc"
                       }
                       """.dedent)

  test "null criteria":
    check initNullCriteria("n").eval(node)
    check not initNullCriteria("b").eval(node)

  test "bool criteria":
    check initCriteria(true, "b").eval(node)
    check not initCriteria(false, "b").eval(node)
    check initOptCriteria(true, "n").eval(node)

  test "int criteria":
    check initCriteria(2, "i").eval(node)
    check not initCriteria(0, "i").eval(node)
    check initOptCriteria(1, "n").eval(node)

  test "float criteria":
    check initCriteria(2.0, "f").eval(node)
    check not initCriteria(1.8, "f").eval(node)
    check initOptCriteria(2.0, "n").eval(node)

  test "string criteria":
    check initCriteria("s", "s").eval(node)
    check not initCriteria("", "s").eval(node)
    check initOptCriteria("s", "n").eval(node)

  test "regex criteria":
    check initCriteria(re"^abc$", "r").eval(node)
    check not initCriteria(re"^(?!abc).*$", "r").eval(node)
    check initOptCriteria(re"^abc$", "n").eval(node)
