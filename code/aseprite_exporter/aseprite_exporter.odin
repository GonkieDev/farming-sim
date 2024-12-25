package aseprite_exporter

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import s "core:strings"

import ase "./aseprite"
import stb_image "vendor:stb/image"

ASEPRITE_EXPOTER_DEBUG :: ODIN_DEBUG

main :: proc() {
	logger_opts := bit_set[runtime.Logger_Option]{.Level, .Time}
	when ASEPRITE_EXPOTER_DEBUG {
		logger_opts += bit_set[runtime.Logger_Option]{.Short_File_Path, .Line}
	}
	context.logger = log.create_console_logger(opt = logger_opts)

	log.info("Starting up...")
	defer log.info("Finished.")

	options := Options{.Log_Tags, .Log_Layers, .Output_To_File}
	//ase_export_from_file("../assets/playre.aseprite", options)
	//ase_export_from_file("../assets/guy.aseprite", options)
	//ase_export_from_file("../assets/tests.aseprite", options)
	ase_export_from_file("../../assets/Player.aseprite", options)

}

ase_export_from_file :: proc(
	filepath: string,
	options := Options{},
	allocator := context.allocator,
) -> (
	raw_sprites: [dynamic]Raw_Sprite,
	raw_anims: [dynamic]Raw_Animation,
	err: Error,
) {
	data, data_ok := os.read_entire_file(filepath, context.temp_allocator)
	if !data_ok {
		err = .Failed_To_Read_File
		return
	}
	return ase_export_from_buffer(data, options, allocator)
}

ase_export_from_buffer :: proc(
	file_data: []byte,
	options := Options{},
	allocator := context.allocator,
) -> (
	raw_sprites: [dynamic]Raw_Sprite,
	raw_anims: [dynamic]Raw_Animation,
	err: Error,
) {
	raw_sprites = make([dynamic]Raw_Sprite, allocator)
	raw_anims = make([dynamic]Raw_Animation, allocator)

	document: ase.Document
	umerr := ase.unmarshal(&document, file_data[:], context.temp_allocator)
	if umerr != nil {
		err = .Failed_To_Unmarshal_File
		return
	}

	if document.header.color_depth != .Indexed && document.header.color_depth != .RGBA {
		err = .Dont_Support_Grayscale
		return
	}

	width, height := int(document.header.width), int(document.header.height)
	total_pixels := width * height
	is_indexed := document.header.color_depth == .Indexed

	// Get layer groups
	layer_groups: [dynamic]Ase_Layer_Group
	layer_groups, err = layer_groups_from_document(&document, options)
	if err != nil do return

	// Debug log
	if .Log_Layers in options {
		for layer_group in layer_groups {
			log.infof("Group: %s", layer_group.layer_chunk.name)
			for layer_types in layer_group.layers {
				for layer in layer_types {
					log.infof("\t[%v]\tLayer: %s", layer.type, layer.layer_chunk.name)
				}
			}
		}
	}

	// Get tags
	tags: [dynamic]^ase.Tag
	tags, err = tags_from_document(&document, options)
	if err != nil do return

	palette: ^ase.Palette_Chunk
	palette_from_frame(&palette, &document.frames[0])

	for &tag in tags {
		for frame_idx in int(tag.from_frame) ..= int(tag.to_frame) {
			frame := &document.frames[frame_idx]
			palette_from_frame(&palette, frame)
			duration: f32 = f32(frame.header.duration) / 1000.0

			for &layer_group in layer_groups {
				if layer_group.is_empty || layer_group.is_broken do continue

				raw_sprite := Raw_Sprite {
					size = {u32(width), u32(height)},
					mod  = make([dynamic][]u8, allocator),
				}

				cels: [Ase_Layer_Type][dynamic]^ase.Cel_Chunk
				for layer_type in Ase_Layer_Type {
					cels[layer_type] = make([dynamic]^ase.Cel_Chunk, context.temp_allocator)
				}

				for &chunk in frame.chunks {
					cel_chunk, is_cel_chunk := &chunk.(ase.Cel_Chunk)
					if !is_cel_chunk do continue

					com_image_cel, is_com_image_cel := &cel_chunk.cel.(ase.Com_Image_Cel)
					if !is_com_image_cel do continue

					layer := layer_from_cel_chunk(cel_chunk, &layer_group)
					if layer == nil do continue

					append(&cels[layer.type], cel_chunk)
				}

				process_non_mod(&raw_sprite, cels[.Non_Mod][:], palette, allocator)
				process_mod(&raw_sprite, cels[.Mod][:], palette, allocator)
				//process_normal(&raw_sprite, &layer_group, cels[.Normal][:])

				if .Output_To_File in options {
					filename := fmt.tprintf(
						"%s_%v_color.bmp",
						layer_group.layer_chunk.name,
						frame_idx,
					)
					dir := filepath.join({"./test_output", tag.name, layer_group.layer_chunk.name})
					write_to_file(tag.name, layer_group.layer_chunk.name, filename, &raw_sprite)
				}

			}
		}
	}

	return
}

