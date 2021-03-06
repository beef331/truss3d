import std/[strutils, parseutils]
import mesh
import glm
import aglet/window/glfw
import aglet

func parseVec[T: Vec2 | Vec3 | Vec4](s: string, pos: var int): T =
  for i in 0 ..< T.sizeof div 4: # 32bit values
    inc pos
    var val: float
    pos += s.parseFloat(val, pos)
    result[i] = val

func parseTris(s: string, pos: var int, mesh: var mesh.Mesh) = 
  let length = s.skipUntil(Newlines, pos) + pos
  while pos < length:
    var vals: array[3, uint]
    pos += s.parseUInt(vals[0], pos) + 1
    pos += s.parseUInt(vals[1], pos) + 1
    pos += s.parseUInt(vals[2], pos) + 1
    for x in vals.mitems: x -= 1
    mesh.tris.add vals
  pos += s.skipUntil('f', pos) - 1

proc parseObj*(path: string): mesh.Mesh =
  let s = readFile(path)
  var i = 0
  while i < s.len:
    case s[i]:
      of 'f': # triangle parse
        i.inc 2
        s.parseTris(i, result)
      of 'v': # per vertex
        inc i 
        case s[i]:
          of ' ': # vertex coord
            result.verts.add s.parseVec[: Vec3f](i)
          of 'n': # normal
            inc i
            result.normals.add s.parseVec[: Vec3f](i)
          of 't': # uv
            inc i
            result.uvs.add s.parseVec[: Vec2f](i)
          else:
            discard
      else:
        discard
    i += s.skipUntil({'\n', '\r'}, i) + 1

proc loadObjMesh*(win: var WindowGlfw, path: string): auto =
  let 
    model = parseObj(path)
    (verts, tris) = model.toVerts
  result = win.newMesh[: Vertex](dpTriangleFan, verts)
  