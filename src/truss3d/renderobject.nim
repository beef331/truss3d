import aglet
type
  RenderObject*[T] = object
    pos*, rot*, scale*: Vec3f
    mesh*: Mesh[T]

proc initRenderObject*[T](pos, rot, scale: Vec3f, mesh: Mesh[T]): RenderObject[T] = RenderObject[T](pos: pos, rot: rot, scale: scale, mesh: mesh)