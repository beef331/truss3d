import uielements
import sdl2_nim/sdl

const timeToInteraction = 0.1f

type TextArea* = ref object of UiElement
  fontSize: float32
  active: bool
  text: string
  onTextChange: proc(s: string)
  timeToInteraction: float32
  vAlign: VerticalAlignment
  hAlign: HorizontalAlignment

proc new*(
  _: typedesc[TextArea];
  pos, size: IVec2;
  fontSize = 11f;
  backgroundColor = vec4(0.5, 0.5, 0.5, 1);
  color = vec4(1);
  anchor = {left, top};
  onTextChange: proc(s: string) = nil,
  hAlign = CenterAlign,
  vAlign = MiddleAlign
  ): TextArea =
  let res = result
  result = TextArea(
    pos: pos,
    size: size,
    fontSize: fontSize,
    color: color,
    anchor: anchor,
    backgroundColor: backgroundColor,
    onTextChange: onTextChange,
    hAlign: hAlign,
    vAlign: vAlign)
  result.texture = genTexture()
  let img = newImage(size.x, size.y)
  img.fill(rgba(0, 0, 0, 0))
  img.copyTo(result.texture)

proc renderTextBlock(tex: textures.Texture, size: IVec2, message: string, fontSize = 30f, hAlign = CenterAlign, vAlign = MiddleAlign) =
  loadFontIfNeedTo()
  let image = newImage(size.x, size.y)
  font.size = fontSize

  var
    typeSet = font.typeSet(message, size.vec2)
    layout = layoutBounds(typeSet)
  while layout.x.int > size.x or layout.y.int > size.y:
    font.size -= 1
    typeSet = font.typeSet(message, size.vec2)
    layout = layoutBounds(typeSet)

  font.paint = rgb(255, 255, 255)
  image.fillText(typeSet)
  image.copyTo(tex)



method update*(textArea: TextArea, dt: float32, offset = ivec2(0), relativeTo = false) =
  let lmbPressed = leftMb.isPressed
  if textArea.shouldRender() and textArea.isOver(offset = offset, relativeTo = relativeTo):
    if not textArea.active:
      textArea.active = true
      let pos = textArea.calculatePos(offset, relativeTo)
      startTextInput(sdl.Rect(x: pos.x, y: pos.y, w: textArea.size.x, h: textArea.size.y), textArea.text)

    if textArea.timeToInteraction <= 0:
      var interacted = false
      if KeyCodeBackSpace.isPressed and textArea.text.len > 0:
        textArea.text.setLen textArea.text.high
        setInputText(textArea.text)
        textArea.timeToInteraction = timeToInteraction
      elif KeyCodeReturn.isPressed:
        textArea.text.add "\n"
        setInputText(textArea.text)
        textArea.timeToInteraction = timeToInteraction

      if textArea.timeToInteraction == timeToInteraction:
        textArea.texture.renderTextBlock(textArea.size, textArea.text, textArea.fontSize, textArea.hAlign, textArea.vAlign)
        if textArea.onTextChange != nil:
          textArea.onTextChange(textArea.text)

    if textArea.text != inputText():
      textArea.text = inputText()
      textArea.texture.renderTextBlock(textArea.size, textArea.text, textArea.fontSize, textArea.hAlign, textArea.vAlign)
      if textArea.onTextChange != nil:
        textArea.onTextChange(textArea.text)
    textArea.timeToInteraction -= dt

  else:
    textArea.active = false
    stopTextInput()



method draw*(textArea: TextArea, offset = ivec2(0), relativeTo = false) =
  if textArea.shouldRender:
    with uishader:
      glEnable(GlDepthTest)
      textArea.setupUniforms(uiShader)
      uiShader.setUniform("modelMatrix", textArea.calculateAnchorMatrix(offset = offset, relativeTo = relativeTo))
      withBlend:
        render(uiQuad)



