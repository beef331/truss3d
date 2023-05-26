import vmath, pixie, gooey
import shaders, textures, instancemodels, models
import gooey/[layouts, buttons, sliders, groups, dropdowns]
import ../truss3D
import std/[sugar, tables, hashes, strutils]

const guiVert* = ShaderFile"""
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

const guiFrag* = ShaderFile"""
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


proc init*(_: typedesc[Vec2], x, y: float32): Vec2 = vec2(x, y)
proc init*(_: typedesc[Vec3], x, y, z: float32): Vec3 = vec3(x, y, z)


type
  UiRenderObj* = object
    color*: Vec4
    backgroundColor*: Vec4
    texture*: uint64
    hasTex*: uint32
    matrix* {.align: 16.}: Mat4

  RenderInstance* = seq[UiRenderObj]

  UiRenderTarget* = object
    model*: InstancedModel[RenderInstance]
    shader*: Shader

  MyUiElement* {.acyclic.} = ref object of UiElement[Vec2, Vec3]
    color*: Vec4 = vec4(1, 1, 1, 1)
    backgroundColor*: Vec4
    texture*: Texture

  MyUiState* = object
    action*: UiAction
    currentElement*: MyUiElement
    input*: UiInput
    inputPos*: Vec2
    screenSize*: Vec2
    scaling*: float32

  HLayout*[T] = ref object of HorizontalLayoutBase[MyUiElement, T] # Need atleast Nim '28a116a47701462a5f22e0fa496a91daff2c1816' for this inheritance
  VLayout*[T] = ref object of VerticalLayoutBase[MyUiElement, T]
  HGroup*[T] = ref object of HorizontalGroupBase[MyUiElement, T]
  VGroup*[T] = ref object of VerticalGroupBase[MyUiElement, T]

  HSlider*[T] {.acyclic.} = ref object of HorizontalSliderBase[MyUiElement, T]
    slideBar*: MyUiElement
    hoveredColor*: Vec4
    baseColor*: Vec4

  Label* {.acyclic.} = ref object of MyUiElement
    text*: string

  NamedSlider*[T] {.acyclic.} = ref object of MyUiElement
    formatter*: string
    name*: Label
    slider*: HSlider[T]

  Button* {.acyclic.} = ref object of ButtonBase[MyUiElement]
    baseColor*: Vec4
    hoveredColor*: Vec4
    label*: Label

  DropDown*[T] = ref object of DropDownBase[MyUiElement, Button, T]

  FontProps = object
    size: Vec2
    text: string

proc `==`(a, b: Texture): bool = Gluint(a) == Gluint(b)
proc hash(a: Texture): Hash = hash(Gluint(a))

proc upload*(ui: MyUiElement, state: MyUiState, target: var UiRenderTarget) =
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


var
  fontPath*: string
  fontTextureCache: Table[FontProps, Texture]
  guiTexRc: Table[Texture, int]
  defaultFont: Font

proc makeTexture*(s: string, size: Vec2): Texture =
  if defaultFont.isNil:
    defaultFont = readFont(fontPath)

  let props = FontProps(size: size, text: s)
  if props in fontTextureCache:
    fontTextureCache[props]
  else:
    var
      tex = genTexture()
      image = newImage(int size.x, int size.y)
      font = defaultFont
    font.size = size.y
    var layout = font.layoutBounds(s)
    while layout.x - 1 > size.x or layout.y - 1 > size.y:
      font.size -= 1
      layout = font.layoutBounds(s)

    font.paint = rgb(255, 255, 255)
    image.fillText(font, s, bounds = size.vec2, hAlign = CenterAlign, vAlign = MiddleAlign)
    image.copyTo(tex)
    image = nil
    fontTextureCache[props] = tex
    guiTexRc[tex] = 0
    tex

proc layout*(label: Label, parent: MyUiElement, offset: Vec3, state: MyUiState) =
  MyUiElement(label).layout(parent, offset, state)
  var orig = label.texture
  label.texture = makeTexture(label.text, label.size)
  if int(orig) != int(label.texture):
    if int(orig) != 0:
      dec guiTexRc[orig]
      if guiTexRc[orig] <= 0:
        guiTexRc.del(orig)
        for x, y in fontTextureCache:
          if y == orig:
            fontTextureCache.del(x)
            break
        orig.delete()
    inc guiTexRc[label.texture]

# Named Slider code

proc usedSize*[T](slider: NamedSlider[T]): Vec2 =
  result.x += slider.name.size.x + slider.slider.size.x
  result.y = max(slider.name.size.y, slider.slider.size.y)

proc layout*[T](slider: NamedSlider[T], parent: MyUiElement, offset: Vec3, state: MyUiState) =
  slider.size = usedSize(slider)
  MyUiElement(slider).layout(parent, offset, state)
  slider.name.layout(MyUiElement slider, vec3(0), state)
  slider.slider.layout(slider, vec3(slider.name.layoutSize.x, 0, 0), state)

