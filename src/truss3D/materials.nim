import shaders, textures
import pkg/[vmath, union]
import std/tables


type
  PropertyType = union(float32 | int32 | uint32 | Vec2 | IVec2 | UVec2 | Vec3 | IVec3 | UVec3 | Vec4 | IVec4 | UVec4 | Mat2 | Mat3 | Mat4 | ref Texture)

  MaterialProperty = object
    uniformName: string
    data: PropertyType

  Material* = object
    uniforms: Table[string, MaterialProperty]
    shader*: ref Shader

proc setProperty*(material: var Material, name: string, val: auto) =
  material.uniforms[name] = MaterialProperty(
    uniformName: name,
    data: val as PropertyType
  )

proc setUniform(shader: Shader, name: string, tex: ref Texture) =
  shader.setUniform(name, tex[])

proc setUniform*(shader: Shader, prop: MaterialProperty) =
  for name, field in prop.fieldPairs:
    when name notin ["uniformName", "kind"]:
      field.unpack:
        shader.setUniform(prop.uniformName, it)
        return

template with*(material: Material, body: untyped) =
  with material.shader[]:
    for name, uniform in material.uniforms.pairs:
      assert name == uniform.uniformName # Dumb but assurance is assurance
      material.shader[].setUniform(uniform)
    body
