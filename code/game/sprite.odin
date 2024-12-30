package game

import "base:runtime"

import log "engine:log"
import atlas_manager "engine:atlas"
import textures "engine:assets/textures"
import build_config "engine:build_config"

Asset :: string
Color :: [4]f32

Sprite_Asset :: struct {
	atlas_result: atlas_manager.Atlas_Result,
	asset: Asset,
}

Sprite_Frame :: struct {
	base: Sprite_Asset,
	mods: []Sprite_Asset,
}

Sprite :: struct {
	frames:    []Sprite_Frame,
	durations: []f32,
	colors:    [][]Color, // one per 'mod' layer * one per choice
}

Sprite_IDs :: enum {
	Player_Walk_East,
}

Frame_Load_Info :: struct {
	base: Asset,
	mods: []Asset,
}

Sprite_Load_Info :: struct {
	frames: []Frame_Load_Info,
}

sprites: [Sprite_IDs]Sprite

load_sprites :: proc() -> (ok: bool) {
	A :: build_config.ASSETS_PATH + "player/"
	load_info := Sprite_Load_Info {
		frames = {
			0 = {
				base = A + "East_0_non_mod.png",
				mods = {
					A + "East_0_mod_0.png",
					A + "East_0_mod_1.png",
					A + "East_0_mod_2.png",
				},
			},
		},
	}
	sprites[.Player_Walk_East] = load_sprite(load_info) or_return

	ok = true
	return
}

load_sprite :: proc(sprite_load_info: Sprite_Load_Info) -> (sprite: Sprite, ok: bool) {
	if len(sprite_load_info.frames) == 0 {
		log.error(.Sprite, "Failed to load sprite: 0 frames")
		return
	}

	alloc_err: runtime.Allocator_Error

	sprite.frames, alloc_err = make([]Sprite_Frame, len(sprite_load_info.frames))
	if alloc_err != nil {
		log.error(.Sprite, "Failed to allocate memory for sprites' frames information.")
		return
	}
	for frame_load_info, frame_idx in sprite_load_info.frames {
		sprite.frames[frame_idx] = load_frame(frame_load_info) or_return
	}

	ok = true
	return
}

load_frame :: proc(frame_load_info: Frame_Load_Info) -> (frame: Sprite_Frame, ok: bool) {
	if frame_load_info.base == "" && len(frame_load_info.mods) == 0 {
		log.error(.Sprite, "Failed to load sprite's frame: no base or modifiable layers.")
		return
	}

	atlas := &state.sprites_atlas
	alloc_err: runtime.Allocator_Error
	
	if frame_load_info.base != {} {
		frame.base = load_sprite_asset(frame_load_info.base, false) or_return
	}
	frame.mods, alloc_err = make([]Sprite_Asset, len(frame_load_info.mods))
	if alloc_err != nil {
		log.error(.Sprite, "Failed to allocate memory for modifiable layers of a sprite.")
		return
	}
	for mod, mod_idx in frame_load_info.mods {
		frame.mods[mod_idx] = load_sprite_asset(mod, true) or_return
	}

	ok = true
	return
}

load_sprite_asset :: proc(asset: Asset, is_mod: bool) -> (sprite_asset: Sprite_Asset, ok: bool) {
	defer {
		if !ok {
			log.errorf(.Sprite, "Failed to load sprite asset %s", asset)
		}
	}

	atlas := &state.sprites_atlas

	sprite_asset.asset = asset

	tex := textures.texture_load(asset) or_return
	sprite_asset.atlas_result = atlas_manager.atlas_reserve(
		atlas,
		{tex.width, tex.height},
		//is_mod,
		false,
		raw_data(tex.pixels.buf),
	) or_return

	ok = true
	return
}

sprite_frame_has_base :: proc(frame: ^Sprite_Frame) -> bool {
	return frame.base.asset != {}
}
