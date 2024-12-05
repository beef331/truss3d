import ../gui, labels
import pixie
import ../inputs


type TextInput* = ref object of UiElement
  text*: string
  textPosition*: int
  label*: Label
  onTextInputHandler*: proc(s: string)
  textWatcher*: proc(): string

method layout*(textInput: TextInput, parent: UiElement, offset: Vec2, state: UiState) =
  if textInput.textWatcher != nil:
    textInput.text = textInput.textWatcher()
    discard textInput.label.setText(textInput.text)

  procCall textInput.UiElement.layout(parent, offset, state)
  textInput.label.layout(textinput, vec2(0), state)

method upload*(textInput: TextInput, state: UiState, target: var UiRenderTarget) =
  textInput.label.upload(state, target)
  textInput.lastRenderFrame = state.currentFrame

proc setColor*[T: TextInput](textInput: T, color: Vec4): T =
  textInput.color = color
  discard textInput.label.setColor(color)
  textInput

proc setBackgroundColor*[T: TextInput](textInput: T, color: Vec4): T =
  textInput.backgroundColor = color
  discard textInput.label.setBackgroundColor(color)
  textInput

proc setTextWatcher*[T: TextInput](textInput: T, prc: proc(): string): T =
  textInput.textWatcher = prc
  textInput

proc setSize*[T: TextInput](textInput: T, size: Vec2): T =
  textInput.size = size
  discard textInput.label.setSize(size)
  textInput

proc textInputOnText*(ui: UiElement, state: UiState) =
  let textInput = TextInput ui
  case state.input.kind
  of UiInputKind.textInput:
    textInput.text.add state.input.str
  of textDelete:
    textInput.text.setLen(max(textInput.text.high, 0))
  of textNewLine:
    textInput.text.add '\n'
  else: discard

  case state.input.kind
  of TextEditFields:
    if textInput.onTextInputHandler != nil:
      textInput.onTextInputHandler(textInput.text)
    discard textInput.label.setText(textInput.text)
  else: discard


proc textInputOnEnter*(ui: UiElement, state: UiState) =
  state.truss.inputs.startTextInput(default(inputs.Rect), "")

proc textInputOnExit*(ui: UiElement, state: UiState) =
  state.truss.inputs.stopTextInput()

proc onTextInput*[T: TextInput](textInput: T, prc: proc(s: string)): T =
  textInput.onTextInputHandler = prc
  textInput

proc textinput*(): TextInput =
  TextInput(
    label: label(),
    onTextHandler: textInputOnText,
    onEnterHandler: textInputOnEnter,
    onExitHandler: textInputOnExit
  )
