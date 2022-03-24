import shaders, models
import opengl

type
  InstancedModel*[T] = object
    ssboData*: T
    ssbo: Ssbo[T]
    model: Model

template getType(instModel: untyped): auto =
  typeof(instModel.ssboData)

proc loadInstancedModel*[T: array](path: string): InstancedModel[T] =
  result.model = loadModel(path)
  result.ssbo = genSsbo[T](1)

proc reuploadSsbo*(instModel: InstancedModel) =
  instModel.ssboData.copyTo instModel.ssbo


proc render*(instModel: InstancedModel) =
  for buf in instModel.model.buffers:
    glBindVertexArray(buf.vao)
    glDrawElementsInstanced(GlTriangles, buf.size, GlUnsignedInt, nil, instModel.ssboData.len.GlSizei)
  glBindVertexArray(0)
