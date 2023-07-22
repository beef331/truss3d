import std/tables
type
  RectangleImpl = concept r, type R # TODO: Expand this
    r.x - r.x
    typeof(r.x).high
    init(R, r.x, r.x, r.x, r.x)
    init(R, r.x, r.x)

  
  Atlas*[T; R: RectangleImpl] = object
    width, height: typeof(default(R).x)
    usedRects: Table[T, R]
    freeRects: seq[R]

proc init*[T; R: RectangleImpl](_: typedesc[Atlas[T, R]], width, height: auto): Atlas[T, R] =
  mixin init
  type FieldType = typeof(result.freeRects[0].w)
  Atlas[T, R](
    width: FieldType width,
    height: FieldType height,
    freeRects: @[R.init(FieldType width, FieldType height)]
  )

proc getNearestSizeIndex*[T, R](atlas: Atlas[T, R], rect: R): int =
  mixin high, init
  var dist = typeof(R.x).high
  type FieldType = typeof(atlas.freeRects[0].w)
  result = -1
  for i, freeRect in atlas.freeRects.pairs:
    let 
      wDiff = freeRect.w - rect.w
      hDiff = freeRect.h - rect.h
      mDist = wDiff + hDiff
    if wDiff >= 0.FieldType and hDiff >= 0.FieldType and dist > mDist: # Probably an issue, but meh
      dist = mDist 
      result = i
    if wDiff == 0.FieldType and hDiff == 0.FieldType:
      break

proc add*[T, R](atlas: var Atlas[T, R], name: T, rect: R): (bool, R) =
  mixin init
  let rectInd = atlas.getNearestSizeIndex(rect)
  if rectInd == -1:
    result[0] = false
  else:
    let 
      oldRect = atlas.freeRects[rectInd]
      rightWidth = oldRect.w - rect.w
      bottomHeight = oldRect.h - rect.h

    if rightWidth > 0:
      atlas.freeRects.add R.init(oldRect.x + rect.w, oldRect.y, rightWidth, oldRect.h) # Add right side

    if bottomHeight > 0:
      atlas.freeRects.add R.init(oldRect.x, oldRect.y + rect.h, rect.w, bottomHeight) # Add Bottom side

    atlas.freeRects.del(rectInd)
    
    if name notin atlas.usedRects:
      result[0] = true
      result[1] = R.init(oldRect.x, oldRect.y, rect.w, rect.h) 
      atlas.usedRects[name] = result[1] # Add new rect

proc remove*[T, R](atlas: var Atlas[T, R], name: T) =
  mixin init
  type FieldType = typeof(atlas.freeRects[0].w)
  const zero = FieldType 0
  let r = atlas.usedRects.getOrDefault(name, R.init(zero, zero))
  if r.w != zero and r.h != zero:
    atlas.freeRects.add r
    atlas.usedRects.del(name)

template floatStuffs() =
  type Rectangle = object
    x, y, w, h: float

  proc init(_: typedesc[Rectangle], x, y, w, h: float): Rectangle = Rectangle(x: x, y: y, w: w, h: h)
  proc init(_: typedesc[Rectangle], w, h: float): Rectangle = Rectangle(w: w, h: h)

  static: assert Rectangle is RectangleImpl
  discard Atlas[string, Rectangle]()
  var atlas = Atlas[string, Rectangle].init(1d, 1d)
  discard atlas.add("Hello", Rectangle(w: 0.5, h: 0.5))
  discard atlas.add("World", Rectangle(w: 0.5, h: 0.5))
  discard atlas.add("1", Rectangle(w: 0.1, h: 0.1))
  discard atlas.add("2", Rectangle(w: 0.1, h: 0.1))
  echo atlas


template intStuffs() =
  type Rectangle = object
    x, y, w, h: int

  proc init(_: typedesc[Rectangle], x, y, w, h: int): Rectangle = Rectangle(x: x, y: y, w: w, h: h)
  proc init(_: typedesc[Rectangle], w, h: int): Rectangle = Rectangle(w: w, h: h)

  var atlas = Atlas[int, Rectangle].init(10, 10)
  discard atlas.add(0, Rectangle(w: 5, h: 5))
  discard atlas.add(1, Rectangle(w: 5, h: 5))
  discard atlas.add(2, Rectangle(w: 1, h: 1))
  discard atlas.add(3, Rectangle(w: 1, h: 1))
  echo atlas
  atlas.remove(3)
  echo atlas
  atlas.remove(3)
  echo atlas

floatStuffs()
intStuffs()
