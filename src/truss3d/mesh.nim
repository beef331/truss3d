import glm

type Mesh* = object
  verts*, normals*: seq[Vec3f]
  uvs*: seq[Vec2f]
  colors*: seq[Vec4f]
  tris*: seq[array[3, uint]]

type Vertex* = object
  vert*: Vec3f
  uv*: Vec2f
  normal*: Vec3f
  colors*: Vec4f

func toVerts*(m: Mesh): (seq[Vertex], seq[uint32]) =
  for tri in m.tris:
    let
      vert = m.verts[tri[0]]
      uv = m.uvs[tri[1]]
      norm = m.normals[tri[2]]
    result[1].add(tri[0].uint32)
    result[0].add Vertex(vert: vert, uv: uv, normal: norm)
