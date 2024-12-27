package render_backend_common

Texture_Key :: u64
Shader_Key :: u64
RenderTarget_Key :: u64

Rect :: struct {
	tl: [2]i32, // topleft
	br: [2]i32, // bottomright
}

Viewport :: distinct Rect
Scissor :: distinct Rect

Clear :: struct {
	color: [4]f32,
}

Render_Begin :: struct {
	alpha:       f32,
	client_dims: [2]i32,
}

Render_Pass_Flag :: enum {
	DepthStencil,
}
Render_Pass_Flags :: bit_set[Render_Pass_Flag]

Render_Begin_Pass :: struct {
	render_target_key: RenderTarget_Key,
	viewport:          Viewport,
	scissor:           Scissor,
	clear:             Clear,
	proj:              matrix[4, 4]f32,
	view:              matrix[4, 4]f32,
}

Render_End_Pass :: struct {
	sprite_draw_data: []Sprite_Draw_Data,
}

Material :: struct {
	color:  [4]f32,
	albedo: Texture_Key,
}

when ODIN_DEBUG {
	Debug_Render_Line :: struct {
		a, b:  [3]f32,
		color: [4]f32,
	}
} else {
	Debug_Render_Line :: struct {}
}

when ODIN_DEBUG {
	Command_Debug :: struct {
		name: string,
	}
} else {
	Command_Debug :: struct {}
}

MAX_RENDER_SPRITES :: 4096
Sprite_Draw_Data :: struct {
	tint:   [4]f32,
	dims:   [2]f32,
	offset: [2]f32,
	uv_offset: 		[2]f32,
	uv_dims: 		[2]f32,
	texture_id: Texture_Key,
}
