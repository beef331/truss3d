import vmath, pixie, truss3D
import truss3D/[textures, shaders, inputs, models]
import std/[options, sequtils, sugar, macros, genasts]


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
    isNineSliced: bool
    nineSliceSize: float32
    backgroundTex: Texture
    texture: Texture
    backgroundColor: Vec4

  Label* = ref object of UiElement

  Button* = ref object of UiElement
    onClick*: proc(){.closure.}
    label: Label

  Scrollable* = concept s, type S
    lerp(s, s, 0f) is S

  ScrollBar*[T: Scrollable] = ref object of UiElement
    direction: InteractDirection
    val: T
    minMax: Slice[T]
    percentage: float32
    onValueChange*: proc(a: T){.closure.}

  LayoutGroup* = ref object of UiElement
    layoutDirection: InteractDirection
    children: seq[UiElement]
    margin: int
    centre: bool

  DropDown*[T] = ref object of UiElement
    values: seq[T]
    buttons: seq[UiElement]
    opened: bool
    selected: int
    button: Button
    margin: int
    onValueChange*: proc(a: T){.closure.}

const
  vertShader = ShaderFile"""
#version 430

layout(location = 0) in vec3 vertex_position;
layout(location = 2) in vec2 uv;


uniform mat4 modelMatrix;

out vec2 fuv;


void main() {
  gl_Position = modelMatrix * vec4(vertex_position, 1.0);
  fuv = uv;
}
"""
  fragShader = ShaderFile"""
#version 430
out vec4 frag_color;

uniform sampler2D tex;
uniform sampler2D backgroundTex;
uniform float nineSliceSize;


uniform int hasTex;
uniform vec4 color;
uniform vec4 backgroundColor;

uniform vec2 size;

in vec2 fuv;

void main() {
  if(nineSliceSize > 0){
    ivec2 texSize = textureSize(backgroundTex, 0);
    vec2 realUv = size * fuv;
    vec2 myUv = fuv;
    if(realUv.x < nineSliceSize){
      myUv.x = realUv.x / (texSize.x - nineSliceSize);
    }
    if(realUv.x > size.x - nineSliceSize){
      myUv.x = (realUv.x - size.x) / (texSize.x - nineSliceSize);
    }
    if(realUv.y < nineSliceSize){
      myUv.y = realUv.y / (texSize.x - nineSliceSize);
    }
    if(realUv.y > size.y - nineSliceSize){
      myUv.y = (realUv.y - size.y) / (texSize.x - nineSliceSize);
    }
    frag_color = texture(backgroundTex, myUv) * backgroundColor;
  }
  else if(hasTex > 0){
    vec4 newCol = texture(tex, fuv);
    frag_color = mix(frag_color, newCol * color, newCol.a);
  }else{
    frag_color = color;
  }
}
"""


var
  uiShader: Shader
  uiQuad: Model
  overGui*: bool

proc init*() =
  uiShader = loadShader(vertShader, fragShader)
  var meshData: MeshData[Vec2]
  meshData.appendVerts([vec2(0, 0), vec2(0, 1), vec2(1, 1), vec2(1, 0)].items)
  meshData.append([0u32, 1, 2, 0, 2, 3].items)
  meshData.appendUv([vec2(0, 1), vec2(0, 0), vec2(1, 0), vec2(1, 1)].items)
  uiQuad = meshData.uploadData()

proc shouldRender(ui: UiElement): bool =
 ui.visibleCond.isNil or ui.visibleCond()

proc calculatePos(ui: UiElement, offset = ivec2(0)): IVec2 =
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


proc isOver(ui: UiElement, pos = getMousePos(), offset = ivec2(0)): bool =
  let realUiPos = ui.calculatePos(offset)
  pos.x in realUiPos.x .. realUiPos.x + ui.size.x and pos.y in realUiPos.y .. realUiPos.y + ui.size.y

proc calculateAnchorMatrix(ui: UiElement, size = none(Vec2), offset = ivec2(0)): Mat4 =
  let
    scrSize = screenSize()
    scale =
      if size.isNone:
        ui.size.vec2 * 2 / scrSize.vec2
      else:
        size.get * 2 / scrSize.vec2
  var pos = ui.calculatePos(offset).vec2 / scrSize.vec2
  pos.y *= -1
  translate(vec3(pos * 2 + vec2(-1, 1 - scale.y), 0f)) * scale(vec3(scale, 0))

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


method update*(ui: UiElement, dt: float32, offset = ivec2(0)) {.base.} = discard
method draw*(ui: UiElement, offset = ivec2(0)) {.base.} = discard


