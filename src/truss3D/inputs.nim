import sdl2_nim/sdl except log
import opengl
import std/[macros, tables, strutils]
import vmath
import logging
export Rect, GameControllerButton, GameControllerAxis

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

  DeviceInteraction* = enum
    Mouse
    Gamepad
    Keyboard

  InputState* = object
    keyRepeating: array[TKeyCode, KeyState]
    keyState: array[TKeyCode, KeyState]
    mouseState: array[MouseButton, KeyState]
    mouseDelta: Vec2
    mousePos: Vec2
    mouseScroll: int32
    mouseMovement = MouseAbsolute
    events*: Events
    textInput: TextInput
    controllers: seq[Controller]
    interactedWithThisFrame*: set[DeviceInteraction]




const
  AxisLeftX* = ControllerAxisLeftX
  AxisLeftY* = ControllerAxisLeftY
  AxisRightX* = ControllerAxisRightX
  AxisRightY* = ControllerAxisRightY
  AxisTriggerL* = ControllerAxisTriggerLeft
  AxisTriggerR* = ControllerAxisTriggerRight

  GamePadAxes* = [AxisLeftX, AxisLeftY, AxisRightX, AxisRightY, AxisTriggerL, AxisTriggerR]


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
  input.interactedWithThisFrame = {}
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

  input.mouseDelta = vec2(0, 0)
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


proc getAxis*(input: var InputState, axis: GameControllerAxis): float32

proc pollInputs*(input: var InputState, screenSize: var IVec2, dt: float32, isRunning: var bool) =
  input.resetInputs(dt)

  discard gameControllerEventState(1)
  var e: Event
  while pollEvent(addr e) != 0:
    case e.kind
    of Keydown:
      input.interactedWithThisFrame.incl Keyboard
      let
        key = e.key.keysym.sym
        lutd = KeyLut[key]

      input.keyRepeating[lutd] = pressed

      if input.keyState[lutd] != held:
        input.keyState[lutd] = pressed
        input.dispatchEvents(lutd, pressed, dt)
    of KeyUp:
      input.interactedWithThisFrame.incl Keyboard
      let
        key = e.key.keysym.sym
        lutd = KeyLut[key]

      input.keyRepeating[lutd] = nothing

      if input.keyState[KeyLut[key]] == held:
        input.keyState[KeyLut[key]] = released
        input.dispatchEvents(lutd, released, dt)
    of MouseMotion:
      input.interactedWithThisFrame.incl Mouse
      let motion = e.motion
      if input.mouseMovement notin relativeMovement:
        input.mousePos = vec2(motion.x.float32, motion.y.float32)
      input.mouseDelta = vec2(motion.xrel.float32, motion.yrel.float32)
    of MouseButtonDown:
      input.interactedWithThisFrame.incl Mouse
      let button = MouseButton(e.button.button - 1)
      input.mouseState[button] = pressed
    of MouseButtonUp:
      input.interactedWithThisFrame.incl Mouse
      let button = MouseButton(e.button.button - 1)
      input.mouseState[button] = released
    of MouseWheel:
      input.interactedWithThisFrame.incl Mouse
      let sign = if e.wheel.direction == MouseWheelFlipped: -1 else: 1
      input.mouseScroll = sign * e.wheel.y
    of WindowEvent:
      case e.window.event.WindowEventID
      of WindowEventResized, WindowEventSizeChanged, WindowEventMaximized:
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
      input.interactedWithThisFrame.incl Gamepad
      for controller in input.controllers.mitems:
        if controller.instanceId == e.cbutton.which:
          controller.buttonState[e.cbutton.button.ord] = released 

    of ControllerButtonDown:
      input.interactedWithThisFrame.incl Gamepad
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

  for axis in GamePadAxes:
    if input.getAxis(axis) notin -0.1..0.1:
      input.interactedWithThisFrame.incl Gamepad

proc interactedWith*(input: InputState): set[DeviceInteraction] = input.interactedWithThisFrame


proc isDown*(input: InputState, k: TKeycode): bool = input.keyState[k] == pressed
proc simulateDown*(input: var InputState, k: TKeycode) = input.keyState[k] = pressed

proc isDownRepeating*(input: InputState, k: TKeycode): bool = input.keyRepeating[k] == pressed
proc simulateDownRepeating*(input: var InputState, k: TKeycode) = input.keyRepeating[k] = pressed

proc isPressed*(input: InputState, k: TKeycode): bool = input.keyState[k] == held
proc simulatePressed*(input: var InputState, k: TKeycode) = input.keyState[k] = held

proc isUp*(input: InputState, k: TKeycode): bool = input.keyState[k] == released
proc simulateUp*(input: var InputState, k: TKeycode) = input.keyState[k] = released
proc isNothing*(input: InputState, k: TKeycode): bool = input.keyState[k] == nothing
proc simulateClear*(input: var InputState, k: TKeycode) =
  input.keyState[k] = nothing
  input.keyRepeating[k] = nothing

proc state*(input: InputState, k: TKeycode): KeyState = input.keyState[k]

proc isDown*(input: InputState, mb: MouseButton): bool = input.mouseState[mb] == pressed
proc simulateDown*(input: var InputState, mb: MouseButton) = input.mouseState[mb] = pressed

proc isPressed*(input: InputState, mb: MouseButton): bool = input.mouseState[mb] == held
proc simulatePressed*(input: var InputState, mb: MouseButton) = input.mouseState[mb] = held

proc isUp*(input: InputState, mb: MouseButton): bool = input.mouseState[mb] == released
proc simulateUp*(input: var InputState, mb: MouseButton) = input.mouseState[mb] = released

proc isNothing*(input: InputState, mb: MouseButton): bool = input.mouseState[mb] == nothing
proc simulateClear*(input: var InputState, mb: MouseButton) = input.mouseState[mb] = nothing

proc state*(input: InputState, mb: MouseButton): KeyState = input.mouseState[mb]


proc getMousePos*(input: InputState): Vec2 = input.mousePos
proc simulateMousePos*(input: var InputState, pos: Vec2) = input.mousePos = pos

proc getMouseDelta*(input: InputState): Vec2 = input.mouseDelta
proc simulateMouseDelta*(input: var InputState, pos: Vec2) = input.mouseDelta = pos

proc getMouseScroll*(input: InputState): int32 = input.mouseScroll
proc simulateMouseScroll*(input: var InputState, dir: int32) = input.mouseScroll = dir

proc setMouseMode*(input: var InputState, mode: MouseRelativeMode) =
  input.mouseMovement = mode
  discard setRelativeMouseMode(mode in relativeMovement)

proc setSoftwareMousePos*(input: var InputState, pos: Vec2) =
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

proc getAxis*(input: var InputState, axisX, axisY: GameControllerAxis): Vec2 =
  vec2(input.getAxis(axisX), input.getAxis(axisY))

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
