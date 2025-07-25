import opengl, vmath, chroma, vmath
import shaders
import std/[macros, os]
import truss3D/logging

const useAssimp*{.booldefine:"truss3D.useAssimp".} = true

when useAssimp:
  import assimp

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

when useAssimp:
  proc loadModel*(path: string): Model =
    var scene = aiImportFile(path, {flipUvs})
    if scene == nil:
      scene = aiImportFile(cstring(modelPath / path), {})
      if scene == nil:
        error path, " invalid model file."
        raise newException(IOError, path & " invalid model file")

    var meshInds: seq[(cint, TMatrix4x4)]
    for child in scene.rootNode.ichildren:
      for meshInd in child.meshes.toOpenArray(0, child.meshCount - 1):
        meshInds.add (meshInd, child.transformation)

    if meshInds.len == 0: # In the case we don't find a tree, assume it's just an empty model file
      for x in 0..<scene.meshCount:
        meshInds.add (x,
          [
            1f, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
          ]
        )

    for (meshInd, transform) in meshInds:
      let mesh = scene.meshes[meshInd]
      type VboKinds = enum
        vert, norm, uv, col
      const vboSize: array[VboKinds, GLsizei] = [Glsizei sizeof TVector3d, Glsizei sizeof TVector3d, Glsizei sizeof TVector3d, Glsizei sizeof TColor4d]
      var vbos: array[VboKinds, Gluint]
      let
        components = block:
          var comps = {vert}
          if mesh.hasNormals():
            comps.incl norm
          if mesh.hasUvs():
            comps.incl uv
          if mesh.hasColors():
            comps.incl col
          comps

      let mat = transform
      for vertInd in 0..<mesh.vertexCount:
        let
          vert = cast[Vec3](mesh.vertices[vertInd]).vec4(1)

          tsfm = mat4(
            vec4(mat[0], mat[4], mat[8], mat[12]),
            vec4(mat[1], mat[5], mat[9], mat[13]),
            vec4(mat[2], mat[6], mat[10], mat[14]),
            vec4(mat[3], mat[7], mat[11], mat[15])
          )

        mesh.vertices[vertInd] = cast[TVector3D]((tsfm * vert).xyz)
        if norm in components:
          let normal = cast[Vec3](mesh.normals[vertInd])
          mesh.normals[vertInd] = cast[TVector3D](mat3(tsfm[0].xyz, tsfm[1].xyz, tsfm[2].xyz) * normal)

      glCreateBuffers(ord(VboKinds.high) + 1, vbos[vert].addr)
      glNamedBufferStorage(vbos[vert], mesh.vertexCount * vboSize[vert], mesh.vertices, GLbitfield 0)

      if norm in components:
        glNamedBufferStorage(vbos[norm], mesh.vertexCount * vboSize[norm], mesh.normals, GLbitfield 0)

      if uv in components:
        glNamedBufferStorage(vbos[uv], mesh.vertexCount * vboSize[uv], mesh.texCoords[0], GLbitfield 0)

      if col in components:
        glNamedBufferStorage(vbos[col], mesh.vertexCount * vboSize[col], mesh.colors[0], GLbitfield 0)

      var msh: Mesh
      glCreateVertexArrays(1, msh.vao.addr)
      glCreateBuffers(1, msh.indices.addr)

      var
        indices = newSeqOfCap[cint](mesh.faceCount * 3)

      for face in mesh.ifaces:
        if face.indexCount != 3:
          raise (ref ValueError)(msg: "Only acceepting triangulated meshes")
        indices.add cast[ptr array[3, cint]](face.indices)[]

      msh.size = indices.len.GlSizei

      glNamedBufferStorage(msh.indices,
        msh.size * sizeof(cint),
        indices[0].addr,
        GLbitfield 0
      )

      glVertexArrayElementBuffer(msh.vao, msh.indices)

      for ind, vbo in vbos.pairs:
        if ind in components:
          glVertexArrayVertexBuffer(msh.vao, Gluint ind, vbo, 0, vboSize[ind])
          glEnableVertexArrayAttrib(msh.vao, Gluint ind)
          case ind
          of vert:
            glVertexArrayAttribFormat(msh.vao, Gluint vert, 3, cGlFloat, GlFalse, 0)
          of norm:
            glVertexArrayAttribFormat(msh.vao, Gluint norm, 3, cGlFloat, GlFalse, 0)
          of uv:
            glVertexArrayAttribFormat(msh.vao, Gluint uv, 3, cGlFloat, GlFalse, 0)
          of col:
            glVertexArrayAttribFormat(msh.vao, Gluint col, 4, cGlFloat, GlFalse, 0)

      glVertexArrayElementBuffer(msh.vao, msh.indices)

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
