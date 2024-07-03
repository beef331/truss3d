import sdl2_nim/sdl except log
import opengl
import std/[macros, tables, strutils]
import vmath
import mathtypes, logging
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

  Controller* = object
    instanceId: JoystickID
    sdlController: GameController
    buttonState: array[ControllerButtonA.ord..ControllerButtonDpadRight.ord, KeyState]
  InputState* = object
    keyRepeating: array[TKeyCode, KeyState]
    keyState: array[TKeyCode, KeyState]
    mouseState: array[MouseButton, KeyState]
    mouseDelta: IVec2
    mousePos: IVec2
    mouseScroll: int32
    mouseMovement = MouseAbsolute
    events*: Events
    textInput: TextInput
    controllers: seq[Controller]




const
  AxisLeftX* = ControllerAxisLeftX
  AxisLeftY* = ControllerAxisLeftY
  AxisRightX* = ControllerAxisRightX
  AxisRightY* = ControllerAxisRightY
  AxisTriggerL* = ControllerAxisTriggerLeft
  AxisTriggerR* = ControllerAxisTriggerRight


  ButtonA* = ControllerButtonA
  ButtonB* = ControllerButtonB
  ButtonX* = ControllerButtonX
  ButtonY* = ControllerButtonY
  ButtonBack* = ControllerButtonBack
  ButtonGuide* = ControllerButtonGuide
  ButtonStart* = ControllerButtonStart
  ButtonLeftStick* = ControllerButtonLeftStick
  ButtonRightStick* = ControllerButtonRightStick
  ButtonLeftShoulder* = ControllerButtonLeftShoulder
  ButtonRightShoulder* = ControllerButtonRightShoulder
  ButtonDpadUp* = ControllerButtonDpadUp
  ButtonDpadDown* = ControllerButtonDpadDown
  ButtonDpadLeft* = ControllerButtonDpadLeft
  ButtonDpadRight* = ControllerButtonDpadRight


proc addEvent*(input: var InputState, key: TKeyCode, state: KeyState, prio: EventPriority, prc: KeyProc, eventFlags: EventFlags = {}) =
  if input.events.keyEvents[prio].hasKeyOrPut((key, state), @[KeyEvent(flags: eventFlags, event: prc)]):
    input.events.keyEvents[prio][(key, state)].add KeyEvent(flags: eventFlags, event: prc)

proc addEvent*(input: var InputState, keys: set[TKeyCode], state: KeyState, prio: EventPriority, prc: KeyProc, eventFlags: EventFlags = {}) =
  for key in keys:
    input.addEvent(key, state, prio, prc, eventFlags)

proc dispatchEvents(input: var InputState, keyCode: TKeyCode, state: KeyState, dt: float32) =
  for prio in EventPriority:
    if (keyCode, state) in input.events.keyEvents[prio]:
      for event in input.events.keyEvents[prio][(keyCode, state)].mitems:
        if efInteruptable notin event.flags or not event.interrupted:
          event.event(event, dt)
          event.interrupted = true

proc resetInputs(input: var InputState, dt: float32) =
  for key, state in input.keyState.pairs:
    case state:
    of released:
      input.keyState[key] = nothing
    of pressed:
      input.keyState[key] = held
    of held:
      input.dispatchEvents(key, held, dt)
    else: discard

  for btn in input.mouseState.mitems:
    case btn:
    of released:
      btn = nothing
    of pressed:
      btn = held
    else:
      discard

  for controller in input.controllers.mitems:
    for state in controller.buttonState.mitems:
      case state
      of released:
        state = nothing
      of pressed:
        state = held
      else: discard


  reset input.keyRepeating

  input.mouseDelta = ivec2(0, 0)
  input.mouseScroll = 0


proc startTextInput*(input: var InputState, r: Rect, text: sink string = "") =
  sdl.startTextInput()
  input.textInput.text = text
  input.textInput.pos = 0


proc stopTextInput*(input: var InputState) =
  sdl.stopTextInput()

proc setInputText*(input: var InputState, str: string) =
  input.textInput.text = str

export isTextInputActive

proc inputText*(input: InputState): lent string = input.textInput.text
proc inputText*(input: var InputState): var string = input.textInput.text


