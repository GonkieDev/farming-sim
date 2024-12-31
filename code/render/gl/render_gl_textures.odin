package render_gl

import gl "vendor:OpenGL"

import bc "../backend_common"

Texture_Key :: bc.Texture_Key

texture_upload_from_data :: proc(
	width, height, depth, channels: i32,
	generate_mips: bool,
	pixels: rawptr,
	is_depth_stencil := false,
) -> (
	texture_key: Texture_Key,
	success: bool,
) {
	gl_texture: GL_Texture
	gl.CreateTextures(gl.TEXTURE_2D, 1, &gl_texture.id)

	if !is_depth_stencil {
		gl.TextureParameteri(gl_texture.id, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
		gl.TextureParameteri(gl_texture.id, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
		gl.TextureParameteri(gl_texture.id, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
		gl.TextureParameteri(gl_texture.id, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	}

	internal_format := u32(gl.RGBA32F)
	if is_depth_stencil {
		internal_format = gl.DEPTH24_STENCIL8
	}
	gl.TextureStorage2D(gl_texture.id, 1, internal_format, i32(width), i32(height))

	gl_texture.handle = gl.GetTextureHandleARB(gl_texture.id)
	assert(gl_texture.handle != 0)
	gl.MakeTextureHandleResidentARB(gl_texture.handle)

	when ODIN_DEBUG {
		if is_depth_stencil {
			assert(pixels == nil)
		}
	}
	if pixels != nil {
		data_format := data_format_from_channels(int(channels))
		data_type := data_type_from_depth(int(depth))

		if is_depth_stencil {
			data_format = gl.DEPTH_COMPONENT
			assert(channels == 1)
		}

		gl.TextureSubImage2D(
			gl_texture.id,
			0, // level
			0,
			0, // x,y offset
			i32(width),
			i32(height),
			data_format,
			data_type,
			pixels,
		)

		if generate_mips {
			gl.GenerateTextureMipmap(gl_texture.id)
		}
	}

	{
		texture_key = u64(len(gl_state.textures))
		append(&gl_state.textures, gl_texture)
	}

	success = true
	return
}

texture_update :: proc(
	texture_key: Texture_Key,
	x, y, width, height, depth, channels: int,
	pixels: rawptr,
) -> (
	success: bool,
) {
	texture := texture_from_key(texture_key)

	data_format := data_format_from_channels(channels)
	data_type := data_type_from_depth(depth)

	gl.TextureSubImage2D(
		texture.id,
		0,
		i32(x),
		i32(y),
		i32(width),
		i32(height),
		data_format,
		data_type,
		pixels,
	)

	success = true
	return
}

texture_destroy :: proc(texture_key: Texture_Key) {
	gl_texture := texture_from_key(texture_key)
	if gl_texture != nil {
		gl.DeleteTextures(1, &gl_texture.id)
	}
}

@(require_results)
texture_from_key :: proc(texture_key: Texture_Key) -> ^GL_Texture {
	if gl_state.textures == nil do return nil
	return &gl_state.textures[texture_key]
}

@(private = "file")
data_type_from_depth :: proc(depth: int) -> u32 {
	data_type := u32(gl.UNSIGNED_BYTE)
	switch depth {
	//odinfmt:disable
	case 8: data_type = gl.UNSIGNED_BYTE
	case: assert(false)
	//odinfmt:enable
	}
	return data_type
}

@(private = "file")
data_format_from_channels :: proc(channels: int) -> u32 {
	data_format := u32(gl.RGBA)
	switch channels {
	//odinfmt:disable
	case 1: data_format = gl.RED
	case 2: data_format = gl.RG
	case 3: data_format = gl.RGB
	case 4: data_format = gl.RGBA
	case: assert(false)
	//odinfmt:enable
	}
	return data_format
}