stack_cel_chunks :: proc(
	w, h: int,
	cel_chunks: []^ase.Cel_Chunk,
	palette: ^ase.Palette_Chunk,
	allocator := context.allocator,
) -> (
	pixels: []RGBA,
) {
	assert(len(cel_chunks) > 0)
	assert(w > 0)
	assert(h > 0)

	pixels = make([]RGBA, w * h, allocator)

	slice.sort_by(cel_chunks[:], proc(i, j: ^ase.Cel_Chunk) -> bool {
		return i.layer_index < j.layer_index
	})

	for cel_chunk in cel_chunks {
		cl, cl_ok := cel_chunk.cel.(ase.Com_Image_Cel)
		assert(cl_ok)

		cel_pixels: []RGBA

		if palette != nil {
			cel_pixels = make([]RGBA, int(cl.width) * int(cl.height), context.temp_allocator)
			for p, idx in cl.pixels {
				if p == 0 {
					continue
				}
				cel_pixels[idx] = RGBA(palette.entries[u32(p)].color)
			}
		} else {
			cel_pixels = slice.reinterpret([]RGBA, cl.pixels)
		}

		src := Image_Blit_Src {
			data   = cel_pixels,
			width  = int(cl.width),
			height = int(cl.height),
		}
		dst := Image_Blit_Dst {
			data         = pixels,
			x            = int(cel_chunk.x),
			y            = int(cel_chunk.y),
			image_width  = int(w),
			image_height = int(h),
		}
		image_blit(dst, src)
	}

	return
}

process_non_mod :: proc(
	raw_sprite: ^Raw_Sprite,
	cel_chunks: []^ase.Cel_Chunk,
	palette: ^ase.Palette_Chunk,
	allocator := context.allocator,
) {
	raw_sprite.non_mod = stack_cel_chunks(
		int(raw_sprite.size.x),
		int(raw_sprite.size.y),
		cel_chunks,
		palette,
		allocator,
	)
}

process_mod :: proc(
	raw_sprite: ^Raw_Sprite,
	cel_chunks: []^ase.Cel_Chunk,
	palette: ^ase.Palette_Chunk,
	allocator := context.allocator,
) {
	stacked_pixels := stack_cel_chunks(
		int(raw_sprite.size.x),
		int(raw_sprite.size.y),
		cel_chunks,
		palette,
		allocator,
	)

	raw_sprite.mod = make([dynamic][]u8, allocator)
	colors := make([dynamic]RGBA, context.temp_allocator)
	for pixel, pixel_idx in stacked_pixels {
		if pixel.a == 0.0 do continue
		color_idx, color_found := slice.linear_search(colors[:], pixel)
		if !color_found {
			color_idx = len(colors)
			append(&colors, pixel)
			append(
				&raw_sprite.mod,
				make([]u8, int(raw_sprite.size.x) * int(raw_sprite.size.y), allocator),
			)
		}
		raw_sprite.mod[color_idx][pixel_idx] = 255
	}
}

layer_from_cel_chunk :: proc(cel_chunk: ^ase.Cel_Chunk, group: ^Ase_Layer_Group) -> ^Ase_Layer {
	for layer_type in Ase_Layer_Type {
		for layer_idx in 0 ..< len(group.layers[layer_type]) {
			layer := &group.layers[layer_type][layer_idx]
			if layer.idx == int(cel_chunk.layer_index) {
				return layer
			}
		}
	}
	return nil
}

