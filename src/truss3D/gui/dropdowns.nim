import ../gui, buttons
import std/sugar

type DropDown* = ref object of UiElement
  openButton*: Button
  buttons*: seq[Button]
  active*: int
  selectHandler*: proc(index: int)
  opened*: bool
  hoverColor*: Vec4 = vec4(0.3)
  labelColor*: Vec4 = vec4(1)
  selectionWatcher*: proc(): int

method layout*(dropDown: DropDown, parent: UiElement, offset: Vec2, state: UiState) =
  procCall UiElement(dropDown).layout(parent, offset, state)
  dropDown.openButton.layout(dropDown, vec2(0), state)
  var offset = dropDown.openButton.calcSize()
  dropDown.openButton.zDepth = dropDown.zDepth + 0.1 * (1f + dropDown.opened.float32 * 3)
  for i, button in dropDown.buttons:
    if i != dropDown.active:
      offset.x = 0
      button.layout(dropDown, offset, state)
      offset += button.calcSize()
    button.zDepth = dropDown.zDepth + 0.1 * (1f + dropDown.opened.float32 * 3)


method upload*(dropDown: DropDown, state: UiState, target: var UiRenderTarget) =
  dropDown.openButton.upload(state, target)
  if dropDown.opened:
    for i, button in dropDown.buttons:
      if i != dropDown.active:
        button.upload(state, target)

method interact*(dropDown: DropDown, state: UiState)  =
  if dropDown.selectionWatcher != nil:
    let
      oldActive = dropDown.active
      wasOpened = dropDown.opened
    dropDown.active = dropDown.selectionWatcher()
    if dropDown.active != oldActive:
      let btn = dropDown.buttons[dropDown.active]
      btn.onClickHandler(btn, state)
      dropDown.opened = wasOpened
  dropDown.openButton.interact(state)
  if dropDown.opened:
    for i, button in dropDown.buttons:
      if i != dropDown.active:
        button.interact(state)

proc dropDown*(): DropDown =
  result = DropDown(flags: {onlyVisual})
  let dd = result
  result.openButton = button()
    .onClick(proc(_: UiElement, _: UiState) = dd.opened = not dd.opened)

proc setOptions*[T: DropDown](dropDown: T, Vals: typedesc[enum | range]): T =
  dropDown.buttons.setLen(0)
  discard dropDown.openButton.setLabel($Vals.low, dropDown.labelColor).setSize(dropDown.size)

  for val in Vals.low..Vals.high:
    let i = dropDown.buttons.len
    capture val, i:
      proc select(ui: UiElement, state: UiState) =
        if dropDown.selectHandler != nil:
          dropDown.selectHandler(i)
        dropDown.active = i
        discard dropDown.openButton.setLabel($val, dropDown.labelColor)
        dropDown.opened = false

      dropDown.buttons.add button()
        .setColor(dropDown.color)
        .setBackgroundColor(dropDown.color)
        .onClick(select)
        .setSize(dropDown.size)
        .setLabel($val, dropDown.labelColor)

  dropDown

proc setSelectionWatcher*[T: DropDown](ui: T, prc: proc(): int): T =
  ui.selectionWatcher = prc
  ui

proc setSelectionWatcher*[T: DropDown, Y: enum | range](ui: T, prc: proc(): Y): T =
  if ui.buttons.len == 0:
    discard ui.setOptions(Y)
  ui.selectionWatcher = proc(): int =
    let val = prc()
    val.ord - Y.low.ord
  ui

proc onSelect*[T: DropDown](ui: T, prc: proc(index: int)): T =
  ui.selectHandler = prc
  ui

proc onSelect*[T: DropDown, Y: enum | range](ui: T, prc: proc(index: Y)): T =
  if ui.buttons.len == 0:
    discard ui.setOptions(Y)
  ui.selectHandler = proc(i: int) =
    when Y isnot range:
      prc(Y(i))
    else:
      prc(Y(i + Y.low.ord))
  ui


proc setColor*[T: DropDown](dropDown: T, color: Vec4): T =
  dropDown.color = color
  discard dropDown.openButton.setColor color
  for button in dropDown.buttons:
    discard button.setColor(color)
  dropDown

proc setBackgroundColor*[T: DropDown](dropDown: T, color: Vec4): T =
  dropDown.backgroundColor = color
  discard dropDown.openButton.setBackgroundColor color
  for button in dropDown.buttons:
    discard button.setBackgroundColor(color)
  dropDown

proc setHoverColor*[T: DropDown](dropDown: T, color: Vec4): T =
  dropDown.hoverColor = color
  discard dropDown.openButton.setHoverColor color
  for button in dropDown.buttons:
    discard button.setHoverColor(color)
  dropDown

proc setLabelColor*[T: DropDown](dropDown: T, color: Vec4): T =
  dropDown.labelColor = color
  discard dropDown.openButton.setLabelColor(color)
  for button in dropDown.buttons:
    discard button.setLabelColor(color)
  dropDown

proc setSize*[T: DropDown](dropDown: T, size: Vec2): T =
  dropDown.size = size
  discard dropDown.openButton.setSize(size)
  for button in dropDown.buttons:
    discard button.setSize(size)
  dropDown
