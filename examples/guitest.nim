import vmath, pixie, gooey, truss3D
import truss3D/[shaders, textures, instancemodels, models, gui]
import std/[sugar, tables, hashes, strutils]

proc lerp(a, b: int, f: float32): int = int(mix(float32 a, float32 b, f))
proc reverseLerp(a: int, slice: Slice[int]): float32 = (a - slice.a) / (slice.b - slice.a)
proc reverseLerp(a: float32, slice: Slice[float32]): float32 = (a - slice.a) / (slice.b - slice.a)


var modelData: MeshData[Vec2]
modelData.appendVerts [vec2(0, 0), vec2(0, 1), vec2(1, 1), vec2(1, 0)].items
modelData.append [0u32, 1, 2, 0, 2, 3].items
modelData.appendUv [vec2(0, 1), vec2(0, 0), vec2(1, 0), vec2(1, 1)].items

proc defineGui(): auto =
  let grid = VLayout[HLayout[Button]](pos: vec3(10, 10, 0), margin: 10, anchor: {top, right})
  for y in 0..<8:
    let horz =  HLayout[Button](margin: 10)
    for x in 0..<4:
      capture x, y:
        horz.children.add:
          Button(
            color: vec4(1),
            hoveredColor: vec4(0.5, 0.5, 0.5, 1),
            clickCb: (proc() = echo x, " ", y),
            size: vec2(40, 40),
            label: Label(color: vec4(0, 0, 0, 1), text: "$#, $#" % [$(x + 1), $(y + 1)])
          )
    grid.children.add horz

  (
    Label(
      color: vec4(1),
      anchor: {top, left},
      pos: vec3(20, 20, 0),
      size: vec2(300, 200),
      text: "This is a Label!!!"
    ).named(test),
    Button(
      color: vec4(1),
      hoveredColor: vec4(0.5, 0.5, 0.5, 1),
      anchor: {bottom, right},
      pos: vec3(10, 10, 0),
      size: vec2(50, 50),
      clickCb: proc() =
        test.pos.x += 10
    ),
    HLayout[Button](
      pos: vec3(10, 10, 0),
      anchor: {bottom, left},
      margin: 10,
      children: @[
        Button(
          color: vec4(1, 0, 0, 1),
          hoveredColor: vec4(0.5, 0, 0, 1),
          clickCb: (proc() = test.color = vec4(1, 0, 0, 1)),
          size: vec2(60, 30),
          label: Label(text: "Red")
        ),
        Button(
          color: vec4(0, 0, 1, 1),
          hoveredColor: vec4(0, 0, 0.5, 1),
          clickCb: (proc() = test.color = vec4(0, 1, 0, 1)),
          size: vec2(60, 30),
          label: Label(text: "Blue")
        ),
        Button(
          color: vec4(0, 1, 0, 1),
          hoveredColor: vec4(0, 0.5, 0, 1),
          clickCb: (proc() = test.color = vec4(0, 0, 1, 1)),
          size: vec2(60, 30),
          label: Label(text: "Green")
        )
      ]
    ),
    grid,
    HSlider[int](pos: vec3(10, 10, 0), size: vec2(200, 25), rng: 0..10),
    NamedSlider[int](
      pos: vec3(10, 100, 0),
      anchor: {bottom, left},
      formatter: "Size: $#",
      name: Label(text: "Size: $#" % $test.size.x, size: vec2(100, 25)),
      slider: HSlider[int](
        rng: 100..400,
        size: vec2(100, 25),
        onChange: proc(i: int) =
          test.size.x = float32(i)
        )
      ),
    HGroup[(Button, HSlider[float32])](
      pos: vec3(300, 100, 0),
      anchor: {bottom, right},
      margin: 10,
      entries: (
        Button(
          label: Label(text: "Hello", color: vec4(0, 0, 0, 1)),
          size: vec2(50, 25),
          hoveredColor: vec4(0.1, 0.4, 0.4, 1),
          clickCB: proc() = echo "Clickity"
        ),
        HSlider[float32](
          size: vec2(100, 25),
          rng: 0f..10f,
          onChange: (proc(f: float32) = echo f),
          hoveredColor: vec4(0.5, 0.3, 0.1, 1)
        )
      )
    ),
    TextInput(
      color: vec4(0),
      backgroundColor: vec4(0.3),
      pos: vec3(0, 300, 0),
      anchor: {bottom},
      size: vec2(300, 200),
    )
  )


fontPath = "../assets/fonts/MarradaRegular-Yj0O.ttf"

var
  renderTarget: UiRenderTarget
  myUi: typeof(defineGui())
  uiState = MyUiState(scaling: 1)


proc init(truss: var Truss) =
  renderTarget.model = uploadInstancedModel[RenderInstance](modelData)
  myUi = defineGui()
  myUi.layout(vec3(0), uiState)
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
    if KeycodeBackspace.isDownRepeating():
      uiState.input = UiInput(kind: textDelete)
    elif KeyCodeReturn.isDownRepeating():
      uiState.input = UiInput(kind: textNewLine)
    else:
      reset uiState.input
  else:
    reset uiState.input

  uiState.screenSize = vec2 truss.windowSize
  uiState.inputPos = vec2 truss.inputs.getMousePos()
  myUi.layout(vec3(0), uiState)
  myUi.interact(uiState)

proc draw(truss: var Truss) =
  renderTarget.model.clear()
  myUi.upload(uiState, renderTarget)
  renderTarget.model.reuploadSsbo()
  atlas.ssbo.bindBuffer(1)
  with renderTarget.shader:
    glEnable(GlBlend)
    renderTarget.shader.setUniform("fontTex", atlas.texture)
    glBlendFunc(GlOne, GlOneMinusSrcAlpha)
    renderTarget.model.render()
    glDisable(GlBlend)

var truss = Truss.init("Test Program", ivec2(1280, 720), guitest.init, guitest.update, guitest.draw, vsync = true)
while truss.isRunning:
  truss.update()
