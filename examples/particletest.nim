import truss3D, truss3D/[models, shaders, particlesystems]
import vmath, chroma, pixie
import std/random

const
  vertShader = """
#version 430
layout(location = 0) in vec3 vertex_position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec2 uv;


uniform mat4 VP;

layout(std430) struct data{
  vec4 color;
  vec3 pos;
  float lifeTime;
  vec4 scale; // Last float is reserved
  vec3 velocity;
  float reserved; // Not needed but here to match the CPU side
};

layout(std430, binding = 0) buffer instanceData{
  data instData[];
};

out vec3 fNormal;
out vec2 fUv;
out float time;
out vec4 color;

void main(){
  data theData = instData[gl_InstanceID];
  vec3 newPos = theData.scale.xyz * vertex_position + theData.pos.xyz;
  gl_Position = VP * vec4(newPos, 1);
  fNormal = normal;
  fUv = uv;
  color = theData.color;
}
"""

  fragShader = """
#version 430

out vec4 frag_colour;
in vec3 fNormal;
in vec4 color;
in vec2 fUv;
uniform sampler2D tex;

void main() {
  frag_colour = texture(tex, fUv) * color;
  frag_colour *= dot(fNormal, normalize(vec3(1, 0, 1))) * 0.5 + 0.5;
}
"""


var
  particleSystem: ParticleSystem
  shader: Shader
  view = lookAt(vec3(0, 4, -5), vec3(0, 0, 0), vec3(0, 1, 0))
  proj: Mat4
  texture: textures.Texture



proc myUpdate*(particle: var Particle, dt: float32, ps: ParticleSystem) =
  particle.pos += dt * particle.velocity * 20 * (1 - (particle.lifeTime / ps.lifeTime))
  particle.scale = vec3((particle.lifeTime / ps.lifeTime))


proc init(truss: var Truss) =
  particleSystem = initParticleSystem(
    "../assets/Cube.glb",
    vec3(5, 0, 5),
    vec4(1)..vec4(1, 0, 0, 1),
    1f,
    vec3(0.3),
    myUpdate
  )
  shader = loadShader(ShaderFile(vertShader), ShaderFile(fragShader))
  let screenSize = truss.windowSize
  proj = perspective(90f, screenSize.x.float / screenSize.y.float, 0.01, 100)
  let sam = readImage"../assets/Sam.jpg"
  texture = genTexture()
  sam.copyTo texture
  shader.setUniform "tex", texture


proc update(truss: var Truss, dt: float32) =
  let screenSize = truss.windowSize
  view = lookAt(vec3(0, 10, 0), vec3(5, 0, 5), vec3(0, 1, 0))
  proj = perspective(90f, screenSize.x.float / screenSize.y.float, 0.01, 100)
  if truss.inputs.isPressed(KeyCodeSpace):
    particleSystem.spawn(100)

  particleSystem.update(dt)

proc draw(truss: var Truss) =
  with shader:
    glEnable(GlDepthTest)
    setUniform("VP", proj * view)
    particleSystem.render()

var truss =Truss.init("Test", ivec2(1280, 720), init, update, draw)
truss.inputs.addEvent(KeyCodeQ, pressed, epHigh) do(keyEvent: var KeyEvent, dt: float):
  truss.isRunning = false

while truss.isRunning:
  truss.update()

