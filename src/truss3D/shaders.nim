import opengl, vmath, pixie
import std/[tables, typetraits, os]
import textures

type
  ShaderKind* = enum
    Vertex, Fragment, Compute
  Ubo*[T] = distinct Gluint
  Ssbo*[T: array] = distinct Gluint
  Shader* = distinct Gluint

const KindLut = [
  Vertex: GlVertexShader,
  Fragment: GlFragmentShader,
  Compute: GlComputeShader
]

var shaderPath* = ""

proc makeActive*(shader: Shader) = glUseProgram(Gluint(shader))

template with*(shader: Shader, body: untyped) =
  shader.makeActive
  body


proc loadShader*(shader: string, kind: ShaderKind): Gluint =
  let
    shaderProg = allocCStringArray([shader])
    shaderLen = shader.len.GLint
    shaderId = glCreateShader(KindLut[kind])
  glShaderSource(shaderId, 1, shaderProg, shaderLen.unsafeaddr)
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

  shaderProg.deallocCStringArray

proc loadShader*(vert, frag: string, isPath = true): Shader =
  let
    vert =
      if isPath:
        try:
          readFile(vert)
        except:
          readFile(shaderPath / vert)
      else:
        vert
    frag =
      if isPath:
        try:
          readFile(frag)
        except:
          readFile(shaderPath / frag)
      else:
        frag
    vs = loadShader(vert, Vertex)
    fs = loadShader(frag, Fragment)
  result = glCreateProgram().Shader
  glAttachShader(result.Gluint, vs)
  glAttachShader(result.Gluint, fs)
  glLinkProgram(result.Gluint)

  var success = 1.Glint

  glGetProgramIv(result.Gluint, GlLinkStatus, success.addr)
  if success == 0:
    var msg = newString(512)
    glGetProgramInfoLog(result.Gluint, 512, nil, msg[0].addr)
    echo msg
  glDeleteShader(vs)
  glDeleteShader(fs)

proc genUbo*[T](shader: Gluint, binding: Natural): Ubo[T] =
  glCreateBuffers(1, result.Gluint.addr)
  glBindBufferbase(GlUniformBuffer, binding.Gluint, result.Gluint)
proc copyTo*[T](val: T, ubo: Ubo[T]) =
  glNamedBufferData(ubo.Gluint, sizeof(T), val.unsafeAddr, GlDynamicDraw)

proc genSsbo*[T](binding: Natural): Ssbo[T] =
  glCreateBuffers(1, result.Gluint.addr)
  glBufferData(GlShaderStorageBuffer, sizeof(T), nil, GlDynamicDraw)
  glBindBufferbase(GlShaderStorageBuffer, GLuint(binding), result.Gluint)

proc copyTo*[T](val: T, ssbo: Ssbo[T]) =
  glNamedBufferData(ssbo.Gluint, sizeof(T).GLsizeiptr, val.unsafeAddr, GlDynamicDraw)

proc copyTo*[T](val: T, ssbo: Ssbo[T], slice: Slice[int]) =
  let newData = val[slice.a].unsafeAddr
  glNamedBufferData(GlShaderStorageBuffer, slice.a * sizeof(int16), (slice.b - slice.a) * sizeOf(
      int16), newData)

proc setUniform*(shader: Shader, uniform: string, value: float32) =
  with shader:
    let loc = glGetUniformLocation(shader.Gluint, uniform)
    if loc != -1:
      glUniform1f(loc, value.GlFloat)

proc setUniform*(shader: Shader, uniform: string, value: int32) =
  with shader:
    let loc = glGetUniformLocation(shader.Gluint, uniform)
    if loc != -1:
      glUniform1i(loc, value.Glint)

proc setUniform*(shader: Shader, uniform: string, value: Vec4) =
  with shader:
    let loc = glGetUniformLocation(shader.Gluint, uniform)
    if loc != -1:
      glUniform4f(loc, value.x, value.y, value.z, value.w)

proc setUniform*(shader: Shader, uniform: string, value: Vec2) =
  with shader:
    let loc = glGetUniformLocation(shader.Gluint, uniform)
    if loc != -1:
      glUniform2f(loc, value.x, value.y)

proc setUniform*(shader: Shader, uniform: string, value: Color) =
  with shader:
    let loc = glGetUniformLocation(shader.Gluint, uniform)
    if loc != -1:
      glUniform4f(loc, value.r, value.g, value.b, value.a)

proc setUniform*(shader: Shader, uniform: string, value: Mat4) =
  with shader:
    let loc = glGetUniformLocation(shader.Gluint, uniform)
    if loc != -1:
      glUniformMatrix4fv(loc, 1, GlFalse, value[0, 0].unsafeAddr)

proc setUniform*(shader: Shader, uniform: string, tex: Texture) =
  with shader:
    let loc = glGetUniformLocation(shader.Gluint, uniform)
    if loc != -1:
      glBindTextureUnit(loc.Gluint, tex.GLuint);
      glUniform1i(loc, loc)
