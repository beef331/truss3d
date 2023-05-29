import pixie, opengl
import textures, shaders
import std/[tables, unicode]

type
  FontEntry* = object
    id*: int
    rect*: Rect
    rune*: Rune # Probably pointless

  Row = object
    usedSpace: int
  FontAtlas* = object
    entries: Table[Rune, FontEntry]
    texture*: Texture
    rows: seq[Row]
    width*, height*: int
    font*: Font
    glyphCount: int
    rectData: seq[Rect]
    ssbo*: Ssbo[seq[Rect]] 

proc blit(atlas: var FontAtlas, row: var Row, rowInd: int, rune: Rune, runeStr: string, image: Image, size: Vec2) =
  image.fillText(atlas.font, runeStr)
  atlas.font.paint = rgb(255, 255, 255)
  var tex = genTexture()
  image.copyTo(tex)



  glCopyImageSubData(
    Gluint tex, GlTexture2d, 0, 0, 0, 0,
    Gluint atlas.texture, GlTexture2d, 0, Glint row.usedSpace, Glint(rowInd) * Glint(atlas.font.size), 0,
    GlSizei size.x, GlSizei atlas.font.size, 1
  )


  tex.delete()
  let rect = Rect(x: float32 row.usedSpace, y: rowInd.float32 * atlas.font.size, w: size.x, h: atlas.font.size)
  
  inc atlas.glyphCount

  atlas.entries[rune] = FontEntry(
    id: atlas.glyphCount,
    rect: rect,
    rune: rune
  )
 
  atlas.rectData.add rect
  atlas.rectData.copyTo(atlas.ssbo, 1)

  row.usedSpace += 1 + int size.x


proc blit(atlas: var FontAtlas, rune: Rune) =
  if Gluint(atlas.texture) == 0:
    atlas.font.paint = rgb(255, 255, 255)
    atlas.texture = genTexture()
    atlas.texture.setSize(atlas.width, atlas.height)
    atlas.ssbo = genSsbo[seq[Rect]](1)

  let
    runeStr = $rune
    size = atlas.font.layoutBounds(runeStr)
    image = newImage(int size.x, int atlas.font.size)

  for i, row in atlas.rows.mpairs:
    if atlas.width - row.usedSpace >= int size.x:
      atlas.blit(row, i, rune, runeStr, image, size)
      return

  if ((atlas.rows.len + 1) * int atlas.font.size) > atlas.height:
    doAssert false, "Should we handle this?"

  atlas.rows.add Row(usedSpace: 0)
  atlas.blit(atlas.rows[^1], atlas.rows.high, rune, runeStr, image, size)


proc runeEntry*(atlas: var FontAtlas, rune: Rune): FontEntry =
  if rune.isWhiteSpace:
    FontEntry()
  else:
    if rune notin atlas.entries:
      atlas.blit(rune)
    atlas.entries[rune]

