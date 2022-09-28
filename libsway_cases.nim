from std/json import parseJson, getStr,
  JsonNode,
  JObject, JString, JInt, JBool, JNull
from std/logging import newConsoleLogger, addHandler, log,
  info, notice, error,
  Level,
  lvlAll, lvlWarn, lvlError
from std/osproc import startProcess, close, waitForExit, errorStream, outputStream,
  Process, ProcessOption
from std/sequtils import toSeq, any, all
from std/strtabs import StringTableRef
from std/streams import readAll
from std/strformat import `&`
from std/sugar import `=>`
from std/re import contains, Regex
from std/tables import contains, `[]`



type
  CriteriaKind = enum
    ckNull,
    ckBool,
    ckInt,
    ckString,
    ckRegex,

  Criteria* = object
    keys: seq[string]
    optional: bool
    case kind: CriteriaKind
    of ckNull: discard
    of ckBool: bval: bool
    of ckInt: num: int
    of ckString: str: string
    of ckRegex:  reg: Regex



func initNullCriteria*(keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), kind: ckNull)
  doAssert keys.len > 0, "Can't have 0 keys for a null criteria"


func initCriteria*(bval: bool, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: false, kind: ckBool, bval: bval)
  doAssert keys.len > 0, &"Can't have 0 keys for '{bval}''"

func initCriteria*(num: int, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: false, kind: ckInt, num: num)
  doAssert keys.len > 0, &"Can't have 0 keys for '{num}''"

func initCriteria*(str: string, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: false, kind: ckString, str: str)
  doAssert keys.len > 0, &"Can't have 0 keys for '{str}''"

func initCriteria*(reg: Regex, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: false, kind: ckRegex, reg: reg)
  doAssert keys.len > 0, &"Can't have 0 keys for a regex criteria'"


func initOptCriteria*(bval: bool, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: true, kind: ckBool, bval: bval)
  doAssert keys.len > 0, &"Can't have 0 keys for '{bval}''"

func initOptCriteria*(num: int, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: true, kind: ckInt, num: num)
  doAssert keys.len > 0, &"Can't have 0 keys for '{num}''"

func initOptCriteria*(str: string, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: true, kind: ckString, str: str)
  doAssert keys.len > 0, &"Can't have 0 keys for '{str}''"

func initOptCriteria*(reg: Regex, keys: varargs[string]): Criteria =
  result = Criteria(keys: toSeq(keys), optional: true, kind: ckRegex, reg: reg)
  doAssert keys.len > 0, &"Can't have 0 keys for a regex criteria'"



func matches(criteria: Criteria; node: JsonNode): bool =
  if node.kind == JNull and (criteria.kind == ckNull or criteria.optional):
    return true

  case criteria.kind:
  of ckNull: false
  of ckBool: node.kind == JBool and node.bval == criteria.bval
  of ckInt: node.kind == JInt and node.num == criteria.num
  of ckString: node.kind == JString and node.str == criteria.str
  of ckRegex: node.kind == JString and node.str.contains(criteria.reg)



func eval*(criteria: Criteria, node: JsonNode): bool =
  var field = node
  for key in criteria.keys:
    if not (field.kind == JObject and key in field.fields):
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

func matchesAny*(criterias: openArray[seq[Criteria]]; node: JsonNode): bool =
  return any(criterias, (criteriaSet) => all(criteriaSet, (criteria) => criteria.eval(node)))
