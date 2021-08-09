import truss3D, truss3D/[models, shaders, inputs]
import vmath, chroma

const
  vert = """
  #version 430
  layout(location = 0) in vec3 vertex_position;

  uniform mat4 matrix;

  void main() {
    gl_Position = matrix * vec4(vertex_position, 1.0);
  }"""
  frag = """
  #version 430
  out vec4 fragCol;
  uniform vec4 col;

  void main() {
    fragCol = col;
  }"""


proc makeNgon(sides: int, size: float32): Model =
  var data: MeshData[Vec2]
  data.verts = @[vec2(0, 0)]
  for i in 0..sides:
    let angle = Tau / sides.float * i.float
    data.verts.add vec2(size.float * cos(angle), size.float * sin(angle))

  let len = data.verts.len.uint32
  for i in 0u32..<len:
    data.indices.add 0
    data.indices.add (2 + i) mod len
    data.indices.add (1 + i) mod len

  result = uploadData(data)

var
  circle, triangle, hexagon, square: Model
  shader: Shader
  ortho = ortho(-10f, 10f, -10f, 10f, 0f, 10f)
  view = lookat(vec3(0), vec3(0, 0, 1), vec3(0, 1, 0))

proc init =
  triangle = makeNgon(3, 1)
  circle = makeNgon(32, 1)
  hexagon = makeNgon(6, 1)
  square = makeNgon(4, 1)
  shader = loadShader(vert, frag, false)
  let xAspect = (screenSize().x / screenSize().y).float32
  ortho = ortho(-10f * xAspect, 10f * xAspect, -10f, 10f, 0f, 10f)
  view = lookat(vec3(0), vec3(0, 0, 1), vec3(0, -1, 0))

proc update(dt: float32) =
  if KeyCodeQ.isDown:
    quitTruss()

proc draw =
  with shader:
    let ov = ortho * view
    var mat = ov * translate(vec3(3, 0, 0))
    shader.setUniform("col", vec4(1, 0, 0, 1))
    shader.setUniform("matrix", mat)
    circle.render()

    mat = ov * translate(vec3(-3, 0, 0)) * rotatez(90.toRadians)
    shader.setUniform("col", vec4(0, 1, 0, 1))
    shader.setUniform("matrix", mat)
    triangle.render()

    mat = ov * translate(vec3(0, -3, 0)) * rotatez(45.toRadians)
    shader.setUniform("col", vec4(0, 0.5, 0.5, 1))
    shader.setUniform("matrix", mat)
    square.render()

    mat = ov * translate(vec3(0, 3, 0))
    shader.setUniform("col", vec4(0, 0, 1, 1))
    shader.setUniform("matrix", mat)
    hexagon.render()


initTruss("Something", ivec2(1280, 720), init, update, draw)