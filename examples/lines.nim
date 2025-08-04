import truss3D, truss3D/[models, shaders]
import vmath, chroma

type
  LineRenderer = object
    width: float
    points: seq[Vec2]
    mesh: Model
    meshData: MeshData[Vec2]

proc getLength(lr: LineRenderer): float32 =
  assert lr.points.len >= 2
  for i, cur in lr.points:
    if i in 1..lr.points.high:
      result += dist(cur, lr.points[i - 1])

proc generateMesh(lr: var LineRenderer) =
  assert lr.points.len >= 2
  lr.meshData.indices.setLen(0)
  lr.meshData.verts.setLen(0)
  lr.meshData.uvs.setLen(0)
  let totalLength = lr.getLength
  var travelled = 0f
  for i, cur in lr.points:
    if i < lr.points.high:
      let
        nextPoint = lr.points[i + 1]
        dir = (nextPoint - cur).normalize
        adjacent = vec2(dir.y, -dir.x) * lr.width / 2
        offSet = dist(cur, nextPoint)
        curDist = travelled / totalLength
        nextDist = curDist + offset / totalLength


      if i == 0:
        lr.meshData.verts.add cur - adjacent
        lr.meshData.verts.add cur + adjacent
        lr.meshData.uvs.add vec2(0, curDist)
        lr.meshData.uvs.add vec2(1, curDist)

      lr.meshData.verts.add nextPoint - adjacent
      lr.meshData.verts.add nextPoint + adjacent

      lr.meshData.uvs.add vec2(0, nextDist)
      lr.meshData.uvs.add vec2(1, nextDist)

      let ind = i.uint32 * 2
      lr.meshData.indices.add ind
      lr.meshData.indices.add ind + 1
      lr.meshData.indices.add ind + 2

      lr.meshData.indices.add ind + 2
      lr.meshData.indices.add ind + 1
      lr.meshData.indices.add ind + 3

      travelled += offset
  lr.mesh = uploadData(lr.meshData)

const
  vert = """
  #version 430
  layout(location = 0) in vec3 vertex_position;
  layout(location = 2) in vec2 vuv;

  uniform mat4 matrix;
  out vec2 fuv;
  void main() {
    gl_Position = matrix * vec4(vertex_position, 1.0);
    fuv = vuv;
  }"""
  frag = """
  #version 430
  out vec4 fragCol;
  uniform vec4 col;
  in vec2 fuv;
  void main() {
    fragCol = col;
  }"""


const camSize = 10f
var
  line = LineRenderer(points: @[vec2(-5, -9), vec2(5, 5), vec2(-5, 5)], width: 1)
  shader: Shader
  ortho = ortho(-camSize, camSize, -camSize, camSize, 0f, 10f)
  view = lookat(vec3(0), vec3(0, 0, 1), vec3(0, 1, 0))

proc init(truss: var Truss) =
  shader = loadShader(ShaderFile vert, ShaderFile frag)
  line.generateMesh
  let xAspect = (truss.windowSize.x / truss.windowSize.y).float32
  ortho = ortho(-camSize * xAspect, camSize * xAspect, -camSize, camSize, 0f, 10f)
  view = lookat(vec3(0), vec3(0, 0, 1), vec3(0, 1, 0))

proc update(truss: var Truss, dt: float32) =
  if truss.inputs.isDown(KeyCodeQ):
    truss.isRunning = false

proc draw(truss: var Truss) =
  let ov = ortho * view

  with shader:
    line.mesh.renderWith(shader):
      "col": vec4(1)
      "matrix": ov



var truss = Truss.init("Something", ivec2(1280, 720), init, update, draw)
while truss.isRunning:
  truss.update()
