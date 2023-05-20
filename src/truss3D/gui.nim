import std/typetraits

type
  InteractDirection* = enum
    horizontal, vertical

  AnchorDirection* = enum
    left, right, top, bottom

  Vec3 = concept vec, type V
    vec.x is float32
    vec.y is float32
    vec.z is float32
    not compiles(vec.w)
    V.init(float32, float32, float32)
    vec + vec is V


  Vec2 = concept vec, type V
    vec.x is float32
    vec.y is float32
    not compiles(vec.z)
    V.init(float32, float32)
    vec + vec is V

  UiFlag* = enum
    onlyVisual
    enabled
    hovered

  UiElement*[SizeVec: Vec2, PosVec: Vec3] = ref object of RootObj # refs allow closures to work
    size*, layoutSize*: SizeVec
    pos*, layoutPos*: PosVec
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
    leftClick
    rightClick

  UiInput* = object
    case kind*: UiInputKind
    of textInput:
      str*: string
    of leftClick, rightClick, nothing:
      discard

  UiState* {.explain.} = concept s
    s.action is UiAction
    s.currentElement is UiElement[auto, auto]
    s.input is UiInput
    s.inputPos is Vec2

proc onlyUiElems*(t: typedesc[tuple]): bool =
  var val: t
  for field in fields(val):
    when field is tuple:
      when not onlyUiElems(field):
        return false
    else:
      when field isnot UiElement[auto, auto]:
        return false
  true

type UiElements* = concept type Ui
  onlyUiElems(Ui)

template named*[S, P](ui: UiElement[S, P], name: untyped): untyped =
  ## Template to allow aliasing constructor for an ergonomic API
  let name = ui
  name

proc isOver[S, P](ui: UiElement[S, P], pos: Vec2): bool =
  pos.x in ui.layoutPos.x .. ui.layoutSize.x + ui.layoutPos.x and
  pos.y in ui.layoutPos.y .. ui.layoutSize.y + ui.layoutPos.y

proc usedSize*[S, P](ui: UiElement[S, P]): S = ui.size


proc layout*[S, P](ui: UiElement[S, P], parent: UiElement[S, P], offset, screenSize: P) =
  let offset =
    if parent != nil:
      parent.layoutPos + offset
    else:
      offset

  ui.layoutSize = ui.size

  if bottom in ui.anchor:
    ui.layoutPos.y = screenSize.y - ui.layoutSize.y - ui.pos.y + offset.y
  elif top in ui.anchor:
    ui.layoutPos.y = ui.pos.y + offset.y

  if right in ui.anchor:
    ui.layoutPos.x = screenSize.x - ui.layoutSize.x - ui.pos.x + offset.x

  elif left in ui.anchor:
    ui.layoutPos.x = ui.pos.x + offset.x


  if ui.anchor == {}:
    ui.layoutPos = ui.pos + offset


proc layout*[T: UiElements; Y: UiElement](ui: T, parent: Y, offset, screenSize: Vec3) =
  mixin layout
  for field in ui.fields:
    layout(field, parent, offset)

proc layout*[T: UiElements](ui: T, offset, screenSize: Vec3) =
  mixin layout
  for field in ui.fields:
    layout(field, default(typeof(field)), offset, screenSize)

proc interact*[S, P; Ui: UiElement[S, P]](ui: Ui, state: var UiState) =
  mixin onClick, onEnter, onHover, onExit, interactImpl
  if state.action == nothing:
    when compiles(onEnter(ui, state)):
      if isOver(ui, state.inputPos):
        onEnter(ui, state)
        state.action = overElement
        state.currentElement = ui
  if state.currentElement == ui:
    if isOver(ui, state.inputPos):
      if state.input.kind == leftClick:
        when compiles(onClick(ui, state)):
          onClick(ui, state)
          reset state.input  # Consume it
      when compiles(onHover(ui, state)):
        onHover(ui, state)
    else:
      when compiles(onExit(ui, state)):
        onExit(ui, state)
      when compiles(onEnter(ui, state)):
        state.action = nothing
        state.currentElement = nil

proc interact*[Ui: UiElements](ui: Ui, state: var UiState) =
  mixin interact
  for field in ui.fields:
    when compiles(interact(field, state)):
      interact(field, state)
    else:
      interact(UiElement[typeof(field.size), typeof(field.pos)](field), state)


proc upload*[Ui: UiElements; T](ui: Ui, state: UiState, target: var T) =
  mixin upload
  for field in ui.fields:
    upload(field, state, target)
