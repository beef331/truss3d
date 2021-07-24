#version 430
out vec4 frag_colour;
in vec3 fNormal;
in vec2 fUv;
void main() {
  frag_colour = vec4(1, 1, 1, 1.0);
  frag_colour *= dot(fNormal, normalize(vec3(1, 0, 1))) * 0.5 + 0.5;
  frag_colour = vec4(fUv, 1, 1);
}