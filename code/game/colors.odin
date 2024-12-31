package game

Color :: [4]f32

color_from_u64 :: proc(u: u64) -> Color {
	return Color {
		0 = f32((u >> 24) & 0x00_00_00_FF) / 255.0,
		1 = f32((u >> 16) & 0x00_00_00_FF) / 255.0,
		2 = f32((u >> 8) & 0x00_00_00_FF) / 255.0,
		3 = f32((u >> 0) & 0x00_00_00_FF) / 255.0,
	}
}
