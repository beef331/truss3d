import opengl, pixie
import std/tables

type
  TextureFormat* = enum
    tfRgba
    tfRgb
    tfRg
    tfR

  TextureWrapping* = enum
    Repeat
    ClampedToEdge
    ClampedToBorder
    MirroredRepeat



  Texture* = distinct Gluint
  TextureHandle* = distinct uint64
  TextureArray* = distinct Gluint
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
    wrapMode: TextureWrapping

proc `=dup`(fb: FrameBufferId): FrameBufferId {.error.}
proc `=dup`(tex: Texture): Texture {.error.}

proc `=destroy`(fb: FrameBufferId) =
  if Gluint(fb) != 0:
    glDeleteFramebuffers(1, fb.Gluint.addr)


proc `=destroy`(tex: Texture) =
  if Gluint(tex) != 0:
    glDeleteTextures(1, tex.Gluint.addr)


const
  internalFormatLut =
    [
      tfRgba: GlInt GlRgba8,
      tfRgb: GlInt GlRgb8,
      tfRg: GlInt GlRg8,
      tfR: GlInt GlR8
    ]

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

  wrapLut = [
    Repeat: GlRepeat,
    GlClampToEdge,
    GlClampToBorder,
    GlMirroredRepeat
    ]

proc genTexture*(): Texture =
  glCreateTextures(GlTexture2D, 1, result.Gluint.addr)

proc clearBlack*(tex: Texture) =
  var data = [0u8, 0, 0, 0]
  glClearTexImage(Gluint tex, 0, GlRgba8, GlRgba8, cast[ptr pointer](data[0].addr))

proc genTextureArray*(width, height, depth: int, mipMapLevel = 1): TextureArray =
  glCreateTextures(GlTexture2dArray, 1, result.Gluint.addr)
  glBindTexture(GlTexture2dArray, Gluint(result))
  glTextureStorage3D(Gluint(result), GlSizei mipMapLevel, GlRgba8, GlSizei width, GlSizei height, GlSizei depth)
  glTexParameteri(GlTexture2dArray, GlTextureMinFilter, GL_NEAREST);
  glTexParameteri(GlTexture2dArray, GlTextureMagFilter, GL_NEAREST);
  glTexParameteri(GlTexture2dArray, GlTextureWrapS, GlClampToEdge);
  glTexParameteri(GlTexture2dArray, GlTextureWrapT, GlClampToEdge);
  glBindTexture(GlTexture2dArray, 0)

proc delete*(tex: var Texture) =
  glDeleteTextures(1, tex.Gluint.addr)

proc getHandle*(tex: Texture): TextureHandle =
  TextureHandle glGetTextureHandleARB(Gluint tex)

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

proc setSize*(tex: Texture, width, height: int) =
  glTextureStorage2D(Gluint tex, 1.Glsizei, GlRgba8, GlSizei width, GlSizei height)


proc copyTo*(img: Image, tex: TextureArray, depth: int) =
  glTextureSubImage3D(
    tex.Gluint,
    0,
    0,
    0,
    GlSizei depth,
    img.width.GlSizei,
    img.height.GlSizei,
    GlSizei 1,
    GlRgba,
    GlUnsignedByte,
    img.data[0].unsafeAddr
  )

template with*(fb: FrameBuffer, body: untyped) =
  block:
    var currentBuffer: Glint
    glGetIntegerv(GlDrawFrameBufferBinding, addr currentBuffer)
    fb.bindBuffer()
    body
    glBindFrameBuffer(GlFrameBuffer, Gluint currentBuffer)
    #glClear(GLDepthbufferBit or GlColorBufferBit)


proc bindBuffer*(fb: FrameBuffer) =
  glBindFrameBuffer(GlFrameBuffer, fb.id.Gluint)

proc unbindFrameBuffer*() = 
  glBindFrameBuffer(GlFrameBuffer, 0.Gluint)

proc attachTexture*(buffer: var FrameBuffer) =
  with buffer:
    if Color in buffer.textures:
      glBindTexture(GlTexture2d, buffer.colourTexture.Gluint)
      glTexImage2D(GlTexture2d, 0.Glint, internalFormatLut[buffer.format], buffer.size.x.GlSizei, buffer.size.y.GlSizei, 0.Glint, formatLut[buffer.format], dataType[buffer.format], nil)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrapLut[buffer.wrapMode])
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrapLut[buffer.wrapMode])
      glNamedFramebufferTexture(buffer.id.Gluint, GlColorAttachment0, buffer.colourTexture.Gluint, 0)

    if Depth in buffer.textures:
      glBindTexture(GlTexture2d, buffer.depthTexture.Gluint)
      glTexImage2D(GlTexture2d, 0.Glint, GlDepthComponent.Glint, buffer.size.x.GlSizei, buffer.size.y.GlSizei, 0.Glint, GlDepthComponent, cGlFloat, nil)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrapLut[buffer.wrapMode])
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrapLut[buffer.wrapMode])
      glNamedFramebufferTexture(buffer.id.Gluint, GlDepthAttachment, buffer.depthTexture.Gluint, 0)

    glBindTexture(GlTexture2d, Gluint(0))

proc clear*(fb: FrameBuffer) =
  with fb:
    if Color in fb.textures:
      let colorPtr = fb.clearColor.r.unsafeAddr
      glClearBufferfv(GlColor, 0, colorPtr)
    if Depth in fb.textures:
      let depth: GlFloat = 1
      glClearBufferfv(GlDepth, 0, depth.unsafeaddr)

proc genFrameBuffer*(size: Ivec2, format: TextureFormat, textures = {FrameBufferKind.Color, Depth}, wrapMode = default TextureWrapping): FrameBuffer =
  assert textures != {}
  result = FrameBuffer(size: size, textures: textures, wrapMode: wrapMode)
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
    fb.clear()

var loadedTextures: Table[string, Texture] # Should use a ref count

proc loadTexture*(path: string): Texture =
  if path in loadedTextures:
    loadedTextures[path]
  else:
    let
      data = readImage path
      tex = genTexture()
    data.copyTo tex
    loadedTextures[path] = tex
    tex
