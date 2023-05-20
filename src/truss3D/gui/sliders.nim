import ../gui
import ../mathtypes

type
  Slideable = concept s, type S
    lerp(s, s, float32) is S

  HorziontalSliderBase*[Base, T] = ref object of Base
    value*: T
    rng*: Slice[T]
    percentage*: float32
    onChange*: proc(a: T)


proc layout*[Base, T](slider: HorziontalSliderBase[Base, T], parent: Base, offset, screenSize: Vec3) =
  mixin layout
  Base(slider).layout(parent, offset, screenSize)

proc onClick*[Base, T](slider: HorziontalSliderBase[Base, T], uiState: var UiState) =
  mixin lerp
  slider.percentage = uiState.inputPos.x - slider.layoutPos.x
  slider.percentage = uiState.layoutSize * slider.percentage
  let newVal = lerp(slider.rng.a, slider.rng.b, slider.percentage)
  if slider.value != newVal:
    slider.value = newVal
    if slider.onChange != nil:
      slider.onChange(slider.value)
