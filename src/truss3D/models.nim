import assimp, opengl


type
  Mesh* = object
    vao*: Gluint
    size*: GLsizei
    indices*: Gluint
  Model* = object
    buffers*: seq[Mesh]


proc loadModel*(path: string): Model =
  let scene = aiImportFile(path, TargetRealtimeQuality)
  for mesh in scene.imeshes:
    var vbo: Gluint

    glGenBuffers(1, vbo.addr)
    glBindBuffer(GlArrayBuffer, vbo)
    glBufferData(GlArrayBuffer, mesh.vertexCount * sizeof(TVector3d), mesh.vertices, GlStaticDraw)

    var msh = Mesh(size: mesh.vertexCount.GlSizei)
    glGenBuffers(1, msh.indices.addr)
    glBindBuffer(GlElementArrayBuffer, msh.indices)

    var indices = newSeqOfCap[cint](mesh.faceCount * 3)
    echo indices.len
    for face in mesh.ifaces:
      for index in face.iindices:
        indices.add(index)

    glBufferData(
      GlElementArrayBuffer,
      mesh.faceCount * sizeOf(cint),
      indices[0].addr,
      GlStaticDraw)



    glGenVertexArrays(1, msh.vao.addr)
    glBindVertexArray(msh.vao)
    glBindBuffer(GlArrayBuffer, vbo)
    glVertexAttribPointer(0, 3, cGlFloat, GlFalse, 0, nil)
    glEnableVertexAttribArray(0)

    result.buffers.add msh
