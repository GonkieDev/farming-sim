package render

import bc "./backend_common"
import backend "./gl"
import textures "engine:assets/textures"

Texture_Key :: bc.Texture_Key
Shader_Key :: bc.Shader_Key
RenderTarget_Key :: bc.RenderTarget_Key

Viewport :: bc.Viewport
Scissor :: bc.Scissor
Render_Begin :: bc.Render_Begin
Render_Begin_Pass :: bc.Render_Begin_Pass
Render_End_Pass :: bc.Render_End_Pass
Material :: bc.Material
Render_Pass_Flags :: bc.Render_Pass_Flags
Sprite_Draw_Data :: bc.Sprite_Draw_Data

init :: proc() -> bool {
	return backend.init()
}

shutdown :: proc() {
	backend.shutdown()
}

render_begin :: proc(rbegin: ^Render_Begin) {
	backend.render_begin(rbegin)
}

render_end :: proc() {
	backend.render_end()
}

render_begin_pass :: proc(target: ^bc.Render_Begin_Pass) {
	backend.render_begin_pass(target)
}
render_end_pass :: proc(target: ^bc.Render_End_Pass) {
	backend.render_end_pass(target)
}

texture_upload :: proc(
	texture: textures.Texture,
	generate_mips: bool,
) -> (
	texture_key: Texture_Key,
	success: bool,
) {
	return backend.texture_upload(texture, generate_mips)
}
texture_upload_from_data :: proc(
	width, height, depth, channels: i32,
	generate_mips: bool,
	pixels: rawptr,
) -> (
	texture_key: Texture_Key,
	success: bool,
) {
	return backend.texture_upload_from_data(width, height, depth, channels, generate_mips, pixels)
}
texture_destroy :: proc(texture_key: Texture_Key) {
	backend.texture_destroy(texture_key)
}

texture_update :: proc(
	texture_key: Texture_Key,
	x, y, width, height, depth, channels: int,
	pixels: rawptr,
) -> (
	success: bool,
) {
	return backend.texture_update(
		texture_key = texture_key,
		x = x,
		y = y,
		width = width,
		height = height,
		depth = depth,
		channels = channels,
		pixels = pixels,
	)
}

shader_create :: proc(
	vs_filepath: string,
	ps_filepath: string,
) -> (
	shader_key: Shader_Key,
	success: bool,
) {
	return backend.shader_create(vs_filepath, ps_filepath)
}
shader_destroy :: proc(shader_key: Shader_Key) {
	backend.shader_destroy(shader_key)
}

render_target_create :: proc(
	flags: Render_Pass_Flags,
	dims: [2]i32,
) -> (
	render_target_key: RenderTarget_Key,
	success: bool,
) {
	return backend.render_target_create(flags, dims)
}

debug_render_line :: proc(debug_render_line: bc.Debug_Render_Line) {
	backend.debug_render_line(debug_render_line)
}

default_shader :: proc() -> Shader_Key {
	return backend.default_shader()
}
