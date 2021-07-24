import opengl, vmath, pixie
import std/[monotimes, times]
import truss3D/[inputs, models, shaders, textures]
import sdl2/sdl except Keycode

type App = object
  window: Window
  windowSize: IVec2
  context: GLContext
  isRunning: bool
  rect: Gluint


type
  InitProc* = proc(){.nimcall.}
  UpdateProc* = proc(dt: float32){.nimcall.}
  DrawProc* = proc(){.nimcall.}

var
  app: App
  gupdateProc: UpdateProc
  gdrawProc: DrawProc
  time = 0f32

proc quitTruss*() =
  glDeleteContext(app.context)
  app.window.destroyWindow

proc update =
  var lastFrame = getMonoTime()
  while app.isRunning:
    assert gupdateProc != nil
    assert gdrawProc != nil

    let dt = (getMonoTime() - lastFrame).inNanoseconds.float / 1000000000
    time += dt
    lastFrame = getMonoTime()
    pollInputs()
    gupdateProc(dt)
    glClear(GlColorBufferBit or GlDepthBufferBit)
    gdrawProc()
    glSwapWindow(app.window)

  quitTruss()

proc initTruss*(name: string, size: IVec2, initProc: InitProc, updateProc: UpdateProc,
    drawProc: DrawProc) =
  if init(INIT_VIDEO) == 0:
    app.isRunning = true
    discard glSetAttribute(GL_CONTEXT_MAJOR_VERSION, 4)
    discard glSetAttribute(GL_CONTEXT_MINOR_VERSION, 3)
    app.windowSize = size
    app.window = createWindow(name, WindowPosUndefined, WindowPosUndefined, size.x, size.y, WindowOpenGl)
    app.context = glCreateContext(app.window)
    loadExtensions()
    glClearColor(0.0, 0.0, 0.0, 1)
    glClearDepth(1)
    discard glSetSwapInterval(0.cint)

    if initProc != nil:
      initProc()

    gupdateProc = updateProc
    gdrawProc = drawProc
    update()

when isMainModule:
  var
    model: Model
    shader: Shader
    view = lookAt(vec3(0, 4, -5), vec3(0, 0, 0), vec3(0, 1, 0))
    proj: Mat4
    texture: textures.Texture

  proc init() =
    model = loadModel("assets/Cube.glb")
    shader = loadShader("assets/vert.glsl", "assets/frag.glsl")
    proj = perspective(90f, app.windowSize.x.float / app.windowSize.y.float, 0.01, 100)
    shader.setUniform "mvp", proj * view * mat4()
    let sam = readImage"assets/Sam.jpg"
    texture = genTexture()
    sam.copyTo texture
    shader.setUniform "tex", texture

  proc update(dt: float32) =
    if KeycodeQ.isDown:
      app.isRunning = false
    view = lookAt(vec3(sin(time) * 4, 1, -3), vec3(0, 0, 0), vec3(0, 1, 0))
    proj = perspective(90f, app.windowSize.x.float / app.windowSize.y.float, 0.01, 100)
    shader.setUniform "mvp", proj * view * mat4()


  proc draw() =
    with shader:
      glEnable(GlDepthTest)
      model.render

  initTruss("Test", ivec2(1280, 720), init, update, draw)
