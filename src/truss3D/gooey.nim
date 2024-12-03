import pkg/vmath
export vmath

type
  AnchorDirection* = enum
    left, right, top, bottom, center

  UiFlag* = enum
    onlyVisual
    enabled
    hovered

  InteractEvent* = proc(ui: UiElement, state: UiState)

  UiElement* = ref object of RootObj
    onEnterHandler*: InteractEvent
    onExitHandler*: InteractEvent
    onClickHandler*: InteractEvent
    onDragHandler*: InteractEvent
    onHoverHandler*: InteractEvent
    onTickHandler*: InteractEvent
    onTextHandler*: InteractEvent
    visibleHandler*: proc(ui: UiElement): bool
    position*, size*, layoutPos*, layoutSize*: Vec2
    flags*: set[UiFlag]
    anchor*: set[AnchorDirection]

  UiAction* = enum
    nothing
    overElement
    interacted
    inputing

  UiInputKind* = enum
    nothing
    textInput
    textDelete
    textNewLine
    leftClick
    rightClick

  UiInput* = object
    isHeld*: bool
    case kind*: UiInputKind
    of textInput:
      str*: string
    of leftClick, rightClick, nothing, textDelete, textNewLine:
      discard

  UiState* = ref object of RootObj
    action*: UiAction
    currentElement*: UiElement
    input*: UiInput
    inputPos*: Vec2
    screenSize*: Vec2
    scaling*: float32
    interactedWithCurrentElement*: bool
    overAnyUi*: bool # This is used for blocking input when over gui that do not interact
    dt*: float32

const TextEditFields* = {textInput..textNewline}

proc isVisible*(ui: UiElement): bool = ui.visibleHandler.isNil or ui.visibleHandler(ui)

proc isOver(ui: UiElement, pos: Vec2): bool =
  pos.x in ui.layoutPos.x .. ui.layoutSize.x + ui.layoutPos.x and
  pos.y in ui.layoutPos.y .. ui.layoutSize.y + ui.layoutPos.y and
  ui.isVisible()

method calcSize*(ui: UiElement): Vec2 {.base.} = ui.size

method layout*(ui: UiElement, parent: UiElement, offset: Vec2,  uiState: UiState) {.base.} =
  let
    screenSize = uiState.screenSize
    scaling = uiState.scaling
    offset =
      if parent != nil:
        parent.layoutPos + offset
      else:
        offset
    pos = vec2(ui.position.x * scaling, ui.position.y * scaling)

  ui.layoutSize = vec2(ui.size.x * scaling, ui.size.y * scaling)

  ui.layoutPos =
    if ui.anchor == {top, left}:
      vec2(pos.x + offset.x, pos.y + offset.y)
    elif ui.anchor == {top}:
      vec2(screenSize.x / 2 + pos.x + offset.x - ui.layoutSize.x / 2, pos.y + offset.y)
    elif ui.anchor == {top, right}:
      vec2(screenSize.x - pos.x + offset.x - ui.layoutSize.x, pos.y + offset.y)
    elif ui.anchor == {right}:
      vec2(screenSize.x - pos.x + offset.x - ui.layoutSize.x, screenSize.y / 2 - pos.y + offset.y - ui.layoutSize.y / 2)
    elif ui.anchor == {bottom, right}:
      vec2(screenSize.x - pos.x + offset.x - ui.layoutSize.x, screenSize.y - pos.y + offset.y - ui.layoutSize.y)
    elif ui.anchor == {bottom}:
      vec2(screenSize.x / 2 + pos.x + offset.x - ui.layoutSize.x / 2, screenSize.y - pos.y + offset.y - ui.layoutSize.y)
    elif ui.anchor == {bottom, left}:
      vec2(pos.x + offset.x, screenSize.y - pos.y + offset.y - ui.layoutSize.y)
    elif ui.anchor == {left}:
      vec2(pos.x + offset.x, screenSize.y / 2 - pos.y + offset.y - ui.layoutSize.y / 2)
    elif ui.anchor == {center}:
      vec2(screenSize.x / 2 - pos.x + offset.x - ui.layoutSize.x / 2, screenSize.y / 2 - pos.y + offset.y - ui.layoutSize.y / 2)
    elif ui.anchor == {}:
      pos + offset
    else:
      raise (ref AssertionDefect)(msg: "Invalid anchor: " & $ui.anchor)

proc onEnter(ui: UiElement, state: var UiState) =
  if ui.onEnterHandler != nil:
    ui.onEnterHandler(ui, state)

proc onClick(ui: UiElement, state: var UiState) =
  if ui.onClickHandler != nil:
    ui.onClickHandler(ui, state)

proc onHover(ui: UiElement, state: var UiState) =
  if ui.onHoverHandler != nil:
    ui.onHoverHandler(ui, state)

proc onExit(ui: UiElement, state: var UiState) =
  if ui.onExitHandler != nil:
    ui.onExitHandler(ui, state)

proc onDrag(ui: UiElement, state: var UiState) =
  if ui.onDragHandler != nil:
    ui.onDragHandler(ui, state)

proc onText(ui: UiElement, state: var UiState) =
  if ui.onTextHandler != nil:
    ui.onTextHandler(ui, state)

proc onTick(ui: UiElement, state: var UiState) =
  if ui.onTickHandler != nil:
    ui.onTickHandler(ui, state)


method interact*(ui: UiElement, state: var UiState) {.base.} =
  if state.action == nothing or
    (state.action == overElement and not state.interactedWithCurrentElement and state.currentElement != ui):
    if isOver(ui, state.inputPos):
      onEnter(ui, state)
      if state.action == overElement:
        reset state.currentElement.flags
      state.action = overElement
      state.currentElement = ui
      state.interactedWithCurrentElement = true

  if state.currentElement == ui:
    if isOver(ui, state.inputPos):
      state.interactedWithCurrentElement = true
      if state.input.kind == leftClick:
        if state.input.isHeld:
          onDrag(ui, state)
        else:
          onClick(ui, state)
          reset state.input  # Consume it
      onHover(ui, state)

      if state.input.kind in TextEditFields:
        onText(ui, state)

    else:
      onExit(ui, state)
      state.action = nothing
      state.currentElement = nil
  onTick(ui, state)

template eventFactory*(name: untyped): untyped =
  proc name*[T: UiElement](ui: T, prc: typeof(UiElement().`name Handler`)): T =
    ui.`name Handler` = prc
    ui

eventFactory onEnter
eventFactory onExit
eventFactory onClick
eventFactory onHover
eventFactory onText
eventFactory visible
eventFactory onTick

proc setPosition*[T: UiElement](ui: T, pos: Vec2): T =
  ui.position = pos
  ui

proc setSize*[T: UiElement](ui: T, size: Vec2): T =
  ui.size = size
  ui

proc setAnchor*[T: UiElement](ui: T, anchor: set[AnchorDirection]): T =
  ui.anchor = anchor
  ui
