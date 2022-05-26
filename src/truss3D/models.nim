import assimp, opengl, vmath, chroma
import shaders
import std/[macros, os]

type
  Mesh* = object
    vao*: Gluint
    size*: GLsizei
    indices*: Gluint
    matrix: Mat4

  Model* = object
    buffers*: seq[Mesh]

  VertIter* = iterable[Vec2 or Vec3]
  IndicesIter* = iterable[uint32]
  UvIter* = iterable[Vec2]
  ColorIter* = iterable[Color]

  MeshData*[T: Vec2 or Vec3] = object
    verts*: seq[T]
    indices*: seq[uint32]
    normals*: seq[Vec3]
    uvs*: seq[Vec2]
    colors*: seq[Color]

var modelPath* = ""

proc loadModel*(path: string): Model =
  var scene = aiImportFile(path, {})
  if scene == nil:
    scene = aiImportFile(cstring(modelPath / path), {})
    if scene == nil:
      raise newException(IOError, path & " invalid model file")
  for mesh in scene.imeshes:
    type VboKinds = enum
      vert, norm, uv, col
    var vbos: array[VboKinds, Gluint]
    let
      hasNormals = mesh.hasNormals
      hasUvs = mesh.hasUvs()
      hasColours = mesh.hasColors()

    glGenBuffers(1, vbos[vert].addr)
    glBindBuffer(GlArrayBuffer, vbos[vert])
    glBufferData(GlArrayBuffer, mesh.vertexCount * sizeof(TVector3d), mesh.vertices, GlStaticDraw)

    if hasNormals:
      glGenBuffers(1, vbos[norm].addr)
      glBindBuffer(GlArrayBuffer, vbos[norm])
      glBufferData(GlArrayBuffer, mesh.vertexCount * sizeof(TVector3d), mesh.normals, GlStaticDraw)

    if hasUvs:
      glGenBuffers(1, vbos[uv].addr)
      glBindBuffer(GlArrayBuffer, vbos[uv])
      glBufferData(GlArrayBuffer, mesh.vertexCount * sizeof(TVector3d), mesh.texCoords[0], GlStaticDraw)

    if hasColours:
      glGenBuffers(1, vbos[col].addr)
      glBindBuffer(GlArrayBuffer, vbos[col])
      glBufferData(GlArrayBuffer, mesh.vertexCount * sizeof(TColor4d), mesh.colors[0], GlStaticDraw)

    var msh: Mesh
    glGenBuffers(1, msh.indices.addr)
    glBindBuffer(GlElementArrayBuffer, msh.indices)

    var indices = newSeqOfCap[cint](mesh.faceCount * 3)

    for face in mesh.ifaces:
      assert face.indexCount == 3, "Only supporting triangulated models"
      let start = indices.len
      indices.setLen(start + face.indexCount)
      copyMem(indices[start].addr, face.indices, face.indexCount * sizeof(cint))

    msh.size = indices.len.GlSizei

    glBufferData(
      GlElementArrayBuffer,
      msh.size * sizeof(cint),
      indices[0].addr,
      GlStaticDraw)

    glGenVertexArrays(1, msh.vao.addr)
    glBindVertexArray(msh.vao)
    glBindBuffer(GlArrayBuffer, vbos[vert])
    glVertexAttribPointer(0, 3, cGlFloat, GlFalse, 0, nil)
    glEnableVertexAttribArray(0)

    if hasNormals:
      glBindBuffer(GlArrayBuffer, vbos[norm])
      glVertexAttribPointer(1, 3, cGlFloat, GlTrue, 0, nil)
      glEnableVertexAttribArray(1)

    if hasUvs:
      glBindBuffer(GlArrayBuffer, vbos[uv])
      glVertexAttribPointer(2, 3, cGlFloat, GlTrue, 0, nil)
      glEnableVertexAttribArray(2)

    if hasColours:
      glBindBuffer(GlArrayBuffer, vbos[col])
      glVertexAttribPointer(3, 4, cGlFloat, GlTrue, 0, nil)
      glEnableVertexAttribArray(3)

    glBindBuffer(GlElementArrayBuffer, msh.indices)
    glBindVertexArray(0)
    glBindBuffer(GlArrayBuffer, 0)
    glBindBuffer(GlElementArrayBuffer, 0)

    result.buffers.add msh
  aiReleaseImport(scene)

