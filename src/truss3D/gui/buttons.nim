import ../gui
import ../mathtypes

type ButtonBase*[Base] = ref object of Base
  clickCb*: proc()

proc layout*[Base](button: ButtonBase[Base], parent: Base, offset, screenSize: Vec3) =
  mixin layout
  Base(button).layout(parent, offset, screenSize)

proc onClick*[Base;S;P](button: ButtonBase[Base], uiState: var UiState[S, P]) =
  button.clickCb()