layer_groups_from_document :: proc(
	document: ^ase.Document,
	options: Options,
	allocator := context.temp_allocator,
) -> (
	export_groups: [dynamic]Ase_Layer_Group,
	err: Error,
) {
	export_groups = make([dynamic]Ase_Layer_Group, allocator)

	parent_stack := make([dynamic]^Ase_Layer_Group, context.temp_allocator)
	parent: ^Ase_Layer_Group

	// Layer data is in the first frame's chunks
	layer_idx := 0
	prev_child_level := 0
	ignore_above_this := max(int)
	for &chunk in document.frames[0].chunks {
		layer_chunk, is_layer_chunk := &chunk.(ase.Layer_Chunk)
		if !is_layer_chunk do continue

		defer layer_idx += 1
		defer prev_child_level = int(layer_chunk.child_level)

		should_pop := prev_child_level > int(layer_chunk.child_level)
		if should_pop {
			parent = pop(&parent_stack)
			if ignore_above_this >= int(layer_chunk.child_level) {
				ignore_above_this = max(int)
			}
		}

		force_ignore := int(layer_chunk.child_level) > ignore_above_this

		switch layer_chunk.type {
		case .Normal:
			if parent != nil && !layer_chunk_should_ignore(layer_chunk) && !force_ignore {
				ignore, layer_type := layer_attributes_str_check(layer_chunk)
				if !ignore {
					layer := Ase_Layer {
						type        = layer_type,
						layer_chunk = layer_chunk,
						idx         = layer_idx,
					}
					append(&parent.layers[layer_type], layer)
				}
			}
		case .Group:
			append(&parent_stack, parent)
			parent = nil

			if !layer_chunk_should_ignore(layer_chunk) && !force_ignore {
				group := Ase_Layer_Group {
					layer_chunk = layer_chunk,
				}
				for type in Ase_Layer_Type {
					group.layers[type] = make([dynamic]Ase_Layer, allocator)
				}
				append(&export_groups, group)
				parent = &export_groups[len(export_groups) - 1]
			} else {
				// Should ignore children
				if int(layer_chunk.child_level) < ignore_above_this {
					ignore_above_this = int(layer_chunk.child_level)
				}
			}

		case .Tilemap:
			// TODO: handle this case more robustely
			fallthrough
		case:
			assert(false)
		}
	}

	for &group in export_groups {
		frames_count := 0
		for layer_type in Ase_Layer_Type {
			fc := len(group.layers[layer_type])
			if fc != 0 {
				if fc != frames_count && frames_count != 0 {
					log.warnf(
						"Folder %s is broken. There are non equal amounts of frames for mod/nonmod/normal.",
						group.layer_chunk.name,
					)
					group.is_broken = true
					if .Abort_On_Broken_Folder in options do err = .Broken_Folder
					break
				}
				frames_count = fc
			}
		}

		group.is_empty = frames_count == 0
	}

	if len(export_groups) == 0 {
		err = .No_Export_Folders_Found
		return
	}
	return
}

tags_from_document :: proc(
	document: ^ase.Document,
	options: Options,
	allocator := context.temp_allocator,
) -> (
	tags: [dynamic]^ase.Tag,
	err: Error,
) {
	tags = make([dynamic]^ase.Tag, allocator)
	tagged_frames_count := 0
	for frame in document.frames {
		for &chunk in frame.chunks {
			tag_chunk, is_tag_chunk := &chunk.(ase.Tags_Chunk)
			if !is_tag_chunk do continue
			for &tag in tag_chunk {
				tagged_frames_count += int(tag.to_frame - tag.from_frame) + 1
				append(&tags, &tag)
			}
		}
	}

	if tagged_frames_count < len(document.frames) - 1 {
		log.warn("There are more than 1 frames without a tag. Using first frame without tag.")
	}

	if .Log_Tags in options {
		for tag in tags {
			log.info(tag)
		}
	}

	return
}

ATTRIB_STR :: "#"
layer_attributes_str_from_str :: proc(str: string) -> string {
	res: string
	attrib_index := s.index(str, ATTRIB_STR)
	if attrib_index != -1 {
		res = str[attrib_index:]
		next_space := s.index(res, " ")
		if next_space == -1 do next_space = len(res)
		res = res[:next_space]
	}
	return res
}

layer_attributes_str_from_layer_chunk :: proc(layer_chunk: ^ase.Layer_Chunk) -> string {
	return layer_attributes_str_from_str(layer_chunk.name)
}

layer_attributes_str_check :: proc(
	layer_chunk: ^ase.Layer_Chunk,
) -> (
	ignore: bool,
	type: Ase_Layer_Type,
) {
	atribs := layer_attributes_str_from_layer_chunk(layer_chunk)
	is_normal := s.contains(atribs, "N")
	is_mod := s.contains(atribs, "M")
	ignore = s.contains(atribs, "I")
	if !ignore {
		if is_mod {
			if is_normal {
				log.warnf("%s labeled as both normal and mod. Assuming mod.", layer_chunk.name)
			}
			type = .Mod
		} else if is_normal {
			type = .Normal
		}
	}
	return
}

