import pixie, opengl
import textures, shaders, atlasser, logging
import std/[tables, unicode]

proc init*(_: typedesc[Rect], w, h: float32): Rect = Rect(x: 0, y: 0, w: w, h: h)
proc init*(_: typedesc[Rect], x, y, w, h: float32): Rect = Rect(x: x, y: y, w: w, h: h)


type
  FontEntry* = object
    id*: int
    rect*: Rect
    rune*: Rune # Probably pointless

  FontAtlas* = object
    texture*: Texture
    atlas*: Atlas[Rune, Rect]
    entries*: Table[Rune, FontEntry]
    font*: Font
    rectData: seq[Rect]
    ssbo*: Ssbo[seq[Rect]]

proc `=dup`(atlas: FontAtlas): FontAtlas {.error.}

proc init*(_: typedesc[FontAtlas], w, h, margin: float32, font: Font): FontAtlas =
  result = FontAtlas(atlas: Atlas[Rune, Rect].init(w, h, margin), font: font)
  result.texture = genTexture()
  result.texture.setSize(int w, int h)
  result.ssbo = genSsbo[seq[Rect]](1)

proc setFontSize*(atlas: var FontAtlas, size: float32) =
  atlas.font.size = size
  atlas.atlas.clear()
  atlas.entries.clear()
  atlas.rectData.setLen(0)
  atlas.texture.clearBlack()

proc setFont*(atlas: var FontAtlas, font: Font) =
  atlas.font[] = font[]
  atlas.atlas.clear()
  atlas.entries.clear()
  atlas.rectData.setLen(0)
  atlas.texture.clearBlack()

proc blit(atlas: var FontAtlas, rune: Rune, runeStr: string, image: Image, size: Vec2): FontEntry =
  let (added, rect) = atlas.atlas.add(rune, Rect.init(size.x, size.y))
  if added:
    atlas.font.paint = rgb(255, 255, 255)
    image.fillText(atlas.font, runeStr)
    var tex = genTexture()
    image.copyTo(tex)

    glCopyImageSubData(
      Gluint tex, GlTexture2d, 0, 0, 0, 0,
      Gluint atlas.texture, GlTexture2d, 0, Glint rect.x, Glint rect.y, 0,
      GlSizei size.x, GlSizei size.y, 1
    )
    tex.delete()

    info "Added: '", runeStr, "' to atlas, at: ", rect

    atlas.rectData.add rect
    atlas.rectData.copyTo(atlas.ssbo)
    result = FontEntry(id: atlas.rectData.len, rect: rect, rune: rune)
    atlas.entries[rune] = result


  else:
    error "Did not add: '", runeStr, "'to atlas."

proc blit(atlas: var FontAtlas, rune: Rune): FontEntry =
  atlas.entries.withValue rune, entry:
    result = entry[]
  do:
    let
      runeStr = $rune
      size = atlas.font.layoutBounds(runeStr)
      image = newImage(int size.x, int size.y)

    result = atlas.blit(rune, runeStr, image, size)


proc runeEntry*(atlas: var FontAtlas, rune: Rune): FontEntry =
  if rune.isWhiteSpace:
    FontEntry()
  else:
    atlas.blit(rune)

