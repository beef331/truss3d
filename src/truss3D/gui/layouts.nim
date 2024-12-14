import ../gui

iterator reversed*[T](oa: openArray[T]): T =
  for i in countDown(oa.high, 0):
    yield oa[i]

type
  LayoutDirection* = enum
    Vertical
    Horizontal

  Layout* = ref object of UiElement
    children*: seq[UiElement]
    direction*: LayoutDirection
    reversed*: bool
    alignment*: AnchorDirection
    margin*: float32

proc layout*(): Layout =
  Layout(flags: {onlyVisual}).setColor(vec4(0))

proc addChildren*[T: Layout](layout: T, children: varargs[UiElement]): T =
  layout.children.add @children
  layout

proc setDirection*[T: Layout](layout: T, dir: LayoutDirection): T =
  layout.direction = dir
  layout

proc setReversed*[T: Layout](layout: T, reversed: bool): T =
  layout.reversed = reversed
  layout

proc setAlignment*[T: Layout](layout: T, align: AnchorDirection): T =
  layout.alignment = align
  layout

proc setMargin*[T: Layout](layout: T, margin: float32): T =
  layout.margin = margin
  layout

method calcSize*(layout: Layout): Vec2 =
  case layout.direction
  of Horizontal:
    result = vec2(0)
    for ele in layout.children:
      if ele.isVisible():
        let childSize = ele.calcSize()
        result.x += childSize.x
        result.y = max(result.y, childSize.y)
        result.x += layout.margin
    result.x -= layout.margin

  of Vertical:
    result = vec2(0)
    for ele in layout.children:
      if ele.isVisible():
        let childSize = ele.calcSize()
        result.y += childSize.y
        result.x = max(result.x, childSize.x)
        result.y += layout.margin
    result.y -= layout.margin


method layout*(layout: Layout, parent: UiElement, offset: Vec2, state: UiState) =
  if layout.isVisible:
    layout.size = layout.calcSize()
    procCall layout.UiElement.layout(parent, offset, state)
    var offset = vec2(0)
    case layout.direction
    of Horizontal:
      if layout.reversed:
        for child in layout.children.reversed:
          if child.isVisible():
            let oldOffset = offset.y
            case layout.alignment:
            of center:
              offset.y += (layout.size.y - calcSize(child).y) / 2
            of bottom:
              offset.y += (layout.size.y - calcSize(child).y)
            else:
              discard
            child.layout(layout, offset, state)
            offset.x += layout.margin * state.scaling + child.layoutSize.x
            offset.y = oldOffset
      else:
        for child in layout.children:
          if child.isVisible():
            let oldOffset = offset.y
            case layout.alignment:
            of center:
              offset.y += (layout.size.y - calcSize(child).y) / 2
            of bottom:
              offset.y += (layout.size.y - calcSize(child).y)
            else:
              discard
            child.layout(layout, offset, state)
            offset.x += layout.margin * state.scaling + child.layoutSize.x
            offset.y = oldOffset
    of Vertical:
      var offset = vec2(0)
      if layout.reversed:
        for child in layout.children.reversed:
          if child.isVisible:
            let oldOffset = offset.x
            case layout.alignment:
            of center:
              offset.x += (layout.size.x - calcSize(child).x) / 2
            of right:
              offset.x += (layout.size.x - calcSize(child).x)
            else:
              discard
            child.layout(layout, offset, state)
            offset.y += layout.margin * state.scaling + child.layoutSize.y
            offset.x = oldOffset
      else:
        for child in layout.children:
          if child.isVisible:
            let oldOffset = offset.x
            case layout.alignment:
            of center:
              offset.x += (layout.size.x - calcSize(child).x) / 2
            of right:
              offset.x += (layout.size.x - calcSize(child).x)
            else:
              discard
            child.layout(layout, offset, state)
            offset.y += layout.margin * state.scaling + child.layoutSize.y
            offset.x = oldOffset
  for elem in layout.children:
    elem.zdepth = layout.zdepth + 0.1


method upload*(layout: Layout, state: UiState, target: var UiRenderTarget) =
  procCall layout.UiElement.upload(state, target)
  if layout.isVisible():
    for elem in layout.children:
      if elem.isVisible:
        elem.upload(state, target)

method interact*(layout: Layout, state: UiState)  =
  if layout.isVisible():
    for elem in layout.children:
      if elem.isVisible:
        elem.interact(state)
