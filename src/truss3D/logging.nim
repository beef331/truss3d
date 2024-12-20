import std/logging as logg
import std/[os, strutils, terminal, colors, times]

type ColoredConsoleLogger = ref object of ConsoleLogger

proc newColoredLogger*(threshold = lvlAll, fmtStr = defaultFmtStr, useStderr = false): ColoredConsoleLogger =
  ColoredConsoleLogger(levelThreshold: threshold, fmtStr: fmtStr, useStderr: useStderr)

const LevelColours: array[Level, Color] = [colWhite, colWhite, colDarkCyan, colDarkOliveGreen, colOrange, colRed, colDarkRed, colWhite]

method log*(logger: ColoredConsoleLogger, level: Level, args: varargs[string, `$`]) {.gcsafe.} =
  let color = ansiForegroundColorCode(LevelColours[level])

  stdout.write(color)
  procCall(logg.log(ConsoleLogger(logger), level, args))
  stdout.write(ansiResetCode)

when defined(truss3D.log):
  var handlers*: seq[Logger]

const debugLevel* {.define: "truss3D.debugLevel".} = 0


when defined(truss3D.log):
  export log, fatal, error, warn, info
else:
  import std/macros


  template info*(args: varargs[typed]) = unpackVarargs(echo, args)
  template error*(args: varargs[typed]) = unpackVarargs(echo, args)
  template warn*(args: varargs[typed]) = unpackVarargs(echo, args)
  template fatal*(args: varargs[typed]) = unpackVarargs(echo, args)

proc addLoggers*(appName: string) =
  when defined(truss3D.log):
    addHandler newColoredLogger()
    let 
      dir = getCacheDir(appName)
      time = getTime()
      logName = time.format("yyyy-MM-dd-ss") & ".log"
    try:
      createDir(dir)
      addHandler newFileLogger(dir / logName)
    except IoError as e:
      error e.msg
    except OsError as e:
      error e.msg

    handlers = getHandlers()



