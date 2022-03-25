import std/random
import truss3D/[shaders, instancemodels]

type
  ParticleShape = enum
    psHemisphere

  ParticleSystem[T] = object
    instancedModel: InstancedModel
    particles: seq[T]
    startSize: Slice[float32]
    speed: float32
    speedDecay: float32
    sizeDecay: float32
    lifeTime: float32
    shape: ParticleShape
    shader: Shader

