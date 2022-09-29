import std/unittest

import std/[sequtils, tables, re]
import std/sugar


import libsway_cases



suite "creating valid criteria":

  template testCriteria(fun: untyped; e: CriteriaKind; value: untyped; body: untyped) =
    for keySeq in [@["a"], @["a", "b"], @["a", "b", "c"]]:
      let c {.inject.} = fun(value, keySeq)
      check:
        c.keys == keySeq
        c.kind == e
      body

  template testCriteria(e: CriteriaKind; value: untyped; body: untyped) =
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

  test "object criteria":
    let tableList = collect(newSeq):
      for t in [@[("a", @["", "a"])], @[("a", @["", "a", "b"]), ("b", @["", "b"])]]:
        collect(initOrderedTable):
          for p in t:
            {p[0] : initCriteria(p[1][0], p[1][1..^1])}

    for t in tableList:
      testCriteria(ckObject, t):
        check toSeq(c.fields.keys) == toSeq(t.keys)
        for (cv, tv) in zip(toSeq(c.fields.values), toSeq(t.values)):
          check cv == tv

  test "array criteria":
    let l = [
             @[@["", "a"], @["", "a", "b"], @["", "b"],],
             @[],
            ].mapIt(it.map((c) => initCriteria(c[0], c[1..^1])))

    for a in l:
      testCriteria(ckArray, a):
        check c.elems.len == a.len
        for (cv, av) in zip(c.elems, a):
          check cv == av

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
