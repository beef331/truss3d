import uielements

type Label* = ref object of UiElement
  fontSize: float32
  horizontalAlignment: HorizontalAlignment
  verticalAlignment: VerticalAlignment
  text: string

proc new*(
  _: typedesc[Label];
  pos, size: IVec2;
  text: string;
  color = vec4(1);
  backgroundColor = vec4(0);
  anchor = {left, top};
  horizontalAlignment = CenterAlign;
  verticalAlignment = MiddleAlign;
  fontsize = 30f
  ): Label =
  result = Label(
    pos: pos,
    size: size,
    color: color,
    text: text,
    backgroundColor: backgroundColor,
    anchor: anchor,
    fontSize: fontSize,
    verticalAlignment: verticalAlignment,
    horizontalAlignment: horizontalAlignment
   )
  result.texture = genTexture()
  result.texture.renderTextTo(size, text, fontSize, horizontalAlignment, verticalAlignment)

proc updateText*(label: Label, msg: string) =
  if msg != label.text:
    label.text = msg
    label.texture.renderTextTo(label.size, label.text, label.fontSize, label.horizontalAlignment, label.verticalAlignment)

method update*(label: Label, dt: float32, offset = ivec2(0), relativeTo = false) = discard
method draw*(label: Label, offset = ivec2(0), relativeTo = false) =
  if label.shouldRender:
    with uishader:
      label.setupUniforms(uiShader)
      uiShader.setUniform("modelMatrix", label.calculateAnchorMatrix(offset = offset, relativeTo = relativeTo))
      withBlend:
        render(uiQuad)
