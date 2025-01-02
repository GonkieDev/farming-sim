package game

import "core:os"
import s "core:strings"

import build_config "engine:build_config"
import log "engine:log"

/*
[[Body Colors]]

[Colors]
FFFFFFFF
00ffFFff
00_00_ff_ff
*/

Catalogue_Color_Entry :: struct {
	name:    string,
	options: [dynamic][dynamic]Color,
}

catalogue_init_colors :: proc() -> (ok: bool) {
	catalogue_str: string
	{
		combined_catalogues_builder: s.Builder
		s.builder_init(&combined_catalogues_builder, context.temp_allocator)
		fis, fis_err := read_dir(build_config.CATALOGUES_COLORS_PATH)
		for fi in fis {
			data, data_read_success := os.read_entire_file(fi.fullpath, context.temp_allocator)
			if !data_read_success {
				log.warnf(.Catalogue, "Failed to read file '%s'. Skipping.")
				continue
			}
			s.write_string(&combined_catalogues_builder, string(data))
		}
		catalogue_str = s.to_string(combined_catalogues_builder)
	}

	catalogue := make([dynamic]Catalogue_Color_Entry, context.allocator)
	curr_entry: ^Catalogue_Color_Entry
	curr_option: ^[dynamic]Color

	lines := s.split(catalogue_str, "\n", context.temp_allocator)
	for line in lines {
		line := line
		line = line_remove_hashtag_comment(line)
		if s.contains(line, "[[") {
			name := line_square_bracket_interior(line)
			if name != "" {
				c := Catalogue_Color_Entry {
					name    = name,
					options = make([dynamic][dynamic]Color, context.allocator),
				}
				append(&catalogue, c)
				curr_entry = &catalogue[len(catalogue) - 1]
			}
		} else if s.contains(line, "[") {
			a := make([dynamic]Color, context.allocator)
			append(&curr_entry.options, a)
			curr_option = &curr_entry.options[len(curr_entry.options) - 1]
		} else {

		}
	}

	ok = true
	return
}

@(private)
read_dir :: proc(
	dir_name: string,
	allocator := context.temp_allocator,
) -> (
	fis: []os.File_Info,
	ok: bool,
) {
	err: os.Error
	f: os.Handle
	f, err = os.open(dir_name, os.O_RDONLY)
	if err != nil do return
	defer os.close(f)
	fis, err = os.read_dir(f, -1, allocator)
	if err != nil do return
	ok = true
	return
}
