import std/logging as logg
import std/[os, strutils, terminal, colors, times]

type ColoredConsoleLogger = ref object of ConsoleLogger

proc newColoredLogger*(threshold = lvlAll, fmtStr = defaultFmtStr, useStderr = false): ColoredConsoleLogger =
  ColoredConsoleLogger(levelThreshold: threshold, fmtStr: fmtStr, useStderr: useStderr)

const LevelColours: array[Level, Color] = [colWhite, colWhite, colDarkCyan, colDarkOliveGreen, colOrange, colRed, colDarkRed, colWhite]

method log*(logger: ColoredConsoleLogger, level: Level, args: varargs[string, `$`]) {.gcsafe.} =
  let
    color = ansiForegroundColorCode(LevelColours[level])
    lvlname = LevelNames[level]
  stdout.write(color)
  procCall(logg.log(ConsoleLogger(logger), level, args))
  stdout.write(ansiResetCode)

when defined(truss3D.log):
  var handlers*: seq[Logger]

proc addLoggers*(appName: string) =
  when defined(truss3D.log):
    addHandler newColoredLogger()
    let 
      dir = getCacheDir(appName)
      time = getTime()
      logName = time.format("yyyy-MM-dd-ss") & ".log"
    discard existsOrCreateDir(dir)
    addHandler newFileLogger(dir / logName)
    handlers = getHandlers()

when defined(truss3D.log):
  export log, fatal, error, warn, info
else:
  template info*(args: varargs[untyped, `$`]) = echo args
  template error*(args: varargs[untyped, `$`]) = echo args
  template warn*(args: varargs[untyped, `$`]) = echo args
  template fatal*(args: varargs[untyped, `$`]) = echo args

