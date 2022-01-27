import sdl2_nim/sdl
import opengl
import std/[macros, tables, strutils]
import vmath

type
  KeyState* = enum
    nothing, pressed, held, released
  MouseButton* = enum
    leftMb
    middleMb
    rightMb
    fourthMb
    fifthMb
  MouseRelativeMode* = enum
    MouseRelative
    MouseAbsolute


const relativeMovement = {MouseRelative}

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

var
  keyState: array[TKeyCode, KeyState]
  mouseState: array[MouseButton, KeyState]
  mouseDelta: IVec2
  mousePos: IVec2
  mouseScroll: int32
  mouseMovement = MouseAbsolute

proc resetInputs() =
  for key in keyState.mitems:
    case key:
    of released:
      key = nothing
    of pressed:
      key = held
    else: discard

  for btn in mouseState.mitems:
    case btn:
    of released:
      btn = nothing
    of pressed:
      btn = held
    else:
      discard

  mouseDelta = ivec2(0, 0)
  mouseScroll = 0

proc pollInputs*(screenSize: var IVec2) =
  resetInputs()

  var e: Event
  while pollEvent(addr e) != 0:
    case e.kind:
    of Keydown:
      let key = e.key.keysym.sym
      if keyState[KeyLut[key]] != held:
        keyState[KeyLut[key]] = pressed
    of KeyUp:
      let key = e.key.keysym.sym
      if keyState[KeyLut[key]] == held:
        keyState[KeyLut[key]] = released
    of MouseMotion:
      let motion = e.motion
      if mouseMovement notin relativeMovement:
        mousePos = ivec2(motion.x.int, motion.y.int)
      mouseDelta = ivec2(motion.xrel.int, motion.yrel.int)
    of MouseButtonDown:
      let button = MouseButton(e.button.button - 1)
      mouseState[button] = pressed
    of MouseButtonUp:
      let button = MouseButton(e.button.button - 1)
      mouseState[button] = released
    of MouseWheel:
      let sign = if e.wheel.direction == MouseWheelFlipped: -1 else: 1
      mouseScroll = sign * e.wheel.y
    of WindowEvent:
      case e.window.event.WindowEventID
      of WindowEventResized, WindowEventSizeChanged:
        screenSize.x = e.window.data1
        screenSize.y = e.window.data2
        glViewport(0, 0, screenSize.x, screenSize.y)
      else: discard

    else: discard

proc isDown*(k: TKeycode): bool = keyState[k] == pressed
proc isPressed*(k: TKeycode): bool = keyState[k] == held
proc isUp*(k: TKeycode): bool = keyState[k] == released
proc isNothing*(k: TKeycode): bool = keyState[k] == nothing

proc state*(k: TKeycode): KeyState = keyState[k]

proc isDown*(mb: MouseButton): bool = mouseState[mb] == pressed
proc isPressed*(mb: MouseButton): bool = mouseState[mb] == held
proc isUp*(mb: MouseButton): bool = mouseState[mb] == released
proc isNothing*(mb: MouseButton): bool = mouseState[mb] == nothing

proc state*(mb: MouseButton): KeyState = mouseState[mb]


proc getMousePos*(): IVec2 = mousePos
proc getMouseDelta*(): IVec2 = mouseDelta
proc getMouseScroll*(): int32 = mouseScroll

proc setMouseMode*(mode: MouseRelativeMode) =
  mouseMovement = mode
  discard setRelativeMouseMode(mode in relativeMovement)

proc setSoftwareMousePos*(pos: IVec2) = 
  ## Does not move the mouse in the OS, just inside Truss3D.
  ## Useful for things like RTS pan cameras.
  mousePos = pos