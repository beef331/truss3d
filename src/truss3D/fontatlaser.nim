import pixie, opengl
import textures, shaders, atlasser, logging
import std/[tables, unicode, hashes]

proc hash*(f: Font): Hash =
  cast[int](f).hash()

type
  FontEntry* = object
    id*: int
    rect*: Rect
    rune*: Rune # Probably pointless

  RuneEntry = object
    rune: Rune
    font: Font

  FontAtlas* = object
    texture*: Texture
    atlas*: Atlas[RuneEntry, Rect]
    entries*: Table[RuneEntry, FontEntry]
    fonts*: Table[string, Font]
    rectData: seq[Rect]
    ssbo*: Ssbo[seq[Rect]]

proc `=dup`(atlas: FontAtlas): FontAtlas {.error.}

proc init*(_: typedesc[FontAtlas], w, h, margin: float32, font: Font, fontName: string = "default"): FontAtlas =
  result = FontAtlas(atlas: Atlas[RuneEntry, Rect].init(w, h, margin))
  result.fonts[fontName] = font
  result.texture = genTexture()
  result.texture.setSize(int w, int h)
  result.ssbo = genSsbo[seq[Rect]](1)

proc hasFonts*(atlas: FontAtlas): bool = atlas.fonts.len != 0

proc setFontSize*(atlas: var FontAtlas, size: float32, font: string = "default") =
  atlas.fonts[font].size = size

proc setFont*(atlas: var FontAtlas, font: Font, name: string = "default") =
  atlas.fonts[name] = font

proc addFont*(atlas: var FontAtlas, font: Font, name: string = "default") =
  atlas.fonts[name] = font

proc blit(atlas: var FontAtlas, font: Font, fontName: string, rune: Rune, runeStr: string, image: Image, size: Vec2): FontEntry =
  let (added, rect) = atlas.atlas.add(RuneEntry(rune: rune, font: font), Rect(w: size.x, h: size.y))

  if added:
    font.paint = rgb(255, 255, 255)
    image.fillText(font, runeStr)
    var tex = genTexture()
    image.copyTo(tex)

    glCopyImageSubData(
      Gluint tex, GlTexture2d, 0, 0, 0, 0,
      Gluint atlas.texture, GlTexture2d, 0, Glint rect.x, Glint rect.y, 0,
      GlSizei size.x, GlSizei size.y, 1
    )
    tex.delete()

    info "Added: '", runeStr, "' to atlas, at: ", rect, " with font: ", fontName

    atlas.rectData.add rect
    atlas.rectData.copyTo(atlas.ssbo)
    result = FontEntry(id: atlas.rectData.len, rect: rect, rune: rune)
    atlas.entries[RuneEntry(rune: rune, font: font)] = result
  else:
    error "Did not add: '", runeStr , "'to atlas. With font: ", fontName

proc blit(atlas: var FontAtlas, fontName: string, rune: Rune): FontEntry =
  let font = atlas.fonts[fontName]
  atlas.entries.withValue RuneEntry(rune: rune, font: font), entry:
    result = entry[]
  do:
    let
      runeStr = $rune
      size = font.layoutBounds(runeStr)
      image = newImage(int size.x, int size.y)

    result = atlas.blit(font, fontName, rune, runeStr, image, size)


proc runeEntry*(atlas: var FontAtlas, rune: Rune, fontName: string = "default"): FontEntry =
  if rune.isWhiteSpace:
    FontEntry()
  else:
    atlas.blit(fontName, rune)

