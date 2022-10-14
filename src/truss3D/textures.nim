import opengl, pixie

type
  TextureFormat* = enum
    tfRgba
    tfRgb
    tfRg
    tfR

  Texture* = distinct Gluint
  RenderBuffer* = distinct GLuint
  FrameBufferId* = distinct Gluint

  FrameBufferKind* = enum
    Color, Depth

  FrameBuffer* = object
    id: FrameBufferId
    size*: IVec2
    format: TextureFormat
    textures: set[FrameBufferKind]
    colourTexture*: Texture
    clearColor*: Color
    depthTexture*: Texture


const 
  formatLut =
    [
      tfRgba: GlRgba,
      tfRgb: GlRgb,
      tfRg: GlRg,
      tfR: GlRed,
    ]
  dataType =
    [
      tfRgba: GlUnsignedByte,
      tfRgb: GlUnsignedByte,
      tfRg: GlUnsignedByte,
      tfR: GlUnsignedByte,
    ]

proc genTexture*(): Texture =
  glCreateTextures(GlTexture2D, 1, result.Gluint.addr)

proc delete*(tex: var Texture) =
  glDeleteTextures(1, tex.Gluint.addr)

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

template with*(fb: FrameBuffer, body: untyped) =
  block:
    var currentBuffer: Gluint
    glGetIntegerv(GlDrawFrameBufferBinding, cast[ptr Glint](addr Gluint(currentBuffer)))
    fb.bindBuffer()
    body
    glBindFrameBuffer(GlFrameBuffer, currentBuffer)
    #glClear(GLDepthbufferBit or GlColorBufferBit)


proc bindBuffer*(fb: FrameBuffer) =
  glBindFrameBuffer(GlFrameBuffer, fb.id.Gluint)

proc unbindFrameBuffer*() = 
  glBindFrameBuffer(GlFrameBuffer, 0.Gluint)

proc attachTexture*(buffer: var FrameBuffer) =
  with buffer:
    if Color in buffer.textures:
      glBindTexture(GlTexture2d, buffer.colourTexture.Gluint)
      glTexImage2D(GlTexture2d, 0.Glint, formatLut[buffer.format].Glint, buffer.size.x.GlSizei, buffer.size.y.GlSizei, 0.Glint, formatLut[buffer.format], dataType[buffer.format], nil)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
      glFramebufferTexture2D(GlFrameBuffer, GlColorAttachment0, GlTexture2D, buffer.colourTexture.Gluint, 0)

    if Depth in buffer.textures:
      glBindTexture(GlTexture2d, buffer.depthTexture.Gluint)
      glTexImage2D(GlTexture2d, 0.Glint, GlDepthComponent.Glint, buffer.size.x.GlSizei, buffer.size.y.GlSizei, 0.Glint, GlDepthComponent, cGlFloat, nil)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
      glFramebufferTexture2D(GlFrameBuffer, GlDepthAttachment, GlTexture2D, buffer.depthTexture.Gluint, 0)

    glBindTexture(GlTexture2d, Gluint(0))

proc clear*(fb: FrameBuffer) =
  with fb:
    if Color in fb.textures:
      let colorPtr = fb.clearColor.r.unsafeAddr
      glClearBufferfv(GlColor, 0, colorPtr)
    if Depth in fb.textures:
      let depth: GlFloat = 1
      glClearBufferfv(GlDepth, 0, depth.unsafeaddr)

proc genFrameBuffer*(size: Ivec2, format: TextureFormat, textures = {FrameBufferKind.Color, Depth}): FrameBuffer =
  assert textures != {}
  result = FrameBuffer(size: size, textures: textures)
  result.colourTexture = genTexture()
  if Depth in result.textures:
    result.depthTexture = genTexture()
  glCreateFramebuffers(1, result.id.Gluint.addr)
  result.attachTexture()
  result.clear()

proc resize*(fb: var FrameBuffer, size: IVec2) =
  if size != fb.size:
    fb.size = size
    fb.attachTexture()
