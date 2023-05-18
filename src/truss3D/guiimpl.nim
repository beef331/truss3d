import vmath
import shaders, gui, textures, instancemodels, models
import gui/[layouts, buttons]
import ../truss3D
import std/sugar

proc init(_: typedesc[Vec2], x, y: float32): Vec2 = vec2(x, y)
proc init(_: typedesc[Vec3], x, y, z: float32): Vec3 = vec3(x, y, z)


type
  UiRenderObj* = object
    color*: Vec4
    backgroundColor*: Vec4
    matrix* {.align: 16.}: Mat4

  RenderInstance = seq[UiRenderObj]

  UiRenderInstance* = object
    shader: int
    instance: InstancedModel[UiRenderObj]

  UiRenderList* = object # Should be faster than iterating a table?
    shaders: seq[Shader]
    instances: seq[UiRenderInstance]

  MyUiElement = ref object of UiElement[Vec2, Vec3]
    color: Vec4
    backgroundColor: Vec4

  HLayout[T] = HorizontalLayoutBase[MyUiElement, T]

  VLayout[T] = VerticalLayoutBase[MyUiElement, T]

  Label = ref object of MyUiElement
    texture: Texture

  Button = ref object of ButtonBase[MyUiElement]
    background: Texture
    baseColor: Vec4
    hoveredColor: Vec4
    label: Label

const vertShader = ShaderFile"""
#version 430
layout(location = 0) in vec2 vertex_position;
layout(location = 2) in vec2 uv;

layout(std430) struct data{
  vec4 color;
  vec4 backgroundColor;
  mat4 matrix;
};

layout(std430, binding = 0) buffer instanceData{
  data instData[];
};

out vec2 fUv;
out vec4 color;

void main(){
  data theData = instData[gl_InstanceID];
  gl_Position = theData.matrix * vec4(vertex_position, 0, 1);
  fUv = uv;
  color = theData.color;
}
"""

const fragShader = ShaderFile"""
#version 430

out vec4 frag_colour;
in vec3 fNormal;
in vec4 color;
in vec2 fUv;
uniform sampler2D tex;

void main() {
  frag_colour = color;
}

"""

proc onEnter(button: Button, uiState: var UiState[Vec2, Vec3]) =
  button.baseColor = button.color

proc onHover(button: Button, uiState: var UiState[Vec2, Vec3]) =
  button.flags.incl hovered
  button.color = button.hoveredColor

proc onExit(button: Button, uiState: var UiState[Vec2, Vec3]) =
  button.flags.excl hovered
  button.color = button.baseColor

proc upload[T;S;P;](horz: HLayout[T] or VLayout[T], state: UiState[S, P], target: var InstancedModel[RenderInstance]) =
  for child in horz.children:
    upload(child, state, target)

proc upload[S;P](ui: MyUiElement, state: UiState[S, P], target: var InstancedModel[RenderInstance]) =
  let
    scrSize = vec2 screenSize()
    size = ui.layoutSize * 2 / scrSize
  var pos = ui.layoutPos / vec3(scrSize, 1)
  pos.y *= -1
  pos.xy = pos.xy * 2f + vec2(-1f, 1f - size.y)

  let mat = translate(pos) * scale(vec3(size, 0))
  target.push UiRenderObj(matrix: mat, color: ui.color)


proc upload[S;P;](button: Button, state: UiState[S, P], target: var InstancedModel[RenderInstance]) =
  MyUiElement(button).upload(state, target)
  #button.label.upload(state, target)


var modelData: MeshData[Vec2]
modelData.appendVerts [vec2(0, 0), vec2(0, 1), vec2(1, 1), vec2(1, 0)].items
modelData.append [0u32, 1, 2, 0, 2, 3].items
modelData.appendUv [vec2(0, 1), vec2(0, 0), vec2(1, 0), vec2(1, 1)].items

proc defineGui(): auto =
  let grid = VLayout[HLayout[Button]](pos: vec3(10, 10, 0), margin: 10, anchor: {top, right})
  for y in 0..<3:
    let horz =  HLayout[Button](margin: 10)
    for x in 0..<3:
      capture x, y:
        horz.children.add:
          Button(
            color: vec4(1),
            hoveredColor: vec4(0.5, 0.5, 0.5, 1),
            clickCb: (proc() = echo x, " ", y),
            size: vec2(30, 30),
            label: Label(flags: {onlyVisual})
          )
    grid.children.add horz

  (
    Label(
      color: vec4(1),
      anchor: {top, left},
      pos: vec3(20, 20, 0),
      size: vec2(300, 200),
    ).named(test),
    Button(
      color: vec4(1),
      hoveredColor: vec4(0.5, 0.5, 0.5, 1),
      anchor: {bottom, right},
      pos: vec3(10, 10, 0),
      size: vec2(50, 50),
      label: Label(),
      clickCb: proc() =
        test.pos.x += 10
    ),
    HLayout[Button](
      pos: vec3(10, 10, 0),
      anchor: {bottom, left},
      margin: 10,
      children: @[
        Button(
          color: vec4(1, 0, 0, 1),
          hoveredColor: vec4(0.5, 0, 0, 1),
          clickCb: (proc() = echo "huh", 1),
          size: vec2(30, 30),
          label: Label()),
        Button(
          color: vec4(0, 1, 0, 1),
          hoveredColor: vec4(0, 0.5, 0, 1),
          clickCb: (proc() = echo "huh", 2),
          size: vec2(30, 30),
          label: Label()),
        Button(
          color: vec4(0, 0, 1, 1),
          hoveredColor: vec4(0, 0, 0.5, 1),
          clickCb: (proc() = echo "huh", 3),
          size: vec2(30, 30),
          label: Label())
      ]
    ),
    grid
  )

var
  guiModel: InstancedModel[RenderInstance]
  myUi: typeof(defineGui())
  uiState = UiState[Vec2, Vec3]()
  uiShader: Shader


proc init() =
  guiModel = uploadInstancedModel[RenderInstance](modelData)
  myUi = defineGui()
  myUi.layout(vec3(0), vec3(vec2 screenSize()))
  uiShader = loadShader(vertShader, fragShader)

proc update(dt: float32) =
  if leftMb.isDown:
    uiState.input = UiInput(kind: leftClick)
  else:
    uiState.input = UiInput(kind: UiInputKind.nothing)
  myUi.layout(vec3(0), vec3(vec2 screenSize(), 0))
  myUi.interact(uiState, vec2 getMousePos())

proc draw() =
  guiModel.clear()
  myUi.upload(uiState, guiModel)
  guiModel.reuploadSsbo()
  with uiShader:
    guiModel.render()


initTruss("Test Program", ivec2(1280, 720), guiimpl.init, guiimpl.update, guiimpl.draw)

