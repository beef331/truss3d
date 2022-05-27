import vmath, pixie, truss3D
import truss3D/[textures, shaders, inputs, models]
import std/[options, sequtils, sugar, macros, genasts]
export pixie

type
  InteractDirection* = enum
    horizontal, vertical

  AnchorDirection* = enum
    left, right, top, bottom

  GuiState* = enum
    nothing, over, interacted

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
    watchValue*: proc(): T {.closure.}

  LayoutGroup* = ref object of UiElement
    layoutDirection: InteractDirection
    children: seq[UiElement]
    margin: int
    centre: bool

  DropDown*[T] = ref object of UiElement
    values: seq[(string, T)]
    buttons: seq[UiElement]
    opened: bool
    selected: int
    button: Button
    margin: int
    onValueChange*: proc(a: T){.closure.}
    watchValue*: proc(): T {.closure.}

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
  guiState* = GuiState.nothing

proc init*() =
  uiShader = loadShader(vertShader, fragShader)
  var meshData: MeshData[Vec2]
  meshData.appendVerts([vec2(0, 0), vec2(0, 1), vec2(1, 1), vec2(1, 0)].items)
  meshData.append([0u32, 1, 2, 0, 2, 3].items)
  meshData.appendUv([vec2(0, 1), vec2(0, 0), vec2(1, 0), vec2(1, 1)].items)
  uiQuad = meshData.uploadData()

proc shouldRender(ui: UiElement): bool =
 ui.visibleCond.isNil or ui.visibleCond()

proc calculatePos(ui: UiElement, offset = ivec2(0), relativeTo = false): IVec2 =
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

proc isOver(ui: UiElement, pos = getMousePos(), offset = ivec2(0), relativeTo = false): bool =
  let realUiPos = ui.calculatePos(offset, relativeTo)
  pos.x in realUiPos.x .. realUiPos.x + ui.size.x and pos.y in realUiPos.y .. realUiPos.y + ui.size.y and guiState == nothing

proc calculateAnchorMatrix(ui: UiElement, size = none(Vec2), offset = ivec2(0), relativeTo = false): Mat4 =
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

proc new*(_: typedesc[Label], pos, size: IVec2, text: string, color = vec4(1), anchor = {left, top}, horizontalAlignment = CenterAlign, verticalAlignment = MiddleAlign): Label =
  result = Label(pos: pos, size: size, color: color, anchor: anchor)
  result.texture = genTexture()
  result.texture.renderTextTo(size, text, horizontalAlignment, verticalAlignment)

method update*(label: Label, dt: float32, offset = ivec2(0), relativeTo = false) = discard
method draw*(label: Label, offset = ivec2(0), relativeTo = false) =
  if label.shouldRender:
    with uishader:
      label.setupUniforms(uiShader)
      uiShader.setUniform("modelMatrix", label.calculateAnchorMatrix(offset = offset, relativeTo = relativeTo))
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


method update*(button: Button, dt: float32, offset = ivec2(0), relativeTo = false) =
  if button.isOver(offset = offset, relativeTo = relativeTo) and button.shouldRender:
    guiState = over
    if leftMb.isDown and button.onClick != nil:
      guiState = interacted
      button.onClick()


method draw*(button: Button, offset = ivec2(0), relativeTo = false) =
  if button.shouldRender:
    glEnable(GlDepthTest)
    with uiShader:
      button.setupUniforms(uiShader)
      uiShader.setUniform("modelMatrix", button.calculateAnchorMatrix(offset = offset, relativeTo = relativeTo))
      uiShader.setUniform("color"):
        if button.isOver(offset = offset):
          vec4(button.color.xyz * 0.5, button.color.w)
        else:
          button.color


      uiShader.setUniform("backgroundColor"):
        if button.isOver(offset = offset, relativeTo = relativeTo):
          vec4(button.backgroundColor.xyz * 0.5, 1)
        else:
          vec4(button.backgroundColor.xyz, 1)
      withBlend:
        render(uiQuad)
      button.label.draw(offset, relativeTo)
  button.label.pos = button.pos
  button.label.size = button.size
  button.label.anchor = button.anchor
  button.label.zDepth = button.zDepth - 1




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
  onValueChange: proc(a: T){.closure.} = nil;
  watchValue: proc(): T {.closure.} = nil
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
    percentage: startPercentage,
    watchValue: watchValue
    )

