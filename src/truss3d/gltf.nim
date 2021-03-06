import base64, json, pixie, opengl, os, strformat, strutils, glm, mesh
import aglet
type
  BufferView = object
    buffer: int
    byteOffset, byteLength, byteStride: Natural

  Texture = object
    source: Natural
    sampler: int

  Sampler = object
    magFilter, minFilter, wrapS, wrapT: GLint

  BaseColorTexture = object
    index: int

  PBRMetallicRoughness = object
    apply: bool
    baseColorTexture: BaseColorTexture

  Material = object
    name: string
    pbrMetallicRoughness: PBRMetallicRoughness

  InterpolationKind = enum
    iLinear, iStep, iCubicSpline

  AnimationSampler = object
    input, output: Natural # Accessor indices
    interpolation: InterpolationKind

  AnimationPath = enum
    pTranslation, pRotation, pScale, pWeights

  AnimationTarget = object
    node: Natural
    path: AnimationPath

  AnimationChannel = object
    sampler: Natural
    target: AnimationTarget

  AnimationState = object
    prevTime: float
    prevKey: int

  Animation = object
    samplers: seq[AnimationSampler]
    channels: seq[AnimationChannel]

  AccessorKind = enum
    atSCALAR, atVEC2, atVEC3, atVEC4, atMAT2, atMAT3, atMAT4

  Accessor = object
    bufferView, byteOffset, count: Natural
    componentType: GLenum
    kind: AccessorKind

  PrimitiveAttributes = object
    position, normal, color0, texcoord0: int

  Primitive = object
    attributes: PrimitiveAttributes
    indices, material: int
    mode: GLenum

  Mesh = object
    name: string
    primitives: seq[Natural]

  Node = object
    name: string
    kids: seq[Natural]
    mesh: int
    applyMatrix: bool
    matrix: Mat4f
    rotation: Quatf
    translation, scale: Vec3f

  Scene = object
    nodes: seq[Natural]

  Model* = ref object
    # All of the data that is indexed into
    buffers: seq[string]
    bufferViews: seq[BufferView]
    textures: seq[Texture]
    samplers: seq[Sampler]
    images: seq[Image]
    animations: seq[Animation]
    materials: seq[Material]
    accessors: seq[Accessor]
    primitives: seq[Primitive]
    meshes: seq[Mesh]
    nodes: seq[Node]
    scenes: seq[Scene]

    # State
    bufferIds, textureIds, vertexArrayIds: seq[GLuint]
    animationState: seq[AnimationState]

    # Model properties
    scene: Natural

func componentCount(accessorKind: AccessorKind): Natural =
  case accessorKind:
    of atSCALAR:
      1
    of atVEC2:
      2
    of atVEC3:
      3
    of atVEC4, atMAT2:
      4
    of atMAT3:
      9
    of atMAT4:
      16

template read[T](buffer: ptr string, byteOffset: int, index = 0): auto =
  cast[ptr T](buffer[byteOffset + (index * sizeof(T))].addr)[]

template readVec3(buffer: ptr string, byteOffset, index: int): Vec3f =
  var v: Vec3f
  v.x = read[float32](buffer, byteOffset, index)
  v.y = read[float32](buffer, byteOffset, index + 1)
  v.z = read[float32](buffer, byteOffset, index + 2)
  v

template readQuat(buffer: ptr string, byteOffset, index: int): Quatf =
  var q: Quatf
  q.x = read[float32](buffer, byteOffset, index)
  q.y = read[float32](buffer, byteOffset, index + 1)
  q.z = read[float32](buffer, byteOffset, index + 2)
  q.w = read[float32](buffer, byteOffset, index + 3)
  q


