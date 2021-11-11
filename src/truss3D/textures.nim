import opengl, pixie

type
  TextureFormat* = enum
    tfRgba
    tfRgb
    tfRg
    tfR
    tfDepth

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


const 
  formatLut =
    [
      tfRgba: GlRgba,
      tfRgb: GlRgb,
      tfRg: GlRg,
      tfR: GlRed,
      tfDepth: GlDepthComponent
    ]
  dataType =
    [
      tfRgba: GlUnsignedByte,
      tfRgb: GlUnsignedByte,
      tfRg: GlUnsignedByte,
      tfR: GlUnsignedByte,
      tfDepth: cGlFloat
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

proc bindBuffer*(fb: FrameBuffer) =
  glBindFrameBuffer(GlFrameBuffer, fb.id.Gluint)

proc unbindFrameBuffer*() = 
  glBindFrameBuffer(GlFrameBuffer, 0.Gluint)

proc attachTexture*(buffer: var FrameBuffer) =
  glBindTexture(GlTexture2d, buffer.texture.Gluint)
  glTexImage2D(GlTexture2d, 0.Glint, formatLut[buffer.format].Glint, buffer.size.x.GlSizei, buffer.size.y.GlSizei, 0.Glint, formatLut[buffer.format], dataType[buffer.format], nil)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)

  buffer.bindBuffer()
  if buffer.format == tfDepth:
    glFramebufferTexture2D(GlFrameBuffer, GlDepthAttachment, GlTexture2D, buffer.texture.Gluint, 0)
    glDrawBuffer(GlNone)
    glReadBuffer(GlNone)
  else:
    glFramebufferTexture2D(GlFrameBuffer, GlColorAttachment0, GlTexture2D, buffer.texture.Gluint, 0)
  unbindFrameBuffer()
  glBindTexture(GlTexture2d, Gluint(0))

proc clear*(fb: FrameBuffer) =
  if fb.clearFlags.card > 0:
    fb.bindBuffer()

    if colour in fb.clearFlags:
      var color: array[4, GlFloat]
      glGetFloatv(GlColorClearValue, color[0].addr)
      glClearColor(fb.clearColor.r, fb.clearColor.g, fb.clearColor.b, fb.clearColor.a)
      glClear(GlColorBufferBit)
      glClearColor(color[0], color[1], color[2], color[3])

    if depth in fb.clearFlags:
      var depth: GlFloat
      glGetFloatv(GlDepthClearValue, depth.addr)
      glClearDepth(1)
      glClear(GLDepthbufferBit)
      glClearDepth(depth)

proc genFrameBuffer*(size: Ivec2, format: TextureFormat, clearFlags = {colour}): FrameBuffer =
  result.clearFlags = clearFlags
  result.size = size
  result.texture = genTexture()
  glCreateFramebuffers(1, result.id.Gluint.addr)
  result.attachTexture()
  result.clear()

proc resize*(fb: var FrameBuffer, size: IVec2) =
  if size != fb.size:
    fb.size = size
    fb.attachTexture()

template with*(fb: FrameBuffer, body: untyped) = 
  block:
    fb.bindBuffer()
    body
    unbindFrameBuffer()
    glClear(GLDepthbufferBit or GlColorBufferBit)