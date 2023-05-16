import truss3D, vmath
import truss3D/gui
import std/sequtils

emitScrollbarMethods(float32)

type MyEnum = enum
  SomeValue
  SomeOtherValue
  SomeOthererValue
  SomeOthrerererValue

emitDropDownMethods(MyEnum)

var
  btns: seq[Button]
  horzLayout, vertLayout: LayoutGroup
  myDropDown: Dropdown[MyEnum]
  textArea: TextArea
  myVal: MyEnum

proc init =
  gui.fontPath = "../assets/fonts/MarradaRegular-Yj0O.ttf"
  gui.init()
  glClearColor(0.1, 0.1, 0.1, 1)
  let backgroundTex = genTexture()
  readImage("../assets/uiframe.png").copyTo(backgroundTex)
  btns.add:
    makeUi(Button):
      pos = ivec2(10, 10)
      size = ivec2(200, 100)
      text = "Hmm"
      backgroundColor = vec4(0.6, 0.6, 0.6, 1)
      backgroundTex = backgroundTex
      nineSliceSize = 28f
      anchor = {AnchorDirection.left, top}
      onClick = proc() = echo "Hello World"

  btns.add:
    makeUi(Button):
      pos = ivec2(10, 10)
      size = ivec2(200, 100)
      text = "Is this text?!"
      color = vec4(0.5)
      anchor = {AnchorDirection.left, bottom}
      onClick = proc() = echo "Hello World"

  btns.add:
    makeUi(Button):
      pos = ivec2(10, 10)
      size = ivec2(200, 100)
      text = "So much memory being wasted."
      color = vec4(0.5)
      anchor = {AnchorDirection.bottom, right}
      onClick = proc() = echo "Hello World"

  btns.add:
    makeUi(Button):
      size = ivec2(200, 100)
      text = "This does not even fit"
      color = vec4(0.5)
      anchor = {}
      onClick = proc() = echo "Hello World"

  btns.add:
    makeUi(Button):
      pos = ivec2(10, 10)
      size = ivec2(200, 100)
      text = "Swap dropdown pos"
      color = vec4(0.5)
      anchor = {AnchorDirection.top, right}
      onClick = proc() =
        swap(myDropDown.anchor, btns[2].anchor)

  horzLayout = makeUi(LayoutGroup):
    pos = ivec2(0, 10)
    size = ivec2(500, 100)
    anchor = {bottom}
    children:
      makeUi(Button):
        size = ivec2(100, 75)
        text = "Red"
        backgroundColor = vec4(1, 0, 0, 1)
        backgroundTex = backgroundTex
        nineSliceSize = 28f
        onClick = proc() =
          echo "Red"
      makeUi(Button):
        size = ivec2(100, 75)
        text = "Green"
        backgroundColor = vec4(0, 1, 0, 1)
        backgroundTex = backgroundTex
        nineSliceSize = 28f
        onClick = proc() =
          echo "Green"
      makeUi(Button):
        size = ivec2(100, 75)
        text = "Blue"
        backgroundColor = vec4(0, 0, 1, 1)
        backgroundTex = backgroundTex
        nineSliceSize = 28f
        onClick = proc() =
          echo "Blue"


  vertLayout = makeUi(LayoutGroup):
    pos = ivec2(0, 10)
    size = ivec2(500, 300)
    anchor = {top}
    layoutDirection = vertical
    children:
      makeUi(ScrollBar[float32]):
        size = ivec2(100, 20)
        minMax = 0f..4f
        color = vec4(0, 0, 0.6, 1)
        backgroundColor = vec4(0, 0, 0.3, 1)
      makeUi(ScrollBar[float32]):
        size = ivec2(400, 20)
        minMax = 0f..4f
        color = vec4(0.6, 0, 0, 1)
        backgroundColor = vec4(0.3, 0.0, 0.0, 1)
      makeUi(ScrollBar[float32]):
        size = ivec2(300, 20)
        minMax = 0f..4f
        color = vec4(0.6, 0, 0.6, 1)
        backgroundColor = vec4(0.3, 0, 0.3, 1)

  myDropDown = makeUi(DropDown[MyEnum]):
    pos = ivec2(10)
    size = ivec2(200, 45)
    fontColor = vec4(0, 0, 0, 1)
    color = vec4(0.75, 0.6, 0.75, 1)
    values = MyEnum.toSeq
    anchor = {AnchorDirection.right}
    onValueChange = proc(a: MyEnum) = myVal = a

  textArea = makeUi(TextArea):
    anchor = {AnchorDirection.left}
    size = ivec2(100, 100)
    fontSize = 40
    backgroundColor = vec4(0.3, 0.3, 0.3, 1)
    onTextChange = proc(s: string) =
      echo s


proc update(dt: float32) =
  for btn in btns:
    btn.update(dt)
  horzLayout.update(dt)
  vertLayout.update(dt)
  myDropDown.update(dt)
  textArea.update(dt)
  guistate = GuiState.nothing


proc draw() =
  for btn in btns:
    btn.draw()
  horzLayout.draw()
  vertLayout.draw()
  myDropDown.draw()
  textArea.draw()

initTruss("Test", ivec2(1280, 720), guitest.init, update, draw)