#[ Todo support this
proc advanceAnimations*(model: Model, totalTime: float) =
  for animationIndex in 0..<len(model.animations):
    let animation = model.animations[animationIndex]
    var animationState = model.animationState[animationIndex]

    for channelIndex in 0..<len(animation.channels):
      # Get the various things we need from the glTF tree
      let
        channel = animation.channels[channelIndex]
        sampler = animation.samplers[channel.sampler]
        input = model.accessors[sampler.input]
        output = model.accessors[sampler.output]
        inputBufferView = model.bufferViews[input.bufferView]
        outputBufferView = model.bufferViews[output.bufferView]
        inputBuffer = model.buffers[inputBufferView.buffer].addr
        outputBuffer = model.buffers[outputBufferView.buffer].addr
        inputByteOffset = input.byteOffset + inputBufferView.byteOffset
        outputByteOffset = output.byteOffset + outputBufferView.byteOffset

      # Ensure time is within the bounds of the animation interval
      let
        min = read[float32](inputBuffer, inputByteOffset)
        max = read[float32](inputBuffer, inputByteOffset, input.count - 1)
        time = max(totalTime mod max, min).float32

      if animationState.prevTime > time:
        animationState.prevKey = 0

      animationState.prevTime = time

      var nextKey: int
      for i in animationState.prevKey..<input.count:
        if time <= read[float32](inputBuffer, inputByteOffset, i):
          nextKey = clamp(i, 1, input.count - 1)
          break

      animationState.prevKey = clamp(nextKey - 1, 0, nextKey)

      let
        prevStartTime = read[float32](
          inputBuffer,
          inputByteOffset,
          animationState.prevKey
        )
        nextStartTime = read[float32](
          inputBuffer,
          inputByteOffset,
          nextKey
        )
        timeDelta = nextStartTime - prevStartTime
        normalizedTime = (time - prevStartTime) / timeDelta # Between [0, 1]

      case sampler.interpolation:
        of iStep:
          case channel.target.path:
            of pTranslation, pScale:
              let transform = readVec3(
                outputBuffer,
                outputByteOffset,
                animationState.prevKey * output.kind.componentCount
              )

              if channel.target.path == pTranslation:
                model.nodes[channel.target.node].translation = transform
              else:
                model.nodes[channel.target.node].scale = transform
            of pRotation:
              model.nodes[channel.target.node].rotation = readQuat(
                outputBuffer,
                outputByteOffset,
                animationState.prevKey * output.kind.componentCount
              )
            of pWeights:
              discard
        of iLinear:
          case channel.target.path:
            of pTranslation, pScale:
              let
                v0 = readVec3(
                  outputBuffer,
                  outputByteOffset,
                  animationState.prevKey * output.kind.componentCount
                )
                v1 = readVec3(
                  outputBuffer,
                  outputByteOffset,
                  nextKey * output.kind.componentCount
                )
                transform = lerp(v0, v1, normalizedTime)

              if channel.target.path == pTranslation:
                model.nodes[channel.target.node].translation = transform
              else:
                model.nodes[channel.target.node].scale = transform
            of pRotation:
              let
                q0 = readQuat(
                  outputBuffer,
                  outputByteOffset,
                  animationState.prevKey * output.kind.componentCount
                )
                q1 = readQuat(
                  outputBuffer,
                  outputByteOffset,
                  nextKey * output.kind.componentCount
                )
              model.nodes[channel.target.node].rotation =
                nlerp(q0, q1, normalizedTime)
            of pWeights:
              discard
        of iCubicSpline:
          let
            t = normalizedTime
            t2 = pow(normalizedTime, 2)
            t3 = pow(normalizedTime, 3)
            prevIndex = animationState.prevKey * output.kind.componentCount * 3
            nextIndex = nextKey * output.kind.componentCount * 3

          template cubicSpline[T](): T =
            var transform: T
            for i in 0..<output.kind.componentCount:
              let
                v0 = read[float32](
                  outputBuffer,
                  outputByteOffset,
                  prevIndex + i + output.kind.componentCount
                )
                a = timeDelta * read[float32](
                  outputBuffer,
                  outputByteOffset,
                  nextIndex + i
                )
                b = timeDelta * read[float32](
                  outputBuffer,
                  outputByteOffset,
                  prevIndex + i + (2 * output.kind.componentCount)
                )
                v1 = read[float32](
                  outputBuffer,
                  outputByteOffset,
                  nextIndex + i + output.kind.componentCount
                )

              transform[i] = ((2*t3 - 3*t2 + 1) * v0) +
                ((t3 - 2*t2 + t) * b) +
                ((-2*t3 + 3*t2) * v1) +
                ((t3 - t2) * a)

            transform

          case channel.target.path:
            of pTranslation, pScale:
              let transform = cubicSpline[Vec3]()
              if channel.target.path == pTranslation:
                model.nodes[channel.target.node].translation = transform
              else:
                model.nodes[channel.target.node].scale = transform
            of pRotation:
              model.nodes[channel.target.node].rotation = cubicSpline[Quat]()
            of pWeights:
              discard
]#

proc toVerts(model: Model): (seq[Vertex], seq[uint32]) =
  model.bufferIds.setLen(len(model.accessors))
  model.textureIds.setLen(len(model.textures))
  model.vertexArrayIds.setLen(len(model.primitives))
  model.animationState.setLen(len(model.animations))

  for node in model.nodes:
    if node.mesh < 0:
      continue
    
    for primitiveIndex in model.meshes[node.mesh].primitives:
      let primitive = model.primitives[primitiveIndex]
      echo primitive
      #[
        result[0].add Vertex(
        vert: primitive.attributes.position,
        uv: primitive.attributes.texcoord0,
        normal: primitive.attributes.normal0,
        colors: primitive.attributes.color0)
      ]#

