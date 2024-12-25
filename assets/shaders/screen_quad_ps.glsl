#version 460 core

in vec2 ps_uv_tex;

uniform sampler2D SrcTexture;

out vec4 FragColor;

void main()
{
	FragColor = texture(SrcTexture, ps_uv_tex);
	// FragColor = vec4(1.0, 0.0,0.0,1.0);
}
