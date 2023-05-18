import std/typetraits
import oopsie

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

  UiState*[SizeVec: Vec2, PosVec: Vec3] = object
    action*: UiAction
    currentElement*: UiElement[SizeVec, PosVec]
    input*: UiInput

proc onlyUiElems*(t: typedesc[tuple]): bool =
  var val: t
  for field in fields(val):
    when field is tuple:
      when not onlyUiElems(field):
        return false
    else:
      when rootSuper(field) isnot UiElement:
        return false
  true

type UiElements* = (tuple)

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

proc onClick[S, P](ui: UiElement[S, P], state: var UiState[S, P]) = discard
proc onEnter[S, P](ui: UiElement[S, P], state: var UiState[S, P]) = discard
proc onHover[S, P](ui: UiElement[S, P], state: var UiState[S, P]) = discard
proc onExit[S, P](ui: UiElement[S, P], state: var UiState[S, P]) = discard

proc interact*[S, P; Ui: UiElement[S, P]](ui: Ui, state: var UiState[S, P], inputPos: S) =
  mixin onClick, onEnter, onHover, onExit, interactImpl
  if state.action == nothing:
    if isOver(ui, inputPos):
      onEnter(ui, state)
      state.action = overElement
      state.currentElement = ui
  if state.currentElement == ui:
    if isOver(ui, inputPos):
      if state.input.kind == leftClick:
        onClick(ui, state)
        reset state.input  # Consume it
      onHover(ui, state)
    else:
      onExit(ui, state)
      state.action = nothing
      state.currentElement = nil

proc interact*[S; P; Ui: UiElements](ui: Ui, state: var UiState[S, P], inputPos: S) =
  mixin interact
  for field in ui.fields:
    when compiles(interact(field, state, inputPos)):
      interact(field, state, inputPos)
    else:
      interact(UiElement[S, P](field), state, inputPos)


proc upload*[S; P; T; Ui: UiElements](ui: Ui, state: UiState[S, P], target: var T) =
  mixin upload
  for field in ui.fields:
    upload(field, state, target)
