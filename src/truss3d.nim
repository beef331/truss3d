import aglet
import aglet/window/glfw  # we need a backend for windowing
from nimPNG import decodePng32
import truss3d/[objparser, mesh, renderobject]
import times
# initialize the library state
var agl = initAglet()
agl.initWindow()
const
  Origin = vec3f(0.0)
  Up = vec3f(0.0, 1.0, 0.0)
  Fov = Pi / 2
  CameraRadius = 5.0
  TestPng = slurp("../assets/linerino.png")
  DepthVert = glsl"""
    #version 330 core
    in vec3 position;

    uniform mat4 model;
    uniform mat4 VP;

    void main(void) {
      gl_Position = VP * model * vec4(position, 1.0);
    }
  """
  DepthFrag = glsl"""
    #version 330 core
    out float color;
    void main(void) {
      color = gl_FragCoord.z;
    }
  """
  TestVert = glsl"""
    #version 330 core
    in vec3 position;
    in vec2 uv;
    in vec3 normals;
    in vec3 colors;

    uniform mat4 model;
    uniform mat4 view;
    uniform mat4 projection;
    uniform mat4 lightMat;

    out vec2 fragUv;
    out vec3 fragColor;
    out vec3 normal;
    out vec4 lightSpace;

    void main(void) {
      fragUv = uv;
      fragUv.y = 1 - fragUv.y;
      normal = normals * (inverse(mat3(model)));
      vec3 worldPos = vec3(model * vec4(position, 1));
      lightSpace = lightMat * vec4(worldPos, 1);
      gl_Position = projection * view * vec4(worldPos, 1);
    }
  """
  TestFrag = glsl"""
    #version 330 core
    
    in vec2 fragUv;
    in vec3 fragColor;
    in vec3 normal;
    in vec4 lightSpace;

    uniform sampler2D tex;
    uniform sampler2D shadowMap;
    uniform vec3 lightDir;

    out vec4 color;

    void main(void) {
      color = texture(shadowMap, fragUv);
      vec2 shadowCoord = lightSpace.xy * 0.5 + 0.5;
      float depth = lightSpace.z * 0.5 + 0.5;
      float shadow = 0.0;
      float bias = max(0.1 *  (dot(normal, lightDir)), 0.005);  
      vec2 texelSize = 1.0 / textureSize(shadowMap, 0);
      for(int x = -1; x <= 1; ++x)
      {
          for(int y = -1; y <= 1; ++y)
          {
              float pcfDepth = texture(shadowMap, shadowCoord.xy + vec2(x, y) * texelSize).r; 
              shadow += depth - bias > pcfDepth ? 0.0 : 1.0;        
          }    
      }
      shadow /= 9.0;
      if(depth > 1){
        shadow = 1;
      }
      float ndotl = dot(normal, -lightDir) * 0.5 + 0.5;
      //color *= vec4(shadow + 0.1) * ndotl;

    }
  """



# create our window
var 
  win = agl.newWindowGlfw(800, 600, "window example", winHints(resizable = true))
  baseProgram = win.newProgram[:Vertex](TestVert, TestFrag)
  depthRender = win.newProgram[:Vertex](DepthVert, DepthFrag)

let 
  testMesh = win.loadObjMesh("./assets/test.obj")
  cube = win.loadObjMesh("./assets/cube.obj")
  sphere = win.loadObjMesh("./assets/sphere.obj")
  plane = win.loadObjMesh("./assets/plane.obj")
  testTexture = win.newTexture2D(Rgba8, decodePng32(TestPng))
  shadowMap = win.newTexture2D[: Red16](vec2i(4096, 4096)).toFramebuffer()

var
  lastMousePos: Vec2f
  dragging = false
  rotationX = 0.0
  rotationY = 0.0
  zoom = 1.0
  lastFrame = 0f32
  modelRot = 0f32
  cameraPos: Vec3f
  lightMatrix = mat4f()
  lightDir = vec3f(1, -1f, 1).normalize

var renderQueue = @[
  initRenderObject(vec3f(0,-0.5,0), vec3f(0,0,0), vec3f(1,1,1), testMesh),
  initRenderObject(vec3f(3,0,0), vec3f(0,0,0), vec3f(1,1,1), cube),
  initRenderObject(vec3f(0, -1, 0), vec3f(0,0,0), vec3f(3, 1, 3), plane)
]

proc renderLightPass() = 
  let
    size = 20f
    proj = ortho(-size, size, -size, size, -size, size)
    view = lookat(Origin, lightDir, vec3f(0, 1, 0))
  var target = shadowMap.render
  lightMatrix = proj * view
  target.clearDepth(1.0)
  target.clearColor rgba(1f, 0f, 0f, 0f)
  let
    params = defaultDrawParams().derive:
      faceCulling {facingFront}
      depthTest
  for i, ro in renderQueue:
    target.draw(depthRender, ro.mesh, uniforms {
      model: mat4f()
        .translate(ro.pos)
        .scale(ro.scale)
        .rotateX(ro.rot.x)
        .rotateY(ro.rot.y)
        .rotateZ(ro.rot.z),
      VP: lightMatrix,
      }, params)

# begin the render loop
while not win.closeRequested:
  # render
  let dt = cpuTime() - lastFrame
  lastFrame = cpuTime()
  modelRot += dt * 2
  renderLightPass()
  var frame = win.render()
  frame.clearColor(rgba(0.0, 0.0, 0.0, 1.0))
  frame.clearDepth(1)
  let
    aspect = win.width / win.height
    projection = perspective(Fov.float32, aspect, 0.01, 100.0)
    view = lookAt(eye = vec3f(3, 3, CameraRadius),
                 center = Origin,
                 up = Up)
          .translate(cameraPos)
          .rotateX(rotationX)
          .rotateY(rotationY)
          .scale(zoom)
    params = defaultDrawParams().derive:
          depthTest
          faceCulling {facingBack}
  for i, ro in renderQueue[2..2]:
    frame.draw(baseProgram, ro.mesh, uniforms {
      model: mat4f()
        .translate(ro.pos)
        .scale(ro.scale)
        .rotateX(ro.rot.x)
        .rotateY(ro.rot.y)
        .rotateZ(ro.rot.z),
      view: view,
      projection: projection,
      ?lightDir: lightDir,
      ?lightMat: lightMatrix,
      ?tex: testTexture.sampler(magFilter = fmNearest, minFilter = fmNearest),
      ?shadowMap: shadowMap.sampler(magFilter = fmNearest, minFilter = fmNearest, wrapS = twClampToEdge, wrapT = twClampToEdge)
      }, params)

  frame.finish()
  # handle events
  win.pollEvents do (event: InputEvent):
    case event.kind
    of iekMousePress, iekMouseRelease:
      dragging = event.kind == iekMousePress
    of iekMouseMove:
      if dragging:
        let delta = event.mousePos - lastMousePos
        rotationX += delta.y / 100
        rotationY += delta.x / 100
      lastMousePos = event.mousePos
    of iekMouseScroll:
      zoom += event.scrollPos.y * 0.1
    of iekKeyRepeat:
      case event.key:
      of keySpace:
        cameraPos.y -= dt * 300
      of keyLShift:
        cameraPos.y += dt * 300
      of keyW:
        cameraPos.z += dt * 300
      of keyS:
        cameraPos.z -= dt * 300
      of keyA:
        cameraPos.x -= dt * 300
      of keyD:
        cameraPos.x += dt * 300
      else: discard
    else: discard