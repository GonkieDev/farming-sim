package game

import la "core:math/linalg"

import atlas "engine:atlas"
import input "engine:input"
import log "engine:log"
import render "engine:render"

Update_In :: struct {
	dt:          f32,
	input_state: ^input.Input_State,
}

Update_Out :: struct {
	moused_locked_to_center: bool,
	alpha:                   f32,
}

State :: struct {
	// RTs
	game_rt:                render.RenderTarget_Key,
	sprites_atlas:          atlas.Atlas,

	//
	common_textures:        Common_Textures,
	fixed_step_accumulator: f32,
}

Common_Textures :: struct {
	white: render.Texture_Key,
	black: render.Texture_Key,
}

state: ^State

init :: proc(client_dims: [2]i32) -> bool {
	state = new(State)
	if state == nil {
		log.error(.Game, "Failed to allocate memory for game state")
		return false
	}

	init_common_textures() or_return

	state.game_rt = render.render_target_create({.DepthStencil}, client_dims) or_return
	atlas.atlas_init(&state.sprites_atlas, smallest_size = 16, biggest_size = 128)

	load_sprites() or_return

	return true
}

shutdown :: proc() {
	if state != nil {
		atlas.atlas_delete(&state.sprites_atlas)
		free(state)
	}
}

FIXED_TIME_STEP :: f32(1.0 / 240.0)
MAX_FIXED_UPATES :: 10
fixed_update :: proc(data: Update_In, time_step: f32) {
}

update :: proc(data: Update_In) -> Update_Out {
	data := data
	data.dt = min(data.dt, FIXED_TIME_STEP * MAX_FIXED_UPATES)
	dt := data.dt

	state.fixed_step_accumulator += dt
	for {
		if state.fixed_step_accumulator < 0 {
			break
		}
		defer state.fixed_step_accumulator -= FIXED_TIME_STEP

		fixed_update(data, FIXED_TIME_STEP)
	}

	out := Update_Out {
		alpha                   = state.fixed_step_accumulator,
		moused_locked_to_center = false,
	}

	return out
}

render :: proc(client_dims: [2]i32) {

	render.render_begin(&{alpha = 0, client_dims = client_dims})
	defer render.render_end()

	proj: m4
	{
		hw := f32(client_dims.x) / 2.0
		hh := f32(client_dims.y) / 2.0
		proj = la.matrix_ortho3d_f32(-hw, hw, -hh, hh, -300.0, 300.0)
	}
	view := la.identity(m4)

	{
		render.render_begin_pass(
			&{
				render_target_key = state.game_rt,
				viewport = {br = client_dims},
				clear = {color = {0.2, 0.2, 0.2, 1.0}},
				proj = proj,
				view = view,
			},
		)

		sprite_draw_data := make([dynamic]render.Sprite_Draw_Data, context.temp_allocator)

		red := v4{1.0, 0.0, 0.0, 1.0}
		green := v4{0.0, 1.0, 0.0, 1.0}
		blue := v4{0.0, 0.0, 1.0, 1.0}
		white := v4{1.0,1.0,1.0,1.0}

		SDD :: render.Sprite_Draw_Data
		//append(&sprite_draw_data, SDD{tint = red, dims = {20, 50}, offset = {0, 50}})
		//append(&sprite_draw_data, SDD{tint = green, dims = {20, 50}})
		//append(&sprite_draw_data, SDD{tint = blue, dims = {30, 30}, offset = {80, 40}})

		draw_sprite(&sprite_draw_data, &sprites[.Player_Walk_East])

		render.render_end_pass(&{sprite_draw_data = sprite_draw_data[:]})
	}
}


init_common_textures :: proc() -> bool {
	using state.common_textures

	{
		pixels := [4]u8{255, 255, 255, 255}
		white = render.texture_upload_from_data(1, 1, 8, 4, false, &pixels[0]) or_return
	}
	{
		pixels := [4]u8{0, 0, 0, 0}
		black = render.texture_upload_from_data(1, 1, 8, 4, false, &pixels[0]) or_return
	}

	return true
}

material_default :: #force_inline proc() -> render.Material {
	return render.Material{color = v4{1.0, 1.0, 1.0, 1.0}, albedo = state.common_textures.white}
}
