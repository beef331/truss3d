type
  Vec2* = concept v
    v.x is float32
    v.y is float32
    not compiles(v.z)
  Vec3* = concept v
    v.x is float32
    v.y is float32
    v.z is float32
    not compiles(v.w)
  Vec4* = concept v
    v.x is float32
    v.y is float32
    v.z is float32
    v.w is float32

  Color*[T] = concept c
    c.r is T
    c.g is T
    c.b is T
    c.a is T


  Mat* = concept type M
    supportsCopyMem(M)
  Mat2V* = concept m, type M
    m[0] is Vec2
  Mat3V* = concept m, type M
    m[0] is Vec3
  Mat4v* = concept m, type M
    m[0] is Vec4

  Mat2f* = concept m, type M
    m[0] is float32
    m isnot openArray
    sizeof(M) == 4 * sizeof(float32)
  Mat3f* = concept m, type M
    m[0] is float32
    m isnot openArray
    sizeof(M) == 9 * sizeof(float32)
  Mat4f* = concept m, type M
    m[0] is float32
    sizeof(M) == 16 * sizeof(float32)

  Mat2* = Mat and (Mat2V or Mat2f) and not (Vec2 or Vec3 or Vec4 or openArray[float32])
  Mat3* = Mat and (Mat3V or Mat3f) and not (Vec2 or Vec3 or Vec4 or openArray[float32])
  Mat4* = Mat and (Mat4V or Mat4f) and not (Vec2 or Vec3 or Vec4 or openArray[float32])
