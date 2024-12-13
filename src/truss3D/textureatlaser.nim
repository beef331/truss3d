import pixie, opengl
import textures, shaders, atlasser, logging
import std/[tables]

proc init*(_: typedesc[Rect], w, h: float32): Rect = Rect(x: 0, y: 0, w: w, h: h)
proc init*(_: typedesc[Rect], x, y, w, h: float32): Rect = Rect(x: x, y: y, w: w, h: h)


type
  TextureEntry* = object
    id*: int = -1
    rect*: Rect
    name*: string

  TextureAtlas* = object
    texture*: Texture
    atlas*: Atlas[string, Rect]
    entries*: Table[string, TextureEntry]
    rectData: seq[Rect]
    ssbo*: Ssbo[seq[Rect]]

proc `=dup`(atlas: TextureAtlas): TextureAtlas {.error.}

proc init*(_: typedesc[TextureAtlas], w, h, margin: float32): TextureAtlas =
  result = TextureAtlas(atlas: Atlas[string, Rect].init(w, h, margin))
  result.texture = genTexture()
  result.texture.setSize(int w, int h)
  result.ssbo = genSsbo[seq[Rect]](1)

proc blitImpl(atlas: var TextureAtlas, name: string, tex: Texture, size: Vec2): TextureEntry =
  var (added, rect) = atlas.atlas.add(name, Rect.init(size.x, size.y))
  let
    startWidth = atlas.atlas.width
    startHeight = atlas.atlas.height
  while not added:
    atlas.atlas.resize(2f)
    (added, rect) = atlas.atlas.add(name, Rect.init(size.x, size.y))
    if added:
      var newTexture = genTexture()
      newTexture.setSize(int atlas.atlas.width, int atlas.atlas.height)
      glCopyImageSubData(
        Gluint atlas.texture, GlTexture2d, 0, 0, 0, 0,
        Gluint newTexture, GlTexture2d, 0, 0, 0, 0,
        GlSizei startWidth, GlSizei startHeight, 1
      )
      atlas.texture = ensureMove newTexture


  glCopyImageSubData(
    Gluint tex, GlTexture2d, 0, 0, 0, 0,
    Gluint atlas.texture, GlTexture2d, 0, Glint rect.x, Glint rect.y, 0,
    GlSizei size.x, GlSizei size.y, 1
  )

  info "Added: '", name, "' to atlas, at: ", rect

  atlas.rectData.add rect
  atlas.rectData.copyTo(atlas.ssbo)
  result = TextureEntry(id: atlas.rectData.len, rect: rect, name: name)
  atlas.entries[name] = result


proc blit*(atlas: var TextureAtlas, name: string, image: Image, size: Vec2): TextureEntry =
  var tex = genTexture()
  image.copyTo(tex)
  atlas.blitImpl(name, tex, size)

proc blit*(atlas: var TextureAtlas, name: string, tex: Texture, size: Vec2): TextureEntry =
  atlas.entries.withValue name, entry:
    result = entry[]
  do:
    result = atlas.blitImpl(name, tex, size)


proc `[]`*(atlas: TextureAtlas, name: string): lent TextureEntry =
  atlas.entries[name]
