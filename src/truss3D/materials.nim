import shaders, textures
import pkg/[vmath, union, opengl]
import std/tables

const bufferCount = 32


template property(T): typedesc = T | (ref T) | ptr T

type
  Property =
    property(float32) |
    property(int32) |
    property(uint32) |
    property(Vec2) |
    property(IVec2) |
    property(UVec2) |
    property(Vec3) |
    property(IVec3) |
    property(UVec3) |
    property(Vec4) |
    property(IVec4) |
    property(UVec4) |
    property(Mat2) |
    property(Mat3) |
    property(Mat4) |
    property(Texture) |
    property(TextureArray)

  PropertyType = union(Property)

  MaterialProperty = object
    uniformName: string
    data: PropertyType
    required: bool

  Material* = object
    uniforms: Table[string, MaterialProperty]
    buffers: array[bufferCount, Gluint]
    usedBuffers: set[0 .. bufferCount - 1]
    shader*: ref Shader

proc setProperty*[T: Property](material: var Material, name: string, val: sink T, required = true) =
  material.uniforms[name] = MaterialProperty(
    uniformName: name,
    data: ensureMove(val) as PropertyType,
    required: required
  )

proc setUniform*(shader: Shader, name: string, tex: ref | ptr, required: bool) =
  shader.setUniform(name, tex[], required)

proc setUniform*(shader: Shader, prop: MaterialProperty) =
  prop.data.unpack(it):
    shader.setUniform(prop.uniformName, it, prop.required)

proc setBuffer*[T](mat: var Material, binding: 0 .. bufferCount - 1, buffer: Ssbo[T]) =
  if buffer.Gluint == 0:
    mat.usedBuffers.excl binding
  else:
    mat.usedBuffers.incl binding
  mat.buffers[binding] = buffer.Gluint

template with*(material: Material, body: untyped) =
  with material.shader[]:
    for name, uniform in material.uniforms.pairs:
      assert name == uniform.uniformName # Dumb but assurance is assurance
      material.shader[].setUniform(uniform)
    for ind in material.usedBuffers:
      glBindBufferBase(GlShaderStorageBuffer, Gluint(ind), material.buffers[ind])
    body


