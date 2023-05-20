import vmath, pixie
import shaders, gui, textures, instancemodels, models
import gui/[layouts, buttons]
import ../truss3D
import std/[sugar, tables, hashes, strutils]

proc init(_: typedesc[Vec2], x, y: float32): Vec2 = vec2(x, y)
proc init(_: typedesc[Vec3], x, y, z: float32): Vec3 = vec3(x, y, z)


type
  UiRenderObj* = object
    color*: Vec4
    backgroundColor*: Vec4
    texture*: uint32
    matrix* {.align: 16.}: Mat4

  RenderInstance = seq[UiRenderObj]

  UiRenderTarget* = object
    model: InstancedModel[RenderInstance]
    loadedTextures: Table[Texture, uint64]
    shader: Shader

  MyUiElement = ref object of UiElement[Vec2, Vec3]
    color: Vec4 = vec4(1, 1, 1, 1)
    backgroundColor: Vec4
    texture: Texture

  MyUiState = object
    action: UiAction
    currentElement: MyUiElement
    input: UiInput

  HLayout[T] = HorizontalLayoutBase[MyUiElement, T]

  VLayout[T] = VerticalLayoutBase[MyUiElement, T]

  Label = ref object of MyUiElement
    text: string

  Button = ref object of ButtonBase[MyUiElement]
    baseColor: Vec4
    hoveredColor: Vec4
    label: Label

  FontProps= object
    size: Vec2
    text: string
    font: Font

proc `==`(a, b: Texture): bool = Gluint(a) == Gluint(b)
proc hash(a: Texture): Hash = hash(Gluint(a))

proc hash(f: Font): Hash = cast[Hash](f)

var
  fontTextureCache: Table[FontProps, Texture]
  defaultFont = readFont"assets/fonts/MarradaRegular-Yj0O.ttf"
  fontCache: Table[string, Font] = {"MarradaRegular": defaultFont}.toTable

proc makeTexture(s: string, size: Vec2): Texture =
  let props = FontProps(size: size, text: s, font: defaultFont)
  if props in fontTextureCache:
    fontTextureCache[props]
  else:
    let
      tex = genTexture()
      image = newImage(int size.x, int size.y)
      font = defaultFont
    font.size = size.y
    var layout = font.layoutBounds(s)
    while layout.x > size.x or layout.y> size.y:
      font.size -= 1
      layout = font.layoutBounds(s)

    font.paint = rgb(255, 255, 255)
    image.fillText(font, s, bounds = size.vec2, hAlign = CenterAlign, vAlign = MiddleAlign)
    image.copyTo(tex)
    fontTextureCache[props] = tex
    tex

proc layout*(label: Label, parent: MyUiElement, offset, screenSize: Vec3) =
  MyUiElement(label).layout(parent, offset, screenSize)
  label.texture = makeTexture(label.text, label.size)

proc layout*(button: Button, parent: MyUiElement, offset, screenSize: Vec3) =
  ButtonBase[MyUiElement](button).layout(parent, offset, screenSize)
  if button.label != nil:
    button.label.pos = vec3(0, 0, button.pos.z + 0.1)
    button.label.size = button.size
    button.label.layout(button, vec3(0), screenSize)

const vertShader = ShaderFile"""
#version 430
layout(location = 0) in vec2 vertex_position;
layout(location = 2) in vec2 uv;

layout(std430) struct data{
  vec4 color;
  vec4 backgroundColor;
  uint texId;
  mat4 matrix;
};

layout(std430, binding = 0) buffer instanceData{
  data instData[];
};

out vec2 fUv;
out vec4 color;
flat out uint texId;

void main(){
  data theData = instData[gl_InstanceID];
  gl_Position = theData.matrix * vec4(vertex_position, 0, 1);
  fUv = uv;
  color = theData.color;
  texId = theData.texId;
}
"""

const fragShader = ShaderFile"""
#version 430

out vec4 frag_color;
in vec3 fNormal;
in vec4 color;
in vec2 fUv;
flat in uint texId;

uniform sampler2D textures[32];

void main() {
  if(texId > 0){
    frag_color = texture(textures[texId - 1], fUv) * color;
  }else{
    frag_color = color;
  }
}

"""

