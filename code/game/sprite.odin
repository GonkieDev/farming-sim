package game

import "base:runtime"

import build_config "engine:build_config"
import image_loader "engine:image_loader"
import log "engine:log"

Sprite_Frame_Layer :: struct {
	atlas_result: Atlas_Result,
}

Sprite_Frame :: struct {
	base: Sprite_Frame_Layer,
	mods: []Sprite_Frame_Layer,
}

Sprite :: struct {
	frames:       []Sprite_Frame,
	sprite_asset: ^Asset_Sprite,
}

Sprite_IDs :: enum {
	Player_Walk_East,
}

sprites: [Sprite_IDs]Sprite

load_sprites :: proc() -> (ok: bool) {
	player_meta := sprite_meta_load(
		build_config.ASSETS_PATH + "player_sprite.sprite_meta",
	) or_return
	sprites[.Player_Walk_East] = load_sprite(&player_meta[0]) or_return

	ok = true
	return
}

@(require_results)
load_sprite :: proc(sprite_asset: ^Asset_Sprite) -> (sprite: Sprite, ok: bool) {
	if len(sprite_asset.frames) == 0 {
		log.error(.Sprite, "Failed to load sprite: 0 frames")
		return
	}

	alloc_err: runtime.Allocator_Error

	sprite.frames, alloc_err = make([]Sprite_Frame, len(sprite_asset.frames))
	if alloc_err != nil {
		log.error(.Sprite, "Failed to allocate memory for sprites' frames information.")
		return
	}
	for frame_load_info, frame_idx in sprite_asset.frames {
		sprite.frames[frame_idx] = load_frame(frame_load_info) or_return
	}

	sprite.sprite_asset = sprite_asset
	ok = true
	return
}

load_frame :: proc(sprite_frame_asset: Asset_Sprite_Frame) -> (frame: Sprite_Frame, ok: bool) {
	if sprite_frame_asset.base == {} && len(sprite_frame_asset.mods) == 0 {
		log.error(.Sprite, "Failed to load sprite's frame: no base or modifiable layers.")
		return
	}

	atlas := &state.sprites_atlas
	alloc_err: runtime.Allocator_Error

	if sprite_frame_asset.base != {} {
		frame.base = load_sprite_frame_layer(sprite_frame_asset.base, false) or_return
	}
	frame.mods, alloc_err = make([]Sprite_Frame_Layer, len(sprite_frame_asset.mods))
	if alloc_err != nil {
		log.error(.Sprite, "Failed to allocate memory for modifiable layers of a sprite.")
		return
	}
	for mod, mod_idx in sprite_frame_asset.mods {
		frame.mods[mod_idx] = load_sprite_frame_layer(mod, true) or_return
	}

	ok = true
	return
}

load_sprite_frame_layer :: proc(
	image_asset: Asset_Image,
	is_mod: bool,
) -> (
	sprite_frame_layer: Sprite_Frame_Layer,
	ok: bool,
) {
	defer {
		if !ok {
			log.errorf(.Sprite, "Failed to load sprite asset %s", image_asset)
		}
	}

	atlas := &state.sprites_atlas

	img := image_loader.load_from_file(image_asset.fp) or_return
	sprite_frame_layer.atlas_result = atlas_reserve(
		atlas,
		{img.width, img.height},
		//is_mod,
		false,
		raw_data(img.pixels.buf),
	) or_return

	ok = true
	return
}

sprite_frame_has_base :: proc(frame: ^Sprite_Frame) -> bool {
	return frame.base != {}
}
