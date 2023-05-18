import shaders, models
import opengl

type
  InstancedModel*[T] = object
    ssboData*: T
    ssbo: Ssbo[T]
    model: Model
    drawCount*: int
    binding: int


proc loadInstancedModel*[T](path: string, binding: int = 0): InstancedModel[T] =
  result.model = loadModel(path)
  result.ssbo = genSsbo[T](binding)
  result.binding = binding

proc uploadInstancedModel*[T](data: MeshData, binding: int = 0): InstancedModel[T] =
  result.model = uploadData(data)
  result.ssbo = genSsbo[T](binding)
  result.binding = binding

proc reuploadSsbo*(instModel: InstancedModel) =
  instModel.ssboData.copyTo instModel.ssbo


proc clear*[T](instModel: var InstancedModel[T]) =
  when T is seq:
    instModel.ssboData.setLen(0)
  instModel.drawCount = 0

proc push*[T](instModel: var InstancedModel[T], val: auto) =
  when T is array:
    assert instModel.drawCount < T.len
    instModel.ssboData[instModel.drawCount] = val
  else:
    instModel.ssboData.add val
  inc instModel.drawCount

proc render*(instModel: InstancedModel) =
  instModel.ssbo.bindBuffer(0)
  for buf in instModel.model.buffers:
    glBindVertexArray(buf.vao)
    glDrawElementsInstanced(GlTriangles, buf.size, GlUnsignedInt, nil, GlSizei instModel.drawCount)
  glBindVertexArray(0)
  unbindSsbo()

proc render*(instModel: InstancedModel, binding: int) =
  if instModel.drawCount > 0:
    instModel.ssbo.bindBuffer(binding)
    for buf in instModel.model.buffers:
      glBindVertexArray(buf.vao)
      glDrawElementsInstanced(GlTriangles, buf.size, GlUnsignedInt, nil, GlSizei instModel.drawCount)
    glBindVertexArray(0)
    unbindSsbo()
