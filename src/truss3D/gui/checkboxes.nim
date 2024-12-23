import ../gui
import boxes

type CheckBox* = ref object of Box
  hoverColor*: Vec4 = vec4(0.3)
  checkedColor*: Vec4 = vec4(1)
  hovertimer*: float32
  hoverSpeed*: float32 = 5
  isChecked*: bool
  onCheckedHandler*: proc(val: bool)
  checkedWatcher*: proc(): bool

proc checkBoxTick*(ui: UiElement, state: UiState) =
  let checkBox = CheckBox(ui)
  if state.currentElement == ui:
    checkBox.hovertimer += state.dt * checkBox.hoverSpeed
  else:
    checkBox.hovertimer -= state.dt * checkBox.hoverSpeed

  checkBox.hoverTimer = clamp(checkBox.hoverTimer, 0, 1)

  if checkBox.checkedWatcher != nil:
    checkBox.isChecked = checkBox.checkedWatcher()

  discard checkBox.setColor(mix(checkbox.checkedColor, checkBox.hoverColor, checkBox.hovertimer))

method layout*(checkBox: CheckBox, parent: UiElement, offset: Vec2, state: UiState) =
  procCall checkBox.UiElement.layout(parent, offset, state)

method upload*(checkBox: CheckBox, state: UiState, target: var UiRenderTarget) =
  let
    color = checkBox.color
    startSize = checkBox.layoutSize
    startPos = checkBox.layoutPos

  reset checkBox.color
  procCall checkBox.UiElement.upload(state, target)
  checkbox.color = color



  if checkBox.isChecked:
    checkBox.layoutPos += vec2(5)
    checkBox.layoutSize -= vec2(5) * 2

    procCall checkBox.UiElement.upload(state, target)
    checkBox.layoutPos = startPos
    checkbox.layoutSize = startSize

proc checkboxClickHandler(ui: UiElement, _: UiState) =
  let checkBox = CheckBox(ui)
  checkBox.isChecked = not checkBox.isChecked
  if checkBox.onCheckedHandler != nil:
    checkBox.onCheckedHandler(checkBox.isChecked)

proc checkBox*(): CheckBox =
  CheckBox(onTickHandler: checkBoxTick, onClickHandler: checkboxClickHandler)

proc setHoverColor*[T: CheckBox](checkBox: T, color: Vec4): T =
  checkBox.hoverColor = color
  checkBox

proc setCheckedColor*[T: CheckBox](checkBox: T, color: Vec4): T =
  checkBox.checkedColor = color
  checkBox

proc seUncheckedColor*[T: CheckBox](checkBox: T, color: Vec4): T =
  checkBox.uncheckedColor = color
  checkBox

proc setHoverSpeed*[T: CheckBox](checkBox: T, speed: float32): T =
  checkBox.hoverSpeed = speed
  checkBox

proc setCheckedWatcher*[T: CheckBox](checkBox: T, checked: proc(): bool): T  =
  checkBox.checkedWatcher = checked
  checkbox

proc onChecked*[T: CheckBox](checkBox: T, checked: proc(val: bool)): T =
  checkBox.onCheckedHandler = checked
  checkBox
