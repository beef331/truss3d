import shaders, textures
import pkg/[vmath, union, opengl]
import std/tables

const bufferCount = 32


type
  PropertyType = union(float32 | int32 | uint32 | Vec2 | IVec2 | UVec2 | Vec3 | IVec3 | UVec3 | Vec4 | IVec4 | UVec4 | Mat2 | Mat3 | Mat4 | ref Texture | Texture | ptr Texture)

  MaterialProperty = object
    uniformName: string
    data: PropertyType

  Material* = object
    uniforms: Table[string, MaterialProperty]
    buffers: array[32, Gluint]
    shader*: ref Shader

proc setProperty*[T](material: var Material, name: string, val: sink T) =
  material.uniforms[name] = MaterialProperty(
    uniformName: name,
    data: ensureMove(val) as PropertyType
  )

proc setUniform*(shader: Shader, name: string, tex: ref Texture | ptr Texture) =
  shader.setUniform(name, tex[])

proc setUniform*(shader: Shader, prop: MaterialProperty) =
  for name, field in prop.fieldPairs:
    when name notin ["uniformName", "kind"]:
      field.unpack:
        shader.setUniform(prop.uniformName, it)
        return

proc setBuffer*[T](mat: var Material, binding: 0..31, buffer: Ssbo[T]) =
  mat.buffers[binding] = buffer.Gluint


template with*(material: Material, body: untyped) =
  with material.shader[]:
    for name, uniform in material.uniforms.pairs:
      assert name == uniform.uniformName # Dumb but assurance is assurance
      material.shader[].setUniform(uniform)
    for i, buffer in material.buffers.pairs:
      if buffer != 0:
        glBindBufferBase(GlShaderStorageBuffer, Gluint(i), buffer)
    body
