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

layout(std430, binding = 1) buffer instanceData{
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


proc explosiveUpdate(particle: var Particle, dt: float32, ps: ParticleSystemBase) =
  particle.pos += dt * particle.velocity * 20 * (1 - (particle.lifeTime / ps.lifeTime))
  particle.scale = vec3((particle.lifeTime / ps.lifeTime))

proc smokeEmitter(ps: ParticleSystemBase): Particle =
  result.pos = ps.pos
  let
    xVelRot = rand (-Tau.float32 / 8f32)..(Tau.float32 / 8f32)
    zVelRot = rand (-Tau.float32 / 8f32)..(Tau.float32 / 8f32)
    vel = normalize(rotateZ(zVelRot) * rotateX(xVelRot) * ps.up) * mix(length ps.startVelocity.a, length ps.startVelocity.b, rand(0f32..1f32))
  result.velocity = vel

proc smokeUpdate(particle: var Particle, dt: float32, ps: ParticleSystemBase) =
  particle.pos += dt * particle.velocity


var
  explosive: ParticleSystem[defaultEmitter, explosiveUpdate]
  smoke: ParticleSystem[smokeEmitter, smokeUpdate]
  shader: Shader
  view = lookAt(vec3(0, 4, -5), vec3(0, 0, 0), vec3(0, 1, 0))
  proj: Mat4
  texture: textures.Texture

addEvent(KeyCodeQ, pressed, epHigh) do(keyEvent: var KeyEvent, dt: float):
  echo "buh bye"
  quitTruss()


proc init() =
  explosive = initParticleSystem(
    "assets/Cube.glb",
    vec3(5, 0, 5),
    vec3(0, 1, 0),
    vec4(1)..vec4(1, 0, 0, 1),
    1f,
    vec3(0.3),
    vec3(0),
    defaultEmitter,
    explosiveUpdate
  )
  smoke = initParticleSystem(
    "assets/Cube.glb",
    vec3(5, 0, 5),
    vec3(0, 1, 0),
    vec4(0.3, 0.3, 0, 1)..vec4(0.6, 0.6, 0.6, 0.3),
    5f,
    vec3(1)..vec3(0.1),
    vec3(0.5) .. vec3(1),
    smokeEmitter,
    smokeUpdate
  )
  shader = loadShader(ShaderFile(vertShader), ShaderFile(fragShader))
  let screenSize = screenSize()
  proj = perspective(90f, screenSize.x.float / screenSize.y.float, 0.01, 100)
  let sam = readImage"assets/Sam.jpg"
  texture = genTexture()
  sam.copyTo texture
  shader.setUniform "tex", texture


var lastSmokeSpawn = 0.1

proc update(dt: float32) =
  let screenSize = screenSize()
  view = lookAt(vec3(0, 10, 0), vec3(5, 0, 5), vec3(0, 1, 0))
  proj = perspective(90f, screenSize.x.float / screenSize.y.float, 0.01, 100)
  if KeycodeSpace.isPressed():
    explosive.spawn(100)
  if lastSmokeSpawn < 0:
    smoke.spawn(1)
    lastSmokeSpawn = 0.1
  lastSmokeSpawn -= dt

  explosive.update(dt)
  smoke.update(dt)

proc draw() =
  with shader:
    glEnable(GlDepthTest)
    glEnable(GlBlend)
    shader.setUniform("VP", proj * view)
    explosive.render()
    smoke.render()
initTruss("Test", ivec2(1280, 720), init, update, draw)
