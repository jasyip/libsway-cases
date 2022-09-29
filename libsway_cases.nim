from std/json import parseJson, getStr,
  JsonNode,
  JNull, JBool, JInt, JFloat, JString, JObject, JArray
from std/logging import newConsoleLogger, addHandler, log,
  debug, info, notice, error,
  Level,
  lvlAll, lvlWarn, lvlError
from std/math import almostEqual
from std/osproc import startProcess, close, waitForExit, errorStream, outputStream,
  Process, ProcessOption
from std/sequtils import toSeq, any, allIt, zip
from std/strtabs import StringTableRef
from std/streams import readAll
from std/strformat import `&`
from std/strutils import validIdentifier
from std/sugar import `=>`
from std/re import contains, Regex
from std/tables import contains, len, keys, values, `[]`, `==`, OrderedTable



type
  CriteriaKind* = enum
    ckNull,
    ckBool,
    ckInt,
    ckFloat,
    ckString,
    ckObject,
    ckArray,
    ckRegex,

  Criteria* {.inheritable.} = object
    keys*: seq[string]
    optional*: bool
    case kind*: CriteriaKind
    of ckNull: discard
    of ckBool: bval*: bool
    of ckInt: num*: BiggestInt
    of ckFloat: fnum*: BiggestFloat
    of ckString: str*: string
    of ckObject: fields*: OrderedTable[string, Criteria]
    of ckArray: elems*: seq[Criteria]
    of ckRegex: reg*: Regex



template initCriteria(
                      keys: varargs[string];
                      optionalVal: bool;
                      kindVal: CriteriaKind;
                      body: untyped
                     ): typed {.dirty.}=

  result = Criteria(keys: toSeq(keys), optional: optionalVal, kind: kindVal)
  doAssert keys.len > 0, "Can't have 0 keys for a null criteria"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )
  body


func initNullCriteria*(keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), kind: ckNull)
  doAssert keys.len > 0, "Can't have 0 keys for a null criteria"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )


func initCriteria*(bval: bool, keys: varargs[string]): Criteria =
  initCriteria(keys, false, ckBool): result.bval = bval

#[
func initCriteria*(bval: bool, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: false, kind: ckBool, bval: bval)
  doAssert keys.len > 0, &"Can't have 0 keys for '{bval}''"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )
]#

func initCriteria*(num: SomeInteger, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: false, kind: ckInt, num: BiggestInt(num))
  doAssert keys.len > 0, &"Can't have 0 keys for '{num}''"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )

func initCriteria*(fnum: SomeFloat, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: false, kind: ckFloat, fnum: BiggestFloat(fnum))
  doAssert keys.len > 0, &"Can't have 0 keys for '{fnum}''"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )

func initCriteria*(str: string, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: false, kind: ckString, str: str)
  doAssert keys.len > 0, &"Can't have 0 keys for '{str}''"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )

func initCriteria*(fields: OrderedTable[string, Criteria], keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: false, kind: ckObject, fields: fields)
  doAssert keys.len > 0, &"Can't have 0 keys for '{fields}''"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )

func initCriteria*(elems: openArray[Criteria], keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: false, kind: ckArray, elems: toSeq(elems))
  doAssert keys.len > 0, &"Can't have 0 keys for '{elems}''"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )

func initCriteria*(reg: Regex, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: false, kind: ckRegex, reg: reg)
  doAssert keys.len > 0, &"Can't have 0 keys for a regex criteria'"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )


func initOptCriteria*(bval: bool, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: true, kind: ckBool, bval: bval)
  doAssert keys.len > 0, &"Can't have 0 keys for '{bval}''"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )

func initOptCriteria*(num: SomeInteger, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: true, kind: ckInt, num: BiggestInt(num))
  doAssert keys.len > 0, &"Can't have 0 keys for '{num}''"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )

func initOptCriteria*(fnum: SomeFloat, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: true, kind: ckFloat, fnum: BiggestFloat(fnum))
  doAssert keys.len > 0, &"Can't have 0 keys for '{fnum}''"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )

func initOptCriteria*(str: string, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: true, kind: ckString, str: str)
  doAssert keys.len > 0, &"Can't have 0 keys for '{str}''"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )

func initOptCriteria*(fields: OrderedTable[string, Criteria], keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: true, kind: ckObject, fields: fields)
  doAssert keys.len > 0, &"Can't have 0 keys for '{fields}''"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )

func initOptCriteria*(elems: openArray[Criteria], keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: true, kind: ckArray, elems: toSeq(elems))
  doAssert keys.len > 0, &"Can't have 0 keys for '{elems}''"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )

