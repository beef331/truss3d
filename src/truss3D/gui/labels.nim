import ../[gui, fontatlaser, instancemodels]
import pixie
export HorizontalAlignment, VerticalAlignment

type Label* = ref object of UiElement
  text*: string
  dirtied*: bool
  timer*: float32 = float32.high # This is silly
  startTimer*: float32
  fontSize*: float32 = 30f
  arrangement*: Arrangement
  hAlign* = LeftAlign
  vAlign* = MiddleAlign
  scaleToFit* = true

proc setScaleToFit*[T: Label](label: T, val: bool): T =
  label.scaleToFit = true
  label

proc setText*[T: Label](label: T, text: sink string): T =
  label.text = text
  label.dirtied = true
  label

proc setFontSize*[T: Label](label: T, fontSize: float32): T =
  label.fontSize = fontSize
  label.dirtied = true
  label

proc timedLabelTick*(ui: UiElement, state: UiState) =
  let label = Label(ui)
  label.timer -= state.dt

proc setTimer*[T: Label](label: T, timer: float32): T =
  if label.onTickHandler == nil:
    label.onTickHandler = timedLabelTick
  label.startTimer = timer
  label.timer = timer
  label

proc arrange*(label: Label) =
  if defaultFont.isNil:
    defaultFont = readFont(fontPath)
    defaultFont.size = 64
    atlas = FontAtlas.init(1024, 1024, 3, defaultFont)

  let startSize = defaultFont.size
  var layout = label.layoutSize
  if label.scaleToFit:
    defaultFont.size = 64
    layout = defaultFont.layoutBounds(label.text)
    while (layout.x >= label.layoutSize.x or layout.y >= label.layoutSize.y) and defaultFont.size > 0:
      defaultFont.size -= 1
      layout = defaultFont.layoutBounds(label.text)
  else:
    defaultFont.size = label.fontSize



  label.arrangement = defaultFont.typeset(label.text, label.layoutSize, hAlign = label.hAlign, vAlign = label.vAlign, wrap = true)
  defaultFont.size = startSize

method layout*(label: Label, parent: UiElement, offset: Vec2, state: UiState) =
  procCall UiElement(label).layout(parent, offset, state)
  if label.dirtied:
    label.arrange()
    label.dirtied = false

method upload*(label: Label, state: UiState, target: var UiRenderTarget) =
  let
    color = label.color
    bgColor = label.backgroundColor
    progress =
      if label.startTimer <= 0:
        1f
      else:
        max(label.timer / label.startTimer, 0)

  label.color = vec4(0)
  label.backgroundColor = mix(vec4(bgColor.rgb, 0), bgColor, progress)
  procCall UiElement(label).upload(state, target)
  label.backgroundColor = bgColor
  label.color = color

  if label.text.len > 0 and label.arrangement != nil:
    let
      color = mix(vec4(label.color.rgb, 0), label.color, progress)
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

        if label.timer > 0 or label.startTimer == 0:
            var pos = parentPos / scrSize + offset / scrSize
            pos.y *= -1
            pos.xy = pos.xy * 2f + vec2(-1f, 1f - size.y)

            let clipRect =
              if label.clipRect == vec4(0):
                state.getClipRect(
                  vec2(label.layoutPos.x, label.layoutPos.y),
                  label.layoutPos + label.layoutSize
                )
              else:
                let
                  x1 = label.clipRect.x
                  y1 = label.clipRect.y
                  x2 = label.clipRect.x + label.clipRect.z
                  y2 = label.clipRect.y + label.clipRect.w
                state.getClipRect(vec2(x1, y1), vec2(x2, y2))


            target.model.push UiRenderObj(
              matrix: translate(vec3(pos, -label.zDepth)) * scale(vec3(size, 0)),
              color: color,
              fontIndex: uint32 fontEntry.id,
              clipRect: clipRect
            )

  label.lastRenderFrame = state.currentFrame

proc timedLabel*(): Label =
  Label(onTickHandler: timedLabelTick, flags: {onlyVisual})

proc label*(): Label =
  Label(flags: {onlyVisual})

proc setHAlign*[T: Label](label: T, align: HorizontalAlignment): T =
  label.halign = align
  label

proc setVAlign*[T: Label](label: T, align: VerticalAlignment): T =
  label.valign = align
  label
