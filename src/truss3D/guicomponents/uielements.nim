import vmath, pixie, opengl
import ../../truss3D
import ../[textures, shaders, inputs, models, instancemodels]
import std/options

export vmath, textures, shaders, options, shaders, inputs, options, pixie, models, opengl, truss3D
type
  InteractDirection* = enum
    horizontal, vertical

  AnchorDirection* = enum
    left, right, top, bottom

  UiRenderObj* = object
    color*: Vec4
    foreground*: Texture
    background*: Texture
    matrix*: Mat4

  UiRenderInstance* = object
    shader: int
    instance: InstancedModel[UiRenderObj]

  UiRenderList* = object
    shaders: seq[Shader]
    instances: seq[UiRenderInstance]

  UiElement* = object of RootObj
    layoutPos*: IVec3
    layoutSize*: IVec2
    pos*: IVec3
    size*: IVec2
    color*: Vec4
    tex*: Texture
    anchor*: set[AnchorDirection]


  UiAction = enum
    nothing
    overElement
    interacted
    inputing

  UiState = object
    action: UiAction
    overElement: int
    currentId: int

proc onlyUiElems(t: tuple): bool =
  for x in fields(t):
    when x is tuple:
      if not onlyUiElems(x):
        return false
    else:
      if x isnot UiElement:
        return false
  true


type UiElements* = concept ui
  onlyUiElems(ui)

proc calculateAnchorMatrix*(ui: UiElement): Mat4 =
  let
    scrSize = screenSize()
    scale = vec2(ui.layoutSize.xy) * 2 / scrSize.vec2
  var pos = vec2(ui.layoutPos.xy) / scrSize.vec2
  pos.y *= -1
  translate(vec3(pos * 2 + vec2(-1, 1 - scale.y), float32 ui.pos.z)) * scale(vec3(scale, 0))


proc isOver(ui: UiElement, pos = getMousePos()): bool =
  pos.x in ui.layoutPos.x .. ui.layoutSize.x + ui.layoutPos.x and
  pos.y in ui.layoutPos.y .. ui.layoutSize.y + ui.layoutPos.y

proc onClick(ui: var UiElement, state: var UiState) = discard
proc onEnter(ui: var UiElement, state: var UiState) = discard
proc onHover(ui: var UiElement, state: var UiState) = discard
proc onExit(ui: var UiElement, state: var UiState) = discard


proc layouter(ui: var UiElement, parent: UiElement, hasParent: bool, offset: IVec2) =
  if hasParent:
    ui.layoutPos = ui.pos + parent.pos + ivec3(offset, 0)
    ui.layoutSize = ui.size
  else:
    ui.layoutPos = ui.pos + ivec3(offset, 0)
    ui.layoutSize = ui.size


proc layout*[T: UiElement](ui: var T, parent: UiElement, hasParent: bool, offset: IVec2) =
  mixin layouter
  layouter(ui, parent, hasParent, offset)


proc interact[T: UiElement](ui: T, ind: var int, state: var UiState) =
  mixin onClick, onEnter, onHover, onExit
  if state.action == nothing:
    if isOver(ui):
      onEnter(ui, state)
      state.action = overElement
      state.ind = ind
  elif state.ind == ind:
    if isOver(ui):
      if leftMb.isPressed:
        onClick(ui, state)
      onHover(ui, state)
    else:
      onExit(ui, state)
  inc ind

proc interact(ui: UiElements, ind: var int, state: var UiState) =
  for field in ui.fields:
    interact(ui, ind, state)

