import ../gui, boxes


type Slider* = ref object of UiElement
  valueRange*: Slice[float32]
  value*: float32
  roundVal*: float32
  onValueHandler*: proc(val: float32)
  valueWatcher*: proc(): float32

proc sliderDragHandler*(ui: UiElement, state: UiState) =
  let
    slider = Slider(ui)
    progress = (state.inputPos.x - ui.layoutPos.x) / ui.layoutSize.x
  var val = mix(slider.valueRange.a, slider.valueRange.b, progress)
  if slider.roundVal > 0:
    val = round(val / slider.roundVal) * slider.roundVal

  slider.value = val
  slider.onValueHandler(val)

method layout*(slider: Slider, parent: UiElement, offset: Vec2, state: UiState) =
  procCall slider.UiElement.layout(parent, offset, state)
  if slider.valueWatcher != nil:
    slider.value = slider.valueWatcher()


method upload*(slider: Slider, state: UiState, target: var UiRenderTarget) =
  let
    bgColor = slider.backgroundColor
    color = slider.color

  slider.color = bgColor
  procCall slider.UiElement.upload(state, target)
  slider.color = color

  let
    scale = (slider.value - slider.valueRange.a) / (slider.valueRange.b - slider.valueRange.a)
    theSize = slider.layoutSize
  slider.layoutSize *= vec2(scale, 1)
  procCall slider.UiElement.upload(state, target)
  slider.layoutSize = theSize


proc setRange*[T: Slider](slider: T, theRange: Slice[float32], roundVal: float32 = 0): T =
  slider.valueRange = theRange
  slider.roundVal = roundVal
  slider

proc setRange*[T: Slider](slider: T, theRange: Slice[int]): T =
  slider.valueRange = theRange.a.float32 .. theRange.b.float32
  slider.roundVal = 1
  slider

proc slider*(): Slider =
  Slider(onDragHandler: sliderDragHandler)

proc onValue*[T: Slider](slider: T, prc: proc(f: float32)): T =
  slider.onValueHandler = prc
  slider

proc onValue*[T: Slider](slider: T, prc: proc(i: int)): T =
  slider.onValueHandler = proc(f: float32) = prc(int(f))
  slider

proc setValueWatcher*[T: Slider](slider: T, prc: proc(): float32): T =
  slider.valueWatcher = prc
  slider

proc setValueWatcher*[T: Slider](slider: T, prc: proc(): int): T =
  slider.valueWatcher = proc(): float32 = prc().float32
  slider
