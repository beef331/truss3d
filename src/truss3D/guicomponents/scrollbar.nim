import uielements
type
  Scrollable* = concept s, type S
    lerp(s, s, 0f) is S

  ScrollBar*[T: Scrollable] = ref object of UiElement
    direction: InteractDirection
    val: T
    minMax: Slice[T]
    percentage: float32
    onValueChange*: proc(a: T){.closure.}
    watchValue*: proc(): T {.closure.}


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
