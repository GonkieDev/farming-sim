#version 460 core

out vec2 ps_uv_tex;

void main()
{
	vec2 ndc_positions[6] = {
		vec2(-1.0, -1.0),
		vec2( 1.0,  1.0),
		vec2( 1.0, -1.0),

		vec2(-1.0, -1.0),
		vec2(-1.0,  1.0),
		vec2( 1.0,  1.0),
	};

	vec2 ndc_pos = ndc_positions[gl_VertexID];
	ps_uv_tex = (ndc_pos + vec2(1.0, 1.0)) * 0.5;
	gl_Position = vec4(ndc_pos, 0.0, 1.0);
}