layer_chunk_should_ignore :: proc(layer_chunk: ^ase.Layer_Chunk) -> bool {
	atribs := layer_attributes_str_from_layer_chunk(layer_chunk)
	ignore := s.contains(atribs, "I")
	return ignore
}

layer_type_from_layer_chunk :: proc(layer_chunk: ^ase.Layer_Chunk) -> Ase_Layer_Type {
	_, type := layer_attributes_str_check(layer_chunk)
	return type
}

palette_from_frame :: proc(palette: ^^ase.Palette_Chunk, frame: ^ase.Frame) {
	for &c in frame.chunks {
		if p, ok := &c.(ase.Palette_Chunk); ok {
			palette^ = p
			break
		}
	}
}

Image_Blit_Src :: struct {
	data:                []RGBA,
	x, y, width, height: int,
}
Image_Blit_Dst :: struct {
	data:         []RGBA,
	x, y:         int,
	image_width:  int,
	image_height: int,
}
image_blit :: proc(dst: Image_Blit_Dst, src: Image_Blit_Src) {
	for sxf in 0 ..< src.width {
		for syf in 0 ..< src.height {
			sx := int(src.x + sxf)
			sy := int(src.y + syf)

			if sx < 0 || sx >= src.width do continue
			if sy < 0 || sy >= src.height do continue

			dx := dst.x + int(sxf)
			dy := dst.y + int(syf)

			if dx < 0 || dx >= dst.image_width do continue
			if dy < 0 || dy >= dst.image_height do continue

			src_idx := sy * src.width + sx
			dst_idx := dy * dst.image_width + dx
			//dst.data[dst_idx] = blend_pixels(dst.data[dst_idx], src.data[src_idx])
			dst.data[dst_idx] = blend_pixels(src.data[src_idx], dst.data[dst_idx])
		}
	}
}

blend_pixels :: proc(dst: RGBA, src: RGBA) -> RGBA {
	c_src := rgba_to_rgbaf32(src)
	c_dst := rgba_to_rgbaf32(dst)
	f_src := 1.0 - c_dst.a
	f_dst := c_dst.a
	res := c_src * f_src + c_dst * f_dst
	return rgbaf32_to_rgba(res)
}

rgba_to_rgbaf32 :: proc(c: RGBA) -> [4]f32 {
	return [4]f32{f32(c.r) / 255.0, f32(c.g) / 255.0, f32(c.b) / 255.0, f32(c.a) / 255.0}
}

rgbaf32_to_rgba :: proc(c: [4]f32) -> RGBA {
	return RGBA{u8(c.r * 255.0), u8(c.g * 255.0), u8(c.b * 255.0), u8(c.a * 255.0)}
}

// TODO: make a function for animations so that it we can delete the directory before writing
write_to_file :: proc(
	dir: string,
	subdir: string,
	filename: string,
	raw_sprite: ^Raw_Sprite,
) -> (
	success: bool,
) {
	if raw_sprite.non_mod == nil && raw_sprite.mod == nil && raw_sprite.normal == nil {
		return true
	}

	context.allocator = context.temp_allocator

	path: string

	path = filepath.join({".", dir})
	os.make_directory(dir)

	path = filepath.join({path, subdir})
	os.make_directory(path)


	if raw_sprite.non_mod != nil {
		non_mod_fp := filepath.join({path, filename})
		log.infof("[Non-Mod] Writing to file: %s", non_mod_fp)
		assert(len(raw_sprite.non_mod[:]) > 0)
		stb_image.write_bmp(
			s.clone_to_cstring(non_mod_fp),
			i32(raw_sprite.size.x),
			i32(raw_sprite.size.y),
			4,
			raw_data(raw_sprite.non_mod[:]),
		)
	}

	if raw_sprite.mod != nil {

		filename_no_ext := s.trim_suffix(filename, ".bmp")
		for mask, mask_idx in raw_sprite.mod {
			mask_name := fmt.tprintf("%s_mask_%v.bmp", filename_no_ext, mask_idx)
			mask_path := filepath.join({path, mask_name})
			log.infof("Writing modifiable to file: %s", mask_path)
			stb_image.write_bmp(
				s.clone_to_cstring(mask_path),
				i32(raw_sprite.size.x),
				i32(raw_sprite.size.y),
				1,
				raw_data(mask[:]),
			)
		}
	}

	success = true
	return
}