proc upload*[T](slider: NamedSlider[T], uiState: MyUiState, target: var UiRenderTarget) =
  slider.name.upload(uiState, target)
  slider.slider.upload(uiState, target)

proc interact*[T](slider: NamedSlider[T], uiState: var MyUiState) =
  let sliderStart = slider.slider.value
  interact(slider.slider, uiState)
  if slider.slider.value != sliderStart:
    slider.name.text = slider.formatter % $slider.slider.value

# Layout/Group Code

proc layout*[T](layout: HLayout[T] or VLayout[T], parent: MyUiElement, offset: Vec3, uiState: MyUiState) =
  layouts.layout(layout, parent, offset, uiState)

proc layout*[T](layout: HGroup[T] or VGroup[T], parent: MyUiElement, offset: Vec3, uiState: MyUiState) =
  groups.layout(layout, parent, offset, uiState)

proc interact*[T](layout: HLayout[T] or VLayout[T], uiState: var MyUiState) =
  layouts.interact(layout, uiState)

proc interact*[T](group: HGroup[T] or VGroup[T], uiState: var MyUiState) =
  groups.interact(group, uiState)

proc upload*[T](layout: HLayout[T] or VLayout[T], state: MyUiState, target: var UiRenderTarget) =
  # Due to generic dispatch these intermediate calls are requied
  layouts.upload(layout, state, target)

proc upload*[T](group: HGroup[T] or VGroup[T], state: MyUiState, target: var UiRenderTarget) =
  # Due to generic dispatch these intermediate calls are requied
  groups.upload(group, state, target)

# Slider Code
proc upload*[T](slider: HSlider[T], state: MyUiState, target: var UiRenderTarget) =
  MyUiElement(slider).upload(state, target)
  slider.slideBar.upload(state, target)

proc layout*[T](slider: HSlider[T], parent: MyUiElement, offset: Vec3, state: MyUiState) =
  mixin layout
  MyUiElement(slider).layout(parent, offset, state)
  if slider.slideBar.isNil:
    new slider.slideBar
    slider.slideBar.color = vec4(1, 0, 0, 1)
  slider.slideBar.pos = slider.pos - vec3(0, 0, 0.1)
  slider.slideBar.size.x = max(slider.percentage * slider.size.x, 0)
  slider.slideBar.size.y = slider.size.y
  slider.slideBar.layout(parent, offset, state)

proc onEnter*[T](slider: HSlider[T], uiState: var MyUiState) =
  slider.baseColor = slider.color

proc onHover*[T](slider: HSlider[T], uiState: var MyUiState) =
  slider.flags.incl hovered
  slider.color = slider.hoveredColor

proc onExit*[T](slider: HSlider[T], uiState: var MyUiState) =
  slider.flags.excl hovered
  slider.color = slider.baseColor

proc onDrag*[T](slider: HSlider[T], uiState: var MyUiState) =
  sliders.onDrag(slider, uiState)

# Button Code

proc upload*(button: Button, state: MyUiState, target: var UiRenderTarget) =
  MyUiElement(button).upload(state, target)
  if button.label != nil:
    button.label.upload(state, target)

proc layout*(button: Button, parent: MyUiElement, offset: Vec3, state: MyUiState) =
  ButtonBase[MyUiElement](button).layout(parent, offset, state)
  if button.label != nil:
    button.label.pos = vec3(0, 0, button.pos.z - 0.1)
    button.label.size = button.size
    button.label.layout(button, vec3(0), state)

proc onClick*(button: Button, uiState: var MyUiState) =
  buttons.onClick(button, uiState)

proc onEnter*(button: Button, uiState: var MyUiState) =
  button.baseColor = button.color

proc onHover*(button: Button, uiState: var MyUiState) =
  button.flags.incl hovered
  button.color = button.hoveredColor

proc onExit*(button: Button, uiState: var MyUiState) =
  button.flags.excl hovered
  button.color = button.baseColor

# Dropdowns

proc layout*[T](dropDown: DropDown[T], parent: MyUiElement, offset: Vec3, uiState: MyUiState) =
  if dropDown.buttons[T.low].isNil:
    for ind, button in dropDown.buttons.mpairs:
      button = Button(size: dropDown.size, label: Label(text: $ind))
  dropdowns.layout(dropDown, parent, offset, uiState)

proc interact*[T](dropDown: DropDown[T], uiState: var MyUiState) =
  dropdowns.interact(dropDown, uiState)

proc upload*[T](dropDown: DropDown[T], state: MyUiState, target: var UiRenderTarget) =
  # Due to generic dispatch these intermediate calls are requied
  dropdowns.upload(dropDown, state, target)
