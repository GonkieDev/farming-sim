package game

import runtime "base:runtime"
import fmt "core:fmt"
import os "core:os"
import path_fp "core:path/filepath"
import slice "core:slice"
import conv "core:strconv"
import strs "core:strings"
import time "core:time"

import log "engine:log"

Sprite_Meta_Version :: enum {
	V0,

	// Leave this at bottom
	LAST,
}

Sprite_Meta_Version_Latest :: Sprite_Meta_Version.LAST - Sprite_Meta_Version(1)

@(require_results)
sprite_meta_load :: proc(all_sprites: ^Asset_All_Sprites, filepath: string, allocator := context.allocator) -> (ok: bool) {
	file_data, file_read_success := os.read_entire_file_from_filename(filepath, context.temp_allocator)
	if !file_read_success {
		log.errorf(.SpriteMeta, "Failed to load sprite meta data. Unable to read file %s", filepath)
		return
	}
	file_str := string(file_data)

	lines := strs.split(file_str, "\n", context.temp_allocator)
	version_str := line_square_bracket_interior(lines[0])
	version_parsed, version_parsed_ok := conv.parse_int(version_str)
	if !version_parsed_ok {
		log.errorf(.Sprite, "[%s:0]: Invalid number in version '%s'", filepath, version_str)
		return
	}

	version := Sprite_Meta_Version(version_parsed)
	lines = lines[1:]
	switch version {
	case .V0:
		return sprite_meta_load_version_0(all_sprites, lines, filepath, allocator)
	case .LAST:
		fallthrough
	case:
		log.errorf(.Sprite, "[%s] Invalid sprite meta version: %s", filepath, version_str)
		return
	}

	return
}

sprite_meta_load_version_0 :: proc(
	all_sprites: ^Asset_All_Sprites,
	lines: []string,
	filename: string,
	allocator := context.allocator,
) -> (
	ok: bool,
) {
	context.allocator = allocator
	all_sprites^ = Asset_All_Sprites {
		sprites = make(map[string]Asset_Sprite),
	}
	p := Parser {
		//curr_mods   = make([dynamic]Asset_Image),
		//curr_frames = make([dynamic]Asset_Sprite_Frame),
		all_sprites = all_sprites,
		lines       = lines,
		filename    = filename,
		load_dir    = path_fp.join({path_fp.dir(filename), path_fp.stem(filename)}, context.temp_allocator),
		allocator   = allocator,
	}

	for line, line_idx in lines {
		line := line_clean(line)
		if line == "" do continue

		// Update parser struct
		p.line_idx = line_idx
		p.line = line
		p.line_kind = line_get_kind(line)

		switch p.line_kind {
		case .Invalid:
			warn(&p, "Invalid line: %s", line)
		case .New_Sprite:
			p.curr_mods = {}
			p.curr_frames = make([dynamic]Asset_Sprite_Frame)

			p.section_kind = .Sprite

			name := line_square_bracket_interior(line)
			p.all_sprites.sprites[name] = Asset_Sprite{}
			p.curr_sprite = &p.all_sprites.sprites[name]

		case .New_Frame:
			p.section_kind = .Frame
			p.curr_mods = make([dynamic]Asset_Image)
			append(&p.curr_frames, Asset_Sprite_Frame{duration = 100 * time.Millisecond})
			p.curr_frame = &p.curr_frames[len(p.curr_frames) - 1]

		case .New_Attribute:
			attrib, attrib_kind := line_get_attrib(line)
			if attrib_kind == .Invalid {
				warn(&p, "Unknown attribute used: %s", line)
				break
			}
			attrib_str := line_get_after_colon_space(line)
			switch p.section_kind {
			case .Sprite:
				warn(&p, "Invalid attribute in [Sprite] section: %s", line)
			case .Frame:
				switch attrib_kind {
				case .Base:
					fp := path_fp.join({p.load_dir, attrib_str}, context.temp_allocator)
					p.curr_frame.base = asset_image(fp)
				case .Mod:
					fp := path_fp.join({p.load_dir, attrib_str}, context.temp_allocator)
					mod := asset_image(fp)
					append(&p.curr_mods, mod)
				case .Duration:
					if duration_ms, parse_ok := conv.parse_int(attrib_str); parse_ok {
						duration := time.Duration(duration_ms) * time.Millisecond
						p.curr_frame.duration = duration
					} else {
						warn(&p, "Invalid frame duration: %v", attrib_str)
					}
				case .Invalid:
					assert(false)
				}
			}
		}

		// TOOD: update slices
		if p.curr_sprite != nil {
			if len(p.curr_frames) > 0 {
				p.curr_sprite.frames = p.curr_frames[:]

				if len(p.curr_mods) > 0 {
					p.curr_frame.mods = p.curr_mods[:]
				}
			}
		}
	}

	ok = true
	return

	Parser :: struct {
		curr_mods:    [dynamic]Asset_Image,
		curr_frame:   ^Asset_Sprite_Frame,
		curr_frames:  [dynamic]Asset_Sprite_Frame,
		curr_sprite:  ^Asset_Sprite,
		all_sprites:  ^Asset_All_Sprites,
		section_kind: Section_Kind,
		line_kind:    Line_Kind,
		line_idx:     int, // starts at 0, so for printing we +1
		line:         string,
		lines:        []string,
		filename:     string,
		load_dir:     string,
		allocator:    runtime.Allocator,
	}

	Section_Kind :: enum {
		Sprite,
		Frame,
	}

	Line_Kind :: enum {
		Invalid,
		New_Sprite,
		New_Frame,
		New_Attribute,
	}

	Attribute_Kind :: enum {
		Invalid,
		Duration,
		Base,
		Mod,
	}

	line_clean :: proc(line: string) -> string {
		return strs.trim_space(line)
	}

	line_get_kind :: proc(line: string) -> Line_Kind {
		if strs.contains(line, "[[") do return .New_Sprite
		if strs.contains(line, "[Frame]") do return .New_Frame
		if strs.contains(line, ":") do return .New_Attribute
		return .Invalid
	}

	line_get_attrib :: proc(line: string) -> (attrib: string, kind: Attribute_Kind) {
		attrib = line_get_before_colon(line)
		switch attrib {
		case "base":
			kind = .Base
		case "duration":
			kind = .Duration
		case "mod":
			kind = .Mod
		case:
			kind = .Invalid
		}
		return
	}

	error :: proc(p: ^Parser, fmt_str: string, args: ..any, sep := " ", location := #caller_location) {
		str := fmt.tprintf(fmt_str, ..args)
		str = fmt.tprintf("[%s:%v]: %s", p.filename, p.line_idx + 1, str)
		log.error(.SpriteMeta, str)
	}
	warn :: proc(p: ^Parser, fmt_str: string, args: ..any, sep := " ", location := #caller_location) {
		str := fmt.tprintf(fmt_str, ..args)
		str = fmt.tprintf("[%s:%v]: %s", p.filename, p.line_idx + 1, str)
		log.warn(.SpriteMeta, str)
	}
}
