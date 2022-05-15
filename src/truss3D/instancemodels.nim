import shaders, models
import opengl

type
  InstancedModel*[T] = object
    ssboData*: T
    ssbo: Ssbo[T]
    model: Model
    drawCount*: int

proc loadInstancedModel*[T](path: string): InstancedModel[T] =
  result.model = loadModel(path)
  result.ssbo = genSsbo[T](1)

proc reuploadSsbo*(instModel: InstancedModel) =
  instModel.ssboData.copyTo instModel.ssbo


proc render*(instModel: InstancedModel) =
  instModel.ssbo.bindBuffer()
  for buf in instModel.model.buffers:
    glBindVertexArray(buf.vao)
    glDrawElementsInstanced(GlTriangles, buf.size, GlUnsignedInt, nil, instModel.drawCount.GlSizei)
  glBindVertexArray(0)

proc render*(instModel: InstancedModel, binding: int) =
  instModel.ssbo.bindBuffer(binding)
  for buf in instModel.model.buffers:
    glBindVertexArray(buf.vao)
    glDrawElementsInstanced(GlTriangles, buf.size, GlUnsignedInt, nil, instModel.drawCount.GlSizei)
  glBindVertexArray(0)
  unbindSsbo()