proc loadModel(file: string): Model =
  result = Model()

  echo &"Loading {file}"
  let
    jsonRoot = parseJson(readFile(file))
    modelDir = splitPath(file)[0]

  for entry in jsonRoot["buffers"]:
    let uri = entry["uri"].getStr()

    var data: string
    if uri.startsWith("data:application/octet-stream"):
      data = decode(uri.split(',')[1])
    else:
      data = readFile(joinPath(modelDir, uri))

    assert len(data) == entry["byteLength"].getInt()
    result.buffers.add(data)

  for entry in jsonRoot["bufferViews"]:
    var bufferView = BufferView()
    bufferView.buffer = entry["buffer"].getInt()
    bufferView.byteOffset = entry{"byteOffset"}.getInt()
    bufferView.byteLength = entry["byteLength"].getInt()
    bufferView.byteStride = entry{"byteStride"}.getInt()

    if entry.hasKey("target"):
      let target = entry["target"].getInt()
      if target notin @[GL_ARRAY_BUFFER.int, GL_ELEMENT_ARRAY_BUFFER.int]:
        raise newException(Exception, &"Invalid bufferView target {target}")

    result.bufferViews.add(bufferView)

  if jsonRoot.hasKey("textures"):
    for entry in jsonRoot["textures"]:
      var texture = Texture()
      texture.source = entry["source"].getInt()

      if entry.hasKey("sampler"):
        texture.sampler = entry["sampler"].getInt()
      else:
        texture.sampler = -1

      result.textures.add(texture)

  if jsonRoot.hasKey("images"):
    for entry in jsonRoot["images"]:
      var image: Image
      if entry.hasKey("uri"):
        let uri = entry["uri"].getStr()
        if uri.startsWith("data:image/png"):
          image = decodeImage(decode(uri.split(',')[1]))
        elif uri.endsWith(".png"):
          image = readImage(joinPath(modelDir, uri))
        else:
          raise newException(Exception, &"Unsupported file extension {uri}")
      else:
        raise newException(Exception, "Unsupported image type")

      result.images.add(image)

  if jsonRoot.hasKey("samplers"):
    for entry in jsonRoot["samplers"]:
      var sampler = Sampler()

      if entry.hasKey("magFilter"):
        sampler.magFilter = entry["magFilter"].getInt().GLint
      else:
        sampler.magFilter = GL_LINEAR

      if entry.hasKey("minFilter"):
        sampler.minFilter = entry["minFilter"].getInt().GLint
      else:
        sampler.minFilter = GL_LINEAR_MIPMAP_LINEAR

      if entry.hasKey("wrapS"):
        sampler.wrapS = entry["wrapS"].getInt().GLint
      else:
        sampler.wrapS = GL_REPEAT

      if entry.hasKey("wrapT"):
        sampler.wrapT = entry["wrapT"].getInt().GLint
      else:
        sampler.wrapT = GL_REPEAT

      result.samplers.add(sampler)

  if jsonRoot.hasKey("materials"):
    for entry in jsonRoot["materials"]:
      var material = Material()
      material.name = entry{"name"}.getStr()

      if entry.hasKey("pbrMetallicRoughness"):
        let pbrMetallicRoughness = entry["pbrMetallicRoughness"]
        material.pbrMetallicRoughness.apply = true
        if pbrMetallicRoughness.hasKey("baseColorTexture"):
          let baseColorTexture = pbrMetallicRoughness["baseColorTexture"]
          material.pbrMetallicRoughness.baseColorTexture.index =
            baseColorTexture["index"].getInt()
        else:
          material.pbrMetallicRoughness.baseColorTexture.index = -1

      result.materials.add(material)

  if jsonRoot.hasKey("animations"):
    for entry in jsonRoot["animations"]:
      var animation = Animation()

      for entry in entry["samplers"]:
        var animationSampler = AnimationSampler()
        animationSampler.input = entry["input"].getInt()
        animationSampler.output = entry["output"].getInt()

        let interpolation = entry["interpolation"].getStr()
        case interpolation:
          of "LINEAR":
            animationSampler.interpolation = iLinear
          of "STEP":
            animationSampler.interpolation = iStep
          of "CUBICSPLINE":
            animationSampler.interpolation = iCubicSpline
          else:
            raise newException(
              Exception,
              &"Unsupported animation sampler interpolation {interpolation}"
            )

        animation.samplers.add(animationSampler)

      for entry in entry["channels"]:
        var animationChannel = AnimationChannel()
        animationChannel.sampler = entry["sampler"].getInt()
        animationChannel.target.node = entry["target"]["node"].getInt()

        let path = entry["target"]["path"].getStr()
        case path:
          of "translation":
            animationChannel.target.path = pTranslation
          of "rotation":
            animationChannel.target.path = pRotation
          of "scale":
            animationChannel.target.path = pScale
          of "weights":
            animationChannel.target.path = pWeights
          else:
            raise newException(
              Exception,
              &"Unsupported animation channel path {path}"
            )

        animation.channels.add(animationChannel)

      result.animations.add(animation)

  for entry in jsonRoot["accessors"]:
    var accessor = Accessor()
    accessor.bufferView = entry["bufferView"].getInt()
    accessor.byteOffset = entry{"byteOffset"}.getInt()
    accessor.count = entry["count"].getInt()
    accessor.componentType = entry["componentType"].getInt().GLenum

    let accessorKind = entry["type"].getStr()
    case accessorKind:
      of "SCALAR":
        accessor.kind = atSCALAR
      of "VEC2":
        accessor.kind = atVEC2
      of "VEC3":
        accessor.kind = atVEC3
      of "VEC4":
        accessor.kind = atVEC4
      of "MAT2":
        accessor.kind = atMAT2
      of "MAT3":
        accessor.kind = atMAT3
      of "MAT4":
        accessor.kind = atMAT4
      else:
        raise newException(
          Exception,
          &"Invalid accessor type {accessorKind}"
        )

    result.accessors.add(accessor)

  for entry in jsonRoot["meshes"]:
    var mesh = Mesh()
    mesh.name = entry{"name"}.getStr()

    for entry in entry["primitives"]:
      var
        primitive = Primitive()
        attributes = entry["attributes"]

      if attributes.hasKey("POSITION"):
        primitive.attributes.position = attributes["POSITION"].getInt()
      else:
        primitive.attributes.position = -1

      if attributes.hasKey("NORMAL"):
        primitive.attributes.normal = attributes["NORMAL"].getInt()
      else:
        primitive.attributes.normal = -1

      if attributes.hasKey("COLOR_0"):
        primitive.attributes.color0 = attributes["COLOR_0"].getInt()
      else:
        primitive.attributes.color0 = -1

      if attributes.hasKey("TEXCOORD_0"):
        primitive.attributes.texcoord0 = attributes["TEXCOORD_0"].getInt()
      else:
        primitive.attributes.texcoord0 = -1

      if entry.hasKey("indices"):
        primitive.indices = entry["indices"].getInt()
      else:
        primitive.indices = -1

      if entry.hasKey("material"):
        primitive.material = entry["material"].getInt()
      else:
        primitive.material = -1

      if entry.hasKey("mode"):
        primitive.mode = entry["mode"].getInt().GLenum
      else:
        primitive.mode = GL_TRIANGLES

      result.primitives.add(primitive)
      mesh.primitives.add(len(result.primitives) - 1)

    result.meshes.add(mesh)

  for entry in jsonRoot["nodes"]:
    var node = Node()
    node.name = entry{"name"}.getStr()

    if entry.hasKey("children"):
      for child in entry["children"]:
        node.kids.add(child.getInt())

    if entry.hasKey("mesh"):
      node.mesh = entry["mesh"].getInt()
    else:
      node.mesh = -1

    if entry.hasKey("matrix"):
      node.applyMatrix = true

      let values = entry["matrix"]
      assert len(values) == 16
      for i in 0..<16:
        node.matrix[i.mod 16, i.div 16] = values[i].getFloat()

    if entry.hasKey("rotation"):
      let values = entry["rotation"]
      assert len(values) == 4
      node.rotation.x = values[0].getFloat()
      node.rotation.y = values[1].getFloat()
      node.rotation.z = values[2].getFloat()
      node.rotation.w = values[3].getFloat()
    else:
      node.rotation.w = 1

    if entry.hasKey("translation"):
      let values = entry["translation"]
      assert len(values) == 3
      node.translation.x = values[0].getFloat()
      node.translation.y = values[1].getFloat()
      node.translation.z = values[2].getFloat()

    if entry.hasKey("scale"):
      let values = entry["scale"]
      assert len(values) == 3
      node.scale.x = values[0].getFloat()
      node.scale.y = values[1].getFloat()
      node.scale.z = values[2].getFloat()
    else:
      node.scale.x = 1
      node.scale.y = 1
      node.scale.z = 1

    result.nodes.add(node)

  for entry in jsonRoot["scenes"]:
    var scene = Scene()
    for node in entry["nodes"]:
      scene.nodes.add(node.getInt())
    result.scenes.add(scene)

  result.scene = jsonRoot["scene"].getInt()

proc loadGltf*(win: Window, path: string): aglet.Mesh[Vertex] =
  let
    model = loadModel(path)
    (verts, tris) = model.toVerts
  win.newMesh[: Vertex, uint32](dpTriangles, verts, tris, muStatic)
