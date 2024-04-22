import opengl
import std/[tables, typetraits, os]
import textures, mathtypes, logging

type
  ShaderKind* = enum
    Vertex, Fragment, Compute
  Ubo*[T] = distinct Gluint
  Ssbo*[T: array or seq] = distinct Gluint
  Shader* = distinct Gluint

  ShaderPath* = distinct string
  ShaderFile* = distinct string
  ShaderSource = ShaderPath or ShaderFile

proc `=dup`(shader: Shader): Shader {.error.}
proc `=dup`[T](ssbo: Ssbo[T]): Ssbo[T] {.error.}


proc `=destroy`[T](ssbo: Ssbo[T]) =
  glDeleteBuffers(1, GLuint(ssbo).addr)

proc `=destroy`(shader: Shader) =
  if Gluint(shader) > 0:
    glDeleteShader(Gluint(shader))



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
    glUseProgram(activeProgram)

proc loadShader*(shader: string, kind: ShaderKind, name: string): Gluint =
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
    if name.len > 0:
      error "Failed to compile: ", name , "\n", buff
    result = Gluint 0

  else:
    result = shaderId

proc loadShader*(vert, frag: distinct ShaderSource): Shader =
  when vert is ShaderPath:
    info "Loading Vertex Shader: ", string vert
  when frag is ShaderPath:
    info "Loading Frag Shader: ", string frag
  let
    vert =
      when vert is ShaderPath:
        try:
          readFile(vert.string)
        except IoError, OSerror:
          readFile(shaderPath / vert.string)
      else:
        vert.string
    frag =
      when frag is ShaderPath:
        try:
          readFile(frag.string)
        except IoError, OsError:
          readFile(shaderPath / frag.string)
      else:
        frag.string
    vsName =
      when vert is ShaderPath:
        string vert
      else:
        ""
    fsName =
      when frag is ShaderPath:
        string frag
      else:
        ""
    vs = loadShader(vert, Vertex, vsName)
    fs = loadShader(frag, Fragment, fsName)

  if Gluint(0) in [Gluint(vs), Gluint(fs)]:
    return
    
  result = glCreateProgram().Shader
  glAttachShader(Gluint result, vs)
  glAttachShader(Gluint result, fs)
  glLinkProgram(Gluint result)

  var success = Glint 1

  glGetProgramIv(Gluint result, GlLinkStatus, success.addr)
  if success == 0:
    var msg = newString(512)
    glGetProgramInfoLog(Gluint result, 512, nil, msg[0].addr)
    error msg
  glDeleteShader(vs)
  glDeleteShader(fs)

proc genUbo*[T](shader: Gluint, binding: Natural): Ubo[T] =
  glCreateBuffers(1, result.Gluint.addr)
  glBindBufferbase(GlUniformBuffer, binding.Gluint, result.Gluint)

proc copyTo*[T](val: T, ubo: Ubo[T]) =
  when T is seq:
    glNamedBufferData(ubo.Gluint, sizeof(T) * val.len, val[0].unsafeAddr, GlDynamicDraw)
  else:
    glNamedBufferData(ubo.Gluint, sizeof(T), val.unsafeAddr, GlDynamicDraw)

proc bindBuffer*(ssbo: Ssbo) =
  glBindBuffer(GlShaderStorageBuffer, Gluint(ssbo))

proc bindBuffer*(ssbo: Ssbo, binding: int) =
  glBindBufferbase(GlShaderStorageBuffer, GLuint binding , Gluint ssbo)

proc unbindSsbo*() =
  glBindBuffer(GlShaderStorageBuffer, 0)

proc genSsbo*[T](binding: Natural): Ssbo[T] =
  glCreateBuffers(1, Gluint(result).addr)
  result.bindBuffer()
  glBindBufferbase(GlShaderStorageBuffer, GLuint(binding), Gluint result)
  unbindSsbo()

proc copyTo*[T](val: T, ssbo: Ssbo[T], buffer = 0) =
  let size =
    when T is seq:
      val.len * sizeof(val[0])
    else:
      sizeof(val)
  ssbo.bindBuffer(buffer)
  glNamedBufferData(Gluint(ssbo), GLsizeiptr(size), val[val.low].unsafeAddr, GlDynamicDraw)
  unbindSsbo()

proc copyTo*[T](val: openArray, ssbo: Ssbo[T], buffer = 0) =
  ssbo.bindBuffer(buffer)
  const size = sizeof(typeof(val[0])) 
  glNamedBufferData(Gluint ssbo, GlSizeIPtr(sizeof(T) * val.len), val[0].addr, GlDynamicDraw)
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
  bind glGetUniformLocation, Gluint, error
  when declared(shader):
    with shader:
      let loc = glGetUniformLocation(Gluint(shader), uniform)
      if loc == -1:
        error "Cannot find uniform: ", name
      body
  else:
    var shader = getActiveShader()
    let loc = glGetUniformLocation(Gluint(shader), uniform)
    if loc == -1:
      error "Cannot find uniform: ", name
    body
    `=wasMoved`(shader)

template makeSetter(T: typedesc, body: untyped) {.dirty.} =
  proc setUniform*(uniform: string, value: T) =
    bind error
    insideUniform(uniform, value):
      body
  proc setUniform*(shader: Shader, uniform: string, value: T) =
    bind error
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

