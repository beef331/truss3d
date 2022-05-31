import vmath, pixie, truss3D, opengl
import truss3D/[textures, shaders, inputs, models, gui]
import std/options

export vmath, textures, shaders, options, shaders, inputs, options, pixie, gui, models, opengl, truss3D
type
  InteractDirection* = enum
    horizontal, vertical

  AnchorDirection* = enum
    left, right, top, bottom

  UiElement* = ref object of RootObj
    pos*: IVec2
    size*: IVec2
    color*: Vec4
    anchor*: set[AnchorDirection]
    visibleCond*: proc(): bool {.closure.}
    isNineSliced*: bool
    nineSliceSize*: float32
    backgroundTex*: Texture
    texture*: Texture
    backgroundColor*: Vec4
    zDepth*: float32


proc shouldRender*(ui: UiElement): bool =
 ui.visibleCond.isNil or ui.visibleCond()

proc calculatePos*(ui: UiElement, offset = ivec2(0), relativeTo = false): IVec2 =
  ## `relativeTo` controls whether we draw from offset or with offset added to the screenpos
  if not relativeTo:
    let scrSize = screenSize()

    if left in ui.anchor:
      result.x = ui.pos.x
    elif right in ui.anchor:
      result.x = scrSize.x - ui.pos.x - ui.size.x
    else:
      result.x = scrSize.x div 2 - ui.size.x div 2 + ui.pos.x

    if top in ui.anchor:
      result.y = ui.pos.y
    elif bottom in ui.anchor:
      result.y = scrSize.y - ui.pos.y - ui.size.y
    else:
      result.y = scrSize.y div 2 - ui.size.y div 2 + ui.pos.y
    result += offset
  else:
    result = offset
    if right in ui.anchor:
      result.x -= ui.pos.x

    if bottom in ui.anchor:
      result.y -=  ui.pos.y

proc isOver*(ui: UiElement, pos = getMousePos(), offset = ivec2(0), relativeTo = false): bool =
  let realUiPos = ui.calculatePos(offset, relativeTo)
  pos.x in realUiPos.x .. realUiPos.x + ui.size.x and pos.y in realUiPos.y .. realUiPos.y + ui.size.y and guiState == GuiState.nothing

proc calculateAnchorMatrix*(ui: UiElement, size = none(Vec2), offset = ivec2(0), relativeTo = false): Mat4 =
  let
    scrSize = screenSize()
    scale =
      if size.isNone:
        ui.size.vec2 * 2 / scrSize.vec2
      else:
        size.get * 2 / scrSize.vec2
  var pos = ui.calculatePos(offset, relativeTo).vec2 / scrSize.vec2
  pos.y *= -1
  translate(vec3(pos * 2 + vec2(-1, 1 - scale.y), ui.zDepth)) * scale(vec3(scale, 0))

template withBlend*(body: untyped) =
  glEnable(GlBlend)
  glBlendFunc(GlOne, GlOneMinusSrcAlpha)
  body
  glDisable(GlBlend)

proc setupUniforms*(ui: UiElement, shader: Shader) =
  uishader.setUniform("color", ui.color)
  uishader.setUniform("tex", ui.texture)
  uiShader.setUniform("size", ui.size.vec2)
  uishader.setUniform("hasTex", ui.texture.int)
  uiShader.setUniform("backgroundTex", ui.backgroundTex)
  uiShader.setUniform("backgroundColor", ui.backgroundColor)
  if ui.isNineSliced:
    uiShader.setUniform("nineSliceSize", ui.nineSliceSize)
  else:
    uiShader.setUniform("nineSliceSize", 0f)


method update*(ui: UiElement, dt: float32, offset = ivec2(0), relativeTo = false) {.base.} = discard
method draw*(ui: UiElement, offset = ivec2(0), relativeTo = false) {.base.} = discard

proc renderTextTo*(tex: Texture, size: IVec2, message: string, hAlign = CenterAlign, vAlign = MiddleAlign) =
  let
    font = readFont("assets/fonts/MarradaRegular-Yj0O.ttf")
    image = newImage(size.x, size.y)
  font.size = 30
  var layout = font.layoutBounds(message)
  while layout.x.int > size.x or layout.y.int > size.y:
    font.size -= 1
    layout = font.layoutBounds(message)

  font.paint = rgb(255, 255, 255)
  image.fillText(font, message, bounds = size.vec2, hAlign = hAlign, vAlign = vAlign)
  image.copyTo(tex)
