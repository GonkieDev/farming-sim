package render_gl

import "engine:hot_reload"
import bc "engine:render/backend_common"
import gl "vendor:OpenGL"

Global_UBO_Binding_Point :: 0
Global_UBO :: struct {
	matrices:    struct {
		proj: matrix[4, 4]f32,
		view: matrix[4, 4]f32,
	},
	screen_size: [2]f32,
	pad:         [2]f32,
}

GL_State :: struct {
	begin_info:         ^bc.Render_Begin,
	curr_pass:          ^bc.Render_Begin_Pass,
	default_vao:        GL_Id,
	global_ubo:         GL_Id,
	debug:              Debug_State,

	//
	sprite_shader:      Shader_Key,
	sprite_ssbo:        GL_Id,
	screen_quad_shader: Shader_Key,

	//
	textures:           [dynamic]GL_Texture,
	shaders:            [dynamic]GL_Shader,
	render_targets:     [dynamic]GL_RenderTarget,
}

GL_Id :: u32
GL_Id_Invalid :: 0xff_ff_ff_ff

GL_Texture :: struct {
	id:     GL_Id,
	handle: u64,
}

GL_Shader :: struct {
	program:       GL_Id,
	uniforms:      gl.Uniforms,
	vs_hot_reload: hot_reload.Hot_Reload,
	ps_hot_reload: hot_reload.Hot_Reload,
}

GL_RenderTarget :: struct {
	flags:         Render_Pass_Flags,
	dims:          [2]i32,
	framebuffer:   GL_Id,
	color_texture: Texture_Key,
	depth_texture: Texture_Key,
}

when ODIN_DEBUG {
	LINES_SSBO_COUNT :: 8192
	LINES_SSBO_SIZE :: size_of(Debug_GL_Render_Line_Vertex) * LINES_SSBO_COUNT
	Debug_GL_Render_Line_Vertex :: struct {
		pos:   [3]f32,
		_pad:  f32,
		color: [4]f32,
	}

	Debug_State :: struct {
		lines_ssbo:              GL_Id,
		lines_ssbo_vertex_count: u64,
		lines_shader:            Shader_Key,
		// NOTE: probably should be in a GL_Begin_Pass structure
		lines_vertices:          []Debug_GL_Render_Line_Vertex,
	}
} else {
	Debug_State :: struct {}
}

MAX_RENDER_SPRITES :: bc.MAX_RENDER_SPRITES
Sprite_Draw_Data :: bc.Sprite_Draw_Data
GL_Sprite_Draw_Data :: struct {
	tint:          [4]f32,
	dims:          [2]f32,
	offset:        [2]f32,
	uv_offset:     [2]f32,
	uv_dims:       [2]f32,
	texture_index: u64, // vec2 in opengl
	z:             f32,
	_padding:      f32,
}

MAX_RENDER_TEXTURES :: 256
