import ../gui
import boxes, labels

type Button* = ref object of Box
  hoverColor*: Vec4 = vec4(0.3)
  baseColor*: Vec4 = vec4(1)
  hovertimer*: float32
  hoverSpeed*: float32 = 5
  label*: Label

proc buttonTick*(ui: UiElement, state: UiState) =
  let button = Button(ui)
  if state.currentElement == ui:
    button.hovertimer += state.dt * button.hoverSpeed
  else:
    button.hovertimer -= state.dt * button.hoverSpeed

  button.hoverTimer = clamp(button.hoverTimer, 0, 1)
  discard button.setColor(mix(button.baseColor, button.hoverColor, button.hovertimer))

method layout*(button: Button, parent: UiElement, offset: Vec2, state: UiState) =
  procCall button.UiElement.layout(parent, offset, state)
  if button.label != nil:
    button.label
      .setPosition(button.position) # Labels sit where buttons are
      .setSize(button.size) # They are button sized
      .layout(button, vec2(0), state)


method upload*(button: Button, state: UiState, target: var UiRenderTarget) =
  procCall button.UiElement.upload(state, target)
  if button.label != nil:
    button.label.upload(state, target)


proc button*(): Button =
  Button(onTickHandler: buttonTick)

proc setLabel*[T: Button](button: T, text: sink string, color = vec4(1)): T =
  button.label = Label().setText(text).setColor(color).setHAlign(CenterAlign).setVAlign(MiddleAlign)
  button

proc setHoverColor*[T: Button](button: T, color: Vec4): T =
  button.hoverColor = color
  button

proc setLabelColor*[T: Button](button: T, color: Vec4): T =
  if button.label != nil:
    discard button.label.setColor(color)
  button

proc setColor*[T: Button](button: T, color: Vec4): T =
  button.color = color
  button.baseColor = color
  button

proc setHoverSpeed*[T: Button](button: T, speed: float32): T =
  button.hoverSpeed = speed
  button
