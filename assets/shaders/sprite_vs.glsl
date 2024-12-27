#version 460 core
#extension GL_ARB_bindless_texture : require

layout (std140, binding = 0) uniform Global_UBO
{
	mat4 proj;
	mat4 view;
	vec2 screen_size;
	vec2 _pad;
};

struct Sprite_Draw_Data {
	float tint[4];
	float dims[2];
	float offset[2];
	float uv_offset[2];
	float uv_dims[2];
	uvec2 tex_handle;
	float _padding[2];
};

//https://ktstephano.github.io/rendering/opengl/prog_vtx_pulling
layout(binding = 0, std430) readonly buffer ssbo1 {
	Sprite_Draw_Data sprite_draw_data[];
};

vec4 get_tint(int idx)
{
	return vec4(
		sprite_draw_data[idx].tint[0],
		sprite_draw_data[idx].tint[1],
		sprite_draw_data[idx].tint[2],
		sprite_draw_data[idx].tint[3]
	);
}

vec2 get_dims(int idx)
{
	return vec2(
		sprite_draw_data[idx].dims[0],
		sprite_draw_data[idx].dims[1]
	);
}

vec2 get_offset(int idx)
{
	return vec2(
		sprite_draw_data[idx].offset[0],
		sprite_draw_data[idx].offset[1]
	);
}

vec2 get_uv_offset(int idx)
{
	return vec2(
		sprite_draw_data[idx].uv_offset[0],
		sprite_draw_data[idx].uv_offset[1]
	);
}

vec2 get_uv_dims(int idx)
{
	return vec2(
		sprite_draw_data[idx].uv_dims[0],
		sprite_draw_data[idx].uv_dims[1]
	);
}

uvec2 get_tex_handle(int idx)
{
	return sprite_draw_data[idx].tex_handle;
}

out flat uvec2 v2f_tex_handle;
out vec2 v2f_uv;
out vec4 v2f_tint;

void main()
{
	vec2 verts[] = {
		vec2(-0.5, -0.5),
		vec2( 0.5,  0.5),
		vec2( 0.5, -0.5),

		vec2(-0.5, -0.5),
		vec2(-0.5,  0.5),
		vec2( 0.5,  0.5),
	};
	vec2 uvs[] = {
		// vec2(0.0, 0.0),
		// vec2(1.0, 1.0),
		// vec2(1.0, 0.0),
		//
		// vec2(0.0, 0.0),
		// vec2(0.0, 1.0),
		// vec2(1.0, 1.0),

		// Flipped
		vec2(0.0, 1.0),
		vec2(1.0, 0.0),
		vec2(1.0, 1.0),

		vec2(0.0, 1.0),
		vec2(0.0, 0.0),
		vec2(1.0, 0.0),
	};

	int idx = gl_VertexID / 6;
	vec4 tint = get_tint(idx);
	vec2 dims = get_dims(idx);
	vec2 offset = get_offset(idx);
	vec2 uv_dims = get_uv_dims(idx);
	vec2 uv_offset = get_uv_offset(idx);
	uvec2 tex_handle = get_tex_handle(idx);

	vec2 vert = verts[gl_VertexID % 6] * dims + offset;
	vec4 pos = proj * view * vec4(vert, 0.0, 1.0);
	gl_Position = pos;

	v2f_tex_handle = tex_handle;
	v2f_uv = uv_offset + uv_dims * uvs[gl_VertexID % 6];
	v2f_tint = tint;
}
