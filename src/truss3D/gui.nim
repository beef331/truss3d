import vmath, pixie, gooey
import shaders, textures, instancemodels, models, fontatlaser
import gooey/[layouts, buttons, sliders, groups, dropdowns, textinputs]
import ../truss3D
import std/[sugar, tables, hashes, strutils]

const guiVert* = ShaderFile"""
#version 430
layout(location = 0) in vec2 vertex_position;
layout(location = 2) in vec2 uv;

layout(std430) struct data{
  vec4 color;
  vec4 backgroundColor;
  uint fontIndex;
  mat4 matrix;
};

layout(std430, binding = 0) buffer instanceData{
  data instData[];
};

out vec2 fUv;
out vec4 color;
flat out uint fontIndex;

void main(){
  data theData = instData[gl_InstanceID];
  gl_Position = theData.matrix * vec4(vertex_position, 0, 1);
  fUv = uv;
  color = theData.color;
  fontIndex = theData.fontIndex;
}
"""

const guiFrag* = ShaderFile"""
#version 430

out vec4 frag_color;
in vec3 fNormal;
in vec4 color;
in vec2 fUv;

uniform sampler2D fontTex;

layout(std430, binding = 1) buffer theFontData{
  vec4 fontData[];
};

flat in uint fontIndex;

void main() {
  if(fontIndex != 0){
    vec2 offset = fontData[fontIndex - 1].xy;
    vec2 size = fontData[fontIndex - 1].zw;
    vec2 texSize = vec2(textureSize(fontTex, 0));
    frag_color = texture(fontTex, offset / texSize + fUv * (size / texSize)) * color;
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
    fontIndex*: uint32
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
    interactedWithCurrentElement*: bool

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
    arrangement: Arrangement
    fontSize: float32

  NamedSlider*[T] {.acyclic.} = ref object of MyUiElement
    formatter*: string
    name*: Label
    slider*: HSlider[T]

  Button* {.acyclic.} = ref object of ButtonBase[MyUiElement]
    baseColor*: Vec4
    hoveredColor*: Vec4
    label*: Label

  DropDown*[T] = ref object of DropDownBase[MyUiElement, Button, T]
    hoveredColor*: Vec4

  TextInput* = ref object of TextInputBase[MyUiElement]
    internalLabel*: Label

  FontProps = object
    size: Vec2
    text: string

proc `==`(a, b: Texture): bool = Gluint(a) == Gluint(b)
proc hash(a: Texture): Hash = hash(Gluint(a))

proc upload*(ui: MyUiElement, state: MyUiState, target: var UiRenderTarget) =
  let
    scrSize = state.screenSize
    size = ui.layoutSize * 2 / scrSize
  var pos = ui.layoutPos / vec3(scrSize, 1)
  pos.y *= -1
  pos.xy = pos.xy * 2f + vec2(-1f, 1f - size.y)

  let
    mat = translate(pos) * scale(vec3(size, 0))
  if ui.backgroundColor != vec4(0):
    target.model.push UiRenderObj(matrix: mat * translate(vec3(0, 0, -0.1)), color: ui.backgroundColor)
  if ui.color != vec4(0):
    target.model.push UiRenderObj(matrix: mat, color: ui.color)


var
  fontPath*: string
  defaultFont: Font
  atlas*: FontAtlas

proc arrange*(label: Label) =
  if defaultFont.isNil:
    defaultFont = readFont(fontPath)
    defaultFont.size = 64
    atlas = FontAtlas(width: 1024, height: 1024, font: defaultFont)
  let startSize = defaultFont.size
  var layout = defaultFont.layoutBounds(label.text)
  while layout.x > label.layoutSize.x or layout.y > label.layoutSize.y:
    defaultFont.size -= 1
    layout = defaultFont.layoutBounds(label.text)
  label.fontSize = defaultFont.size
  label.arrangement = defaultFont.typeset(label.text, label.layoutSize, hAlign = CenterAlign, vAlign = MiddleAlign)
  defaultFont.size = startSize
  
proc layout*(label: Label, parent: MyUiElement, offset: Vec3, state: MyUiState) =
  MyUiElement(label).layout(parent, offset, state)
  label.arrange()

proc upload*(label: Label, state: MyUiState, target: var UiRenderTarget) =
  if label.text.len > 0 and label.arrangement != nil:
    let
      scrSize = state.screenSize
      parentPos = label.layoutPos
      scale = label.fontSize /  defaultFont.size

    for i, rune in label.arrangement.runes:
      let fontEntry = atlas.runeEntry(rune)

      if fontEntry.id > 0:
        let
          rect = label.arrangement.selectionRects[i]
          offset = vec2(rect.x, rect.y)
          size = rect.wh * 2 / scrSize

        var pos = parentPos / vec3(scrSize, 1) + vec3(offset, 0) / vec3(scrSize, 1)
        pos.y *= -1
        pos.xy = pos.xy * 2f + vec2(-1f, 1f - size.y)
        target.model.push UiRenderObj(matrix: translate(pos) * scale(vec3(size, 0)), color: label.color, fontIndex: uint32 fontEntry.id)

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
  MyUiElement(group).upload(state, target)
  groups.upload(group, state, target)

# Slider Code
proc upload*[T](slider: HSlider[T], state: MyUiState, target: var UiRenderTarget) =
  MyUiElement(slider).upload(state, target)
  slider.slideBar.upload(state, target)

proc layout*[T](slider: HSlider[T], parent: MyUiElement, offset: Vec3, state: MyUiState) =
  mixin layout
  sliders.layout(slider, parent, offset, state)
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
  let baseColor = button.color
  button.color =
    if hovered in button.flags:
      button.hoveredColor
    else:
      button.color
  MyUiElement(button).upload(state, target)
  button.color = baseColor
  if button.label != nil:
    button.label.upload(state, target)

proc layout*(button: Button, parent: MyUiElement, offset: Vec3, state: MyUiState) =
  ButtonBase[MyUiElement](button).layout(parent, offset, state)
  if button.label != nil:
    button.label.pos.z = button.pos.z - 0.1
    button.label.size = button.size
    button.label.layout(button, vec3(0), state)

proc onClick*(button: Button, uiState: var MyUiState) =
  buttons.onClick(button, uiState)
  button.baseColor = button.color

proc onEnter*(button: Button, uiState: var MyUiState) = discard

proc onHover*(button: Button, uiState: var MyUiState) =
  button.flags.incl hovered

proc onExit*(button: Button, uiState: var MyUiState) =
  button.flags.excl hovered

# Dropdowns

proc layout*[T](dropDown: DropDown[T], parent: MyUiElement, offset: Vec3, uiState: MyUiState) =
  if dropDown.buttons[T.low].isNil:
    for ind, button in dropDown.buttons.mpairs:
      button = Button(size: dropDown.size, color: dropDown.color, hoveredColor: dropDown.hoveredColor, label: Label(text: $ind))

  for button in dropDown.buttons:
    button.pos.z = dropDown.pos.z - 0.1

  dropdowns.layout(dropDown, parent, offset, uiState)

proc interact*[T](dropDown: DropDown[T], uiState: var MyUiState) =
  dropdowns.interact(dropDown, uiState)

proc upload*[T](dropDown: DropDown[T], state: MyUiState, target: var UiRenderTarget) =
  # Due to generic dispatch these intermediate calls are requied
  MyUiElement(dropDown).upload(state, target)
  dropdowns.upload(dropDown, state, target)


# TextInputs
proc upload*(input: TextInput, state: UiState, target: var UiRenderTarget) =
  MyUiElement(input).upload(state, target)
  input.internalLabel.upload(state, target)

proc layout*(input: TextInput, parent: Element, offset: Vec3, state: UiState) =
  textinputs.layout(input, parent, offset, state)
  if input.internalLabel.isNil:
    input.internalLabel = Label(size: input.size)
  input.internalLabel.text = input.text
  input.internalLabel.layout(input, Vec3.init(0, 0, 0), state)

proc onEnter*(input: TextInput, uiState: var UiState) =
  startTextInput(default(inputs.Rect), "")

proc onTextInput*(input: TextInput, uiState: var UiState) =
  textinputs.onTextInput(input, uiState)

proc onExit*(input: TextInput, uiState: var UiState) =
  stopTextInput()


