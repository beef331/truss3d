import uielements

type Label* = ref object of UiElement
  fontSize: float32
  horizontalAlignment: HorizontalAlignment
  verticalAlignment: VerticalAlignment
  text: string
  characterLimit: int

proc new*(
  _: typedesc[Label];
  pos, size: IVec2;
  text: string;
  color = vec4(1);
  backgroundColor = vec4(0);
  anchor = {left, top};
  horizontalAlignment = CenterAlign;
  verticalAlignment = MiddleAlign;
  fontsize = 30f;
  characterLimit = 30;
  ): Label =
  let text =
    if characterLimit != 0 and text.len >= characterLimit:
      var newText = text
      newText.setLen(characterLimit)
      newText[^3..^1] = "..."
      newText
    else:
      text

  result = Label(
    pos: pos,
    size: size,
    color: color,
    text: text,
    backgroundColor: backgroundColor,
    anchor: anchor,
    fontSize: fontSize,
    verticalAlignment: verticalAlignment,
    horizontalAlignment: horizontalAlignment,
    characterLimit: characterLimit
   )
  result.texture = genTexture()
  result.texture.renderTextTo(size, text, fontSize, horizontalAlignment, verticalAlignment)

proc updateText*(label: Label, msg: string) =
  let isNewString =
    if label.characterLimit > 0 and msg.len > label.characterLimit:
        label.text != msg.toOpenArray(0, label.characterLimit - 3)
    else:
      msg != label.text
  if isNewString:
    label.text =
      if label.characterLimit > 0 and msg.len >= label.characterLimit:
        var newText = msg
        newText.setLen(label.characterLimit)
        newText[^3..^1] = "..."
        newText
      else:
        msg
    label.texture.renderTextTo(label.size, label.text, label.fontSize, label.horizontalAlignment, label.verticalAlignment)

method update*(label: Label, dt: float32, offset = ivec2(0), relativeTo = false) = discard
method draw*(label: Label, offset = ivec2(0), relativeTo = false) =
  if label.shouldRender:
    with uishader:
      label.setupUniforms(uiShader)
      setUniform("modelMatrix", label.calculateAnchorMatrix(offset = offset, relativeTo = relativeTo))
      withBlend:
        render(uiQuad)
