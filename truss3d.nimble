# Package

version       = "0.1.0"
author        = "Jason"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.5.1"
requires "aglet"

task rund, "Runs the project":
  selfExec("c -r -d:debug --out:./truss3d.out ./src/truss3d")