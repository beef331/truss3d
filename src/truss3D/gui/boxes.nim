import ../gui

type Box* = ref object of UiElement

proc box*(): Box =
  Box(flags: {onlyVisual})
