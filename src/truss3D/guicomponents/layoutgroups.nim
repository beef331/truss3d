import uielements


type LayoutGroup* = ref object of UiElement
  layoutDirection*: InteractDirection
  children*: seq[UiElement]
  margin*: int
  centre*: bool


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

proc largestSize(layoutGroup: LayoutGroup): IVec2 =
  for item in layoutGroup.children:
    result.x = max(item.size.x, result.x)
    result.y = max(item.size.y, result.y)

iterator offsetElement(layoutGroup: LayoutGroup, offset: IVec2, relativeTo = false): (IVec2, UiElement) =
  ## Iterates over `layoutGroup`s children yielding pos and element
  var pos = layoutGroup.calculateStart(offset, relativeTo)
  let largestSize = layoutGroup.largestSize()
  for item in layoutGroup.renderOrder:
    if item.shouldRender():
      case layoutGroup.layoutDirection
      of horizontal:
        var tempPos = pos
        tempPos.y += (largestSize.y - item.size.y) div 2
        if bottom in layoutGroup.anchor:
          yield (tempPos - ivec2(0, item.size.y), item)
        elif right in layoutGroup.anchor:
          pos.x -= item.size.x + layoutGroup.margin
          tempPos.x = pos.x
          yield (tempPos, item)
        else:
          yield (tempPos, item)
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
