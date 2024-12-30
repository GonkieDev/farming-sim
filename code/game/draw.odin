package game

import render "engine:render"
import atlas_manager "engine:atlas"

draw_sprite :: proc(sprite_draw_data: ^[dynamic]render.Sprite_Draw_Data, sprite: ^Sprite) {
	SDD :: render.Sprite_Draw_Data

	frame := &sprite.frames[0]

	sdd_from_sprite_asset :: proc(sa: ^Sprite_Asset, dims: [2]f32, tint: Color, z: f32) -> render.Sprite_Draw_Data {
		ar := &sa.atlas_result
		tex_id := atlas_manager.atlas_texture_from_result(&state.sprites_atlas, ar^)
		assert(ar.uv_dims != {})
		return SDD {
			tint = tint,
			dims = dims,
			offset = {},
			uv_offset = ar.uv_offset,
			uv_dims = ar.uv_dims,
			texture_id = tex_id,
			z = z,
		}
	}

	dims := [2]f32{300,300}

	// TODO: remove
	red := v4{1.0, 0.0, 0.0, 1.0}
	green := v4{0.0, 1.0, 0.0, 1.0}
	blue := v4{0.0, 0.0, 1.0, 1.0}
	white := v4{1.0,1.0,1.0,1.0}
	colors := [?][4]f32 {
		red,green,blue,white,
	}

	// Draw base
	if sprite_frame_has_base(frame) {
		base_sdd := sdd_from_sprite_asset(&frame.base, dims, {1.0,1.0,1.0,1.0}, z = -1)
		append(sprite_draw_data, base_sdd)
	}
	// Draw mods
	for &mod, mod_idx in frame.mods {
		sdd := sdd_from_sprite_asset(&mod, dims, colors[mod_idx], f32(mod_idx))
		append(sprite_draw_data, sdd)
	}

}
