import opengl, vmath, pixie
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

template with*(shader: Shader, body: untyped) =
  shader.makeActive
  body


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
  glCreateBuffers(1, Gluint(result).addr)
  result.bindBuffer()
  glBindBufferbase(GlShaderStorageBuffer, GLuint(binding), Gluint result)
  unbindSsbo()

proc copyTo*[T](val: T, ssbo: Ssbo[T]) =
  let size =
    when T is seq:
      val.len * sizeof(val[0])
    else:
      sizeof(val)
  ssbo.bindBuffer()
  glNamedBufferData(Gluint(ssbo), GLsizeiptr(size), val[0].unsafeAddr, GlDynamicDraw)
  unbindSsbo()

proc copyTo*[T](val: T, ssbo: Ssbo[T], slice: Slice[int]) =
  let newData = val[slice.a].unsafeAddr
  ssbo.bindBuffer()
  glNamedBufferData(GlShaderStorageBuffer, slice.a * sizeof(int16), (slice.b - slice.a) * sizeOf(
      int16), newData)
  unbindSsbo()



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
