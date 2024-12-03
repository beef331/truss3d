import vmath, pixie, gooey
import shaders, textures, instancemodels, models, fontatlaser
import ../truss3D
import std/[sugar, tables, hashes, strutils, unicode]

export gooey


const guiVert* = ShaderFile"""
#version 430
layout(location = 0) in vec2 vertex_position;
layout(location = 2) in vec2 uv;

struct data{
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
    frag_color = texture(fontTex, offset / texSize + fUv * (size / texSize)) * color * color.a;
  }else{
    frag_color = color;
  }
}

"""


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

  TrussUiElement* = ref object of UiElement
    color*: Vec4 = vec4(1, 1, 1, 1)
    backgroundColor*: Vec4 = vec4(0, 0, 0, 0)
    texture*: Texture

  TrussUiState* = ref object of UiState
    truss*: ptr Truss # Unsafe, but who gives a hoot how many of these are we making?!

#[
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

  TimedLabel* = ref object of Label
    timer: float32
    time*: float32
]#

method upload*(ui: TrussUiElement, state: TrussUiState, target: var UiRenderTarget) {.base.} =
  let
    scrSize = state.screenSize
    size = ui.layoutSize * 2 / scrSize
  var pos = ui.layoutPos / scrSize
  pos.y *= -1
  pos.xy = pos.xy * 2f + vec2(-1f, 1f - size.y)

  let mat = translate(vec3(pos, 0)) * scale(vec3(size, 0))
  if ui.backgroundColor != vec4(0):
    target.model.push UiRenderObj(matrix: mat * translate(vec3(0, 0, -0.1)), color: ui.backgroundColor)
  if ui.color != vec4(0):
    target.model.push UiRenderObj(matrix: mat, color: ui.color)


proc setColor*[T: TrussUiElement](ele: T, color: Vec4): T =
  ele.color = color
  ele

var
  fontPath*: string
  defaultFont*: Font
  atlas*: FontAtlas
