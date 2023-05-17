import vmath
import shaders, gui, textures, instancemodels

proc init(_: typedesc[Vec2], x, y: float32): Vec2 = vec2(x, y)
proc init(_: typedesc[Vec3], x, y, z: float32): Vec3 = vec3(x, y, z)


type
  UiRenderObj* = object
    foreground*: Texture
    background*: Texture
    nineSliceSize* {.align(16).}: float32
    color*: Vec4
    backgroundColor*: Vec4
    matrix* {.align(16).}: Mat4


  UiRenderInstance* = object
    shader: int
    instance: InstancedModel[UiRenderObj]

  UiRenderList* = object # Should be faster than iterating a table?
    shaders: seq[Shader]
    instances: seq[UiRenderInstance]

  MyUiElement = UiElement[Vec2, Vec3]

  Label = ref object of MyUiElement
    texture: Texture

  Button = ref object of MyUiElement
    background: Texture
    label: Label
    clickCb: proc()


proc onClick(button: Button, uiState: var UiState) =
  button.clickCb()

var myUi =(
  Label(
    anchor: {top, left},
    pos: vec3(10, 10, 0),
    size: vec2(100, 200)
  ),
  Button(
    flags: {interactable},
    anchor: {top, left},
    size: vec2(300, 400),
    label: Label(
      size: vec2(300, 400)
    ),
    clickCb: proc() = echo "hello"
  )
)

myUi.layout(MyUiElement(), false, vec3(0))

var
  uiState = UiState(input: UIInput(kind: leftClick))
  ind = -1
myUi.interact(ind, uiState, vec2(0, 0))
echo uiState

