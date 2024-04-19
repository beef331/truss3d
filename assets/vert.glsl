#version 430

layout(location = 0) in vec3 vertex_position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 uv;

uniform mat4 mvp;
out vec3 fNormal;
out vec2 fUv;

void main() {
  gl_Position = mvp * vec4(vertex_position, 1.0);
  fNormal = normal;
  fUv = uv.xy;
}
