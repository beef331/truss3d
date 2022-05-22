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
  horzLayout = LayoutGroup.new(ivec2(0, 10), ivec2(500, 100), {bottom}, margin = 10)
  vertLayout = LayoutGroup.new(ivec2(0, 10), ivec2(500, 300), {top}, margin = 10, layoutDirection = vertical)
  myDropDown: Dropdown[MyEnum]
  myVal: MyEnum

proc init =
  gui.init()

  btns.add  Button.new(ivec2(10, 10), ivec2(200, 100), "Hmmm", color = vec4(0.5), anchor = {left,top})
  btns[^1].onClick = proc() = echo "Hello world"

  btns.add  Button.new(ivec2(10, 10), ivec2(200, 100), "Is this text?!", color = vec4(0.5), anchor = {left,bottom})
  btns[^1].onClick = proc() = echo "Hello world"

  btns.add  Button.new(ivec2(10, 10), ivec2(200, 100), "So much memory being wasted", color = vec4(0.5), anchor = {right, bottom})
  btns[^1].onClick = proc() = echo "Hello world"

  btns.add  Button.new(ivec2(10, 10), ivec2(200, 100), "Move dropbox down", color = vec4(0.5), anchor = {right, top})
  btns[^1].onClick = proc() =
    swap(myDropDown.anchor, btns[2].anchor)
  btns.add  Button.new(ivec2(0), ivec2(200, 100), "This doesnt even fit", color = vec4(0.5), anchor = {})
  btns[^1].onClick = proc() = echo "Hello world"

  horzLayout.add Button.new(ivec2(10, 10), ivec2(100, 50), "Red", color = vec4(1, 0, 0, 1))
  horzLayout.add Button.new(ivec2(10, 10), ivec2(100, 50), "Green", color = vec4(0, 1, 0 , 1))
  horzLayout.add Button.new(ivec2(10, 10), ivec2(100, 50), "Blue", color = vec4(0, 0, 1, 1))


  vertLayout.add ScrollBar[float32].new(ivec2(0, 0), iVec2(100, 20), 0f..4f, vec4(0, 0, 0.6, 1), vec4(0.1, 0.1, 0, 1))
  vertLayout.add ScrollBar[float32].new(ivec2(0, 0), iVec2(400, 20), 0f..4f, vec4(0.6, 0, 0, 1), vec4(0.1, 0.1, 0.3, 1))
  vertLayout.add ScrollBar[float32].new(ivec2(0, 0), iVec2(300, 20), 0f..4f, vec4(0.6, 0, 0.6, 1), vec4(0.1, 0.1, 0.1, 1))
  myDropDown = Dropdown[MyEnum].new(ivec2(10, 10), ivec2(200, 45), MyEnum.toSeq, anchor = {right})
  myDropDown.onValueChange = proc(a: MyEnum) = myVal = a

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
