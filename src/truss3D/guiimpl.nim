import vmath, pixie
import shaders, gui, textures, instancemodels, models
import gui/[layouts, buttons, sliders]
import ../truss3D
import std/[sugar, tables, hashes, strutils]

proc init(_: typedesc[Vec2], x, y: float32): Vec2 = vec2(x, y)
proc init(_: typedesc[Vec3], x, y, z: float32): Vec3 = vec3(x, y, z)


type
  UiRenderObj* = object
    color*: Vec4
    backgroundColor*: Vec4
    texture*: uint64
    hasTex*: uint32
    matrix* {.align: 16.}: Mat4

  RenderInstance = seq[UiRenderObj]

  UiRenderTarget* = object
    model: InstancedModel[RenderInstance]
    shader: Shader

  MyUiElement {.acyclic.} = ref object of UiElement[Vec2, Vec3]
    color: Vec4 = vec4(1, 1, 1, 1)
    backgroundColor: Vec4
    texture: Texture

  MyUiState = object
    action: UiAction
    currentElement: MyUiElement
    input: UiInput
    inputPos: Vec2

  HLayout[T] {.acyclic.} = HorizontalLayoutBase[MyUiElement, T]
  VLayout[T] {.acyclic.} = VerticalLayoutBase[MyUiElement, T]

  HSlider[T] {.acyclic.} = ref object of MyUiElement
    value: T
    rng: Slice[T]
    percentage: float32
    slideBar: MyUiElement
    onChange: proc(a: T)

  Label {.acyclic.} = ref object of MyUiElement
    text: string

  NamedSlider[T] {.acyclic.} = ref object of MyUiElement
    formatter: string
    name: Label
    slider: HSlider[T]

  Button {.acyclic.} = ref object of ButtonBase[MyUiElement]
    baseColor: Vec4
    hoveredColor: Vec4
    label: Label

  FontProps = object
    size: Vec2
    text: string
    font: Font

proc lerp(a, b: int, f: float32): int = int(mix(float32 a, float32 b, f))

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
    var
      tex = genTexture()
      image = newImage(int size.x, int size.y)
      font = defaultFont
    font.size = size.y
    var layout = font.layoutBounds(s)
    while layout.x > size.x or layout.y > size.y:
      font.size -= 1
      layout = font.layoutBounds(s)

    font.paint = rgb(255, 255, 255)
    image.fillText(font, s, bounds = size.vec2, hAlign = CenterAlign, vAlign = MiddleAlign)
    image.copyTo(tex)
    image = nil
    fontTextureCache[props] = tex
    tex

proc layout*(label: Label, parent: MyUiElement, offset, screenSize: Vec3) =
  MyUiElement(label).layout(parent, offset, screenSize)
  label.texture = makeTexture(label.text, label.size)

proc layout*(button: Button, parent: MyUiElement, offset, screenSize: Vec3) =
  ButtonBase[MyUiElement](button).layout(parent, offset, screenSize)
  if button.label != nil:
    button.label.pos = vec3(0, 0, button.pos.z - 0.1)
    button.label.size = button.size
    button.label.layout(button, vec3(0), screenSize)

proc upload[T](slider: HSlider[T], state: MyUiState, target: var UiRenderTarget) =
  MyUiElement(slider).upload(state, target)
  slider.slideBar.upload(state, target)

proc layout*[T](slider: HSlider[T], parent: MyUiElement, offset, screenSize: Vec3) =
  mixin layout
  MyUiElement(slider).layout(parent, offset, screenSize)
  if slider.slideBar.isNil:
    new slider.slideBar
    slider.slideBar.color = vec4(1, 0, 0, 1)
  slider.slideBar.pos = slider.pos - vec3(0, 0, 0.1)
  slider.slideBar.size.x = max(slider.percentage * slider.size.x, 0)
  slider.slideBar.size.y = slider.size.y
  slider.slideBar.layout(parent, offset, screenSize)

proc onEnter*[T](slider: HSlider[T], uiState: var UiState) = discard

