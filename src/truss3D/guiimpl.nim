import vmath
import shaders, gui, textures, instancemodels, models
import ../truss3D
import std/sugar

proc init(_: typedesc[Vec2], x, y: float32): Vec2 = vec2(x, y)
proc init(_: typedesc[Vec3], x, y, z: float32): Vec3 = vec3(x, y, z)


type
  UiRenderObj* = object
    #foreground*: Texture
    #background*: Texture
    #nineSliceSize* {.align(16).}: float32
    #color*: Vec4
    #backgroundColor*: Vec4
    matrix* {.align: 16.}: Mat4

  RenderInstance = seq[UiRenderObj]

  UiRenderInstance* = object
    shader: int
    instance: InstancedModel[UiRenderObj]

  UiRenderList* = object # Should be faster than iterating a table?
    shaders: seq[Shader]
    instances: seq[UiRenderInstance]

  MyUiElement = UiElement[Vec2, Vec3]

  HorizontalLayout[T] = ref object of MyUiElement # Probably can be in own module and can take [S, P, T]?
    children: seq[T]
    margin: float32
    rightToLeft: bool

  VerticalLayout[T] = ref object of MyUiElement # Probably can be in own module and can take [S, P, T]?
    children: seq[T]
    margin: float32
    bottomToTop: bool

  Label = ref object of MyUiElement
    texture: Texture

  Button = ref object of MyUiElement
    background: Texture
    label: Label
    clickCb: proc()


proc layout[T](horiz: HorizontalLayout[T], parent: MyUiElement, offset: Vec3) =
  MyUiElement(horiz).layout(parent, offset)
  var offset = vec3(0)
  for child in horiz.children:
    child.layout(horiz, offset)
    offset.x += horiz.margin + child.layoutSize.x


proc layout[T](vert: VerticalLayout[T], parent: MyUiElement, offset: Vec3) =
  MyUiElement(vert).layout(parent, offset)
  var offset = vec3(0)
  for child in vert.children:
    child.layout(vert, offset)
    offset.y += vert.margin + child.layoutSize.y

proc interactImpl*[S, P; T: HorizontalLayout or VerticalLayout](ui: T, state: var UiState[S, P], inputPos: Vec2) =
  for x in ui.children:
    interact(x, state, inputPos)

proc layout(button: Button, parent: MyUiElement, offset: Vec3) =
  MyUiElement(button).layout(parent, offset)
  button.label.layout(button, vec3(0))


const vertShader = ShaderFile"""
#version 430
layout(location = 0) in vec2 vertex_position;
layout(location = 2) in vec2 uv;

layout(std430) struct data{
//  sampler2D foregroundTex;
//  sampler2D backgroundTex;
//  float nineSliceSize;
//  vec4 color;
//  vec4 backgroundColor;
  mat4 matrix;
};

layout(std430, binding = 0) buffer instanceData{
  data instData[];
};

out vec2 fUv;

void main(){
  data theData = instData[gl_InstanceID];
  gl_Position = theData.matrix * vec4(vertex_position, 0, 1);
  fUv = uv;
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
  frag_colour = vec4(1);
}

"""

proc onClick(button: Button, uiState: var UiState) =
  button.clickCb()

proc upload[T;S;P;](horz: HorizontalLayout[T] or VerticalLayout[T], state: UiState[S, P], target: var InstancedModel[RenderInstance]) =
  for child in horz.children:
    upload(child, state, target)

proc upload[S;P;](button: Button, state: UiState[S, P], target: var InstancedModel[RenderInstance]) =
  MyUiElement(button).upload(state, target)
  button.label.upload(state, target)

proc upload[S;P](ui: MyUiElement, state: UiState[S, P], target: var InstancedModel[RenderInstance]) =
  let
    scrSize = vec2 screenSize()
    size = ui.layoutSize * 2 / scrSize
  var pos = ui.layoutPos / vec3(scrSize, 1)
  pos.y *= -1
  pos.xy = pos.xy * 2f + vec2(-1f, 1f - size.y)

  let mat = translate(pos) * scale(vec3(size, 0))
  target.push UiRenderObj(matrix: mat)

var modelData: MeshData[Vec2]
modelData.appendVerts [vec2(0, 0), vec2(0, 1), vec2(1, 1), vec2(1, 0)].items
modelData.append [0u32, 1, 2, 0, 2, 3].items
modelData.appendUv [vec2(0, 1), vec2(0, 0), vec2(1, 0), vec2(1, 1)].items

proc defineGui(): auto =
  let grid = VerticalLayout[HorizontalLayout[Button]](pos: vec3(700, 50, 0), margin: 10)
  for y in 0..<3:
    let horz =  HorizontalLayout[Button](margin: 10, size: vec2(0, 30))
    for x in 0..<3:
      capture x, y:
        horz.children.add:
          Button(
            clickCb: (proc() = echo x, " ", y),
            size: vec2(30, 30),
            label: Label(flags: {onlyVisual})
          )
    grid.children.add horz

  (
    Label(
      anchor: {top, left},
      pos: vec3(50, 50, 0),
      size: vec2(300, 200),
      flags: {onlyVisual}
    ).named(test),
    Button(
      anchor: {top, left},
      size: vec2(100, 100),
      pos: vec3(1180, 620, 0),
      label: Label(
        flags: {onlyVisual},
        size: vec2(300, 400)
      ),
      clickCb: proc() =
        echo test.pos
    ),
    HorizontalLayout[Button](
      pos: vec3(300, 500, 0),
      margin: 10,
      flags: {onlyVisual},
      children: @[
        Button(
          clickCb: (proc() = echo "huh", 1),
          size: vec2(30, 30),
          label: Label(flags: {onlyVisual})),
        Button(
          clickCb: (proc() = echo "huh", 2),
          size: vec2(30, 30),
          label: Label(flags: {onlyVisual})),
        Button(
          clickCb: (proc() = echo "huh", 3),
          size: vec2(30, 30),
          label: Label(flags: {onlyVisual}))
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
  myUi.layout(vec3(0))
  uiShader = loadShader(vertShader, fragShader)

proc update(dt: float32) =
  if leftMb.isPressed:
    uiState.input = UiInput(kind: leftClick)
  else:
    uiState.input = UiInput(kind: UiInputKind.nothing)
  myUi.interact(uiState, vec2 getMousePos())

proc draw() =
  guiModel.clear()
  myUi.upload(uiState, guiModel)
  guiModel.reuploadSsbo()
  with uiShader:
    guiModel.render()


initTruss("Test Program", ivec2(1280, 720), guiimpl.init, guiimpl.update, guiimpl.draw)

