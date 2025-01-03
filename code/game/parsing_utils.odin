package game
import s "core:strings"

line_square_bracket_interior :: proc(line: string) -> string {
	interior := line[s.last_index(line, "[") + 1:s.index(line, "]")]
	return interior
}

line_remove_hashtag_comment :: proc(line: string) -> string {
	hashtag_idx := s.index(line, "#")
	if hashtag_idx <= 0 do return line
	return line[:hashtag_idx - 1]
}

line_get_after_colon_space :: proc(line: string) -> string {
	colon_idx := s.index(line, ":")
	after_colon := line[colon_idx + 1:]
	trimmed := s.trim_space(after_colon)
	return trimmed
}

line_get_before_colon :: proc(line: string) -> string {
	colon_idx := s.index(line, ":")
	return line[:colon_idx]
}
