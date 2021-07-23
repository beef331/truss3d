#version 430

layout(location = 0) in vec3 vertex_position;
uniform mat4 mvp;
void main() {
  gl_Position = mvp * vec4(vertex_position, 1.0);
}