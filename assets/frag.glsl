#version 430
out vec4 frag_colour;
in vec3 fNormal;
in vec2 fUv;
uniform sampler2D tex;

void main() {
  frag_colour = texture(tex, fUv);
  frag_colour *= dot(fNormal, normalize(vec3(1, 0, 1))) * 0.5 + 0.5;
}
