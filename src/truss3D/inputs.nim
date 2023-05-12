import sdl2_nim/sdl
import opengl
import std/[macros, tables, strutils]
import vmath
export Rect
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
type
  KeyProc* = proc(ke: var KeyEvent, dt: float){.closure.}
  MouseEvent* = proc(dt, delta: float){.closure.}

  EventPriority* = enum
    epHigh
    epMedium
    epLow

  EventFlag* = enum
    efInteruptable
  EventFlags* = set[EventFlag]
  KeyEvent* = object
    flags: set[EventFlag]
    event: KeyProc
    interrupted*: bool


  Events* = object
    keyEvents: array[EventPriority, Table[(TKeyCode, KeyState), seq[KeyEvent]]]
  TextInput = object
    text: string
    pos: int
    rect: Rect

var
  keyState: array[TKeyCode, KeyState]
  mouseState: array[MouseButton, KeyState]
  mouseDelta: IVec2
  mousePos: IVec2
  mouseScroll: int32
  mouseMovement = MouseAbsolute
  events*: Events
  textInput: TextInput


proc addEvent*(key: TKeyCode, state: KeyState, prio: EventPriority, prc: KeyProc, eventFlags: EventFlags = {}) =
  if events.keyEvents[prio].hasKeyOrPut((key, state), @[KeyEvent(flags: eventFlags, event: prc)]):
    events.keyEvents[prio][(key, state)].add KeyEvent(flags: eventFlags, event: prc)

proc addEvent*(keys: set[TKeyCode], state: KeyState, prio: EventPriority, prc: KeyProc, eventFlags: EventFlags = {}) =
  for key in keys:
    addEvent(key, state, prio, prc, eventFlags)


proc dispatchEvents(keyCode: TKeyCode, state: KeyState, dt: float32) =
  for prio in EventPriority:
    if (keyCode, state) in events.keyEvents[prio]:
      for event in events.keyEvents[prio][(keyCode, state)].mitems:
        if efInteruptable notin event.flags or not event.interrupted:
          event.event(event, dt)
          event.interrupted = true

proc resetInputs(dt: float32) =
  for key, state in keyState.pairs:
    case state:
    of released:
      keyState[key] = nothing
    of pressed:
      keyState[key] = held
    of held:
      dispatchEvents(key, held, dt)
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

proc startTextInput*(r: Rect, text: sink string = "") =
  sdl.startTextInput()
  textInput.text = text
  textInput.pos = 0

export stopTextInput

proc setInputText*(str: string) =
  textInput.text = str


proc inputText*(): lent string = textInput.text

proc pollInputs*(screenSize: var IVec2, dt: float32, isRunning: var bool) =
  resetInputs(dt)

  var e: Event
  while pollEvent(addr e) != 0:
    case e.kind:
    of Keydown:
      let
        key = e.key.keysym.sym
        lutd = KeyLut[key]
      if keyState[lutd] != held:
        keyState[lutd] = pressed
        dispatchEvents(lutd, pressed, dt)
    of KeyUp:
      let
        key = e.key.keysym.sym
        lutd = KeyLut[key]
      if keyState[KeyLut[key]] == held:
        keyState[KeyLut[key]] = released
        dispatchEvents(lutd, released, dt)
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
      of WindowEventClose:
        isRunning = false
      else: discard
    of sdl.TextInput:
      textInput.text.add $e.text.text
    of TextEditing:
      textInput.pos = e.edit.start
      #textInput.text = $e.edit.text


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