proc renderTextTo(tex: Texture, size: IVec2, message: string) =
  let
    font = readFont("assets/fonts/MarradaRegular-Yj0O.ttf")
    image = newImage(size.x, size.y)
  font.size = 30
  font.paint = rgb(255, 255, 255)
  image.fillText(font, message, bounds = size.vec2, hAlign = CenterAlign, vAlign = MiddleAlign)
  image.copyTo(tex)

proc new*(_: typedesc[Label], pos, size: IVec2, text: string, color = vec4(1), anchor = {left, top}): Label =
  result = Label(pos: pos, size: size, color: color, anchor: anchor)
  result.texture = genTexture()
  result.texture.renderTextTo(size, text)

method update*(label: Label, dt: float32, offset = ivec2(0)) = discard
method draw*(label: Label, offset = ivec2(0)) =
  if label.shouldRender:
    with uishader:
      label.setupUniforms(uiShader)
      uiShader.setUniform("modelMatrix", label.calculateAnchorMatrix(offset = offset))
      withBlend:
        render(uiQuad)

proc new*(
  _: typedesc[Button];
  pos, size: IVec2;
  text: string;
  color = vec4(1);
  nineSliceSize = 0f;
  backgroundTex: Texture or string = Texture(0);
  backgroundColor = vec4(0.3, 0.3, 0.3, 1);
  fontColor = vec4(1);
  anchor = {left, top};
  onClick = (proc(){.closure.})(nil)
): Button =
  result = Button(
    pos: pos,
    size: size,
    color: color,
    anchor: anchor,
    onClick: onClick,
    isNineSliced: nineSliceSize > 0,
    nineSliceSize: nineSliceSize,
    backgroundColor: backgroundColor)
  result.label = Label.new(pos, size, text, fontColor, anchor)
  when backgroundTex is string:
    result.backgroundTex = genTexture()
    readImage(backgroundTex).copyTo result.backgroundTex
  else:
    result.backgroundTex = backgroundTex


method update*(button: Button, dt: float32, offset = ivec2(0)) =
  if button.isOver(offset = offset) and button.shouldRender:
    overGui = true
    if leftMb.isDown and button.onClick != nil:
      button.onClick()

method draw*(button: Button, offset = ivec2(0)) =
  if button.shouldRender:
    with uiShader:
      glDisable(GlDepthTest)
      button.setupUniforms(uiShader)
      uiShader.setUniform("modelMatrix", button.calculateAnchorMatrix(offset = offset))
      uiShader.setUniform("color"):
        if button.isOver(offset = offset):
          vec4(button.color.xyz * 0.5, button.color.w)
        else:
          button.color


      uiShader.setUniform("backgroundColor"):
        if button.isOver(offset = offset):
          vec4(button.backgroundColor.xyz * 0.5, 1)
        else:
          vec4(button.backgroundColor.xyz, 1)
      withBlend:
        render(uiQuad)
      button.label.draw(offset)
  button.label.pos = button.pos
  button.label.size = button.size
  button.label.anchor = button.anchor




proc new*[T](
  _: typedesc[ScrollBar[T]],
  pos, size: IVec2,
  minMax: Slice[T],
  color, backgroundColor: Vec4,
  direction = InteractDirection.horizontal,
  anchor = {left, top},
  onValueChange: proc(a: T){.closure.} = nil
): ScrollBar[T] =
  result = ScrollBar[T](
    pos: pos,
    size: size,
    minMax: minMax,
    direction: direction,
    color: color,
    backgroundColor: backgroundColor,
    anchor: anchor,
    onValueChange: onValueChange
    )

proc new*[T](
  _: typedesc[ScrollBar[T]];
  pos, size: IVec2;
  minMax: Slice[T];
  color = vec4(1);
  backgroundColor = vec4(0.1, 0.1, 0.1, 1);
  startPercentage: float32;
  direction = InteractDirection.horizontal;
  anchor = {left, top};
  onValueChange: proc(a: T){.closure.} = nil
): ScrollBar[T] =
  result = ScrollBar[T](
    pos: pos,
    size: size,
    minMax: minMax,
    direction: direction,
    color: color,
    backgroundColor: backgroundColor,
    anchor: anchor,
    onValueChange: onValueChange,
    percentage: startPercentage
    )