proc uploadData*(mesh: MeshData): Model =
  var vertVbo, normVbo, uvVbo, colVbo: Gluint
  let
    hasNormals = mesh.normals.len > 0
    hasUvs = mesh.uvs.len > 0
    hasColors = mesh.colors.len > 0

  glGenBuffers(1, vertVbo.addr)
  glBindBuffer(GlArrayBuffer, vertVbo)
  glBufferData(GlArrayBuffer, mesh.verts.len * sizeOf(mesh.type.T), mesh.verts[0].unsafeaddr, GlStaticDraw)

  if hasNormals:
    glGenBuffers(1, normVbo.addr)
    glBindBuffer(GlArrayBuffer, normVbo)
    glBufferData(GlArrayBuffer, mesh.normals.len * sizeOf(Vec3), mesh.normals[0].unsafeaddr, GlStaticDraw)

  if hasUvs:
    glGenBuffers(1, uvVbo.addr)
    glBindBuffer(GlArrayBuffer, uvVbo)
    glBufferData(GlArrayBuffer, mesh.uvs.len * sizeOf(Vec2), mesh.uvs[0].unsafeaddr, GlStaticDraw)

  if hasColors:
    glGenBuffers(1, colVbo.addr)
    glBindBuffer(GlArrayBuffer, colVbo)
    glBufferData(GlArrayBuffer, mesh.colors.len * sizeOf(Color), mesh.colors[0].unsafeaddr, GlStaticDraw)

  var msh: Mesh
  glGenBuffers(1, msh.indices.addr)
  glBindBuffer(GlElementArrayBuffer, msh.indices)

  glBufferData(
    GlElementArrayBuffer,
    mesh.indices.len * sizeof(uint32),
    mesh.indices[0].unsafeaddr,
    GlStaticDraw)

  msh.size = GlSizei(mesh.indices.len)

  glGenVertexArrays(1, msh.vao.addr)
  glBindVertexArray(msh.vao)
  glBindBuffer(GlArrayBuffer, vertVbo)
  glVertexAttribPointer(0, sizeOf(mesh.type.T) div 4, cGlFloat, GlFalse, 0, nil)
  glEnableVertexAttribArray(0)

  if hasNormals:
    glBindBuffer(GlArrayBuffer, normVbo)
    glVertexAttribPointer(1, 3, cGlFloat, GlTrue, 0, nil)
    glEnableVertexAttribArray(1)

  if hasUvs:
    glBindBuffer(GlArrayBuffer, uvVbo)
    glVertexAttribPointer(2, 2, cGlFloat, GlTrue, 0, nil)
    glEnableVertexAttribArray(2)

  if hasColors:
    glBindBuffer(GlArrayBuffer, colVbo)
    glVertexAttribPointer(3, 4, cGlFloat, GlTrue, 0, nil)
    glEnableVertexAttribArray(3)

  glBindBuffer(GlElementArrayBuffer, msh.indices)
  glBindVertexArray(0)
  glBindBuffer(GlArrayBuffer, 0)
  glBindBuffer(GlElementArrayBuffer, 0)
  result.buffers.add msh

proc render*(model: Model) =
  for buf in model.buffers:
    glBindVertexArray(buf.vao)
    glDrawElements(GlTriangles, buf.size, GlUnsignedInt, nil)
    glBindVertexArray(0)

macro renderWith*(model: Model, shader: Shader, body: untyped): untyped =
  result = newStmtList()
  for x in body:
    let
      name = x[0]
      val = x[1]
    result.add quote do:
      `shader`.setUniform(`name`, `val`)
  result.add quote do:
    render(`model`)

template append*(m: var MeshData, ind: IndicesIter) =
  let start = m.indices.len.uint32
  for i in ind:
    m.indices.add start + i

template appendColor*(m: var MeshData, colIter: ColorIter) =
  for x in colIter:
    m.colors.add(x)
  m.colors.setLen(m.verts.len)

template appendUV*(m: var MeshData, uvIter: UvIter) =
  for x in uvIter:
    m.uvs.add(x)
  m.uvs.setLen(m.verts.len)

template appendVerts*(m: var MeshData[Vec2], vertIter: VertIter) =
  for v in vertIter:
    when typeof(v) is Vec3:
      m.verts.add v.xy
    else:
      m.verts.add v

template appendVerts*(m: var MeshData[Vec3], vertIter: VertIter) =
  for v in vertIter:
    when typeOf(v) is Vec2:
      m.verts.add vec3(v)
    else:
      m.verts.add v

template append*(m: var MeshData[Vec3], verts: VertIter, ind: IndicesIter) =
  m.append(verts)
  m.append(ind)

template append*(m: var MeshData[Vec2], vertIter: VertIter, ind: IndicesIter) =
  m.appendVerts(vertIter)
  m.append(ind)

template append*(m: var MeshData[Vec2], vertIter: VertIter, ind: IndicesIter,
    colorIter: ColorIter) =
  for v in vertIter:
    when typeof(v) is Vec3:
      m.verts.add v.xy
    else:
      m.verts.add v
  m.appendColor(colorIter)
  m.append(ind)
