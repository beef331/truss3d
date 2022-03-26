import truss3D/[shaders, instancemodels]
import vmath

type
  ParticleShape = enum
    psHemisphere
  ParticleType* = enum
    ptBurst, ptEmitter

  Particle = concept p
    p.pos is Vec3
    p.scale is Vec3
    p.velocity is Vec3
    p.lifeTime is float32

  ParticleArr[T] = concept p
    p[0] is Particle
    p is (array or seq)

  ParticleSystemProperties = object
    startSize, startSpeed, lifeTime: Slice[float32]
    speedDecay: float32
    sizeDecay: float32
    shape: ParticleShape
    maxCount: int
    case particleType: ParticleType
    of ptBurst:
      discard
    of ptEmitter:
      pos: Vec3

  ParticleSystem[T: ParticleArr] = object
    particles: T
    propertiest: ParticleSystemProperties

  PooledParticleSystem*[T: ParticleArr] = object
    instancedModel: InstancedModel[T]
    shader: Shader
    systems: seq[ParticleSystem[T]]
    properties: ParticleSystemProperties


proc init*(
  _: typedesc[ParticleSystemProperties],
  startSize, startSpeed, lifeTime: Slice[float32],
  speedDecay, sizeDecay: float32,
  shape: ParticleShape,
  maxCount: int, particleType: ParticleType): ParticleSystemProperties =
  ParticleSystemProperties(
    startSize: startSize,
    startSpeed: startSpeed,
    lifeTime: lifeTime,
    speedDecay: speedDecay,
    sizeDecay: sizeDecay,
    shape: shape,
    maxCount: maxCount,
    particleType: particleType)


proc pooledParticle*[T](model: InstancedModel[T], shader: Shader, props: ParticleSystemProperties): PooledParticleSystem[T] =
  PooledParticleSystem[T](model: model, shader: shader, props: props)

proc emitterPool*[T](
  model: InstancedModel[T],
  shader: Shader,
  startSize, startSpeed, lifeTime = 1f..1f,
  speedDecay = 0f,
  sizeDecay = 0f,
  shape = psHemisphere,
  maxCount = 100,
  pos = vec3(0, 0, 0)): PooledParticleSystem[T] =
  var props = ParticleSystemProperties.init(startSize, startSpeed, lifeTime, speedDecay, sizeDecay, shape, maxCount, ptEmitter)
  props.pos = pos

  pooledParticle[T](model: model, shader: shader, props: props)

proc burstPool*[T](
  model: InstancedModel[T],
  shader: Shader,
  startSize, startSpeed, lifeTime = 1f..1f,
  speedDecay = 0f,
  sizeDecay = 0f,
  shape = psHemisphere,
  maxCount = 100): PooledParticleSystem[T] =
  var props = ParticleSystemProperties.init(startSize, startSpeed, lifeTime, speedDecay, sizeDecay, shape, maxCount, ptBurst)
  pooledParticle[T](model: model, shader: shader, props: props)


proc burst[T](particle: Particle, dt: float32) =
  particle.pos += particle.velocity * dt
  particle.lifeTime += dt

proc update*[T](model: PooledParticleSystem[T], dt: float32) =
  for system in model.systems:
    for particle in system.particles:
      particle.burst(dt)


