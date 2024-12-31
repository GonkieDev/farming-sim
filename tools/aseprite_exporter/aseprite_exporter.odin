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

output_dir: string = "./aseprite_export"

v2i :: [2]u32
RGBA :: [4]u8 // NOTE: max color depth in aseprite is 32bpp
Mod_Pixel :: RGBA
Normal_Map_Pixel :: [3]f32

Raw_Sprite :: struct {
	mod:     [dynamic][]Mod_Pixel,
	non_mod: []RGBA,
	normal:  []Normal_Map_Pixel,
	//origin:  v2i, 
	// TODO: origin
	size:    v2i,
}

Raw_Frame :: struct {
	sprite:   Raw_Sprite,
	duration: f32,
}

Loop_Dir :: enum (i32) {
	Forward,
	Reverse,
	Ping_Pong,
	Ping_Pong_Reverse,
}

Raw_Animation :: struct {
	frames:   []Raw_Frame,
	loop_dir: Loop_Dir,
	repeat:   i32,
	//0 = Infinite
	//1 = Plays once (for ping-pong, it plays just in one direction)
	//2 = Plays twice (for ping-pong, it plays once in one direction,
	//    and once in reverse)
	//n = Plays N times
}

Error :: enum {
	None,
	Failed_To_Read_File,
	Failed_To_Unmarshal_File,
	Dont_Support_Grayscale,
	Broken_Folder,
	No_Export_Folders_Found,
}

Option :: enum {
	Log_Layers,
	Log_Tags,
	Abort_On_Broken_Folder,
	Output_To_File_Log,
}
Options :: bit_set[Option]

Ase_Layer_Type :: enum {
	Non_Mod,
	Mod,
	Normal,
}
Ase_Layer :: struct {
	type:        Ase_Layer_Type, // TODO: remove this
	layer_chunk: ^ase.Layer_Chunk,
	idx:         int,
}
Ase_Layer_Group :: struct {
	layer_chunk:        ^ase.Layer_Chunk,
	layers:             [Ase_Layer_Type][dynamic]Ase_Layer,
	is_broken:          bool,
	is_empty:           bool,
	parent:             ^Ase_Layer_Group,
	has_group_children: bool,
}

main :: proc() {
	logger_opts := bit_set[runtime.Logger_Option]{.Level, .Time}
	when ASEPRITE_EXPOTER_DEBUG {
		logger_opts += bit_set[runtime.Logger_Option]{.Short_File_Path, .Line}
	}
	context.logger = log.create_console_logger(opt = logger_opts)

	if len(os.args) <= 1 {
		log.error("No input file provided.")
		log.info("Usage:")
		log.info("\taseprite_exporter.exe in_file.aseprite /path/to/output_dir")
		log.infof("\tProvided: %s", os.args)
		return
	}

	if len(os.args) <= 2 {
		log.info("No output path provided, assuming default.")
	} else {
		output_dir = os.args[2]
	}

	filename := os.args[1]
	log.infof("Exporting %s to dir %s", filename, output_dir)

	//options := Options{.Log_Tags, .Log_Layers, .Output_To_File}
	options := Options{}
	log.infof("Options: %v", options)

	os.make_directory(output_dir)

	_, _, err := ase_export_from_file(filename, options)
	if err == nil {
		log.info("Finished successfully.")
	} else {
		log.infof("Failure: %v", err)
	}
}

ase_export_from_file :: proc(
	filename: string,
	options := Options{},
	allocator := context.allocator,
) -> (
	raw_sprites: [dynamic]Raw_Sprite,
	raw_anims: [dynamic]Raw_Animation,
	err: Error,
) {
	data, data_ok := os.read_entire_file(filename, context.temp_allocator)
	if !data_ok {
		err = .Failed_To_Read_File
		return
	}

	meta_name: string
	{
		using filepath
		meta_name = fmt.tprintf("%s.test_sprite_meta", stem(base(filename)))
	}

	return ase_export_from_buffer(data, meta_name, options, allocator)
}

