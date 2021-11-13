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
  FrameBuffer* = object
    id: FrameBufferId
    size*: IVec2
    format: TextureFormat
    colourTexture*: Texture
    clearColor*: Color
    case hasDepth*: bool
    of true:
      depthTexture*: Texture
    else: discard


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
  glBindTexture(GlTexture2d, buffer.colourTexture.Gluint)
  glTexImage2D(GlTexture2d, 0.Glint, formatLut[buffer.format].Glint, buffer.size.x.GlSizei, buffer.size.y.GlSizei, 0.Glint, formatLut[buffer.format], dataType[buffer.format], nil)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
  buffer.bindBuffer()
  glFramebufferTexture2D(GlFrameBuffer, GlColorAttachment0, GlTexture2D, buffer.colourTexture.Gluint, 0)

  if buffer.hasDepth:
    glBindTexture(GlTexture2d, buffer.depthTexture.Gluint)
    glTexImage2D(GlTexture2d, 0.Glint, GlDepthComponent.Glint, buffer.size.x.GlSizei, buffer.size.y.GlSizei, 0.Glint, GlDepthComponent, cGlFloat, nil)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
    glFramebufferTexture2D(GlFrameBuffer, GlDepthAttachment, GlTexture2D, buffer.depthTexture.Gluint, 0)

  unbindFrameBuffer()
  glBindTexture(GlTexture2d, Gluint(0))

proc clear*(fb: FrameBuffer) =
  fb.bindBuffer()
  let colorPtr = fb.clearColor.r.unsafeAddr
  glClearBufferfv(GlColor, 0, colorPtr)
  if fb.hasDepth:
    let depth: GlFloat = 1
    glClearBufferfv(GlDepth, 0, depth.unsafeaddr)

proc genFrameBuffer*(size: Ivec2, format: TextureFormat, hasDepth = true): FrameBuffer =
  result = FrameBuffer(size: size, hasDepth: hasDepth)
  result.colourTexture = genTexture()
  if result.hasDepth:
    result.depthTexture = genTexture()
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
    #glClear(GLDepthbufferBit or GlColorBufferBit)