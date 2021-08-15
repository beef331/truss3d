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
    if i < lr.points.high - 1:
      let
        nextPoint = lr.points[i + 1]
        dir = (nextPoint - cur).normalize
        adjacent = vec2(dir.y, -dir.x) * lr.width / 2
        offset = dist(cur, nextPoint)
        curDist = travelled / totalLength
        nextDist = curDist + offset / totalLength
        endPos = nextPoint - dir * lr.width / 2

      if i == 0:
        let offset = cur + dir * lr.width / 2
        lr.meshData.verts.add offset + adjacent
        lr.meshData.verts.add offset - adjacent

      lr.meshData.verts.add endPos + adjacent
      lr.meshData.verts.add endPos - adjacent

      let nextDir = (lr.points[i + 2] - nextPoint).normalize



      lr.meshData.verts.add endPos + adjacent
      lr.meshData.verts.add endPos - adjacent






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

proc init =
  shader = loadShader(vert, frag, false)
  line.generateMesh
  let xAspect = (screenSize().x / screenSize().y).float32
  ortho = ortho(-camSize * xAspect, camSize * xAspect, -camSize, camSize, 0f, 10f)
  view = lookat(vec3(0), vec3(0, 0, 1), vec3(0, 1, 0))

proc update(dt: float32) =
  if KeyCodeQ.isDown:
    quitTruss()

proc draw =
  let ov = ortho * view

  with shader:
    line.mesh.renderWith(shader):
      "col": vec4(1)
      "matrix": ov



initTruss("Something", ivec2(1280, 720), init, update, draw)