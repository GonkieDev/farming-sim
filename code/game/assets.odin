package game

import "core:strings"
import "core:time"

Asset :: struct {
	fp: string,
}

Asset_Image :: distinct Asset

Asset_Sprite_Frame :: struct {
	base:     Asset_Image,
	mods:     []Asset_Image,
	duration: time.Duration,
}

Asset_Sprite :: struct {
	frames:     []Asset_Sprite_Frame,
	mod_colors: [][]Color,
}

asset_image_from_filepath :: proc(
	filepath: string,
	allocator := context.allocator,
) -> Asset_Image {
	return Asset_Image{fp = strings.clone(filepath, allocator)}
}

asset_image :: proc {
	asset_image_from_filepath,
}
