import truss3D, truss3D/[inputs], pkg/vmath

proc init(truss: var Truss) =
  discard

proc update(truss: var Truss, dt: float32) =
  for drop in truss.inputs.dropped:
    echo drop

proc draw(truss: var Truss) = discard



var truss = Truss.init("Something", ivec2(1280, 720), init, update, draw)
while truss.isRunning:
  truss.update()
