import uielements

type Label* = ref object of UiElement

proc new*(_: typedesc[Label], pos, size: IVec2, text: string, color = vec4(1), anchor = {left, top}, horizontalAlignment = CenterAlign, verticalAlignment = MiddleAlign): Label =
  result = Label(pos: pos, size: size, color: color, anchor: anchor)
  result.texture = genTexture()
  result.texture.renderTextTo(size, text, horizontalAlignment, verticalAlignment)

method update*(label: Label, dt: float32, offset = ivec2(0), relativeTo = false) = discard
method draw*(label: Label, offset = ivec2(0), relativeTo = false) =
  if label.shouldRender:
    with uishader:
      label.setupUniforms(uiShader)
      uiShader.setUniform("modelMatrix", label.calculateAnchorMatrix(offset = offset, relativeTo = relativeTo))
      withBlend:
        render(uiQuad)