template emitScrollbarMethods*(t: typedesc) =
  mixin lerp
  method update*(scrollbar: ScrollBar[t], dt: float32, offset = ivec2(0)) =
    if isOver(scrollBar, offset = offset) and shouldRender(scrollBar):
      overGui = true
      if leftMb.isPressed():
        let pos = calculatePos(scrollBar, offset)
        case scrollbar.direction
        of horizontal:
          let oldPercentage = scrollbar.percentage
          scrollbar.percentage = (getMousePos().x - pos.x) / scrollBar.size.x
          scrollbar.val = lerp(scrollbar.minMax.a, scrollbar.minMax.b, scrollbar.percentage)
          if oldPercentage != scrollbar.percentage and scrollbar.onValueChange != nil:
            scrollbar.onValueChange(scrollbar.val)
        of vertical:
          assert false, "Unimplemented"


  method draw*(scrollBar: ScrollBar[t], offset = ivec2(0)) =
    if shouldRender(scrollBar):
      with uiShader:
        let isOver = isOver(scrollBar, offset = offset)
        glDisable(GlDepthTest)
        scrollBar.setupUniforms(uiShader)
        uiShader.setUniform("modelMatrix", calculateAnchorMatrix(scrollBar, offset = offset))
        uiShader.setUniform("color"):
          if isOver:
            vec4(scrollBar.backgroundColor.xyz / 2, scrollBar.backgroundColor.w)
          else:
            scrollBar.backgroundColor
        withBlend:
          render(uiQuad)

        let sliderScale = scrollBar.size.vec2 * vec2(clamp(scrollbar.percentage, 0, 1), 1)
        scrollBar.setupUniforms(uiShader)
        uiShader.setUniform("size", vec2(float32(scrollBar.size.x) * scrollBar.percentage, scrollBar.size.y.float32))
        uiShader.setUniform("modelMatrix", calculateAnchorMatrix(scrollBar, some(sliderScale), offset))
        uiShader.setUniform("color"):
          if isOver:
            vec4(scrollBar.color.xyz * 2, scrollBar.color.w)
          else:
            scrollBar.color
        withBlend:
          render(uiQuad)


proc new*(
  _: typedesc[LayoutGroup];
  pos, size: IVec2;
  anchor = {top, left};
  margin = 10;
  layoutDirection = InteractDirection.horizontal;
  centre = true
  ): LayoutGroup =
  LayoutGroup(pos: pos, size: size, anchor: anchor, margin: margin, layoutDirection: layoutDirection, centre: centre)

proc calculateStart(layoutGroup: LayoutGroup, offset = ivec2(0)): IVec2 =
  if layoutGroup.centre:
    case layoutGroup.layoutDirection
    of horizontal:
      var totalWidth = 0
      for i, item in layoutGroup.children:
        totalWidth += item.size.x + layoutGroup.margin
      result = ivec2((layoutGroup.size.x - totalWidth) div 2, 0) + layoutGroup.calculatePos(offset)
    of vertical:
      result =  layoutGroup.calculatePos(offset) # Assume top left?
  else:
    result = layoutGroup.calculatePos(offset)


iterator offsetElement(layoutGroup: LayoutGroup, offset: IVec2): (IVec2, UiElement) =
  ## Iterates over `layoutGroup`s children yielding offset and element
  var pos = layoutGroup.calculateStart(offset)
  for item in layoutGroup.children:
    case layoutGroup.layoutDirection
    of horizontal:
      yield (pos, item)
      pos.x += item.size.x + layoutGroup.margin

    of vertical:
      let renderPos = ivec2(pos.x + (layoutGroup.size.x - item.size.x) div 2, pos.y)
      yield (renderPos, item)
      pos.y += item.size.y + layoutGroup.margin



method update*(layoutGroup: LayoutGroup, dt: float32, offset = ivec2(0)) =
  if layoutGroup.shouldRender:
    for pos, item in layoutGroup.offsetElement(offset):
      update(item, dt, pos)


method draw*(layoutGroup: LayoutGroup, offset = ivec2(0)) =
  if layoutGroup.shouldRender:
    for pos, item in layoutGroup.offsetElement(offset):
      draw(item, pos)

proc add*(layoutGroup: LayoutGroup, ui: UiElement) =
  ui.anchor = {top, left} # Layout groups require top left anchored elements
  layoutGroup.children.add ui

proc add*[T: UiElement](layoutGroup: LayoutGroup, uis: openArray[T]) =
  for ui in uis:
    ui.anchor = {top, left} # Layout groups require top left anchored elements
    layoutGroup.children.add ui

proc remove*(layoutGroup: LayoutGroup, ui: UiElement) =
  let ind = layoutGroup.children.find(ui)
  if ind > 0:
    layoutGroup.children.delete(ind)

proc clear*(layoutGroup: LayoutGroup) =
  layoutGroup.children.setLen(0)