proc onDrag*[T](slider: HSlider[T], uiState: var UiState) =
  mixin lerp
  slider.percentage = (uiState.inputPos.x - slider.layoutPos.x) / slider.size.x
  let newVal = lerp(slider.rng.a, slider.rng.b, slider.percentage)
  if slider.value != newVal:
    slider.value = newVal
    if slider.onChange != nil:
      slider.onChange(slider.value)

proc usedSize*[T](slider: NamedSlider[T]): Vec2 =
  result.x += slider.name.size.x + slider.slider.size.x
  result.y = max(slider.name.size.y, slider.slider.size.y)

proc layout*[T](slider: NamedSlider[T], parent: MyUiElement, offset, screenSize: Vec3) =
  slider.size = usedSize(slider)
  MyUiElement(slider).layout(parent, offset, screenSize)
  slider.name.layout(MyUiElement slider, vec3(0), screenSize)
  slider.slider.layout(slider, vec3(slider.name.layoutSize.x, 0, 0), screenSize)

proc upload[T](slider: NamedSlider[T], uiState: MyUiState, target: var UiRenderTarget) =
  slider.name.upload(uiState, target)
  slider.slider.upload(uiState, target)

proc interact*[T](slider: NamedSlider[T], uiState: var MyUiState) =
  let sliderStart = slider.slider.value
  interact(slider.slider, uiState)
  if slider.slider.value != sliderStart:
    slider.name.text = slider.formatter % $slider.slider.value

const vertShader = ShaderFile"""
#version 430
#extension GL_ARB_bindless_texture : require
layout(location = 0) in vec2 vertex_position;
layout(location = 2) in vec2 uv;

layout(std430) struct data{
  vec4 color;
  vec4 backgroundColor;
  sampler2D tex;
  uint hasTex;
  mat4 matrix;
};

layout(std430, binding = 0) buffer instanceData{
  data instData[];
};

out vec2 fUv;
out vec4 color;
flat out sampler2D tex;
flat out uint hasTex;

void main(){
  data theData = instData[gl_InstanceID];
  gl_Position = theData.matrix * vec4(vertex_position, 0, 1);
  fUv = uv;
  color = theData.color;
  hasTex = theData.hasTex;
  tex = theData.tex;
}
"""

const fragShader = ShaderFile"""
#version 430
#extension GL_ARB_bindless_texture : require

out vec4 frag_color;
in vec3 fNormal;
in vec4 color;
in vec2 fUv;

flat in sampler2D tex;
flat in uint hasTex;

void main() {
  if(hasTex > 0){
    frag_color = texture(tex, fUv) * color;
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
      if Gluint(ui.texture) > 0:
        uint64(ui.texture.getHandle())
      else:
        0u64

  target.model.push UiRenderObj(matrix: mat, color: ui.color, texture: tex, hasTex: uint32(tex))

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
  for y in 0..<8:
    let horz =  HLayout[Button](margin: 10)
    for x in 0..<4:
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
    grid,
    HSlider[int](pos: vec3(10, 10, 0), size: vec2(200, 25), rng: 0..10),
    NamedSlider[int](
      pos: vec3(10, 100, 0),
      anchor: {bottom, left},
      formatter: "Size: $#",
      name: Label(text: "Size: $#" % $test.size.x, size: vec2(100, 25)),
      slider: HSlider[int](
        rng: 100..400,
        size: vec2(100, 25),
        onChange: proc(i: int) =
          test.size.x = float32(i)
        )
      ),
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
  elif leftMb.isPressed:
    uiState.input = UiInput(kind: leftClick, isHeld: true)
  else:
    uiState.input = UiInput(kind: UiInputKind.nothing)
  uiState.inputPos = vec2 getMousePos()
  myUi.layout(vec3(0), vec3(vec2 screenSize(), 0))
  myUi.interact(uiState)

proc draw() =
  renderTarget.model.clear()
  myUi.upload(uiState, renderTarget)
  renderTarget.model.reuploadSsbo()
  with renderTarget.shader:
    glEnable(GlBlend)
    glBlendFunc(GlOne, GlOneMinusSrcAlpha)
    renderTarget.model.render()
    glDisable(GlBlend)


initTruss("Test Program", ivec2(1280, 720), guiimpl.init, guiimpl.update, guiimpl.draw)

