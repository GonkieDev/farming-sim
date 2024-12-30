package aseprite_exporter

import ase "./aseprite"

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
	Output_To_File,
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
	layer_chunk: ^ase.Layer_Chunk,
	layers:      [Ase_Layer_Type][dynamic]Ase_Layer,
	is_broken:   bool,
	is_empty:    bool,
}
