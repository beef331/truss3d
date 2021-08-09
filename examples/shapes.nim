import truss3D, truss3D/[models, shaders, inputs]
import vmath, chroma

const
  vert = """
  #version 430
  layout(location = 0) in vec3 vertex_position;
  layout(location = 3) in vec4 vCol;

  uniform mat4 matrix;
  out vec4 fCol;
  void main() {
    gl_Position = matrix * vec4(vertex_position, 1.0);
    fCol = vCol;
  }"""
  frag = """
  #version 430
  out vec4 fragCol;
  uniform vec4 col;
  in vec4 fCol;
  void main() {
    fragCol = col * fCol;
  }"""


proc makeNgon(sides: int, size: float): Model =
  var data: MeshData[Vec2]
  data.verts = @[vec2(0, 0)]
  data.colors = @[rgba(0,0,0,0).asColor]
  for i in 0..sides:
    let angle = Tau / sides.float * i.float
    data.verts.add vec2(size * cos(angle - (Tau / 4)), size * sin(angle - (Tau / 4)))
    data.colors.add rgba(255, 255, 255, 255).asColor

  let len = data.verts.len.uint32
  for i in 0u32..<len:
    data.indices.add 0
    data.indices.add (2 + i) mod len
    data.indices.add (1 + i) mod len

  result = uploadData(data)

const camSize = 10f
var
  circle, triangle, hexagon, square, pentagon: Model
  shader: Shader
  ortho = ortho(-camSize, camSize, -camSize, camSize, 0f, 10f)
  view = lookat(vec3(0), vec3(0, 0, 1), vec3(0, 1, 0))

proc init =
  triangle = makeNgon(3, 1)
  circle = makeNgon(32, 1)
  hexagon = makeNgon(6, 1)
  pentagon = makeNgon(5, 10)
  square = makeNgon(4, 1)
  shader = loadShader(vert, frag, false)
  let xAspect = (screenSize().x / screenSize().y).float32
  ortho = ortho(-camSize * xAspect, camSize * xAspect, -camSize, camSize, 0f, 10f)
  view = lookat(vec3(0), vec3(0, 0, 1), vec3(0, -1, 0))

proc update(dt: float32) =
  if KeyCodeQ.isDown:
    quitTruss()

proc draw =
  let ov = ortho * view

  with shader:
    pentagon.renderWith(shader):
      "col": vec4(1)
      "matrix": ov

    pentagon.renderWith(shader):
      "col": vec4(0.3, 0.9, 0.9, 1)
      "matrix": ov * scale(vec3(0.9))

    circle.renderWith(shader):
      "col": vec4(1, 0, 0, 1)
      "matrix": ov * translate(vec3(3, 0, 0))
    
    triangle.renderWith(shader):
      "col": vec4(0, 1, 0, 1)
      "matrix": ov * translate(vec3(-3, 0, 0))

    square.renderWith(shader):
      "col": vec4(0, 0.5, 0.5, 1)
      "matrix": ov * translate(vec3(0, -3, 0)) * rotateZ(Tau.float32 / 8f)

    hexagon.renderWith(shader):
      "col": vec4(0, 0, 1, 1)
      "matrix": ov * translate(vec3(0, 3, 0))


initTruss("Something", ivec2(1280, 720), init, update, draw)