template emitScrollbarMethods*(t: typedesc) =
  mixin lerp
  method update*(scrollbar: ScrollBar[t], dt: float32, offset = ivec2(0), relativeTo = false) =
    if isOver(scrollBar, offset = offset, relativeTo = relativeTo) and shouldRender(scrollBar):
      guiState = over
      if leftMb.isPressed():
        guiState = interacted
        let pos = calculatePos(scrollBar, offset, relativeTo)
        case scrollbar.direction
        of horizontal:
          let oldPercentage = scrollbar.percentage
          scrollbar.percentage = (getMousePos().x - pos.x) / scrollBar.size.x
          scrollbar.val = lerp(scrollbar.minMax.a, scrollbar.minMax.b, scrollbar.percentage)
          if oldPercentage != scrollbar.percentage and scrollbar.onValueChange != nil:
            scrollbar.onValueChange(scrollbar.val)
        of vertical:
          assert false, "Unimplemented"


  method draw*(scrollBar: ScrollBar[t], offset = ivec2(0), relativeTo = false) =
    if shouldRender(scrollBar):
      with uiShader:
        let isOver = isOver(scrollBar, offset = offset, relativeTo = relativeTo)
        glDisable(GlDepthTest)
        scrollBar.setupUniforms(uiShader)
        uiShader.setUniform("modelMatrix", calculateAnchorMatrix(scrollBar, offset = offset, relativeTo = relativeTo))
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
        uiShader.setUniform("modelMatrix", calculateAnchorMatrix(scrollBar, some(sliderScale), offset, relativeTo = relativeTo))
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

proc calculateStart(layoutGroup: LayoutGroup, offset = ivec2(0), relativeTo = false): IVec2 =
  if not relativeTo:
    let scrSize = screenSize()

    if left in layoutGroup.anchor:
      result.x = layoutGroup.pos.x
    elif right in layoutGroup.anchor:
      result.x = scrSize.x - layoutGroup.pos.x
    else:
      result.x = scrSize.x div 2 - layoutGroup.size.x div 2 + layoutGroup.pos.x

    if top in layoutGroup.anchor:
      result.y = layoutGroup.pos.y
    elif bottom in layoutGroup.anchor:
      result.y = scrSize.y - layoutGroup.pos.y
    else:
      result.y = scrSize.y div 2 - layoutGroup.size.y div 2 + layoutGroup.pos.y
    result += offset
  else:
    result = offset
    if right in layoutGroup.anchor:
      result.x -= layoutGroup.pos.x

    if bottom in layoutGroup.anchor:
      result.y -= layoutGroup.pos.y

  if layoutGroup.centre:
    var actualSize = ivec2(layoutGroup.margin * layoutGroup.children.high)
    for item in layoutGroup.children:
      actualSize += item.size
    case layoutGroup.layoutDirection
    of horizontal:
      result.x += (layoutGroup.size.x - actualSize.x) div 2
    of vertical:
      ##result.y += (layoutGroup.size.y - actualSize.y) div 2

iterator renderOrder(layoutGroup: LayoutGroup): UiElement =
  template defaultIter() =
    for item in layoutGroup.children:
      yield item
  template invertedIter() =
    for i in layoutGroup.children.high.countDown(0):
      yield layoutGroup.children[i]
  case layoutGroup.layoutDirection
  of horizontal:
    if right in layoutGroup.anchor:
      invertedIter()
    else:
      defaultIter()
  of vertical:
    if bottom in layoutGroup.anchor:
      invertedIter()
    else:
      defaultIter()


