import ../gui, boxes, layouts, sliders


type ScrollView* = ref object of UiElement
  layout: Layout
  scrollBar: UiElement
  scrollAmount: float32


method layout*(scrollView: ScrollView, parent: UiElement, offset: Vec2, state: UiState) =
  procCall UiElement(scrollView).layout(parent, offset, state)
  scrollView.layout.layout(scrollView, scrollView.layout.size.y * offset, state)
  scrollview.scrollBar.layout(scrollView, vec2(scrollview.layout.position.x, 0), state)


method upload*(scrollView: ScrollView, state: UiState, target: var UiRenderTarget) =
  procCall UiElement(scrollView).upload(state, target)
  scrollview.layout.clipRect = vec4(scrollView.position, scrollview.size)
  scrollView.layout.upload(state, target)
  scrollView.scrollBar.upload(state, target)


proc scrollView*(): ScrollView =
  ScrollView(
    layout: layout().setDirection(Vertical),
    scrollBar: slider()
  )

proc addChildren*[T: ScrollView](view: T, ui: varargs[UiElement]): T =
  discard view.layout.addChildren(ui)
  view

proc setSize*[T: ScrollView](view: T, size: Vec2): T =
  discard view.layout.setSize(size)
  discard UiElement(view).setSize(size)
  view
