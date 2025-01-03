#version 460 core
#extension GL_ARB_bindless_texture : require

in flat uvec2 v2f_tex_handle;
in vec2 v2f_uv;
in vec4 v2f_tint;

out vec4 FragColor;

void main()
{
	sampler2D tex = sampler2D(v2f_tex_handle);
	FragColor = v2f_tint * texture(tex, v2f_uv);
	// if (FragColor.a == 0.0) {
	// 	discard;
	// }
}