ase_export_from_buffer :: proc(
	file_data: []byte,
	meta_name: string,
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

	meta: s.Builder
	s.builder_init(&meta, context.temp_allocator)
	s.write_string(&meta, "[0]\n\n") // version

	// Create meta string builder for each layer/sprite animation
	anims_meta := make([]s.Builder, len(layer_groups))
	for &anim_meta, anim_meta_idx in anims_meta {
		s.builder_init(&anim_meta, context.temp_allocator)
	}

	// Create [[SpriteName]] for each layer
	for layer_group, layer_group_idx in layer_groups {
		anim_meta := &anims_meta[layer_group_idx]
		if layer_group.is_empty || layer_group.is_broken do continue
		if len(layer_group.layers) <= 0 do continue
		s.write_string(anim_meta, fmt.tprintf("[[%s]]\n\n", layer_group.layer_chunk.name))
	}

	defer {
		for anim_meta in anims_meta {
			s.write_string(&meta, s.to_string(anim_meta))
		}
		meta_filepath := filepath.join({".", output_dir, meta_name}, context.temp_allocator)
		log.infof("Writing meta to %s", meta_filepath)
		os.write_entire_file(meta_filepath, meta.buf[:])
	}

	for &tag, tag_idx in tags {
		for frame_idx in int(tag.from_frame) ..= int(tag.to_frame) {
			//s.write_string(tag_meta, "[Frame]\n")
			//defer s.write_string(tag_meta, "\n")

			frame := &document.frames[frame_idx]
			palette_from_frame(&palette, frame)
			duration: f32 = f32(frame.header.duration) / 1000.0

			for &layer_group, layer_idx in layer_groups {
				if layer_group.is_empty || layer_group.is_broken do continue

				raw_sprite := Raw_Sprite {
					size = {u32(width), u32(height)},
					mod  = make([dynamic][]Mod_Pixel, allocator),
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

				if len(cels[.Non_Mod]) > 0 || len(cels[.Mod]) > 0 {
					anim_meta := &anims_meta[layer_idx]
					s.write_string(anim_meta, "[Frame]\n")

					name := fmt.tprintf("%s_%v", layer_group.layer_chunk.name, frame_idx)
					write_to_file(output_dir, name, &raw_sprite, options, anim_meta)

					s.write_string(anim_meta, "\n")
				}
			}

			//s.write_string(&meta, "\n")
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
	if len(cel_chunks) == 0 do return
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

	raw_sprite.mod = make([dynamic][]Mod_Pixel, allocator)
	colors := make([dynamic]RGBA, context.temp_allocator)
	for pixel, pixel_idx in stacked_pixels {
		if pixel.a == 0.0 do continue
		color_idx, color_found := slice.linear_search(colors[:], pixel)
		if !color_found {
			color_idx = len(colors)
			append(&colors, pixel)
			append(
				&raw_sprite.mod,
				make([]Mod_Pixel, int(raw_sprite.size.x) * int(raw_sprite.size.y), allocator),
			)
		}
		//raw_sprite.mod[color_idx][pixel_idx] = 255
		raw_sprite.mod[color_idx][pixel_idx] = {255, 255, 255, 255}
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
				if parent.has_group_children {
					log.warn("Illegal: Group has both normal layers and group layers.")
					assert(parent.has_group_children)
				}
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
				if parent != nil {
					parent.has_group_children = true
				}

				group := Ase_Layer_Group {
					layer_chunk = layer_chunk,
					parent      = parent,
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

	if len(export_groups) == 0 {
		err = .No_Export_Folders_Found
		return
	}

	for &export_group in export_groups {
		if len(export_group.layers) == 0 {
			export_group.is_empty = true
			continue
		}

		all_layers_empty := true
		for layer in export_group.layers {
			if len(layer) != 0 {
				all_layers_empty = false
			}
		}
		if all_layers_empty {
			export_group.is_empty = true
		}
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
	output_dir: string,
	base_name: string, // without extension
	raw_sprite: ^Raw_Sprite,
	options: Options,
	meta: ^s.Builder,
) -> (
	success: bool,
) {
	if raw_sprite.non_mod == nil && raw_sprite.mod == nil && raw_sprite.normal == nil {
		return true
	}

	context.allocator = context.temp_allocator

	if raw_sprite.non_mod != nil {
		filename := s.concatenate({base_name, "_non_mod.png"})
		non_mod_fp := filepath.join({output_dir, filename})

		if .Output_To_File_Log in options {
			log.infof("[Non-Mod] Writing to file: %s", non_mod_fp)
		}

		stb_image.write_png(
			s.clone_to_cstring(non_mod_fp),
			i32(raw_sprite.size.x),
			i32(raw_sprite.size.y),
			4,
			raw_data(raw_sprite.non_mod[:]),
			i32(raw_sprite.size.x * size_of(RGBA)),
		)

		s.write_string(meta, fmt.tprintf("base: %s\n", filename))
	}

	if raw_sprite.mod != nil {

		for mask, mask_idx in raw_sprite.mod {
			filename := fmt.tprintf("%s_mod_%v.png", base_name, mask_idx)
			mod_fp := filepath.join({output_dir, filename})

			if .Output_To_File_Log in options {
				log.infof("[Mod] Writing modifiable to file: %s", mod_fp)
			}

			stb_image.write_png(
				s.clone_to_cstring(mod_fp),
				i32(raw_sprite.size.x),
				i32(raw_sprite.size.y),
				size_of(Mod_Pixel) / size_of(u8),
				raw_data(mask[:]),
				i32(raw_sprite.size.x * size_of(Mod_Pixel)),
			)

			s.write_string(meta, fmt.tprintf("mod: %s\n", filename))
		}
	}

	success = true
	return
}