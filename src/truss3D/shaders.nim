import opengl
import std/[tables, typetraits, os]
import textures

type
  ShaderKind* = enum
    Vertex, Fragment, Compute
  Ubo*[T] = distinct Gluint
  Ssbo*[T: array or seq] = distinct Gluint
  Shader* = distinct Gluint

  ShaderPath* = distinct string
  ShaderFile* = distinct string
  ShaderSource = ShaderPath or ShaderFile

const KindLut = [
  Vertex: GlVertexShader,
  Fragment: GlFragmentShader,
  Compute: GlComputeShader
]

var shaderPath* = ""

proc makeActive*(shader: Shader) = glUseProgram(Gluint(shader))

proc getActiveShader*(): Shader =
  glGetIntegerv(GlCurrentProgram, cast[ptr Glint](addr result))

template with*(shader: Shader, body: untyped) =
  var activeProgram: Gluint
  glGetIntegerv(GlCurrentProgram, cast[ptr Glint](addr activeProgram))
  try:
    shader.makeActive
    body
  finally:
    Shader(activeProgram).makeActive

proc loadShader*(shader: string, kind: ShaderKind): Gluint =
  let
    shaderProg = shader.cstring
    shaderLen = shader.len.GLint
    shaderId = glCreateShader(KindLut[kind])
  glShaderSource(shaderId, 1, cast[cstringArray](shaderProg.unsafeAddr), shaderLen.unsafeaddr)
  glCompileShader(shaderId)
  var success = 0.Glint
  glGetShaderiv(shaderId, GlCompileStatus, success.addr)

  if success == 0:
    var
      buff = newString(512)
      len = 0.GlSizeI
    glGetShaderInfoLog(shaderId, 512, len.addr, buff[0].addr)
    buff.setLen(len.int)
    echo buff

  result = shaderId

proc loadShader*(vert, frag: distinct ShaderSource): Shader =
  let
    vert =
      when vert is ShaderPath:
        try:
          readFile(vert.string)
        except:
          readFile(shaderPath / vert.string)
      else:
        vert.string
    frag =
      when frag is ShaderPath:
        try:
          readFile(frag.string)
        except:
          readFile(shaderPath / frag.string)
      else:
        frag.string
    vs = loadShader(vert, Vertex)
    fs = loadShader(frag, Fragment)
  result = glCreateProgram().Shader
  glAttachShader(Gluint result, vs)
  glAttachShader(Gluint result, fs)
  glLinkProgram(Gluint result)

  var success = Glint 1

  glGetProgramIv(Gluint result, GlLinkStatus, success.addr)
  if success == 0:
    var msg = newString(512)
    glGetProgramInfoLog(Gluint result, 512, nil, msg[0].addr)
    echo msg
  glDeleteShader(vs)
  glDeleteShader(fs)

proc genUbo*[T](shader: Gluint, binding: Natural): Ubo[T] =
  glCreateBuffers(1, result.Gluint.addr)
  glBindBufferbase(GlUniformBuffer, binding.Gluint, result.Gluint)

proc copyTo*[T](val: T, ubo: Ubo[T]) =
  glNamedBufferData(ubo.Gluint, sizeof(T), val.unsafeAddr, GlDynamicDraw)

proc bindBuffer*(ssbo: Ssbo) =
  glBindBuffer(GlShaderStorageBuffer, Gluint(ssbo))

proc bindBuffer*(ssbo: Ssbo, binding: int) =
  glBindBufferbase(GlShaderStorageBuffer, GLuint(binding), Gluint(ssbo))

proc unbindSsbo*() =
  glBindBuffer(GlShaderStorageBuffer, 0)

proc genSsbo*[T](binding: Natural): Ssbo[T] =
  glCreateBuffers(1, result.Gluint.addr)
  result.bindBuffer()
  glBindBufferbase(GlShaderStorageBuffer, GLuint(binding), result.Gluint)
  unbindSsbo()

