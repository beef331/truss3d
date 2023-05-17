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

  UiFlag = enum
    interactable
    enabled


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
    textInput
    leftClick
    rightClick

  UiInput* = object
    case kind*: UiInputKind
    of textInput:
      str*: string
    of leftClick, rightClick:
      discard

  UiState* = object
    action*: UiAction
    overElement*: int
    currentId*: int
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

type UiElements* = concept ui, type UI
  onlyUiElems(Ui)


proc isOver[S, P](ui: UiElement[S, P], pos: Vec2): bool =
  pos.x in ui.layoutPos.x .. ui.layoutSize.x + ui.layoutPos.x and
  pos.y in ui.layoutPos.y .. ui.layoutSize.y + ui.layoutPos.y

proc layouter[S, P](ui: UiElement[S, P], parent: UiElement[S, P], hasParent: bool, offset: P) =
  if hasParent:
    ui.layoutPos = ui.pos + parent.pos + offset
    ui.layoutSize = ui.size
  else:
    ui.layoutPos = ui.pos + offset
    ui.layoutSize = ui.size


proc layout*[S, P](ui: UIElement[S, P], parent: UiElement[S, P], hasParent: bool, offset: P) =
  mixin layouter
  layouter(ui, parent, hasParent, offset)

proc layout*[T: UiElements; Y: UiElement](ui: T, parent: Y, hasParent: bool, offset: Y.PosVec) =
  mixin layouter
  for field in ui.fields:
    layouter(field, default(Y), false, offset)


proc onClick[S, P](ui: UiElement[S, P], state: var UiState) = discard
proc onEnter[S, P](ui: UiElement[S, P], state: var UiState) = discard
proc onHover[S, P](ui: UiElement[S, P], state: var UiState) = discard
proc onExit[S, P](ui: UiElement[S, P], state: var UiState) = discard

proc interacter*(ui: auto, ind: var int, state: var UiState, inputPos: Vec2) =
  mixin onClick, onEnter, onHover, onExit
  if interactable in ui.flags:
    if state.action == nothing:
      if isOver(ui, inputPos):
        onEnter(ui, state)
        state.action = overElement
        state.currentId = ind
    if state.currentId == ind:
      if isOver(ui, inputPos):
        if state.input.kind == leftClick:
          onClick(ui, state)
        onHover(ui, state)
      else:
        onExit(ui, state)
        state.action = nothing
  inc ind

proc interact*[T: UiElements](ui: T, ind: var int, state: var UiState, inputPos: Vec2) =
  mixin interacter
  for field in ui.fields:
    interacter(field, ind, state, inputPos)

proc upload*[T](ui: UiElements, ind: var int, state: var UiState, target: T) =
  for field in ui.fields:
    upload(field, ind, state, target)
