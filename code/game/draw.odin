package game

import render "engine:render"

draw_sprite :: proc(sprite_draw_data: ^[dynamic]render.Sprite_Draw_Data, sprite: ^Sprite) {
	SDD :: render.Sprite_Draw_Data

	frame_idx := 2

	sdd_from_sprite_frame_layer :: proc(layer: ^Sprite_Frame_Layer, dims: [2]f32, tint: Color, z: f32) -> render.Sprite_Draw_Data {
		ar := &layer.atlas_result
		tex_id := atlas_texture_from_result(&state.sprites_atlas, ar^)
		assert(ar.uv_dims != {})
		return SDD{tint = tint, dims = dims, offset = {}, uv_offset = ar.uv_offset, uv_dims = ar.uv_dims, texture_id = tex_id, z = z}
	}

	dims := [2]f32{700, 700}

	// TODO: remove
	red := v4{1.0, 0.0, 0.0, 1.0}
	green := v4{0.0, 1.0, 0.0, 1.0}
	blue := v4{0.0, 0.0, 1.0, 1.0}
	white := v4{1.0, 1.0, 1.0, 1.0}
	colors := [?][4]f32{red, green, blue, white}

	frame := &sprite.frames[frame_idx]

	// Draw mods
	for &mod, mod_idx in frame.mods {
			//odinfmt:disable
		mod_colors := []Color{
			{1.0, 0.0, 0.0, 1.0},
			{0.0, 1.0, 0.0, 1.0},
			{0.0, 0.0, 1.0, 1.0},
			{1.0, 1.0, 1.0, 1.0},
			{1.0, 1.0, 1.0, 1.0},
		}
		//odinfmt:enable
		tint := mod_colors[mod_idx]
		//tint := sprite.sprite_asset.mod_colors[0][mod_idx]
		sdd := sdd_from_sprite_frame_layer(&mod, dims, tint, f32(mod_idx) - f32(len(frame.mods)))
		append(sprite_draw_data, sdd)
	}

	// Draw base
	if sprite_frame_has_base(frame) {
		base_sdd := sdd_from_sprite_frame_layer(&frame.base, dims, {1.0, 1.0, 1.0, 1.0}, z = 1)
		append(sprite_draw_data, base_sdd)
	}
}
