import ../[gui, fontatlaser, instancemodels]
import pixie

type Label* = ref object of TrussUiElement
  text*: string
  dirtied*: bool
  timer*: float32 = float32.high # This is silly
  fontSize*: float32 = 30f
  arrangement*: Arrangement

proc setText*[T: Label](label: T, text: sink string): T =
  label.text = text
  label.dirtied = true
  label

proc setFontSize*[T: Label](label: T, fontSize: float32): T =
  label.fontSize = fontSize
  label.dirtied = true
  label

proc setTimer*[T: Label](label: T, timer: float32): T =
  label.timer = timer
  label

proc arrange*(label: Label) =
  if defaultFont.isNil:
    defaultFont = readFont(fontPath)
    defaultFont.size = 64
    atlas = FontAtlas.init(1024, 1024, 3, defaultFont)

  let startSize = defaultFont.size
  var layout = defaultFont.layoutBounds(label.text)
  while layout.x > label.layoutSize.x or layout.y > label.layoutSize.y:
    defaultFont.size -= 1
    layout = defaultFont.layoutBounds(label.text)
  label.fontSize = defaultFont.size
  label.arrangement = defaultFont.typeset(label.text, label.layoutSize, hAlign = CenterAlign, vAlign = MiddleAlign)
  defaultFont.size = startSize

method layout*(label: Label, parent: UiElement, offset: Vec2, state: UiState) =
  procCall UiElement(label).layout(parent, offset, state)
  if label.dirtied:
    label.arrange()
    label.dirtied = false
    label.timer -= state.dt

method upload*(label: Label, state: TrussUiState, target: var UiRenderTarget) =
  if label.text.len > 0 and label.arrangement != nil:
    let
      scrSize = state.screenSize
      parentPos = label.layoutPos
      scale = label.fontSize /  defaultFont.size

    for i, rune in label.arrangement.runes:
      let fontEntry = atlas.runeEntry(rune)

      if fontEntry.id > 0:
        let
          rect = label.arrangement.selectionRects[i]
          offset = vec2(rect.x, rect.y)
          size = rect.wh * 2 / scrSize

        var pos = parentPos / scrSize + offset / scrSize
        pos.y *= -1
        pos.xy = pos.xy * 2f + vec2(-1f, 1f - size.y)
        target.model.push UiRenderObj(matrix: translate(vec3(pos, 0)) * scale(vec3(size, 0)), color: label.color, fontIndex: uint32 fontEntry.id)
