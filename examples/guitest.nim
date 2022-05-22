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
  myVal: MyEnum

proc init =
  gui.init()

  btns.add:
    makeUi(Button):
      pos = ivec2(10, 10)
      size = ivec2(200, 100)
      text = "Hmm"
      color = vec4(0.5)
      anchor = {left, top}
      onClick = proc() = echo "Hello World"

  btns.add:
    makeUi(Button):
      pos = ivec2(10, 10)
      size = ivec2(200, 100)
      text = "Is this text?!"
      color = vec4(0.5)
      anchor = {left, bottom}
      onClick = proc() = echo "Hello World"

  btns.add:
    makeUi(Button):
      pos = ivec2(10, 10)
      size = ivec2(200, 100)
      text = "So much memory being wasted."
      color = vec4(0.5)
      anchor = {bottom, right}
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
      anchor = {top, right}
      onClick = proc() =
        swap(myDropDown.anchor, btns[2].anchor)

  horzLayout = makeUi(LayoutGroup):
    pos = ivec2(0, 10)
    size = ivec2(500, 100)
    anchor = {bottom}
    children:
      makeUi(Button):
        size = ivec2(100, 50)
        text = "Red"
        color = vec4(1, 0, 0, 1)
        onClick = proc() =
          echo "Red"
      makeUi(Button):
        size = ivec2(100, 50)
        text = "Green"
        color = vec4(0, 1, 0, 1)
        onClick = proc() =
          echo "Green"
      makeUi(Button):
        size = ivec2(100, 50)
        text = "Blue"
        color = vec4(0, 0, 1, 1)
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
        backgroundColor = vec4(0.1, 0.1, 0, 1)
      makeUi(ScrollBar[float32]):
        size = ivec2(400, 20)
        minMax = 0f..4f
        color = vec4(0.6, 0, 0, 1)
        backgroundColor = vec4(0.1, 0.1, 0.3, 1)
      makeUi(ScrollBar[float32]):
        size = ivec2(300, 20)
        minMax = 0f..4f
        color = vec4(0.6, 0, 0.6, 1)
        backgroundColor = vec4(0.1, 0.1, 0.1, 1)

  myDropDown = makeUi(DropDown[MyEnum]):
    pos = ivec2(10)
    size = ivec2(200, 45)
    values = MyEnum.toSeq
    anchor = {right}
    onValueChange = proc(a: MyEnum) = myVal = a


proc update(dt: float32) =
  for btn in btns:
    btn.update(dt)
  horzLayout.update(dt)
  vertLayout.update(dt)
  myDropDown.update(dt)


proc draw() =
  for btn in btns:
    btn.draw()
  horzLayout.draw()
  vertLayout.draw()
  myDropDown.draw()

initTruss("Test", ivec2(1280, 720), guitest.init, update, draw)