proc copyTo*[T](val: T, ssbo: Ssbo[T]) =
  let size =
    when T is seq:
      val.len * sizeof(val[0])
    else:
      sizeof(val)
  ssbo.bindBuffer()
  glNamedBufferData(Gluint(ssbo), GLsizeiptr(size), val[val.low].unsafeAddr, GlDynamicDraw)
  unbindSsbo()

proc copyTo*[T](val: T, ssbo: Ssbo[T], slice: Slice[int]) =
  let newData = val[slice.a].unsafeAddr
  ssbo.bindBuffer()
  glNamedBufferData(GlShaderStorageBuffer, slice.a * sizeof(int16), (slice.b - slice.a) * sizeOf(
      int16), newData)
  unbindSsbo()

type
  Vec2 = concept v
    v.x is float32
    v.y is float32
    not compiles(v.z)
  Vec3 = concept v
    v.x is float32
    v.y is float32
    v.z is float32
    not compiles(v.w)
  Vec4 = concept v
    v.x is float32
    v.y is float32
    v.z is float32
    v.w is float32
  Mat = concept type M
    supportsCopyMem(M)
  Mat2V = concept m, type M
    m[0] is Vec2
  Mat3V = concept m, type M
    m[0] is Vec3
  Mat4v = concept m, type M
    m[0] is Vec4

  Mat2f = concept m, type M
    m[0] is float32
    sizeof(M) == 4 * sizeof(float32)
  Mat3f = concept m, type M
    m[0] is float32
    sizeof(M) == 9 * sizeof(float32)
  Mat4f = concept m, type M
    m[0] is float32
    sizeof(M) == 16 * sizeof(float32)

  Mat2 = Mat and (Mat2V or Mat2f) and not (Vec2 or Vec3 or Vec4)
  Mat3 = Mat and (Mat3V or Mat3f) and not (Vec2 or Vec3 or Vec4)
  Mat4 = Mat and (Mat4V or Mat4f) and not (Vec2 or Vec3 or Vec4)

template insideUniform(name: string, value: auto, body: untyped) {.dirty.} =
  bind glGetUniformLocation, Gluint
  when declared(shader):
    with shader:
      let loc = glGetUniformLocation(Gluint(shader), uniform)
      if loc != -1:
        body
  else:
    let
      shader = getActiveShader()
      loc = glGetUniformLocation(Gluint(shader), uniform)
    if loc != -1:
      body

template makeSetter(T: typedesc, body: untyped) {.dirty.} =
  proc setUniform*(uniform: string, value: T) =
    insideUniform(uniform, value):
      body
  proc setUniform*(shader: Shader, uniform: string, value: T) =
    insideUniform(uniform, value):
      body

makeSetter(float32):
  glUniform1f(loc, value.GlFloat)

makeSetter(int32):
  glUniform1i(loc, value.Glint)

makeSetter(Vec2):
  mixin x, y, z, w
  glUniform2f(loc, value.x, value.y)

makeSetter(Vec3):
  mixin x, y, z, w
  glUniform3f(loc, value.x, value.y, value.z)

makeSetter(Vec4):
  mixin x, y, z, w
  glUniform4f(loc, value.x, value.y, value.z, value.w)

makeSetter(Mat2):
  glUniformMatrix2fv(loc, 1, GlFalse,cast[ptr float32](value.unsafeAddr))

makeSetter(Mat3):
  glUniformMatrix3fv(loc, 1, GlFalse, cast[ptr float32](value.unsafeAddr))

makeSetter(Mat4):
  glUniformMatrix4fv(loc, 1, GlFalse, cast[ptr float32](value.unsafeaddr))

makeSetter(Texture):
  glBindTextureUnit(loc.Gluint, value.GLuint);
  glUniform1i(loc, loc)

makeSetter(TextureArray):
  glBindTextureUnit(loc.Gluint, value.GLuint);
  glUniform1i(loc, loc)

