import opengl, pixie

type
  Texture* = distinct Gluint
  FrameBuffer* = distinct Gluint
  RenderBuffer* = distinct GLuint
  TextureFormat* = enum
    tfRgba
    tfRgb
    tfRg
    tfR

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


proc attachTexture*(buffer: FrameBuffer, size: IVec2, tex: Texture, format: TextureFormat) =
  glBindFrameBuffer(GlFrameBuffer, buffer.Gluint)
  glBindTexture(GlTexture2d, tex.Gluint)
  glTexImage2D(GlTexture2d, 0.Glint, textureLut[format].Glint, size.x.GlSizei, size.y.GlSizei, 0.Glint, textureLut[format], GlUnsignedByte, nil)
  glFramebufferTexture2D(GlFrameBuffer, GlColorAttachment0, GL_TEXTURE_2D, tex.Gluint, 0);  
  glBindFrameBuffer(GlFrameBuffer, 0)

proc attachTexture*(buffer: FrameBuffer, size: IVec2, format: TextureFormat) =
  glBindFrameBuffer(GlFrameBuffer, buffer.Gluint)
  let tex = genTexture()
  glBindTexture(GlTexture2d, tex.Gluint)
  glTexImage2D(GlTexture2d, 0.Glint, textureLut[format].Glint, size.x.GlSizei, size.y.GlSizei, 0.Glint, textureLut[format], GlUnsignedByte, nil)
  glFramebufferTexture2D(GlFrameBuffer, GlColorAttachment0, GL_TEXTURE_2D, tex.Gluint, 0);  
  glBindFrameBuffer(GlFrameBuffer, 0)

proc genFrameBuffer*(): FrameBuffer =
  glGenFramebuffers(1, result.Gluint.addr)
  glBindFrameBuffer(GlFrameBuffer, result.Gluint)
  glClearColor(0, 0, 0, 0)
  glClearDepth(1.0)
  glBindFrameBuffer(GlFrameBuffer, 0)

proc genFrameBuffer*(size: Ivec2, format: TextureFormat): FrameBuffer =
  result = genFrameBuffer()
  glGenFramebuffers(1, result.Gluint.addr)
  result.attachTexture(size, format)
  glBindFrameBuffer(GlFrameBuffer, 0)
