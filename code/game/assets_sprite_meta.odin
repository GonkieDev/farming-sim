package game

import "core:fmt"
import os "core:os"
import path_fp "core:path/filepath"
import conv "core:strconv"
import s "core:strings"
import "core:time"

import log "engine:log"

_ :: time

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
	sprite_assets: []Asset_Sprite,
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

sprite_meta_load_version_0_old :: proc(
	lines: []string,
	load_directory: string,
	filepath: string, // for error messages
	allocator := context.allocator,
) -> (
	out_sprite_assets: []Asset_Sprite,
	ok: bool,
) {
	when false {
		get_line_kind :: proc(line: string) -> Line_Kind {
			if s.contains(line, "[[") do return .New_Major_Section
			if s.contains(line, "[") do return .New_Section
			if line == "" do return .Invalid
			return .Attribute
		}

		get_major_section_kind :: proc(line: string) -> Major_Section_Kind {
			interior := bracket_interior(line)
			if len(interior) == 0 {
				return .Invalid
			}
			if s.contains(line, "Colors Group") do return .Colors_Group
			return .Sprite
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
			New_Section,
			New_Major_Section,
		}

		Major_Section_Kind :: enum {
			Invalid,
			Colors_Group,
			Sprite,
		}

		Section_Kind :: enum {
			Invalid,
			Frame,
			Colors,
		}

		Layer_Colors :: struct {
			colors: [dynamic]Color,
		}

		Colors_Options_Group :: struct {
			options: [dynamic]Layer_Colors,
			name:    string,
		}

		failure: bool
		context.allocator = allocator

		// WARNING: do not early return inside of this function after this line
		// because the caller will not be able to free the data in case of failure
		// since sprite_assets only gets converted into the returning slice `out_sprite_assets`
		// at the end
		sprite_assets := make([dynamic]Asset_Sprite)

		current_section := Section_Kind.Invalid
		current_sprite: ^Asset_Sprite
		current_sprite_frames: [dynamic]Asset_Sprite_Frame
		current_frame_mods: [dynamic]Asset_Image

		colors_allocator := context.temp_allocator
		color_options_groups := make([dynamic]Colors_Options_Group)
		current_color_option_group: ^Colors_Options_Group

		current_major_section: Major_Section_Kind

		current_sprite_color_option_group: ^Colors_Options_Group

		line_loop: for raw_line, line_idx in lines {
			no_comment_line := line_remove_comment(raw_line)
			line := s.trim_space(no_comment_line)

			line_kind := get_line_kind(line)
			switch line_kind {

			//
			// New Major section
			//
			case .New_Major_Section:
				// Error checking / unsetting before switching major section
				switch current_major_section {
				case .Colors_Group:
					if current_color_option_group.name == "" {
						log.error(.Sprite, "Color Group without a name. Aborting.")
						failure = true
						break line_loop
					}
				case .Sprite:
					if current_sprite_color_option_group == nil {
						log.error(.Sprite, "Sprite without a color group name. Aborting.")
						failure = true
						break line_loop
					}

					color_group := current_sprite_color_option_group
					current_sprite.mod_colors = make([][]Color, len(color_group.options))
					for &colors, idx in current_sprite.mod_colors {
						option := color_group.options[idx]
						(&colors)^ = make([]Color, len(option.colors))
						for color_idx in 0 ..< len(colors) {
							colors[color_idx] = option.colors[color_idx]
						}
					}

					current_sprite_color_option_group = nil
				case .Invalid:
					assert(false)
				}

				// Switch to new major section & allocate stuff
				current_major_section = get_major_section_kind(line)
				switch current_major_section {
				case .Colors_Group:
					close_idx := s.last_index(line, "]")
					name := line[close_idx + 1:]
					name = s.trim_space(name)

					group := Colors_Options_Group {
						options = make([dynamic]Layer_Colors, colors_allocator),
						name    = name,
					}
					append(&color_options_groups, group)
					current_color_option_group =
					&color_options_groups[len(color_options_groups) - 1]


				case .Sprite:
					append(&sprite_assets, Asset_Sprite{})
					current_sprite = &sprite_assets[len(sprite_assets) - 1]
					current_sprite_frames = make([dynamic]Asset_Sprite_Frame)

				case .Invalid:
					log.errorf(
						.Sprite,
						"Invalid major section[%s:%v]: '%s'. Aborting.",
						filepath,
						line_idx + 1,
						line,
					)
					failure = true
					break line_loop
				}

			//
			// New Section
			//
			case .New_Section:
				section_kind := get_section_kind(line)
				current_section = section_kind
				switch section_kind {

				case .Frame:
					if current_major_section != .Sprite {
						log.errorf(
							.Sprite,
							"Invalid section[%s:%v]: Frame section is invalid inside a [%v] section. Aborting.",
							filepath,
							line_idx + 1,
							current_major_section,
						)
						failure = true
						break line_loop
					}

					append(&current_sprite_frames, Asset_Sprite_Frame{})
					current_frame_mods = make([dynamic]Asset_Image)

				case .Colors:
					switch current_major_section {
					case .Colors_Group:
						layer_colors := Layer_Colors {
							colors = make([dynamic]Color, colors_allocator),
						}
						append(&current_color_option_group.options, layer_colors)
					case .Sprite:
					case .Invalid:
						assert(false)
					}

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
					frame: ^Asset_Sprite_Frame = &current_sprite_frames[len(current_sprite_frames) - 1]
					attrib := line_get_after_colon_space(line)
					if s.contains(line, "base") {
						fp := path_fp.join({load_directory, attrib}, context.temp_allocator)
						frame.base = asset_image(fp)
					} else if s.contains(line, "normal") {
					} else if s.contains(line, "mod") {
						fp := path_fp.join({load_directory, attrib}, context.temp_allocator)
						append(&current_frame_mods, Asset_Image{})
						mod: ^Asset_Image = &current_frame_mods[len(current_frame_mods) - 1]
						mod^ = asset_image(fp)
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
					switch current_major_section {
					case .Colors_Group:
						color_parsed, color_parsed_ok := conv.parse_u64(line, base = 16)
						color: Color
						if color_parsed_ok {
							color = color_from_u64(color_parsed)
						} else {
							log.warnf(
								.Sprite,
								"Invalid color[%s:%v]: %s. Using default.",
								filepath,
								line_idx + 1,
								line,
							)
							color = {255, 0, 255, 255}
						}

						layer_colors := &current_color_option_group.options[len(current_color_option_group.options) - 1]
						append(&layer_colors.colors, color)

					case .Sprite:
						color_group_name := line
						for &color_group in color_options_groups {
							if color_group.name == color_group_name {
								current_sprite_color_option_group = &color_group
							}
						}

					case .Invalid:
						assert(false)
					}

				case .Invalid:
					log.warnf(
						.Sprite,
						"Invalid major section[%s:%v]: %s. Ignoring.",
						filepath,
						line_idx + 1,
						line,
					)
				}

			case .Invalid:
				fallthrough
			case:
			}

			if current_sprite != nil {
				if len(current_sprite_frames) > 0 {
					current_sprite.frames = current_sprite_frames[:]

					if len(current_frame_mods) > 0 {
						frame: ^Asset_Sprite_Frame = &current_sprite_frames[len(current_sprite_frames) - 1]
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

		ok = !failure
		out_sprite_assets = sprite_assets[:]
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
	out_sprite_assets: []Asset_Sprite,
	ok: bool,
) {
	get_line_kind :: proc(line: string) -> Line_Kind {
		if s.contains(line, "[[") do return .New_Major_Section
		if s.contains(line, "[") do return .New_Section
		if line == "" do return .Invalid
		return .Attribute
	}

	get_major_section_kind :: proc(line: string) -> Major_Section_Kind {
		interior := bracket_interior(line)
		if len(interior) == 0 {
			return .Invalid
		}
		if s.contains(line, "Colors Group") do return .Colors_Group
		return .Sprite
	}

	get_section_kind :: proc(line: string) -> Section_Kind {
		interior := bracket_interior(line)
		if interior == "Frame" do return .Frame
		if interior == "Colors" do return .Colors
		if interior == "Colors Group" do return .Sprite_Colors_Group
		return .Invalid
	}

	Line_Kind :: enum {
		Invalid,
		Attribute,
		New_Section,
		New_Major_Section,
	}

	Major_Section_Kind :: enum {
		Invalid,
		Colors_Group,
		Sprite,
	}

	Section_Kind :: enum {
		Invalid,
		Frame,
		Colors,
		Sprite_Colors_Group,
	}

	Meta_Sprite_Frame :: struct {
		base:     string,
		mods:     [dynamic]string,
		duration: f32,
	}

	Colors :: [dynamic]Color
	Colors_Options :: struct {
		options: [dynamic]Colors,
		name:    string,
	}

	Meta_Sprite :: struct {
		frames:        Meta_Sprite_Frame,
		colors_option: ^Colors_Options,
		name:          string,
	}

	Meta_Context :: struct {
		sprites:        [dynamic]Meta_Sprite,
		colors_options: [dynamic]Colors_Options,
		file:           string,
		line:           string,
		line_idx:       int,
		lines:          []string,
		line_kind:      Line_Kind,
		section:        Section_Kind,
		major:          Major_Section_Kind,
	}

	curr_sprite :: proc(mc: ^Meta_Context) -> ^Meta_Sprite {
		return &mc.sprites[len(mc.sprites) - 1]
	}
	curr_color_option :: proc(mc: ^Meta_Context) -> ^Colors_Options {
		return &mc.colors_options[len(mc.colors_options) - 1]
	}

	error :: proc(mc: ^Meta_Context, args: ..any, sep := " ", location := #caller_location) {
		str := fmt.tprint(..args, sep = sep)
		str = fmt.tprintf("[%s:%v]: %s", mc.file, mc.line_idx, str)
		log.error(.Sprite, str)
	}
	warn :: proc(mc: ^Meta_Context, args: ..any, sep := " ", location := #caller_location) {
		str := fmt.tprint(..args, sep = sep)
		str = fmt.tprintf("[%s:%v]: %s", mc.file, mc.line_idx, str)
		log.warn(.Sprite, str)
	}

	@(require_results)
	new_major :: proc(mc: ^Meta_Context) -> (ok: bool) {
		mc.major = get_major_section_kind(mc.line)
		switch mc.major {
		case .Invalid:
		case .Colors_Group:
			ok = true
			return
		case .Sprite:
			ok = true
			return
		}
		return
	}

	//
	// Actual code
	//
	context.allocator = context.temp_allocator
	mc := Meta_Context {
		sprites = make([dynamic]Meta_Sprite),
		lines   = lines,
		file    = filepath,
	}

	lines_loop: for raw_line, line_idx in mc.lines {
		mc.line_idx = line_idx
		mc.line = line_remove_comment(raw_line)
		mc.line = s.trim_space(mc.line)

		if mc.line == "" do continue

		mc.line_kind = get_line_kind(mc.line)

		switch mc.line_kind {
		case .Invalid:
			assert(false) // invalid is only caused when a line is empty which we checked for earlier
		case .Attribute:
			attrib := line_get_after_colon_space(mc.line)
		case .New_Section:
			mc.section = get_section_kind(mc.line)
		case .New_Major_Section:
			new_major(&mc) or_return
		}
	}

	ok = true
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
