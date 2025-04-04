import std/tables
type
  Atlas*[T; R] = object
    width, height, margin*: typeof(default(R).x)
    usedRects: Table[T, R]
    freeRects: seq[R]

proc init*[T; R](_: typedesc[Atlas[T, R]], width, height, margin: auto): Atlas[T, R] =
  type FieldType = typeof(result.freeRects[0].w)
  Atlas[T, R](
    width: FieldType width,
    height: FieldType height,
    margin: FieldType margin,
    freeRects: @[R(w: FieldType width, h: FieldType height)]
  )

proc clear*[T, R](atlas: var Atlas[T, R]) =
  mixin init
  type FieldType = typeof(atlas.freeRects[0].w)
  atlas.freeRects.setLen(1)
  atlas.freeRects[0] = R(w: FieldType atlas.width, h: FieldType atlas.height)
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
      mDist = abs(wDiff) + abs(hDiff)

    if wDiff >= 0.FieldType and hDiff >= 0.FieldType:
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

    if rightWidth >= atlas.margin:
      atlas.freeRects.add R(x: oldRect.x + rect.w + atlas.margin, y: oldRect.y, w: rightWidth - atlas.margin, h: oldRect.h) # Add right side

    if bottomHeight >= atlas.margin:
      atlas.freeRects.add R(x: oldRect.x, y: oldRect.y + rect.h + atlas.margin, w: rect.w, h: bottomHeight - atlas.margin) # Add Bottom side

    atlas.freeRects.del(rectInd)
    
    if name notin atlas.usedRects:
      result = (true, R(x: oldRect.x, y: oldRect.y, w: rect.w, h: rect.h))
      atlas.usedRects[name] = result[1] # Add new rect

proc remove*[T, R](atlas: var Atlas[T, R], name: T) =
  type FieldType = typeof(atlas.freeRects[0].w)
  const zero = FieldType 0
  let r = atlas.usedRects.getOrDefault(name, R(w: zero, h: zero))
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
  atlas.freeRects.add R(x: 0, y: startHeight + margin, w: startWidth * 2 - margin, h: startHeight - margin)
  atlas.freeRects.add R(x: startWidth + margin, y: 0, w: startWidth - margin, h: startHeight)