proc pollInputs*(input: var InputState, screenSize: var IVec2, dt: float32, isRunning: var bool) =
  input.resetInputs(dt)

  discard gameControllerEventState(1)
  var e: Event
  while pollEvent(addr e) != 0:
    case e.kind
    of Keydown:
      let
        key = e.key.keysym.sym
        lutd = KeyLut[key]

      input.keyRepeating[lutd] = pressed

      if input.keyState[lutd] != held:
        input.keyState[lutd] = pressed
        input.dispatchEvents(lutd, pressed, dt)
    of KeyUp:
      let
        key = e.key.keysym.sym
        lutd = KeyLut[key]

      input.keyRepeating[lutd] = nothing

      if input.keyState[KeyLut[key]] == held:
        input.keyState[KeyLut[key]] = released
        input.dispatchEvents(lutd, released, dt)
    of MouseMotion:
      let motion = e.motion
      if input.mouseMovement notin relativeMovement:
        input.mousePos = ivec2(motion.x.int, motion.y.int)
      input.mouseDelta = ivec2(motion.xrel.int, motion.yrel.int)
    of MouseButtonDown:
      let button = MouseButton(e.button.button - 1)
      input.mouseState[button] = pressed
    of MouseButtonUp:
      let button = MouseButton(e.button.button - 1)
      input.mouseState[button] = released
    of MouseWheel:
      let sign = if e.wheel.direction == MouseWheelFlipped: -1 else: 1
      input.mouseScroll = sign * e.wheel.y
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
      input.textInput.text = $e.text.text
    of TextEditing:
      input.textInput.pos = e.edit.start
      #textInput.text = $e.edit.text
    of ControllerButtonUp:
      for controller in input.controllers.mitems:
        if controller.instanceId == e.cbutton.which:
          controller.buttonState[e.cbutton.button.ord] = released 

    of ControllerButtonDown:
      for controller in input.controllers.mitems:
        if controller.instanceId == e.cbutton.which:
          controller.buttonState[e.cbutton.button.ord] = pressed

    of ControllerDeviceAdded:
      let 
        id = joystickGetDeviceInstanceID(e.cdevice.which)

      info "Connected: ", gameControllerNameForIndex(id) 
      input.controllers.add Controller(instanceId: id, sdlController: gameControllerOpen(id))
    of ControllerDeviceRemoved:
      for x, controller in input.controllers.mpairs:
        if controller.instanceId == e.cdevice.which:
          info "Disconnected: ", gameControllerName(controller.sdlController)
          gameControllerClose(controller.sdlController)
          input.controllers.delete(x)
          break


    else: discard

proc isDown*(input: InputState, k: TKeycode): bool = input.keyState[k] == pressed
proc isDownRepeating*(input: InputState, k: TKeycode): bool = input.keyRepeating[k] == pressed

proc isPressed*(input: InputState, k: TKeycode): bool = input.keyState[k] == held
proc isUp*(input: InputState, k: TKeycode): bool = input.keyState[k] == released
proc isNothing*(input: InputState, k: TKeycode): bool = input.keyState[k] == nothing

proc state*(input: InputState, k: TKeycode): KeyState = input.keyState[k]

proc isDown*(input: InputState, mb: MouseButton): bool = input.mouseState[mb] == pressed
proc isPressed*(input: InputState, mb: MouseButton): bool = input.mouseState[mb] == held
proc isUp*(input: InputState, mb: MouseButton): bool = input.mouseState[mb] == released
proc isNothing*(input: InputState, mb: MouseButton): bool = input.mouseState[mb] == nothing

proc state*(input: InputState, mb: MouseButton): KeyState = input.mouseState[mb]


proc getMousePos*(input: InputState): IVec2 = input.mousePos
proc getMouseDelta*(input: InputState): IVec2 = input.mouseDelta
proc getMouseScroll*(input: InputState): int32 = input.mouseScroll

proc setMouseMode*(input: var InputState, mode: MouseRelativeMode) =
  input.mouseMovement = mode
  discard setRelativeMouseMode(mode in relativeMovement)

proc setSoftwareMousePos*(input: var InputState, pos: IVec2) =
  ## Does not move the mouse in the OS, just inside Truss3D.
  ## Useful for things like RTS pan cameras.
  input.mousePos = pos

