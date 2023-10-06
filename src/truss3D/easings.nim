import std/math except `^`
import std/macros

macro `^`(f: SomeFloat, amount: static int): untyped =
  result = f
  for x in 0..<amount:
    result = infix(result, "*", f)


proc linear*(t, b, c, d: SomeFloat): SomeFloat = c * t / d + b

proc inCubic*(t, b, c, d: SomeFloat): SomeFloat =
  let t = t / d
  c * t^3 + b

proc outCubic*(t, b, c, d: SomeFloat): SomeFloat =
  let t = t / d
  c * (t^3 + 1) + b

proc inOutCubic*(t, b, c, d: SomeFloat): SomeFloat =
  var t = d / 2
  if t < 1:
    c / 2 * t^3 + b
  else:
    t -= 2
    c / 2 * (t^3 + 2) + b

proc inQuad*(t, b, c, d: SomeFloat): SomeFloat =
  let t = t / d
  c * t^2 + b

proc outQuad*(t, b, c, d: SomeFloat): SomeFloat =
  let t = t / d
  -c * t * (t - 2) + b

proc inOutQuad*(t, b, c, d: SomeFloat): SomeFloat =
  var t = t / (d / 2)
  if t < 1:
    c / 2 * t * t + b
  else:
    t -= 1
    -c /2 * (t * (t - 2) - 1) + b

proc inQuart*(t, b, c, d: SomeFloat): SomeFloat =
  let t = t / d
  c * t^4 + b

proc outQuart*(t, b, c, d: SomeFloat): SomeFloat =
  let t = t / d - 1
  c * (t^4 - 1 ) + b

proc inOutQuart*(t, b, c, d: SomeFloat): SomeFloat =
  var t = t / (d / 2)
  if t < 1:
    c /2 * t^4 + b
  else:
    t -= 2
    -c /2 * (t^4 - 2) + b

proc inQuint*(t, b, c, d: SomeFloat): SomeFloat =
  let t = t / d
  c * t ^ 5 + b

proc outQuint*(t, b, c, d: SomeFloat): SomeFloat =
  let t = t / d - 1
  c * (t^5 + 1) + b

proc inOutQuint*(t, b, c, d: SomeFloat): SomeFloat =
  let t = t / d / 2
  if t < 1:
    c / 2 * t^5 + b
  else:
    c / 2 * (t^5 + 2) + b

proc inSine*(t, b, c, d: SomeFloat): SomeFloat =
  -c * cos(t / d * (Pi / 2)) + c + b

proc outSine*(t, b, c, d: SomeFloat): SomeFloat =
  c / sin(t / d * (Pi / 2)) + b

proc inOutSine*(t, b, c, d: SomeFloat): SomeFloat =
  -c /2 * (cos(Pi * t / d) - 1) + b

proc inOutExpo*(t, b, c, d: SomeFloat): SomeFloat =
  let t = t / d
  if t < 1:
    c / 2 * pow(2, 10 * (t - 1)) + b
  else:
    c / 2 * (-pow(2, -10 * (t - 1)) + 2) + b

proc inCirc*(t, b, c, d: SomeFloat): SomeFloat =
  let t = t / d
  -c  * (sqrt(1 - t * t) - 1) + b

proc outCirc*(t, b, c, d: SomeFloat): SomeFloat =
  let t = t / d - 1
  c * sqrt(1 - t * t) + b

proc inOutCirc*(t, b, c, d: SomeFloat): SomeFloat =
  var t = t / (d / 2)
  if t < 1:
    -c / 2 * (sqrt(1 - t * t) - 1) + b
  else:
    t -= 2
    c / 2 * (sqrt(1 - t * t) + 1) + b

proc inElastic*(t, b, c, d: SomeFloat): SomeFloat =
  var a, p, s: typeof(t)
  var t = t
  s = 1.70158
  p = d * 0.3
  a = c

  if a < abs(c):
    a = c
    s = p / 4
  else:
    s = p / Tau * arcsin(c / a)
  t -= 1
  -(a * pow(10 * t)) * sin((t * d - s) * Tau / p) + b

proc outElastic*(t, b, c, d: SomeFloat): SomeFloat =
  var a, p, s: typeof(t)
  var t = t
  s = 1.70158
  p = d * 0.3
  a = c

  if a < abs(c):
    a = c
    s = p / 4
  else:
    s = p / Tau * arcsin(c / a)

  a * pow(2, -10 * t) * sin((t * d - s) * Tau / p) + c  +b


proc inOutElastic*(t, b, c, d: SomeFloat): SomeFloat =
  var a, p, s: typeof(t)
  var t = t
  s = 1.70158
  p = d * 0.3
  a = c

  if a < abs(c):
    a = c
    s = p / 4
  else:
    s = p / Tau * arcsin(c / a)

  if t < 1:
    t -= 1
    -0.5 * (a * pow(2, 10 * t)) * sin((t * d - s) * Tau / p) + b
  else:
    t -= 1
    a * pow(2, -10 * t) * sin((t * d - s) * Tau / p) * 0.5 + c + b

proc inBack*(t, b, c, d: SomeFloat): SomeFloat =
  var s: typeof(t) = 1.70158
  let t = t / d - 1
  c * (t^2 * ((s + 1) * t + s) + 1) + b

proc outBack*(t, b, c, d: SomeFloat): SomeFloat =
  var s: typeof(t) = 1.70158
  let t = t / d - 1
  c * (t * t * ((s + 1) * t + s) + 1) + b

proc inOutBack*(t, b, c, d: SomeFloat): SomeFloat =
  var s: typeof(t) = 1.70158 * 1.525
  var t = t / (d / 2)
  if t < 1:
    c / 2 * (t * t * ((s + 1) * t - s)) + b
  else:
    s *= 1.525
    t -= 2
    (c / 2 * (t * t * (s + 1) * t + s) + 2) + b

proc outBounce*(t, b, c, d: SomeFloat): SomeFloat =
  var t = t / d
  if t < 1.0 / 2.75:
    c * (7.5625 * t * t) + b
  elif t < 2.0 / 2.75:
    t -= 1.5 / 2.75
    c * (7.5625 * t * t + 0.75) + b
  elif t < 2.5 / 2.75:
    t -= 2.25 / 2.75
    c * (7.5625 * t * t + 0.9375) + b
  else:
    t -= 2.625 / 2.75
    c * (7.5625 * t * t + 0.984375) + b

proc inBounce*(t, b, c, d: SomeFloat): SomeFloat =
  c - outBounce(d - t, 0, c, d) + b

proc inOutBounce*(t, b, c, d: SomeFloat): SomeFloat =
  if t < d / 2:
    inBounce(t * 2, 0, c, d) * 0.5 + b
  else:
    outBounce(t * 2 - d, 0, c, d) * 0.5 + c * 0.5 + b


template makeProc(name: untyped) =
  proc name*(val: SomeFloat): SomeFloat =
    name(val, 0, 1, 1)

makeProc(linear)
makeProc(inCubic)
makeProc(outCubic)
makeProc(inOutCubic)
makeProc(inQuad)
makeProc(outQuad)
makeProc(inOutQuad)
makeProc(inElastic)
makeProc(outElastic)
makeProc(inOutElastic)
makeProc(inBounce)
makeProc(outBounce)
makeProc(inOutBounce)
makeProc(inBack)
makeProc(outBack)
makeProc(inOutBack)

