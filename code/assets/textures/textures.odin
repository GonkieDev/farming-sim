package assets_textures

import "core:image"
import "core:image/bmp"
import "core:image/png"

_ :: png
_ :: bmp

Texture_Kind :: enum {
	Tex2D,
}

Texture :: struct {
	kind:      Texture_Kind,
	using img: ^image.Image,
}

texture_load :: proc(
	filepath: string,
	allocator := context.allocator,
) -> (
	texture: Texture,
	success: bool,
) {
	options := image.Options{.alpha_add_if_missing}
	img, err := image.load(filepath, options, allocator)
	if err != nil {
		return
	}
	assert(img.which == .PNG || img.which == .BMP)

	texture = {
		kind = .Tex2D,
		img  = img,
	}

	success = true
	return
}

texture_destroy :: proc(texture: ^Texture) {
	image.destroy(texture.img)
}
