import opengl, vmath
import std/[monotimes, times]
import truss3D/[inputs, models, shaders]
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

    let dt = (getMonoTime() - lastFrame).inNanoseconds.float / 10000000
    time += dt
    lastFrame = getMonoTime()
    pollInputs()
    gupdateProc(dt)
    glClear(GL_ColorBufferBit)
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
    view = lookAt(vec3(0, 0, -10), vec3(0, 0, 0), vec3(0, 1, 0))
    proj = perspective(60f, 16f / 9f, 0.1, 100)
  proc init() =
    model = loadModel("assets/Cube.glb")
    shader = loadShader("assets/vert.glsl", "assets/frag.glsl")
    shader.setUniform "mvp", proj * view * mat4()

  proc update(dt: float32) =
    if KeycodeQ.isDown:
      app.isRunning = false

  proc draw() =
    with shader:
      glBindVertexArray(model.buffers[0].vao)
      glEnableVertexAttribArray(0)
      glDrawArrays(GlTriangles, 0, model.buffers[0].size)
  initTruss("Test", ivec2(1280, 720), init, update, draw)
