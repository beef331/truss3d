import opengl, vmath, pixie
import std/[monotimes, times, os]
import std/logging as logg
import truss3D/[inputs, models, shaders, textures, logging]
import sdl2_nim/sdl except Keycode
export models, shaders, textures, inputs, opengl

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

type WindowFlag* = enum
  FullScreen
  Shown = 2
  Hidden
  Borderless
  Resizable
  Maximized
  Minimized
  MouseGrabbed
  InputFocus
  MouseFocus
  HighDpi


var
  app: App
  gupdateProc: UpdateProc
  gdrawProc: DrawProc
  time = 0f32

proc quitTruss*() =
  app.isRunning = false

proc screenSize*: IVec2 = app.windowSize
proc getTime*: float32 = time

proc update =
  var lastFrame = getMonoTime()
  while app.isRunning:
    assert gupdateProc != nil
    assert gdrawProc != nil

    let dt = (getMonoTime() - lastFrame).inNanoseconds.float / 1000000000
    time += dt
    lastFrame = getMonoTime()
    pollInputs(app.windowSize, dt, app.isRunning)
    gupdateProc(dt)
    glBindFramebuffer(GlFrameBuffer, 0)
    glClear(GlColorBufferBit or GlDepthBufferBit)
    gdrawProc()
    glSwapWindow(app.window)

  quitTruss()
  glDeleteContext(app.context)
  app.window.destroyWindow

proc openGlDebug(source: GLenum,
    typ: GLenum,
    id: GLuint,
    severity: GLenum,
    length: GLsizei,
    message: ptr GLchar,
    userParam: pointer) {.stdcall.} =

  when defined(truss3D.log):
    if getHandlers().len == 0:
      for handler in cast[ptr seq[Logger]](userParam)[]:
        addHandler(handler)

  if length > 0 and message != nil:
    var str = newString(length)
    copyMem(str[0].addr, message, length)
    when defined(truss3D.log):
      case severity
      of GlDebugSeverityHigh:
        error str
      of GlDebugSeverityMedium:
        warn str
      of GlDebugSeverityLow, GlDebugSeverityNotification:
        info str
      else: discard
    else:
      echo str

proc initTruss*(name: string, size: IVec2, initProc: InitProc, updateProc: UpdateProc,
    drawProc: DrawProc; vsync = false, flags = {Resizable}) =
  if init(INIT_VIDEO or INIT_GAMECONTROLLER) == 0:
    setCurrentDir(getAppDir())
    app.isRunning = true
    discard glSetAttribute(GL_CONTEXT_MAJOR_VERSION, 4)
    discard glSetAttribute(GL_CONTEXT_MINOR_VERSION, 3)
    app.windowSize = size
    app.window = createWindow(name, WindowPosUndefined, WindowPosUndefined, size.x.cint, size.y.cint, WindowOpenGl or cast[uint32](flags))
    app.context = glCreateContext(app.window)
    loadExtensions()
    glClearColor(0.0, 0.0, 0.0, 1)
    glClearDepth(1)
    enableAutoGLerrorCheck(false)
    discard glSetSwapInterval(cint(ord(vSync)))
    when not defined(release):
      glEnable(GlDebugOutput)
      glDebugMessageCallback(openGlDebug):
        when defined(truss3D.log):
          cast[ptr pointer](handlers.addr)
        else:
          nil
    if initProc != nil:
      initProc()

    gupdateProc = updateProc
    gdrawProc = drawProc
    update()

proc moveMouse*(target: IVec2) =
  let target = ivec2(clamp(target.x, 0, app.windowSize.x), clamp(target.y, 0, app.windowSize.y))
  setSoftwareMousePos(target)
  warpMouseInWindow(cast[ptr Window](app.window), target.x.cint, target.y.cint)

proc grabWindow*() = setWindowGrab(app.window, true)
proc releaseWindow*() = setWindowGrab(app.window, false)

proc getNormalizedMousePos*(): Vec2 =
  let
    screenSize = screenSize()
    mousePos = getMousePos()
  vec2(mousePos.x / screenSize.x, mousePos.y / screenSize.y)

when isMainModule:
  var
    model: Model
    shader: Shader
    view = lookAt(vec3(0, 4, -5), vec3(0, 0, 0), vec3(0, 1, 0))
    proj: Mat4
    texture: textures.Texture

  addEvent(KeyCodeQ, pressed, epHigh) do(keyEvent: var KeyEvent, dt: float):
    echo "buh bye"
    quitTruss()

  proc init() =
    model = loadModel("../assets/Cube.glb")
    shader = loadShader(ShaderPath"../assets/vert.glsl", ShaderPath"../assets/frag.glsl")
    proj = perspective(90f, app.windowSize.x.float / app.windowSize.y.float, 0.01, 100)
    let sam = readImage"../assets/Sam.jpg"
    texture = genTexture()
    sam.copyTo texture
    shader.setUniform "mvp", proj * view * mat4()
    shader.setUniform "tex", texture

  proc update(dt: float32) = discard


  proc draw() =
    with shader:
      view = lookAt(vec3(sin(time) * 4, 1, -3), vec3(0, 0, 0), vec3(0, 1, 0))
      proj = perspective(90f, app.windowSize.x.float / app.windowSize.y.float, 0.01, 100)
      setUniform "mvp", proj * view * mat4()
      glEnable(GlDepthTest)
      model.render
  addLoggers("truss3D")
  initTruss("Test", ivec2(1280, 720), init, update, draw)
