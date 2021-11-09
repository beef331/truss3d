import opengl, pixie

type
  TextureFormat* = enum
    tfRgba
    tfRgb
    tfRg
    tfR

  ClearFlag* = enum
    colour, depth

  Texture* = distinct Gluint
  RenderBuffer* = distinct GLuint
  FrameBufferId* = distinct Gluint
  FrameBuffer* = object
    id: FrameBufferId
    size*: IVec2
    format: TextureFormat
    texture*: Texture
    clearFlags*: set[ClearFlag]
    clearColor*: Color


const textureLut =
  [
    tfRgba: GlRgba,
    tfRgb: GlRgb,
    tfRg: GlRg,
    tfR: GlRed
  ]

proc genTexture*(): Texture =
  glCreateTextures(GlTexture2D, 1, result.Gluint.addr)

proc copyTo*(img: Image, tex: Texture) =
  glTextureStorage2D(tex.Gluint, 1.GlSizei, GlRgba8, img.width.GlSizei, img.height.GlSizei)
  glTextureSubImage2D(tex.Gluint,
                      0.Glint,
                      0.Glint,
                      0.Glint,
                      img.width.GlSizei,
                      img.height.GlSizei,
                      GlRgba,
                      GlUnsignedByte,
                      img.data[0].unsafeAddr)

proc attachTexture*(buffer: var FrameBuffer) =
  glBindFrameBuffer(GlFrameBuffer, buffer.id.Gluint)
  glBindTexture(GlTexture2d, buffer.texture.Gluint)
  glTexImage2D(GlTexture2d, 0.Glint, textureLut[buffer.format].Glint, buffer.size.x.GlSizei, buffer.size.y.GlSizei, 0.Glint, textureLut[buffer.format], GlUnsignedByte, nil)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
  glFramebufferTexture2D(GlFrameBuffer, GlColorAttachment0, GlTexture2D, buffer.texture.Gluint, 0)
  glBindFrameBuffer(GlFrameBuffer, 0)

proc clear*(fb: FrameBuffer) =
  if fb.clearFlags.card > 0:
    glBindFrameBuffer(GlFrameBuffer, fb.id.Gluint)
    if colour in fb.clearFlags:
      glClearColor(fb.clearColor.r, fb.clearColor.g, fb.clearColor.b, fb.clearColor.a)
      glClear(GlColorBufferBit)
    if depth in fb.clearFlags:
      glClearDepth(0)
      glClear(GLDepthbufferBit)
    glBindFrameBuffer(GlFrameBuffer, 0)

proc genFrameBuffer*(size: Ivec2, format: TextureFormat, clearFlags = {colour}): FrameBuffer =
  result.clearFlags = clearFlags
  result.texture = genTexture()
  glCreateFramebuffers(1, result.id.Gluint.addr)
  result.attachTexture()
  result.clear()

proc resize*(fb: var FrameBuffer, size: IVec2) =
  if size != fb.size:
    fb.size = size
    fb.attachTexture()
