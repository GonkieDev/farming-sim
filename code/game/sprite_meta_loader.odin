package game

import os "core:os"
import path_fp "core:path/filepath"
import conv "core:strconv"
import s "core:strings"
import "core:time"

import log "engine:log"
//import build_config "engine:build_config"

SPRITE_META_DEFAULT_FRAME_DURATION :: 100 // same as aseprite

Sprite_Meta_Version :: enum {
	V0,

	// Leave this at bottom
	LAST,
}

Sprite_Meta_Version_Latest :: Sprite_Meta_Version.LAST - Sprite_Meta_Version(1)

@(require_results)
sprite_meta_load :: proc(
	filepath: string,
	allocator := context.allocator,
) -> (
	sprite_assets: []Sprite_Asset,
	ok: bool,
) {
	file_str: string
	if file_data, success := os.read_entire_file_from_filename(filepath, context.temp_allocator);
	   success {
		file_str = string(file_data)
	} else {
		log.errorf(.Sprite, "Failed to load sprite meta data. Unable to read file %s", filepath)
		return
	}

	load_directory := path_fp.dir(filepath)

	lines := s.split(file_str, "\n", context.temp_allocator)
	version_str := bracket_interior(lines[0])
	version_parsed, version_parsed_ok := conv.parse_int(version_str)
	if !version_parsed_ok || version_parsed > int(Sprite_Meta_Version_Latest) {
		log.errorf(.Sprite, "Invalid sprite meta version (%s) in %s", version_str, filepath)
		return
	}
	version := Sprite_Meta_Version(version_parsed)
	lines = lines[1:]
	switch version {
	case .V0:
		sprite_assets, ok = sprite_meta_load_version_0(lines, load_directory, filepath, allocator)
		return
	case .LAST:
		fallthrough
	case:
		return
	}

	return
}

sprite_meta_load_version_0 :: proc(
	lines: []string,
	load_directory: string,
	filepath: string, // for error messages
	allocator := context.allocator,
) -> (
	out_sprite_assets: []Sprite_Asset,
	ok: bool,
) {

	get_line_kind :: proc(line: string) -> Line_Kind {
		if s.contains(line, "[[") do return .New_Sprite
		if s.contains(line, "[") do return .New_Section
		if line == "" do return .Invalid
		return .Attribute
	}

	get_section_kind :: proc(line: string) -> Section_Kind {
		interior := bracket_interior(line)
		if interior == "Frame" do return .Frame
		if interior == "Colors" do return .Colors
		return .Invalid
	}

	Line_Kind :: enum {
		Invalid,
		Attribute,
		New_Sprite,
		New_Section,
	}

	Section_Kind :: enum {
		Invalid,
		Frame,
		Colors,
	}

	context.allocator = allocator

	// WARNING: do not early return inside of this function after this line
	// because the caller will not be able to free the data in case of failure
	// since sprite_assets only gets converted into the returning slice `out_sprite_assets`
	// at the end
	sprite_assets := make([dynamic]Sprite_Asset)

	current_section := Section_Kind.Invalid
	current_sprite: ^Sprite_Asset
	current_sprite_frames: [dynamic]Sprite_Frame_Asset
	current_frame_mods: [dynamic]Image_Asset
	current_sprite_mod_colors: [dynamic][]Color
	current_colors: [dynamic]Color

	for raw_line, line_idx in lines {
		no_comment_line := line_remove_comment(raw_line)
		line := s.trim_space(no_comment_line)

		line_kind := get_line_kind(line)
		switch line_kind {
		case .New_Sprite:
			append(&sprite_assets, Sprite_Asset{})
			current_sprite = &sprite_assets[len(sprite_assets) - 1]
			current_sprite_frames = make([dynamic]Sprite_Frame_Asset)
			current_sprite_mod_colors = make([dynamic][]Color)

		case .New_Section:
			section_kind := get_section_kind(line)
			current_section = section_kind
			switch section_kind {

			case .Frame:
				append(&current_sprite_frames, Sprite_Frame_Asset{})
				current_frame_mods = make([dynamic]Image_Asset)

			case .Colors:
				append(&current_sprite_mod_colors, []Color{})
				current_colors = make([dynamic]Color)

			case .Invalid:
				fallthrough
			case:
			}

		case .Attribute:
			invalid_attrib := false
			defer {
				if invalid_attrib {
					log.warnf(
						.Sprite,
						"Invalid attribute[%s:%v]: '%s' in [%v] section",
						filepath,
						line_idx + 1,
						line,
						current_section,
					)
				}
			}

			switch current_section {
			case .Frame:
				frame: ^Sprite_Frame_Asset = &current_sprite_frames[len(current_sprite_frames) - 1]
				attrib := line_get_after_colon_space(line)
				if s.contains(line, "base") {
					fp := path_fp.join({load_directory, attrib}, context.temp_allocator)
					frame.base = image_asset(fp)
				} else if s.contains(line, "normal") {
				} else if s.contains(line, "mod") {
					fp := path_fp.join({load_directory, attrib}, context.temp_allocator)
					append(&current_frame_mods, Image_Asset{})
					mod: ^Image_Asset = &current_frame_mods[len(current_frame_mods) - 1]
					mod^ = image_asset(fp)
				} else if s.contains(line, "duration") {
					if duration_ms, parse_ok := conv.parse_int(attrib); parse_ok {
						duration := time.Duration(duration_ms) * time.Millisecond
						frame.duration = duration
					} else {
						log.warnf(
							.Sprite,
							"Invalid frame duration [%s:%v]: %s",
							filepath,
							line_idx + 1,
							attrib,
						)
					}
				} else {
					invalid_attrib = true
				}
			case .Colors:
				color_parsed, color_parsed_ok := conv.parse_u64(line, base = 16)
				if color_parsed_ok {
					color := color_from_u64(color_parsed)
					append(&current_colors, color)
				} else {
					log.warnf(.Sprite, "Invalid color[%s:%v]: %s", filepath, line_idx + 1, line)
				}

			case .Invalid:
				fallthrough
			case:
			}

		case .Invalid:
			fallthrough
		case:
		}

		if current_sprite != nil {
			if len(current_sprite_frames) > 0 {
				current_sprite.frames = current_sprite_frames[:]

				if len(current_frame_mods) > 0 {
					frame: ^Sprite_Frame_Asset = &current_sprite_frames[len(current_sprite_frames) - 1]
					frame.mods = current_frame_mods[:]
				}
			}

			if len(current_sprite_mod_colors) > 0 {
				if len(current_colors) > 0 {
					current_sprite_mod_colors[len(current_sprite_mod_colors) - 1] =
					current_colors[:]
				}

				current_sprite.mod_colors = current_sprite_mod_colors[:]
			}
		}
	}

	ok = true
	out_sprite_assets = sprite_assets[:]
	return
}

@(private = "file")
bracket_interior :: proc(line: string) -> string {
	interior := line[s.last_index(line, "[") + 1:s.index(line, "]")]
	return interior
}

@(private = "file")
line_remove_comment :: proc(line: string) -> string {
	hashtag_idx := s.index(line, "#")
	if hashtag_idx <= 0 do return line
	return line[:hashtag_idx - 1]
}

@(private = "file")
line_get_after_colon_space :: proc(line: string) -> string {
	colon_idx := s.index(line, ":")
	after_colon := line[colon_idx + 1:]
	trimmed := s.trim_space(after_colon)
	return trimmed
}
