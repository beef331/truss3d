import vmath, pixie, truss3D
import truss3D/[shaders, textures, instancemodels, models, gui]
import std/[sugar, tables, hashes, strutils]
import truss3D/gui
import truss3D/gui/[labels, boxes, buttons, layouts]

proc lerp(a, b: int, f: float32): int = int(mix(float32 a, float32 b, f))
proc reverseLerp(a: int, slice: Slice[int]): float32 = (a - slice.a) / (slice.b - slice.a)
proc reverseLerp(a: float32, slice: Slice[float32]): float32 = (a - slice.a) / (slice.b - slice.a)


var modelData: MeshData[Vec2]
modelData.appendVerts [vec2(0, 0), vec2(0, 1), vec2(1, 1), vec2(1, 0)].items
modelData.append [0u32, 1, 2, 0, 2, 3].items
modelData.appendUv [vec2(0, 1), vec2(0, 0), vec2(1, 0), vec2(1, 1)].items

proc defineGui(): seq[TrussUiElement] =
  @[
    Box().setSize(vec2(50)).setPosition(vec2(30, 30)).setAnchor({top, left}),
    TrussUiElement (let lab = label().setText("Hello").setSize(vec2(100, 50)).setTimer(1).setColor(vec4(1, 1, 0, 1)).setBackgroundColor(vec4(0.3)); lab),


    Box().onClick(proc(ui: UiElement, state: UiState) = discard lab.setTimer(1)).setSize(vec2(10, 10)).setAnchor({center}),
    button()
      .setLabel("Test", vec4(1, 0, 0, 1))
      .setSize(vec2(100, 50))
      .setAnchor({top})
      .setColor(vec4(0.7, 0.7, 0.7, 1))
      .setHoverColor(vec4(1))
      .onClick(proc(ui: UiElement, state: UiState) = discard ui.setAnchor(if ui.anchor == {top}: {bottom} else: {top}))
    ,

    layout()
      .addChildren(button().setSize(vec2(30)), button().setSize(vec2(30)))
      .setMargin(10)
      .setAnchor({bottom, right})
      .setPosition(vec2(10))
    ,
    layout().addChildren(button().setSize(vec2(30)), button().setSize(vec2(30))).setMargin(10).setAnchor({bottom, left}).setDirection(Horizontal),
  ]


fontPath = "../assets/fonts/MarradaRegular-Yj0O.ttf"

var
  renderTarget: UiRenderTarget
  myUi: typeof(defineGui())
  uiState = TrussUiState(scaling: 1)


proc init(truss: var Truss) =
  renderTarget.model = uploadInstancedModel[RenderInstance](modelData)
  myUi = defineGui()
  for ele in myUi:
    ele.layout(nil, vec2(0), uiState)
  renderTarget.shader = loadShader(guiVert, guiFrag)

proc update(truss: var Truss, dt: float32) =
  let
    isTextInput = isTextInputActive()
    inputString =
      if isTextInput:
        truss.inputs.inputText()
      else: ""
  truss.inputs.setInputText("")

  if truss.inputs.isDown(leftMb):
    uiState.input = UiInput(kind: leftClick)
  elif truss.inputs.isPressed(leftMb):
    uiState.input = UiInput(kind: leftClick, isHeld: true)
  elif isTextInput and inputString != "":
    uiState.input = UiInput(kind: textInput, str: inputString)
  elif isTextInput:
    if truss.inputs.isDownRepeating(KeyCodeBackspace):
      uiState.input = UiInput(kind: textDelete)
    elif truss.inputs.isDownRepeating(KeyCodeReturn):
      uiState.input = UiInput(kind: textNewLine)
    else:
      reset uiState.input
  else:
    reset uiState.input

  uiState.dt = dt
  uiState.screenSize = vec2 truss.windowSize
  uiState.inputPos = vec2 truss.inputs.getMousePos()
  for ele in myUi:
    ele.layout(nil, vec2(0), uiState)
    ele.interact(UiState uiState)

proc draw(truss: var Truss) =
  renderTarget.model.clear()
  for ele in myUi:
    ele.upload(uiState, renderTarget)
  renderTarget.model.reuploadSsbo()
  atlas.ssbo.bindBuffer(1)
  with renderTarget.shader:
    glEnable(GlBlend)
    renderTarget.shader.setUniform("fontTex", atlas.texture)
    glBlendFunc(GlOne, GlOneMinusSrcAlpha)
    renderTarget.model.render()
    glDisable(GlBlend)

var truss = Truss.init("Test Program", ivec2(1280, 720), guitest.init, guitest.update, guitest.draw, vsync = true)
uiState.truss = truss.addr
while truss.isRunning:
  truss.update()