proc onEnter(button: Button, uiState: var MyUiState) =
  button.baseColor = button.color

proc onHover(button: Button, uiState: var MyUiState) =
  button.flags.incl hovered
  button.color = button.hoveredColor

proc onExit(button: Button, uiState: var MyUiState) =
  button.flags.excl hovered
  button.color = button.baseColor

proc upload[T](layout: HLayout[T] or VLayout[T], state: MyUiState, target: var UiRenderTarget) =
  # This should not be required, why it's not calling the exact version is beyond me
  layouts.upload(layout, state, target)

proc upload(ui: MyUiElement, state: MyUiState, target: var UiRenderTarget) =
  let
    scrSize = vec2 screenSize()
    size = ui.layoutSize * 2 / scrSize
  var pos = ui.layoutPos / vec3(scrSize, 1)
  pos.y *= -1
  pos.xy = pos.xy * 2f + vec2(-1f, 1f - size.y)

  let
    mat = translate(pos) * scale(vec3(size, 0))
    tex =
      if ui.texture in target.loadedTextures:
        target.loadedTextures[ui.texture]
      elif Gluint(ui.texture) > 0:
        let val = uint64(target.loadedTextures.len + 1)
        target.loadedTextures[ui.texture] = val
        target.shader.setUniform("textures[$#]" % $(val - 1), ui.texture)
        val
      else:
        0

  target.model.push UiRenderObj(matrix: mat, color: ui.color, texture: uint32 tex)

proc upload(button: Button, state: MyUiState, target: var UiRenderTarget) =
  MyUiElement(button).upload(state, target)
  if button.label != nil:
    button.label.upload(state, target)


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
            size: vec2(40, 40),
            label: Label(color: vec4(0, 0, 0, 1), text: "$#, $#" % [$(x + 1), $(y + 1)])
          )
    grid.children.add horz

  (
    Label(
      color: vec4(1),
      anchor: {top, left},
      pos: vec3(20, 20, 0),
      size: vec2(300, 200),
      text: "This is a Label!!!"
    ).named(test),
    Button(
      color: vec4(1),
      hoveredColor: vec4(0.5, 0.5, 0.5, 1),
      anchor: {bottom, right},
      pos: vec3(10, 10, 0),
      size: vec2(50, 50),
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
          size: vec2(60, 30),
          label: Label(text: "Red")
        ),
        Button(
          color: vec4(0, 1, 0, 1),
          hoveredColor: vec4(0, 0.5, 0, 1),
          clickCb: (proc() = echo "huh", 2),
          size: vec2(60, 30),
          label: Label(text: "Blue")
        ),
        Button(
          color: vec4(0, 0, 1, 1),
          hoveredColor: vec4(0, 0, 0.5, 1),
          clickCb: (proc() = echo "huh", 3),
          size: vec2(60, 30),
          label: Label(text: "Green")
        )
      ]
    ),
    grid
  )

var
  renderTarget: UiRenderTarget
  myUi: typeof(defineGui())
  uiState = MyUiState()


proc init() =
  renderTarget.model = uploadInstancedModel[RenderInstance](modelData)
  myUi = defineGui()
  myUi.layout(vec3(0), vec3(vec2 screenSize()))
  renderTarget.shader = loadShader(vertShader, fragShader)

proc update(dt: float32) =
  if leftMb.isDown:
    uiState.input = UiInput(kind: leftClick)
  else:
    uiState.input = UiInput(kind: UiInputKind.nothing)
  myUi.layout(vec3(0), vec3(vec2 screenSize(), 0))
  myUi.interact(uiState, vec2 getMousePos())

proc draw() =
  renderTarget.model.clear()
  renderTarget.loadedTextures.clear()
  myUi.upload(uiState, renderTarget)
  renderTarget.model.reuploadSsbo()
  with renderTarget.shader:
    glEnable(GlBlend)
    glBlendFunc(GlOne, GlOneMinusSrcAlpha)
    renderTarget.model.render()
    glDisable(GlBlend)


initTruss("Test Program", ivec2(1280, 720), guiimpl.init, guiimpl.update, guiimpl.draw)

