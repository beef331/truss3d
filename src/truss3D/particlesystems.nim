import truss3D/[shaders, instancemodels]
import vmath
import std/[random, options]

type
  Particle* {.packed.}= object
    color*: Vec4
    pos*: Vec3
    lifeTime*: float32
    scale*: Vec3
    reserved1: int32
    velocity*: Vec3
    reserved2: int32

  ParticleSystem* = object
    pos: Vec3
    model: InstancedModel[seq[Particle]]
    color*: Slice[Vec4]
    lifeTime*: float32
    scale*: Slice[Vec3]
    updateProc: proc(particle: var Particle, dt: float32, ps: ParticleSystem)


proc initParticleSystem*(
  model: InstancedModel[seq[Particle]] or string;
  pos: Vec3;
  color: Slice[Vec4] or Vec4;
  lifeTime = 1f;
  scale: Slice[Vec3] or Vec3;
  updateProc: proc(particle: var Particle, dt: float32, ps: ParticleSystem)
  ): ParticleSystem =
    when model is string:
      let model = loadInstancedModel[seq[Particle]](model)
    when color is Vec4:
      let color = color..color
    when scale is Vec3:
      let scale = scale..scale
    ParticleSystem(pos: pos, model: model, color: color, scale: scale, updateProc: updateProc, lifeTime: lifeTime)

proc generateParticle(ps: ParticleSystem, startPos = none(Vec3), extraData = [0i32, 0i32]): Particle =
  Particle(
    pos:
      if startPos.isSome:
        startPos.get
      else:
        ps.pos
    ,
    color: ps.color.a,
    lifeTime: ps.lifeTime,
    scale: ps.scale.a,
    velocity: vec3(rand(-1f..1f), rand(-1f..1f), rand(-1f..1f)).normalize(),
    reserved1: extraData[0],
    reserved2: extraData[1],
  )


proc spawn*(particleSystem: var ParticleSystem, count = 1, pos = none(Vec3), extraData = [0i32, 0i32]) =
  for x in 0..<count:
    particleSystem.model.ssboData.add particleSystem.generateParticle(pos, extraData)

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
      particleSystem.updateProc(particle, dt, particleSystem)
    else:
      particleSystem.model.ssboData.del(i)
  if particleSystem.model.ssboData.len > 0:
    particleSystem.model.reuploadSsbo()
    particleSystem.model.drawCount = particleSystem.model.ssboData.len
  else:
    particleSystem.model.drawCount = 0

proc render*(ps: ParticleSystem, binding = 1) =
  render(ps.model, binding)

