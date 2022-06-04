import miniaudio
export miniaudio # Easier than selectively choosing all the operations, code smell though
import vmath

type
  SoundEffect* = object
    sound*: Sound
    positionFunc: proc(): Vec3

var
  engine: AudioEngine
  soundEffects: seq[SoundEffect]


proc init*() =
  engine = AudioEngine.new()

proc loadSound*(path: string, looping, spatial = false): SoundEffect =
  result = SoundEffect(sound: engine.loadSoundFromFile(path))
  result.sound.looping = looping
  result.sound.spatial = spatial

proc setListeningPos*(pos: Vec3) =
  for listener in engine.listenerIter:
    engine.setListenerPos(listener, pos)

proc setListeningDir*(dir: Vec3) =
  for listener in engine.listenerIter:
    engine.setListenerDir(listener, dir)

proc play*(sound: SoundEffect, positionFunc: proc(): Vec3 = nil): Sound {.discardable.} =
  soundEffects.add SoundEffect(positionFunc: positionFunc)
  result = engine.duplicate(sound.sound)
  soundEffects[^1].sound = result
  result.looping = sound.sound.looping
  result.volume = sound.sound.volume
  result.spatial = sound.sound.spatial
  result.start()



proc update*() =
  if soundEffects.len > 0:
    for i in countdown(soundEffects.high, 0):
      if soundEffects[i].sound.atEnd:
        soundEffects[i].sound.maSoundUninit()
        soundEffects.del(i)
        continue

      if soundEffects[i].positionFunc != nil:
        soundEffects[i].sound.position = soundEffects[i].positionFunc()
