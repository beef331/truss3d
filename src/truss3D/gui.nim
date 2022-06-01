import vmath, pixie, truss3D
import truss3D/[textures, shaders, inputs, models]
import std/[options, sequtils, sugar, macros, genasts]
export pixie

type
  GuiState* = enum
    nothing, over, interacted



const
  vertShader = ShaderFile"""
#version 430

layout(location = 0) in vec3 vertex_position;
layout(location = 2) in vec2 uv;


uniform mat4 modelMatrix;

out vec2 fuv;


void main() {
  gl_Position = modelMatrix * vec4(vertex_position, 1.0);
  fuv = uv;
}
"""
  fragShader = ShaderFile"""
#version 430
out vec4 frag_color;

uniform sampler2D tex;
uniform sampler2D backgroundTex;
uniform float nineSliceSize;


uniform int hasTex;
uniform vec4 color;
uniform vec4 backgroundColor;

uniform vec2 size;

in vec2 fuv;

void main() {
  if(nineSliceSize > 0){
    ivec2 texSize = textureSize(backgroundTex, 0);
    vec2 realUv = size * fuv;
    vec2 myUv = fuv;
    if(realUv.x < nineSliceSize){
      myUv.x = realUv.x / (texSize.x - nineSliceSize);
    }
    if(realUv.x > size.x - nineSliceSize){
      myUv.x = (realUv.x - size.x) / (texSize.x - nineSliceSize);
    }
    if(realUv.y < nineSliceSize){
      myUv.y = realUv.y / (texSize.x - nineSliceSize);
    }
    if(realUv.y > size.y - nineSliceSize){
      myUv.y = (realUv.y - size.y) / (texSize.x - nineSliceSize);
    }
    frag_color = texture(backgroundTex, myUv) * backgroundColor;
  }
  else if(hasTex > 0){
    vec4 newCol = texture(tex, fuv);
    vec4 oldCol = frag_color;
    frag_color = mix(frag_color, newCol * color, newCol.a);
    frag_color = mix(frag_color, backgroundColor, 1.0 - frag_color.a);
  }else{
    frag_color = color;
  }
}
"""


var
  uiShader*: Shader
  uiQuad*: Model
  guiState* = GuiState.nothing


proc init*() =
  uiShader = loadShader(vertShader, fragShader)
  var meshData: MeshData[Vec2]
  meshData.appendVerts([vec2(0, 0), vec2(0, 1), vec2(1, 1), vec2(1, 0)].items)
  meshData.append([0u32, 1, 2, 0, 2, 3].items)
  meshData.appendUv([vec2(0, 1), vec2(0, 0), vec2(1, 0), vec2(1, 1)].items)
  uiQuad = meshData.uploadData()

import guicomponents/[dropdowns, buttons, labels, scrollbar, uielements, layoutgroups, textareas]
export dropdowns, buttons, labels, scrollbar, uielements, layoutgroups, textareas


macro makeUi*(t: typedesc, body: untyped): untyped =
  ## Nice DSL to make life less of a chore
  let
    constr = newCall("new", t)
    childrenAdd = newStmtList()
    uiName = genSym(nskVar, "ui")
  var visCond: NimNode
  var gotPos = false

  for statement in body:
    if statement[0].eqIdent"children":
      for child in statement[1]:
        childrenAdd.add newCall("add", uiName, child)
    else:
      if statement[0].eqIdent"pos":
        gotPos = true
      if statement[0].eqIdent"visibleCond":
        visCond = statement[1]
      else:
        constr.add nnkExprEqExpr.newTree(statement[0], statement[1])
  if not gotPos:
    constr.add nnkExprEqExpr.newTree(ident"pos", newCall("ivec2", newLit 0))
  result = genast(uiName, childrenAdd, constr, visCond):
    block:
      var uiName = constr
      when visCond != nil:
        uiName.visibleCond = visCond
      childrenAdd
      uiName
