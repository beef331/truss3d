import truss3D, truss3D/[models, shaders, instancemodels, audio, materials]
import vmath, chroma, pixie
import std/[random, enumerate, sugar]

const count = 100
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

layout(std430, binding = 0) buffer instanceData{
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
  cameraPos = vec3(0, 10, 0)
  lookPos = vec3(5, 0, 5)


var
  model: InstancedModel[Buffer]
  material = Material()
  view = lookAt(cameraPos, lookPos, vec3(0, 1, 0))
  proj: Mat4
  texture: textures.Texture
  mySound: SoundEffect



proc randomizeSSBO() =
  for x in model.ssboData.mitems:
    x.pos = vec4(rand(0f..10f), 0, rand(0f..10f), 0)
    x.scale = vec4(rand(0f..0.5f))
  model.reuploadSsbo()


proc init(truss: var Truss) =
  model = loadInstancedModel[Buffer]("../assets/Cube.glb")
  let shader = loadShader(ShaderFile(vertShader), ShaderFile(fragShader))
  new material.shader
  material.shader[] = shader

  let screenSize = truss.windowSize
  proj = perspective(90f, screenSize.x.float / screenSize.y.float, 0.01, 100)
  let sam = readImage"../assets/Sam.jpg"
  texture = genTexture()
  sam.copyTo texture

  let matTex = new Texture
  matTex[] = texture
  material.setProperty("tex", matTex)

  randomizeSSBO()
  model.drawCount = model.ssboData.len
  audio.init()
  setListeningPos(cameraPos)
  setListeningDir(normalize(lookPos - cameraPos))
  mySound = loadSound("../assets/test.wav", true, true)
  for i, obj in model.ssboData.pairs:
    capture(i):
      let sound = mySound.play(proc(): Vec3 = model.ssboData[i].pos.xyz)
      sound.volume = length(obj.scale)



proc moveSSBO(dt: float32) =
  for x in model.ssboData.mitems:
    x.pos.y += (1 / length(x.scale)) * 0.1 * dt
  model.reuploadSsbo()

proc update(truss: var Truss, dt: float32) =
  let screenSize = truss.windowSize
  proj = perspective(90f, truss.windowSize.x.float / truss.windowSize.y.float, 0.01, 100)
  moveSsbo(dt)
  audio.update()
  material.setProperty("VP", proj * view)

proc draw(truss: var Truss) =
  with material:
    glEnable(GlDepthTest)
    model.render()

var truss = Truss.init("Test", ivec2(1280, 720), instmodels.init, update, draw)

truss.inputs.addEvent(KeyCodeQ, pressed, epHigh) do(keyEvent: var KeyEvent, dt: float):
  echo "buh bye"
  truss.isRunning = false

while truss.isRunning:
  truss.update()
