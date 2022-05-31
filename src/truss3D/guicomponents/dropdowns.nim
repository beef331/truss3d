import uielements, buttons
import truss3D/gui
import std/sugar

type DropDown*[T] = ref object of UiElement
    values: seq[(string, T)]
    buttons: seq[UiElement]
    opened: bool
    selected: int
    button: Button
    margin: int
    onValueChange*: proc(a: T){.closure.}
    watchValue*: proc(): T {.closure.}



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
        for (pos, item) in offsetElement(dropDown, offset):
          item.update(dt, pos)
        if leftMb.isDown():
          dropDown.opened = false
      else:
        dropdown.button.anchor = dropdown.anchor
        dropDown.button.update(dt, offset)

  method draw*(dropDown: DropDown[t], offset = ivec2(0), relativeTo = false) =
    if shouldRender(dropDown):
      if dropDown.opened:
        for (pos, item) in offsetElement(dropDown, offset):
          item.draw(pos)
      else:
        dropDown.button.draw(offset)
