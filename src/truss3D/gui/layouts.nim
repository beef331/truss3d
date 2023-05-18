import ../gui
import ../mathtypes

type
  HorizontalLayout*[Base, T] = ref object of Base
    children*: seq[T]
    margin*: float32
    rightToLeft*: bool

  VerticalLayout*[Base, T] = ref object of Base
    children*: seq[T]
    margin*: float32
    bottomToTop: bool


proc usedSize*[Base, T](horz: HorizontalLayout[Base, T]): Vec2 =
  result = typeof(horz.size).init(horz.margin * float32 horz.children.high, 0)
  for child in horz.children:
    let size = child.usedSize()
    result.x += size.x
    result.y = max(size.y, result.y)

proc layout*[Base, T](horz: HorizontalLayout[Base, T], parent: Base, offset, screenSize: Vec3) =
  horz.size = usedSize(horz)
  Base(horz).layout(parent, offset, screenSize)
  var offset = typeof(offset).init(0, 0, 0)
  for child in horz.children:
    child.layout(horz, offset, screenSize)
    offset.x += horz.margin + child.layoutSize.x

proc usedSize*[Base, T](vert: VerticalLayout[Base, T]): Vec2 =
  result = typeof(vert.size).init(0, vert.margin * float32 vert.children.high)
  result.y = vert.margin * float32 vert.children.high
  for child in vert.children:
    let size = child.usedSize()
    result.x = max(size.x, result.x)
    result.y += size.y

proc layout*[Base, T](vert: VerticalLayout[Base, T], parent: Base, offset, screenSize: Vec3) =
  vert.size = usedSize(vert)
  Base(vert).layout(parent, offset, screenSize)
  var offset = typeof(offset).init(0, 0, 0)
  for child in vert.children:
    child.layout(vert, offset, screenSize)
    offset.y += vert.margin + child.layoutSize.y

proc interact*[Base, T, S, P](horz: HorizontalLayout[Base, T] or VerticalLayout[Base, T], state: var UiState[S, P], inputPos: Vec2) =
  mixin interact
  for x in horz.children:
    interact(x, state, inputPos)

