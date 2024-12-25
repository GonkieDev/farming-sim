package render_gl

import "base:runtime"
import "core:os"
import gl "vendor:OpenGL"

import hot_reload "engine:assets/hot_reload"
import build_config "engine:build_config"
import log "engine:log"
import bc "engine:render/backend_common"

Shader_Key :: bc.Shader_Key
shader_from_key :: proc(shader_key: Shader_Key) -> ^GL_Shader {
	if gl_state.shaders == nil do return nil
	shader := &gl_state.shaders[shader_key]
	when build_config.HOT_RELOAD {
		{
			if hot_reload.check_reload(&shader.vs_hot_reload) ||
			   hot_reload.check_reload(&shader.ps_hot_reload) {
				reloaded_shader, success := shader_create_inner(
					shader.vs_hot_reload.filepath,
					shader.ps_hot_reload.filepath,
				)
				if success {
					gl.DeleteProgram(shader.program)
					gl.destroy_uniforms(shader.uniforms)
					shader^ = reloaded_shader
					log.infof(
						.GL,
						"[Hot reload] Success: %s & %s",
						shader.vs_hot_reload,
						shader.ps_hot_reload,
					)
				} else {
					log.infof(
						.GL,
						"[Hot reload] Failed: %s & %s",
						shader.vs_hot_reload,
						shader.ps_hot_reload,
					)
				}
			}
		}
	}
	return shader
}

shader_create_inner :: proc(
	vs_filepath: string,
	ps_filepath: string,
) -> (
	shader: GL_Shader,
	success: bool,
) {
	vs := compile_shader_from_file(vs_filepath, .VERTEX_SHADER) or_return
	defer gl.DeleteShader(vs)
	ps := compile_shader_from_file(ps_filepath, .FRAGMENT_SHADER) or_return
	defer gl.DeleteShader(ps)

	shader.program = create_and_link_program({vs, ps}) or_return
	shader.uniforms = gl.get_uniforms_from_program(shader.program)
	shader.vs_hot_reload = hot_reload.hot_reload_from_filepath(vs_filepath)
	shader.ps_hot_reload = hot_reload.hot_reload_from_filepath(ps_filepath)

	success = true
	return
}

shader_create :: proc(
	vs_filepath: string,
	ps_filepath: string,
) -> (
	shader_key: Shader_Key,
	success: bool,
) {
	shader_key = u64(len(gl_state.shaders))
	shader := shader_create_inner(vs_filepath, ps_filepath) or_return
	append(&gl_state.shaders, shader)
	success = true
	return
}

shader_destroy :: proc(shader_key: Shader_Key) {
	shader := shader_from_key(shader_key)
	if shader == nil do return
	gl.DeleteProgram(shader.program)
	gl.destroy_uniforms(shader.uniforms)
	hot_reload.hot_reload_destroy(&shader.vs_hot_reload)
	hot_reload.hot_reload_destroy(&shader.ps_hot_reload)
}

compile_shader_from_file :: proc(
	filepath: string,
	shader_type: gl.Shader_Type,
) -> (
	shader_id: u32,
	ok: bool,
) {
	log.debugf(.GL, "Compiling shader %s", filepath)
	file_data := os.read_entire_file(filepath) or_return
	defer delete(file_data)
	return compile_shader_from_source(string(file_data), shader_type)
}

compile_shader_from_source :: proc(
	shader_data: string,
	shader_type: gl.Shader_Type,
) -> (
	shader_id: u32,
	ok: bool,
) {
	shader_id = gl.CreateShader(cast(u32)shader_type)
	length := i32(len(shader_data))
	shader_data_copy := cstring(raw_data(shader_data))
	gl.ShaderSource(shader_id, 1, &shader_data_copy, &length)
	gl.CompileShader(shader_id)

	check_error(
		shader_id,
		shader_type,
		gl.COMPILE_STATUS,
		gl.GetShaderiv,
		gl.GetShaderInfoLog,
	) or_return

	ok = true
	return
}

create_and_link_program :: proc(
	shader_ids: []u32,
	binary_retrievable := false,
) -> (
	program_id: u32,
	ok: bool,
) {
	program_id = gl.CreateProgram()
	for id in shader_ids {
		gl.AttachShader(program_id, id)
	}
	if binary_retrievable {
		gl.ProgramParameteri(
			program_id,
			gl.PROGRAM_BINARY_RETRIEVABLE_HINT,
			1,
			/*true*/
		)
	}
	gl.LinkProgram(program_id)

	check_error(
		program_id,
		.SHADER_LINK,
		gl.LINK_STATUS,
		gl.GetProgramiv,
		gl.GetProgramInfoLog,
	) or_return
	ok = true
	return
}

@(private = "file")
check_error :: proc(
	id: u32,
	type: gl.Shader_Type,
	status: u32,
	iv_func: proc "c" (_: u32, _: u32, _: [^]i32, _: runtime.Source_Code_Location),
	log_func: proc "c" (_: u32, _: i32, _: ^i32, _: [^]u8, _: runtime.Source_Code_Location),
	loc := #caller_location,
) -> (
	success: bool,
) {
	result, info_log_length: i32
	iv_func(id, status, &result, loc)
	iv_func(id, gl.INFO_LOG_LENGTH, &info_log_length, loc)

	when ODIN_DEBUG {
		if result == 0 {
			msg: [4096]u8
			msg_len := i32(0) // excluding null terminator
			log_func(id, len(msg), &msg_len, &msg[0], loc)
			log.errorf(.GL, "Error in %v:\n%s", type, string(msg[0:msg_len]))
			return false
		}
	}

	return true
}
