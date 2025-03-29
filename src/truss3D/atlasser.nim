import std/tables
type
  RectangleImpl = concept r, type R # TODO: Expand this
    r.x - r.x
    typeof(r.x).high
    init(R, r.x, r.x, r.x, r.x)
    init(R, r.x, r.x)

  
  Atlas*[T; R: RectangleImpl] = object
    width, height, margin*: typeof(default(R).x)
    usedRects: Table[T, R]
    freeRects: seq[R]

proc init*[T; R: RectangleImpl](_: typedesc[Atlas[T, R]], width, height, margin: auto): Atlas[T, R] =
  mixin init
  type FieldType = typeof(result.freeRects[0].w)
  Atlas[T, R](
    width: FieldType width,
    height: FieldType height,
    margin: FieldType margin,
    freeRects: @[R.init(FieldType width, FieldType height)]
  )

proc clear*[T, R](atlas: var Atlas[T, R]) =
  mixin init
  type FieldType = typeof(atlas.freeRects[0].w)
  atlas.freeRects.setLen(1)
  atlas.freeRects[0] = R.init(FieldType atlas.width, FieldType atlas.height)
  atlas.usedRects.clear()

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

    if wDiff >= 0.FieldType and hDiff >= 0.FieldType and
    dist > mDist and freeRect.x + rect.w < atlas.width and freeRect.y + rect.h < atlas.height:
      dist = mDist 
      result = i
      if wDiff == 0.FieldType and hDiff == 0.FieldType: # Found nearest fit
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
      atlas.freeRects.add R.init(oldRect.x + rect.w + atlas.margin, oldRect.y, rightWidth, oldRect.h) # Add right side

    if bottomHeight > 0:
      atlas.freeRects.add R.init(oldRect.x, oldRect.y + rect.h + atlas.margin, rect.w, bottomHeight) # Add Bottom side

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

proc `[]`*[T, R](atlas: var Atlas[T, R], name: T): R =
  if name in atlas.usedRects:
    result = atlas.usedRects[name]

proc `{}`*[T, R](atlas: var Atlas[T, R], name: T): (bool, R) =
  if name in atlas.usedRects:
    (true, atlas.usedRects[name])
  else:
    (false, default(R))


proc width*[T, R](atlas: Atlas[T, R]): auto =
  typeof(atlas.freeRects[0].w) atlas.width

proc height*[T, R](atlas: Atlas[T, R]): auto =
  typeof(atlas.freeRects[0].w) atlas.height

proc resize*[T, R](atlas: var Atlas[T, R], factor: auto) =
  mixin init
  let
    startWidth = atlas.width
    startHeight = atlas.height
    margin = atlas.margin
  atlas.width *= factor
  atlas.height *= factor
  atlas.freeRects.add R.init(0, startHeight + margin, startWidth * 2 - margin, startHeight - margin)
  atlas.freeRects.add R.init(startWidth + margin, 0, startWidth - margin, startHeight)
