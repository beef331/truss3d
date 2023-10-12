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

var
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

  for controller in controllers.mitems:
    for state in controller.buttonState.mitems:
      case state
      of released:
        state = nothing
      of pressed:
        state = held
      else: discard


  reset keyRepeating

  mouseDelta = ivec2(0, 0)
  mouseScroll = 0

proc startTextInput*(r: Rect, text: sink string = "") =
  sdl.startTextInput()
  textInput.text = text
  textInput.pos = 0

export stopTextInput, isTextInputActive

proc setInputText*(str: string) =
  textInput.text = str

proc inputText*(): lent string = textInput.text

proc pollInputs*(screenSize: var IVec2, dt: float32, isRunning: var bool) =
  resetInputs(dt)

  discard gameControllerEventState(1)
  var e: Event
  while pollEvent(addr e) != 0:
    case e.kind
    of Keydown:
      let
        key = e.key.keysym.sym
        lutd = KeyLut[key]

      keyRepeating[lutd] = pressed

      if keyState[lutd] != held:
        keyState[lutd] = pressed
        dispatchEvents(lutd, pressed, dt)
    of KeyUp:
      let
        key = e.key.keysym.sym
        lutd = KeyLut[key]

      keyRepeating[lutd] = nothing

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
      textInput.text = $e.text.text
    of TextEditing:
      textInput.pos = e.edit.start
      #textInput.text = $e.edit.text
    of ControllerButtonUp:
      for controller in controllers.mitems:
        if controller.instanceId == e.cbutton.which:
          controller.buttonState[e.cbutton.button.ord] = released 

    of ControllerButtonDown:
      for controller in controllers.mitems:
        if controller.instanceId == e.cbutton.which:
          controller.buttonState[e.cbutton.button.ord] = pressed

    of ControllerDeviceAdded:
      let 
        id = joystickGetDeviceInstanceID(e.cdevice.which)

      info "Connected: ", gameControllerNameForIndex(id) 
      controllers.add Controller(instanceId: id, sdlController: gameControllerOpen(id))
    of ControllerDeviceRemoved:
      for x, controller in controllers.mpairs:
        if controller.instanceId == e.cdevice.which:
          info "Disconnected: ", gameControllerName(controller.sdlController)
          gameControllerClose(controller.sdlController)
          controllers.delete(x)
          break


    else: discard

proc isDown*(k: TKeycode): bool = keyState[k] == pressed
proc isDownRepeating*(k: TKeycode): bool = keyRepeating[k] == pressed

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

proc getAxis*(axis: GameControllerAxis): float32 =
  for controller in controllers:
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

proc getAxis*[T: mathtypes.Vec2](axisX, axisY: GameControllerAxis): T =
  result.x = getAxis(axisX)
  result.y = getAxis(axisY)

proc isDown*(button: GameControllerButton): bool =
  for controller in controllers:
    if controller.buttonState[button.ord] == pressed:
      return true

proc isPressed*(button: GameControllerButton): bool =
  for controller in controllers:
    if controller.buttonState[button.ord] == held:
      return true

proc isUp*(button: GameControllerButton): bool =
  for controller in controllers:
    if controller.buttonState[button.ord] == released:
      return true

proc rumble*(left, right, time: float32) =
  let
    left = uint16(uint16.high.float32 * left)
    right = uint16(uint16.high.float32 * right)
    time = uint32(time * 1000)
  for controller in controllers:
    discard controller.sdlController.gameControllerRumble(left, right, time)
