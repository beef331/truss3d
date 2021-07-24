import assimp, opengl, vmath


type
  Mesh* = object
    vao*: Gluint
    size*: GLsizei
    indices*: Gluint
    matrix: Mat4
  Model* = object
    buffers*: seq[Mesh]


proc loadModel*(path: string): Model =
  let scene = aiImportFile(path, TargetRealtimeQuality)
  for mesh in scene.imeshes:
    var vertVbo, normVbo, uvVbo: Gluint
    let
      hasNormals = mesh.hasNormals
      hasUvs =  mesh.texCoords[0] != nil
    glGenBuffers(1, vertVbo.addr)
    glBindBuffer(GlArrayBuffer, vertVbo)
    glBufferData(GlArrayBuffer, mesh.vertexCount * sizeof(TVector3d), mesh.vertices, GlStaticDraw)

    if hasNormals:
      glGenBuffers(1, normVbo.addr)
      glBindBuffer(GlArrayBuffer, normVbo)
      glBufferData(GlArrayBuffer, mesh.vertexCount * sizeof(TVector3d), mesh.normals, GlStaticDraw)
    
    if hasUvs:
      glGenBuffers(1, uvVbo.addr)
      glBindBuffer(GlArrayBuffer, uvVbo)
      glBufferData(GlArrayBuffer, mesh.vertexCount * sizeof(TVector3d), mesh.texCoords[0], GlStaticDraw)


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
    glBindBuffer(GlArrayBuffer, vertVbo)
    glVertexAttribPointer(0, 3, cGlFloat, GlFalse, 0, nil)
    glEnableVertexAttribArray(0)

    if hasNormals:
      glBindBuffer(GlArrayBuffer, normVbo)
      glVertexAttribPointer(1, 3, cGlFloat, GlTrue, 0, nil)
      glEnableVertexAttribArray(1)

    if hasUvs:
      glBindBuffer(GlArrayBuffer, uvVbo)
      glVertexAttribPointer(2, 3, cGlFloat, GlTrue, 0, nil)
      glEnableVertexAttribArray(2)

    result.buffers.add msh
  aiReleaseImport(scene)

proc render*(model: Model) =
  for buf in model.buffers:
    glBindVertexArray(buf.vao)
    glBindBuffer(GlElementArrayBuffer, buf.indices)
    glDrawElements(GlTriangles, buf.size, GlUnsignedInt, nil)