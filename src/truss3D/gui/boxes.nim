import ../gui

type Box* = ref object of TrussUiElement

proc box*(): Box =
  Box(flags: {onlyVisual})
