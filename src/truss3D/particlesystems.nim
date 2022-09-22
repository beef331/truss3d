import truss3D/[shaders, instancemodels]
import vmath
import std/[random, options]

type
  Particle* {.packed.}= object
    color*: Vec4
    pos*: Vec3
    lifeTime*: float32
    scale*: Vec3
    someReserved: float32
    velocity*: Vec3
    someMoreReserved: float32 # we need rotation...

  EmitProc* = proc(p: ParticleSystemBase): Particle
  UpdateProc* = proc(particle: var Particle, dt: float32, ps: ParticleSystemBase) # One day I hope we can use `ParticleSystem`...

  ParticleSystemBase* = object of RootObj
    pos*, right*, up*: Vec3
    model: InstancedModel[seq[Particle]]
    color*: Slice[Vec4]
    lifeTime*: float32
    scale*: Slice[Vec3]
    startVelocity*: Slice[Vec3]
  ParticleSystem*[emitter: static EmitProc, updater: static UpdateProc] = object of ParticleSystemBase


proc defaultEmitter*(ps: ParticleSystemBase): Particle =
  Particle(
    pos: ps.pos,
    color: ps.color.a,
    scale: ps.scale.a,
    velocity: vec3(rand(-1f..1f), rand(-1f..1f), rand(-1f..1f)).normalize()
    )

proc initParticleSystem*(
  model: InstancedModel[seq[Particle]] or string;
  pos, up: Vec3;
  color: Slice[Vec4] or Vec4;
  lifeTime = 1f;
  scale: Slice[Vec3] or Vec3;
  startVelocity: Slice[Vec3] or Vec3;
  emitProc: static EmitProc = defaultEmitter;
  updateProc: static UpdateProc;
  ): ParticleSystem[emitProc, updateProc] =
    when model is string:
      let model = loadInstancedModel[seq[Particle]](model)
    when color is Vec4:
      let color = color..color
    when scale is Vec3:
      let scale = scale..scale
    when startVelocity is Vec3:
      let startVelocity = startVelocity..startVelocity
    ParticleSystem[emitProc, updateProc](up: up, pos: pos, model: model, color: color, scale: scale, lifeTime: lifeTime, startVelocity: startVelocity)

proc spawn*(particleSystem: var ParticleSystem, count = 1, pos = none(Vec3)) =
  for x in 0..<count:
    var particle = particleSystem.emitter(particleSystem)
    particle.lifeTime = particleSystem.lifeTime
    particleSystem.model.ssboData.add particle


  particleSystem.model.reuploadSsbo()
  particleSystem.model.drawCount = particleSystem.model.ssboData.len

proc update*(particleSystem: var ParticleSystem, dt: float32) =
  let startLen = particleSystem.model.ssboData.len
  for i in countDown(particleSystem.model.ssboData.high, 0):
    template particle: Particle = particleSystem.model.ssboData[i]
    particle.lifeTime -= dt
    if particle.lifeTime > 0:
      particle.color = mix(particleSystem.color.b, particleSystem.color.a, particle.lifeTime / particleSystem.lifeTime)
      particle.scale = mix(particleSystem.scale.b, particleSystem.scale.a, particle.lifeTime / particleSystem.lifeTime)
      particleSystem.updater(particle, dt, particleSystem)
    else:
      particleSystem.model.ssboData.del(i)
  if particleSystem.model.ssboData.len > 0:
    particleSystem.model.reuploadSsbo()
    particleSystem.model.drawCount = particleSystem.model.ssboData.len
  else:
    particleSystem.model.drawCount = 0

proc render*(ps: ParticleSystem, binding = 1) =
  render(ps.model, binding)

