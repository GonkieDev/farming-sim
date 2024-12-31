package image_loader

import "core:image"
import "core:image/bmp"
import "core:image/png"

_ :: png
_ :: bmp

load_from_file :: proc(
	filepath: string,
	allocator := context.allocator,
) -> (
	img: ^image.Image,
	success: bool,
) {
	options := image.Options{.alpha_add_if_missing}
	err: image.Error
	img, err = image.load(filepath, options, allocator)
	if err != nil {
		return
	}
	assert(img.which == .PNG || img.which == .BMP)
	success = true
	return
}

destroy :: proc(img: ^image.Image) {
	image.destroy(img)
}
