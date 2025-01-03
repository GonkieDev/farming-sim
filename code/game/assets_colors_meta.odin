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

Colors_Meta_Version :: enum {
	V0,

	// Leave this at bottom
	LAST,
}

Colors_Meta_Version_Latest :: Colors_Meta_Version.LAST - Colors_Meta_Version(1)

@(require_results)
color_meta_load :: proc(all_colors: ^Asset_All_Colors, filepath: string, allocator := context.allocator) -> (ok: bool) {
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
		log.errorf(.ColorsMeta, "[%s:0]: Invalid number in version '%s'", filepath, version_str)
		return
	}

	version := Colors_Meta_Version(version_parsed)
	lines = lines[1:]
	switch version {
	case .V0:
		return color_meta_load_version_0(all_colors, lines, filepath, allocator)
	case .LAST:
		fallthrough
	case:
		log.errorf(.Sprite, "[%s] Invalid sprite meta version: %s", filepath, version_str)
		return
	}

	return
}

color_meta_load_version_0 :: proc(
	all_colors: ^Asset_All_Colors,
	lines: []string,
	filename: string,
	allocator := context.allocator,
) -> (
	ok: bool,
) {
	context.allocator = allocator
	all_colors^ = Asset_All_Colors {
		colors = make(map[string]Asset_Color_Options),
	}
	p := Parser {
		all_colors = all_colors,
		lines      = lines,
		filename   = filename,
		allocator  = allocator,
	}
	for line, line_idx in lines {
		line := line_clean(line)
		if line == "" do continue

		// Update parser struct
		p.line_idx = line_idx
		p.line = line
		p.line_kind = line_get_kind(line)

		switch p.line_kind {
		case .New_Set:
		case .New_Option:
		case .New_Color:
		}
	}

	ok = true
	return

	Parser :: struct {
		all_colors:   ^Asset_All_Colors,
		section_kind: Section_Kind,
		line_kind:    Line_Kind,
		line_idx:     int, // starts at 0, so for printing we +1
		line:         string,
		lines:        []string,
		filename:     string,
		allocator:    runtime.Allocator,
	}

	Line_Kind :: enum {
		New_Set,
		New_Option,
		New_Color,
	}

	Section_Kind :: enum {
		Invalid,
		Option,
		Set,
	}

	line_clean :: proc(line: string) -> string {
		line := line
		line = line_remove_hashtag_comment(line)
		line = strs.trim_space(line)
		return line
	}

	line_get_kind :: proc(line: string) -> Line_Kind {
		if strs.contains(line, "[[") do return .New_Set
		if strs.contains(line, "[") do return .New_Option
		return .New_Color
	}

	error :: proc(p: ^Parser, fmt_str: string, args: ..any, sep := " ", location := #caller_location) {
		str := fmt.tprintf(fmt_str, ..args)
		str = fmt.tprintf("[%s:%v]: %s", p.filename, p.line_idx + 1, str)
		log.error(.ColorsMeta, str)
	}
	warn :: proc(p: ^Parser, fmt_str: string, args: ..any, sep := " ", location := #caller_location) {
		str := fmt.tprintf(fmt_str, ..args)
		str = fmt.tprintf("[%s:%v]: %s", p.filename, p.line_idx + 1, str)
		log.warn(.ColorsMeta, str)
	}
}
