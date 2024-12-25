package atlas

import "base:runtime"
import "core:math"

import "engine:log"
import "engine:render"

_ :: log

TEXTURE_SIZE :: 1024

Atlas_Result :: struct {
	region_idx: int,
	region_gen: int,
	tex_idx:    int,
}

Region :: struct {
	occupied: bool,
	gen:      int,
}

Atlas_Texture :: struct {
	regions:     []Region,
	region_size: int,
	gen:         int,
	render_key:  render.Texture_Key,
}

Atlas :: struct {
	textures:      [dynamic]Atlas_Texture,
	// one dynamic array for each possible size according to parameters
	biggest_size:  int,
	smallest_size: int,
	num_of_sizes:  int,
	allocator:     runtime.Allocator,
}

atlas_init :: proc(
	atlas: ^Atlas,
	biggest_size := 128,
	smallest_size := 8,
	allocator := context.allocator,
) -> bool {
	assert(math.is_power_of_two(biggest_size))
	assert(math.is_power_of_two(smallest_size))

	context.allocator = allocator

	atlas^ = Atlas {
		num_of_sizes  = 1 + int(
			math.log(f32(biggest_size), 2.0),
		) - int(math.log(f32(smallest_size), 2.0)),
		smallest_size = smallest_size,
		biggest_size  = biggest_size,
		allocator     = allocator,
	}

	err: runtime.Allocator_Error
	atlas.textures, err = make([dynamic]Atlas_Texture)
	if err != nil do return false

	return true
}

atlas_delete :: proc(atlas: ^Atlas) {
	if atlas == nil do return
	delete(atlas.textures)
}

@(require_results)
atlas_reserve :: proc(
	atlas: ^Atlas,
	dims: [2]int,
	is_mask: bool,
	pixels: rawptr,
) -> (
	result: Atlas_Result,
	ok: bool,
) {
	size := max(dims.x, dims.y)
	if size > atlas.biggest_size do return
	if size < atlas.smallest_size do size = atlas.smallest_size

	aligned_rect := atlas_size_align(size)
	result.tex_idx = atlas_available_texture_from_rect(atlas, aligned_rect)
	if result.tex_idx != -1 {
		result.tex_idx = atlas_allocate_new_texture(atlas, size, is_mask)
		assert(result.tex_idx != -1)
	}

	texture := &atlas.textures[result.tex_idx]
	for &region, region_idx in texture.regions {
		if !region.occupied {
			region.occupied = true
			result.region_idx = region_idx
			result.region_gen = region.gen
			break
		}
	}

	x, y, w, h := atlas_xywh_from_result(atlas, result)
	render.texture_update(texture.render_key, x, y, w, h, 8, 1 if is_mask else 4, pixels)

	ok = true
	return
}

atlas_delete_block :: proc(atlas: ^Atlas, atlas_result: Atlas_Result) {
	texture := &atlas.textures[atlas_result.tex_idx]
	region := texture.regions[atlas_result.region_idx]
	if region.gen != atlas_result.region_gen {
		return
	}
	region.gen += 1
	region.occupied = false
}

atlas_allocate_new_texture :: proc(atlas: ^Atlas, size: int, is_mask: bool) -> int {
	assert(size <= TEXTURE_SIZE)
	regions_count := TEXTURE_SIZE / size
	regions_count *= regions_count
	texture := Atlas_Texture {
		region_size = size,
		regions     = make([]Region, regions_count, atlas.allocator),
	}

	_, err := append(&atlas.textures, texture)
	assert(err == nil)

	upload_ok: bool
	texture.render_key, upload_ok = render.texture_upload_from_data(
		width = TEXTURE_SIZE,
		height = TEXTURE_SIZE,
		depth = 8,
		channels = 1 if is_mask else 4,
		pixels = nil,
		generate_mips = false,
	)
	assert(upload_ok)

	return len(atlas.textures) - 1
}

atlas_available_texture_from_rect :: proc(atlas: ^Atlas, size: int) -> int {
	atlas_assert_size_is_aligned(size)
	for &texture, texture_idx in atlas.textures {
		if altas_texture_can_fit(&texture, size) {
			return texture_idx
		}
	}
	return -1
}

altas_texture_can_fit :: proc(texture: ^Atlas_Texture, size: int) -> bool {
	atlas_assert_size_is_aligned(size)
	if texture.region_size != size {
		return false
	}
	for region in texture.regions {
		if !region.occupied do return true
	}
	return false
}

atlas_size_align :: proc(s: int) -> int {
	return math.next_power_of_two(s)
}
atlas_assert_size_is_aligned :: proc(s: int) {
	assert(math.is_power_of_two(s))
}

atlas_xywh_from_result :: proc(atlas: ^Atlas, result: Atlas_Result) -> (x, y, w, h: int) {
	texture := atlas.textures[result.tex_idx]
	rs := texture.region_size
	w = rs
	h = w

	x = result.region_idx * (TEXTURE_SIZE % rs)
	y = result.region_idx * (TEXTURE_SIZE / rs)

	return
}
