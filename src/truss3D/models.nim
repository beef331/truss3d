import assimp, opengl


type
  Mesh* = object
    vao*: Gluint
    size*: GLsizei
  Model* = object
    buffers*: seq[Mesh]


proc loadModel*(path: string): Model =
  let scene = aiImportFile(path, TargetRealtimeQuality)
  for mesh in scene.imeshes:
    var vbo: Gluint
    glGenBuffers(1, vbo.addr)
    glBindBuffer(GlArrayBuffer, vbo)
    glBufferData(GlArrayBuffer, mesh.vertexCount * sizeof(TVector3d), mesh.vertices, GlStaticDraw)

    var mesh = Mesh(size: mesh.vertexCount.GlSizei)
    glGenVertexArrays(1, mesh.vao.addr)
    glBindVertexArray(mesh.vao)
    glBindBuffer(GlArrayBuffer, vbo)
    glVertexAttribPointer(0, 3, cGlFloat, GlFalse, 0, nil)
    glEnableVertexAttribArray(0)

    result.buffers.add mesh
