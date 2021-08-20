import sdl2_nim/sdl
import std/[macros, tables, strutils]

type
  KeyState = enum
    nothing, pressed, held, released



macro emitEnumFaff(key: typedesc[enum]): untyped =
  result = key.getImpl
  result[0] = postfix(ident"TKeycode", "*")

  var
    newIdents: seq[NimNode]
    highest: NimNode
  let
    arrSetters = newStmtList()
    arrName = ident"KeyLut"

  for x in result[^1][1..^1]:
    let
      name = "Keycode" & ($x[0]).nimIdentNormalize[1..^1]
      ident = ident(name)
      sym = x[0]
    highest = `sym`
    newIdents.add ident
    arrSetters.add quote do:
      `arrName`[`sym`] = inputs.`ident`


  result[^1] = nnkEnumTy.newTree(newEmptyNode())
  result[^1].add newIdents

  result = newStmtList(nnkTypeSection.newTree(result))
  result.add quote do:
    const `arrName` = block:
      var `arrName`: Table[`key`, inputs.TKeycode]
      `arrSetters`
      `arrName`

emitEnumFaff(Keycode)

var keyState: array[TKeyCode, KeyState]

proc pollInputs*() =
  for key in keyState.mitems:
    case key:
    of released:
      key = nothing
    of pressed:
      key = held
    else: discard

  var e: Event
  while pollEvent(addr e) != 0:
    case e.kind:
    of Keydown:
      let key = e.key.keysym.sym
      keyState[KeyLut[key]] = pressed
    of KeyUp:
      let key = e.key.keysym.sym
      keyState[KeyLut[key]] = released
    else: discard

proc isDown*(k: TKeycode): bool = keyState[k] == pressed
proc isPressed*(k: TKeycode): bool = keyState[k] == held
proc isUp*(k: TKeycode): bool = keyState[k] == released
proc isNothing*(k: TKeycode): bool = keyState[k] == nothing