proc new*[T](
  _: typedesc[DropDown[T]];
  pos, size: IVec2;
  values: openarray[(string, T)];
  color = vec4(0.5, 0.5, 0.5, 1);
  fontColor = vec4(1);
  backgroundColor = vec4(0.5, 0.5, 0.5, 1);
  backgroundTex: Texture or string = Texture(0);
  nineSliceSize = 0f32;
  margin = 10;
  anchor = {top, left};
  onValueChange: proc(a: T){.closure.} = nil
  ): DropDown[T] =
  result = DropDown[T](pos: pos, size: size, anchor: anchor, onValueChange: onValueChange, margin: margin)

  let res = result # Hack to get around `result` outliving the closure
  for i, iterVal in values:
    let
      (name, value) = iterVal
      thisColor =
        if i == 0:
          color
        else:
          vec4(color.xyz / 2, color.w)
    result.buttons.add Button.new(ivec2(0), size, name, thisColor, nineSliceSize, backgroundTex, backgroundColor, fontColor)
    result.values.add value
    capture(name, value, i):
      Button(res.buttons[^1]).onClick = proc() =
        res.opened = false
        res.button.label.texture.renderTextTo(size, name)
        if res.selected != i and res.onvalueChange != nil:
          res.onValueChange(res.values[i])
        res.selected = i
        for ind, child in res[].buttons:
          if ind == i:
            child.backgroundColor = color
            child.color = color
          else:
            child.backgroundColor = vec4(color.xyz / 2, color.w)
            child.color = vec4(color.xyz / 2, color.w)

  result.button = Button.new(pos, size, values[0][0], color, nineSliceSize, backgroundTex, backgroundColor, fontColor)
  result.button.onClick = proc() =
    res.opened = not res.opened

proc new*[T](
  _: typedesc[DropDown[T]];
  pos, size: IVec2;
  values: openarray[T];
  color = vec4(0.5, 0.5, 0.5, 1);
  fontColor = vec4(1);
  backgroundColor = vec4(0.5, 0.5, 0.5, 1);
  backgroundTex: Texture or string = Texture(0);
  nineSliceSize = 0f32;
  margin = 10;
  anchor = {top, left};
  onValueChange : proc(a: T){.closure.} = nil
  ): DropDown[T] =
  var vals = newSeqOfCap[(string, T)](values.len)
  for x in values:
    vals.add ($x, x)
  DropDown[T].new(pos, size, vals, color, fontColor, backgroundColor, backgroundTex, nineSliceSize, margin, anchor, onValueChange)

iterator offsetElement(dropDown: DropDown, offset: IVec2): (IVec2, UiElement) =
  ## Iterates over `dropDown`s children yielding offset and element in proper order
  var yPos = dropDown.calculatePos(offset).y
  yPos += dropDown.buttons[dropDown.selected].size.y + dropDown.margin # our selected is always first
  for i, item in dropDown.buttons:
    if i != dropDown.selected:
      yPos += item.size.y + dropdown.margin

  let dir =
    if yPos > screenSize().y: # We're off the screen invert direction it's probably right
      -1
    else:
      1

  var pos = dropDown.calculatePos(offset)
  yield (pos, dropDown.buttons[dropDown.selected])
  pos.y += (dropDown.buttons[dropDown.selected].size.y + dropDown.margin) * dir
  for i, item in dropDown.buttons:
    if i != dropDown.selected:
      let renderPos = ivec2(pos.x + (dropDown.size.x - item.size.x) div 2, pos.y)
      yield (renderPos, item)
      pos.y += (item.size.y + dropDown.margin) * dir

template emitDropDownMethods*(t: typedesc) =
  method update*(dropDown: DropDown[t], dt: float32, offset = ivec2(0)) =
    if shouldRender(dropDown):
      if dropDown.opened:
        for (pos, item) in dropDown.offsetElement(offset):
          item.update(dt, pos)
        if leftMb.isDown():
          dropDown.opened = false
      else:
        dropdown.button.anchor = dropdown.anchor
        dropDown.button.update(dt, offset)

  method draw*(dropDown: DropDown[t], offset = ivec2(0)) =
    if shouldRender(dropDown):
      if dropDown.opened:
        for (pos, item) in dropDown.offsetElement(offset):
          item.draw(pos)
      else:
        dropDown.button.draw(offset)


macro makeUi*(t: typedesc, body: untyped): untyped =
  ## Nice DSL to make life less of a chore
  let
    constr = newCall("new", t)
    childrenAdd = newStmtList()
    uiName = genSym(nskVar, "ui")
  var visCond: NimNode
  var gotPos = false

  for statement in body:
    if statement[0].eqIdent"children":
      for child in statement[1]:
        childrenAdd.add newCall("add", uiName, child)
    else:
      if statement[0].eqIdent"pos":
        gotPos = true
      if statement[0].eqIdent"visibleCond":
        visCond = statement[1]
      else:
        constr.add nnkExprEqExpr.newTree(statement[0], statement[1])
  if not gotPos:
    constr.add nnkExprEqExpr.newTree(ident"pos", newCall("ivec2", newLit 0))
  result = genast(uiName, childrenAdd, constr, visCond):
    block:
      var uiName = constr
      when visCond != nil:
        uiName.visibleCond = visCond
      childrenAdd
      uiName
