import truss3D, truss3D/[models, shaders, instancemodels, audio]
import vmath, chroma, pixie
import std/[random, enumerate, sugar]

const count = 5
type
  InstanceBuffer {.packed.} = object
    pos: Vec4
    scale: Vec4
  Buffer = array[count, InstanceBuffer]

const
  vertShader = """
#version 430
layout(location = 0) in vec3 vertex_position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec2 uv;


uniform mat4 VP;

struct data{
  vec4 pos;
  vec4 scale;
};

layout(std430, binding = 1) buffer instanceData{
  data instData[];
};

out vec3 fNormal;
out vec2 fUv;
out float time;
void main(){
  data theData = instData[gl_InstanceID];
  vec3 newPos = theData.scale.xyz * vertex_position + theData.pos.xyz;
  gl_Position = VP * vec4(newPos, 1);
  fNormal = normal;
  fUv = uv;
}
"""

  fragShader = """
#version 430

out vec4 frag_colour;
in vec3 fNormal;
in vec2 fUv;
uniform sampler2D tex;

void main() {
  frag_colour = texture(tex, fUv);
  frag_colour *= dot(fNormal, normalize(vec3(1, 0, 1))) * 0.5 + 0.5;
}
"""

const
  cameraPos = vec3(0, 4, 0)
  lookPos = vec3(5, 0, 5)


var
  model: InstancedModel[Buffer]
  shader: Shader
  view = lookAt(cameraPos, lookPos, vec3(0, 1, 0))
  proj: Mat4
  texture: textures.Texture
  mySound: SoundEffect
  hasExited: array[count, bool]

addEvent(KeyCodeQ, pressed, epHigh) do(keyEvent: var KeyEvent, dt: float):
  echo "buh bye"
  quitTruss()

proc randomizeSSBO() =
  with shader:
    for x in model.ssboData.mitems:
      x.pos = vec4(rand(0f..10f), 0, rand(0f..10f), 0)
      x.scale = vec4(rand(0f..0.5f))
    model.reuploadSsbo()


proc init() =
  model = loadInstancedModel[Buffer]("assets/Cube.glb")
  shader = loadShader(ShaderFile(vertShader), ShaderFile(fragShader))
  let screenSize = screenSize()
  proj = perspective(90f, screenSize.x.float / screenSize.y.float, 0.01, 100)
  let sam = readImage"assets/Sam.jpg"
  texture = genTexture()
  sam.copyTo texture
  shader.setUniform "tex", texture
  randomizeSSBO()
  model.drawCount = model.ssboData.len
  audio.init()
  mySound = loadSound("./assets/test.wav", true)
  setListeningPos(cameraPos)
  setListeningDir(normalize(lookPos - cameraPos))
  for i, obj in model.ssboData.pairs:
    capture(i):
      mySound.play(proc(): Vec3 = model.ssboData[i].pos.xyz)


proc moveSSBO(dt: float32) =
  with shader:
    for i, x in enumerate model.ssboData.mitems:
      x.pos.y += (1 / length(x.scale)) * 0.1 * dt
    model.reuploadSsbo()

proc update(dt: float32) =
  let screenSize = screenSize()
  proj = perspective(90f, screenSize.x.float / screenSize.y.float, 0.01, 100)
  moveSsbo(dt)
  audio.update()

proc draw() =
  with shader:
    glEnable(GlDepthTest)
    shader.setUniform("VP", proj * view)
    model.render()
initTruss("Test", ivec2(1280, 720), instmodels.init, update, draw)