proc getAxis*(input: var InputState, axis: GameControllerAxis): float32 =
  for controller in input.controllers:
    let input = controller.sdlController.gameControllerGetAxis(axis)
    case axis
    of AxisTriggerL, AxisTriggerR:
      result = input / int16.high
    else:
      if input < 0:
        result = -(input / int16.low)
      else:
        result = input / int16.high
    if result != 0:
      break

proc getAxis*[T: mathtypes.Vec2](input: var InputState, axisX, axisY: GameControllerAxis): T =
  result.x = getAxis(axisX)
  result.y = getAxis(axisY)

proc isDown*(input: var InputState, button: GameControllerButton): bool =
  for controller in input.controllers:
    if controller.buttonState[button.ord] == pressed:
      return true

proc isPressed*(input: var InputState, button: GameControllerButton): bool =
  for controller in input.controllers:
    if controller.buttonState[button.ord] == held:
      return true

proc isUp*(input: var InputState, button: GameControllerButton): bool =
  for controller in input.controllers:
    if controller.buttonState[button.ord] == released:
      return true

proc rumble*(input: var InputState, left, right, time: float32) =
  let
    left = uint16(uint16.high.float32 * left)
    right = uint16(uint16.high.float32 * right)
    time = uint32(time * 1000)
  for controller in input.controllers:
    discard controller.sdlController.gameControllerRumble(left, right, time)

when not defined(truss3D.inputHandler):
  var inputs = InputState()
  proc addEvent*(key: TKeyCode, state: KeyState, prio: EventPriority, prc: KeyProc, eventFlags: EventFlags = {}) =
    inputs.addEvent(key, state, prio, prc, eventFlags)

  proc addEvent*(keys: set[TKeyCode], state: KeyState, prio: EventPriority, prc: KeyProc, eventFlags: EventFlags = {}) =
    inputs.addEvent(keys, state, prio, prc, eventFlags)

  proc startTextInput*(r: Rect, text: sink string = "") =
    inputs.startTextInput(r, text)

  proc stopTextInput*() =
    inputs.stopTextInput()

  proc setInputText*(str: string) =
    inputs.setInputText(str)


  proc inputText*(): var string = inputs.textInput.text


  proc pollInputs*(screenSize: var IVec2, dt: float32, isRunning: var bool) =
    inputs.pollInputs(screenSize, dt, isRunning)

  proc isDown*(k: TKeycode): bool = inputs.isDown(k)
  proc isDownRepeating*(k: TKeycode): bool = inputs.isDownRepeating(k)

  proc isPressed*(k: TKeycode): bool = inputs.isPressed(k)
  proc isUp*(k: TKeycode): bool = inputs.isUp(k)
  proc isNothing*(k: TKeycode): bool = inputs.isNothing(k)

  proc state*(k: TKeycode): KeyState = inputs.state(k)

  proc isDown*(mb: MouseButton): bool = inputs.isDown(mb)
  proc isPressed*(mb: MouseButton): bool = inputs.isPressed(mb)
  proc isUp*(mb: MouseButton): bool = inputs.isUp(mb)
  proc isNothing*(mb: MouseButton): bool = inputs.isNothing(mb)

  proc state*(mb: MouseButton): KeyState = inputs.mouseState[mb]


  proc getMousePos*(): IVec2 = inputs.mousePos
  proc getMouseDelta*(): IVec2 = inputs.mouseDelta
  proc getMouseScroll*(): int32 = inputs.mouseScroll

  proc setMouseMode*(mode: MouseRelativeMode) = inputs.setMouseMode(mode)

  proc setSoftwareMousePos*(pos: IVec2) =
    ## Does not move the mouse in the OS, just inside Truss3D.
    ## Useful for things like RTS pan cameras.
    inputs.setSoftwareMousePos(pos)

  proc getAxis*(axis: GameControllerAxis): float32 =
    inputs.getAxis(axis)

  proc getAxis*[T: mathtypes.Vec2](axisX, axisY: GameControllerAxis): T =
    inputs.getAxis[: T](axisX, axisY)

  proc isDown*(button: GameControllerButton): bool =
    inputs.isDown(button)

  proc isPressed*(button: GameControllerButton): bool =
    inputs.isPressed(buttoN)

  proc isUp*(button: GameControllerButton): bool =
    inputs.isUp(button)

  proc rumble*(left, right, time: float32) =
    inputs.rumble(left, right, time)