func initOptCriteria*(reg: Regex, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: true, kind: ckRegex, reg: reg)
  doAssert keys.len > 0, &"Can't have 0 keys for a regex criteria'"
  doAssert(keys.allIt(it.len > 0 and validIdentifier(it)),
           "All keys must be non-empty and alphabetic",
          )



method matches*(criteria: Criteria; node: JsonNode): bool {.base.} =
  if node.kind == JNull and (criteria.kind == ckNull or criteria.optional):
    return true

  case criteria.kind:
  of ckNull: false
  of ckBool: node.kind == JBool and node.bval == criteria.bval
  of ckInt: node.kind == JInt and node.num == criteria.num
  of ckFloat: node.kind == JFloat and almostEqual(node.fnum, criteria.fnum)
  of ckString: node.kind == JString and node.str == criteria.str
  of ckObject:
    if  node.kind != JObject or
        criteria.fields.len != node.fields.len or
        toSeq(criteria.fields.keys) != toSeq(node.fields.keys):
      return false

    allIt(zip(toSeq(criteria.fields.values), toSeq(node.fields.values)), it[0].matches(it[1]))

  of ckArray:
    if  node.kind != JArray or
        criteria.elems.len != node.elems.len:
      return false

    allIt(zip(criteria.elems, node.elems), it[0].matches(it[1]))

  of ckRegex: node.kind == JString and node.str.contains(criteria.reg)


method `==`*(a, b: Criteria): bool {.base.} =
  if not (a.kind == b.kind and a.optional == b.optional): return false

  case a.kind:
  of ckNull: return true
  of ckBool: return a.bval == b.bval
  of ckInt: return a.num == b.num
  of ckFloat: return a.fnum == b.fnum
  of ckString: return a.str == b.str
  of ckObject: return a.fields == b.fields
  of ckArray: return a.elems.len == b.elems.len and allIt(zip(a.elems, b.elems), it[0] == it[1])
  of ckRegex: doAssert(false, "Comparing two regex criteria unsupported")



proc eval(criteria: Criteria, node: JsonNode): bool =

  var field = node
  for key in criteria.keys:
    if not (field.kind == JObject and key in field.fields):
      debug &"""{criteria.keys} not present in '{node.fields["name"].getStr()}'"""
      return false
    field = field.fields[key]

  return matches(criteria, field)






const logLevel: Level = when defined(release): lvlWarn else: lvlAll

var
  stdoutLogger = newConsoleLogger(logLevel)
  stderrLogger = newConsoleLogger(logLevel, useStdErr = true)

addHandler(stdoutLogger)

proc errorExit(message: string, exitCode: int = 1){.noreturn.} =
  stderrLogger.log(lvlError, message)
  quit exitCode

proc errorCodeExit(command: string, exitCode: int = 1){.noreturn.} =
  errorExit(&"'{command}' returned error code of {exitCode}")


proc smoothExec*(
    command: string;
    workingDir: string = "";
    args: openArray[string] = [];
    env: StringTableRef = nil;
    options: set[ProcessOption] = {poUsePath}
): string =

  let process: Process = startProcess(command, workingDir, args, env, options -
      {poStdErrToStdOut})

  defer: process.close()

  let exitCode = process.waitForExit()

  let errorMessage: string = process.errorStream().readAll()
  if errorMessage.len > 0:
    notice &"'{command}' error stream: {errorMessage}"

  if exitCode != 0:
    errorCodeExit(command, exitCode)

  return process.outputStream().readAll()


const containerTypes = ["con", "floating_con"]
const nodeAttributes = ["nodes", "floating_nodes"]

func getFocusedWindow(parent: JsonNode): JsonNode =

  if parent.fields["type"].str in containerTypes and
      "focused" in parent.fields and
      parent.fields["focused"].bval:
    return parent

  for nodeAttribute in nodeAttributes:
    for childNode in parent.fields[nodeAttribute].elems:
      let childNodeResult: JsonNode = getFocusedWindow(childNode)
      if not isNil(childNodeResult):
        return childNodeResult
  return nil


proc getFocusedWindow*(): JsonNode =

  let treeNode: JsonNode = parseJson(
    smoothExec("swaymsg", args = ["--raw", "-t", "get_tree"])
  )
  if treeNode.fields["type"].str == "root":

    let focusedWindow: JsonNode = getFocusedWindow(treeNode)

    if isNil(focusedWindow):
      errorExit "Couldn't find focused window"

    return focusedWindow

  else:
    errorExit "Couldn't find root tree"

proc matchesAny*(criterias: openArray[seq[Criteria]]; node: JsonNode): bool =
  return any(criterias, (criteriaSet) => allIt(criteriaSet, it.eval(node)))