iterator offsetElement(layoutGroup: LayoutGroup, offset: IVec2, relativeTo = false): (IVec2, UiElement) =
  ## Iterates over `layoutGroup`s children yielding pos and element
  var pos = layoutGroup.calculateStart(offset, relativeTo)
  for item in layoutGroup.renderOrder:
    if item.shouldRender():
      case layoutGroup.layoutDirection
      of horizontal:

        if bottom in layoutGroup.anchor:
          yield (pos - ivec2(0, item.size.y), item)
        elif right in layoutGroup.anchor:
          pos.x -= item.size.x + layoutGroup.margin
          yield (pos, item)
        else:
          yield (pos, item)
        if right notin layoutGroup.anchor:
          pos.x += item.size.x + layoutGroup.margin

      of vertical:
        let renderPos = ivec2(pos.x + (layoutGroup.size.x - item.size.x) div 2, pos.y)
        yield (renderPos, item)
        pos.y += item.size.y + layoutGroup.margin



method update*(layoutGroup: LayoutGroup, dt: float32, offset = ivec2(0), relativeTo = false) =
  if layoutGroup.shouldRender:
    for pos, item in layoutGroup.offsetElement(offset, relativeTo):
      update(item, dt, pos, true)


method draw*(layoutGroup: LayoutGroup, offset = ivec2(0), relativeTo = false) =
  if layoutGroup.shouldRender:
    for pos, item in layoutGroup.offsetElement(offset, relativeTo):
      draw(item, pos, true)

proc add*(layoutGroup: LayoutGroup, ui: UiElement) =
  ui.anchor = layoutGroup.anchor
  layoutGroup.children.add ui

proc add*[T: UiElement](layoutGroup: LayoutGroup, uis: openArray[T]) =
  for ui in uis:
    ui.anchor = layoutGroup.anchor
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
  onValueChange: proc(a: T){.closure.} = nil;
  watchValue: proc(): T {.closure.} = nil
  ): DropDown[T] =
  result = DropDown[T](pos: pos, color: color, size: size, anchor: anchor, onValueChange: onValueChange, margin: margin, watchValue: watchValue)

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
    result.values.add iterVal
    capture(name, value, i):
      Button(res.buttons[^1]).onClick = proc() =
        res.opened = false
        res.button.label.texture.renderTextTo(size, name)
        if res.selected != i and res.onvalueChange != nil:
          res.onValueChange(res.values[i][1])
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
  onValueChange : proc(a: T){.closure.} = nil;
  watchValue: proc(): T {.closure.} = nil
  ): DropDown[T] =
  var vals = newSeqOfCap[(string, T)](values.len)
  for x in values:
    vals.add ($x, x)
  DropDown[T].new(pos, size, vals, color, fontColor, backgroundColor, backgroundTex, nineSliceSize, margin, anchor, onValueChange, watchValue)

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
  method update*(dropDown: DropDown[t], dt: float32, offset = ivec2(0), relativeTo = false) =
    if shouldRender(dropDown):
      if dropDown.watchValue != nil:
        for i, (name, val) in dropDown.values:
          if val == dropdown.watchValue() and i != dropDown.selected:
            dropDown.selected = i
            dropDown.button.label.texture.renderTextTo(dropDown.button.size, name)
            for ind, child in dropDown.buttons:
              if ind == i:
                child.backgroundColor = dropDown.color
                child.color = dropDown.color
              else:
                child.backgroundColor = vec4(dropDown.color.xyz / 2, dropDown.color.w)
                child.color = vec4(dropDown.color.xyz / 2, dropDown.color.w)

      if dropDown.opened:
        for (pos, item) in dropDown.offsetElement(offset):
          item.update(dt, pos)
        if leftMb.isDown():
          dropDown.opened = false
      else:
        dropdown.button.anchor = dropdown.anchor
        dropDown.button.update(dt, offset)

  method draw*(dropDown: DropDown[t], offset = ivec2(0), relativeTo = false) =
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
