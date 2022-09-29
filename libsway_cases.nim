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
    of ckRegex: reg*: Regex



template initCriteria(
                      optionalVal: bool;
                      kindVal: CriteriaKind;
                     ) {.dirty.} =
  result = Criteria(keys: toSeq(keys), optional: optionalVal, kind: kindVal)
  doAssert(keys.len > 0, "Must have at least one key")
  for key in keys:
    doAssert(key.len > 0, "All keys must be non-empty")
    for letter in key:
      doAssert(letter == '_' or 
               (letter >= 'a' and letter <= 'z'), 
               "All keys must be non-empty and alphabetic",
              )


func initNullCriteria*(keys: varargs[string]): Criteria =
  initCriteria(false, ckNull)


func initCriteria*(bval: bool; keys: varargs[string]): Criteria =
  initCriteria(false, ckBool)
  result.bval = bval

func initCriteria*(num: SomeInteger; keys: varargs[string]): Criteria =
  initCriteria(false, ckInt)
  result.num = BiggestInt(num)

func initCriteria*(fnum: SomeFloat; keys: varargs[string]): Criteria =
  initCriteria(false, ckFloat)
  result.fnum = BiggestFloat(fnum)

func initCriteria*(str: string, keys: varargs[string]): Criteria =
  initCriteria(false, ckString)
  result.str = str

func initCriteria*(reg: Regex, keys: varargs[string]): Criteria =
  initCriteria(false, ckRegex)
  result.reg = reg


func initOptCriteria*(bval: bool; keys: varargs[string]): Criteria =
  initCriteria(true, ckBool)
  result.bval = bval

func initOptCriteria*(num: SomeInteger; keys: varargs[string]): Criteria =
  initCriteria(true, ckInt)
  result.num = BiggestInt(num)

func initOptCriteria*(fnum: SomeFloat; keys: varargs[string]): Criteria =
  initCriteria(true, ckFloat)
  result.fnum = BiggestFloat(fnum)

func initOptCriteria*(str: string, keys: varargs[string]): Criteria =
  initCriteria(true, ckString)
  result.str = str

func initOptCriteria*(reg: Regex, keys: varargs[string]): Criteria =
  initCriteria(true, ckRegex)
  result.reg = reg



method matches*(criteria: Criteria; node: JsonNode): bool {.base.} =
  if node.kind == JNull and (criteria.kind == ckNull or criteria.optional):
    return true

  case criteria.kind:
  of ckNull: false
  of ckBool: node.kind == JBool and node.bval == criteria.bval
  of ckInt: node.kind == JInt and node.num == criteria.num
  of ckFloat: node.kind == JFloat and almostEqual(node.fnum, criteria.fnum)
  of ckString: node.kind == JString and node.str == criteria.str
  of ckRegex: node.kind == JString and node.str.contains(criteria.reg)


method `==`*(a, b: Criteria): bool {.base.} =
  if not (a.kind == b.kind and a.optional == b.optional): return false

  case a.kind:
  of ckNull: true
  of ckBool: a.bval == b.bval
  of ckInt: a.num == b.num
  of ckFloat: a.fnum == b.fnum
  of ckString: a.str == b.str
  of ckRegex: a.reg == b.reg



proc eval*(criteria: Criteria, node: JsonNode): bool =

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
