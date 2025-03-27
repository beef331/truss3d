import opengl, vmath, pixie
import std/[monotimes, times, os]
import std/logging as logg
import truss3D/[inputs, models, shaders, textures, logging]
import sdl2_nim/sdl except Keycode
export models, shaders, textures, inputs, opengl

type
  InitProc* = proc(truss: var Truss){.nimcall.}
  UpdateProc* = proc(truss: var Truss, dt: float32){.nimcall.}
  DrawProc* = proc(truss: var Truss){.nimcall.}
  Truss* = object
    window: Window
    windowSize*: IVec2
    context: GLContext
    isRunning*: bool
    rect: Gluint
    updateProc*: UpdateProc
    drawProc*: DrawProc
    initProc*: InitProc
    time: float
    hasInit: bool
    inputs*: InputState
    lastFrame: MonoTime



  WindowFlag* = enum
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

proc `=destroy`(truss: Truss) =
  if truss.hasInit:
    glDeleteContext(truss.context)
    truss.window.destroyWindow

proc update*(truss: var Truss) =
  assert truss.updateProc != nil
  assert truss.drawProc != nil

  let thisFrame = getMonoTime()
  let dt = (thisFrame - truss.lastFrame).inNanoSeconds.float32 * 1e-9
  truss.time += dt

  truss.inputs.pollInputs(truss.windowSize, dt, truss.isRunning)
  truss.updateProc(truss, dt)

  glBindFramebuffer(GlFrameBuffer, 0)
  glClear(GlColorBufferBit or GlDepthBufferBit)
  truss.drawProc(truss)
  glSwapWindow(truss.window)
  truss.lastFrame = thisFrame

proc hasInit*(truss: Truss): bool = truss.hasInit

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
    case severity
    of GlDebugSeverityHigh:
      if debugLevel >= 0:
        error str
    of GlDebugSeverityMedium:
      if debugLevel >= 1:
        warn str
    of GlDebugSeverityLow, GlDebugSeverityNotification:
      if debugLevel >= 2:
        info str
    else: discard

proc init*(_: typedesc[Truss], name: string, size: IVec2, initProc: InitProc, updateProc: UpdateProc,
    drawProc: DrawProc; vsync = false, flags = {Resizable}): Truss =
  if init(INIT_VIDEO or INIT_GAMECONTROLLER) == 0:
    setCurrentDir(getAppDir())
    result = Truss(isRunning: true, hasInit: true, windowSize: size)
    discard glSetAttribute(GL_CONTEXT_MAJOR_VERSION, 4)
    discard glSetAttribute(GL_CONTEXT_MINOR_VERSION, 3)
    result.windowSize = size
    result.window = createWindow(name, WindowPosUndefined, WindowPosUndefined, size.x.cint, size.y.cint, WindowOpenGl or cast[uint32](flags))
    result.context = glCreateContext(result.window)
    loadExtensions()
    glClearColor(0.0, 0.0, 0.0, 1)
    glClearDepth(1)
    enableAutoGLerrorCheck(false)
    discard glSetSwapInterval(cint(ord(vSync)))
    when debugLevel >= 0:
      glEnable(GlDebugOutput)
      glDebugMessageCallback(openGlDebug):
        when defined(truss3D.log):
          cast[ptr pointer](handlers.addr)
        else:
          nil
    if initProc != nil:
      initProc(result)
    result.lastFrame = getMonoTime()
    result.updateProc = updateProc
    result.drawProc = drawProc

proc moveMouse*(truss: var Truss, target: Vec2) =
  let target = vec2(clamp(target.x, 0f, truss.windowSize.x.float32), clamp(target.y, 0f, truss.windowSize.y.float32))
  truss.inputs.setSoftwareMousePos(target)
  warpMouseInWindow(cast[ptr Window](truss.window), target.x.cint, target.y.cint)

proc grabWindow*(truss: var Truss) = setWindowGrab(truss.window, true)
proc releaseWindow*(truss: var Truss) = setWindowGrab(truss.window, false)

proc getNormalizedMousePos*(truss: Truss): Vec2 =
  let
    screenSize = truss.windowSize
    mousePos = truss.inputs.getMousePos()
  vec2(mousePos.x / screenSize.x.float32, mousePos.y / screenSize.y.float32)

proc time*(truss: Truss): float = truss.time

when isMainModule:
  var
    model: Model
    shader: Shader
    view = lookAt(vec3(0, 4, -5), vec3(0, 0, 0), vec3(0, 1, 0))
    proj: Mat4
    texture: textures.Texture

  proc init(truss: var Truss) =
    model = loadModel("../assets/Cube.glb")
    shader = loadShader(ShaderPath"../assets/vert.glsl", ShaderPath"../assets/frag.glsl")
    proj = perspective(90f, truss.windowSize.x.float / truss.windowSize.y.float, 0.01, 100)
    let sam = readImage"../assets/Sam.jpg"
    texture = genTexture()
    sam.copyTo texture
    shader.setUniform "mvp", proj * view * mat4()
    shader.setUniform "tex", texture

  proc update(truss: var Truss, dt: float32) = discard


  proc draw(truss: var Truss) =
    with shader:
      view = lookAt(vec3(sin(truss.time) * 4, 1, -3), vec3(0, 0, 0), vec3(0, 1, 0))
      proj = perspective(90f, truss.windowSize.x.float / truss.windowSize.y.float, 0.01, 100)
      setUniform "mvp", proj * view * mat4()
      glEnable(GlDepthTest)
      model.render
  addLoggers("truss3D")

  var truss = Truss.init("Truss3D", ivec2(1280, 720), InitProc init, UpdateProc update, DrawProc draw)

  while truss.isRunning:
    truss.update()


