package render_gl

#assert(ODIN_OS == .Windows)
import win32 "core:sys/windows" // for win32.gl_set_proc_address
import gl "vendor:OpenGL"

import build_config "../../build_config"
import log "../../log"
import bc "../backend_common"

SHADERS_PATH :: build_config.SHADERS_PATH

init :: proc() -> bool {
	gl_callback_context = context
	gl_state = new(GL_State)
	assert(gl_state != nil)

	gl_state.shaders = make([dynamic]GL_Shader)
	gl_state.textures = make([dynamic]GL_Texture)

	gl.load_up_to(
		int(build_config.GL_VERSION[0]),
		int(build_config.GL_VERSION[1]),
		win32.gl_set_proc_address,
	)
	log.infof(.GL, "GL Loaded up to: %s", gl.GetString(gl.VERSION))

	setup_debug()

	// Default vao
	gl.CreateVertexArrays(1, &gl_state.default_vao)

	// Global UBO
	gl.CreateBuffers(1, &gl_state.global_ubo)
	gl.NamedBufferStorage(gl_state.global_ubo, size_of(Global_UBO), nil, gl.DYNAMIC_STORAGE_BIT)

	// debug state
	when ODIN_DEBUG {
		// lines ssbo
		{
			gl.CreateBuffers(1, &gl_state.debug.lines_ssbo)
			gl.NamedBufferStorage(
				gl_state.debug.lines_ssbo,
				LINES_SSBO_SIZE,
				nil,
				gl.DYNAMIC_STORAGE_BIT,
			)
		}
	}

	gl_state.sprite_shader = shader_create(
		SHADERS_PATH + "sprite_vs.glsl",
		SHADERS_PATH + "sprite_ps.glsl",
	) or_return
	gl_state.screen_quad_shader = shader_create(
		SHADERS_PATH + "screen_quad_vs.glsl",
		SHADERS_PATH + "screen_quad_ps.glsl",
	) or_return

	gl.CreateBuffers(1, &gl_state.sprite_ssbo)
	gl.NamedBufferStorage(
		gl_state.sprite_ssbo,
		MAX_RENDER_SPRITES * size_of(GL_Sprite_Draw_Data),
		nil,
		gl.DYNAMIC_STORAGE_BIT,
	)

	return true
}

shutdown :: proc() {
	if gl_state != nil {
		when ODIN_DEBUG {
			shader_destroy(gl_state.debug.lines_shader)
		}
		shader_destroy(gl_state.sprite_shader)
		shader_destroy(gl_state.screen_quad_shader)
		delete(gl_state.textures)
		delete(gl_state.shaders)
		delete(gl_state.render_targets)
		free(gl_state)
	}
}

render_begin :: proc(rbegin: ^bc.Render_Begin) {
	gl_state.begin_info = rbegin

	// Clear default framebuffer
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	clear_color := [4]f32{0.0, 0.0, 0.0, 0.0}
	gl.ClearBufferfv(gl.COLOR, 0, &clear_color[0])
	d := f32(1.0)
	gl.ClearBufferfv(gl.DEPTH, 0, &d)

	{
		global_ubo_data: Global_UBO
		global_ubo_data.screen_size = {f32(rbegin.client_dims.x), f32(rbegin.client_dims.y)}
		gl.NamedBufferSubData(
			gl_state.global_ubo,
			int(offset_of(global_ubo_data.screen_size)),
			size_of(global_ubo_data.screen_size),
			rawptr(&global_ubo_data.screen_size),
		)
	}
}

render_end :: proc() {
}

render_begin_pass :: proc(pass: ^bc.Render_Begin_Pass) {
	assert(pass != gl_state.curr_pass)
	//assert(target.render_target_key != gl_state.curr_pass.render_target_key)
	gl_state.curr_pass = pass
	render_target := render_target_from_key(pass.render_target_key)

	when ODIN_DEBUG {
		gl_state.debug.lines_vertices = make(
			[]Debug_GL_Render_Line_Vertex,
			LINES_SSBO_COUNT,
			context.temp_allocator,
		)
	}

	render_target_resize(pass.render_target_key, gl_state.begin_info.client_dims)

	gl.BindFramebuffer(gl.FRAMEBUFFER, render_target.framebuffer)

	// NOTE: should this be here all the time or only when .DepthStencil in flags ?
	gl.Enable(gl.DEPTH_TEST)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	gl.Viewport(pass.viewport.tl.x, pass.viewport.tl.y, pass.viewport.br.x, pass.viewport.br.y)

	// Clear
	gl.ClearBufferfv(gl.COLOR, 0, &pass.clear.color[0])
	if .DepthStencil in render_target.flags {
		// TODO: depth from curr_pass
		d := f32(1.0)
		gl.ClearBufferfv(gl.DEPTH, 0, &d)
	}

	{
		global_ubo_data: Global_UBO
		global_ubo_data.matrices = {
			proj = pass.proj,
			view = pass.view,
		}
		gl.NamedBufferSubData(
			gl_state.global_ubo,
			int(offset_of(global_ubo_data.matrices)),
			size_of(global_ubo_data.matrices),
			rawptr(&global_ubo_data.matrices),
		)
	}
}

render_end_pass :: proc(target: ^bc.Render_End_Pass) {
	defer gl_state.curr_pass = nil
	curr_pass := gl_state.curr_pass
	assert(curr_pass != nil)

	gl.BindBufferBase(gl.UNIFORM_BUFFER, Global_UBO_Binding_Point, gl_state.global_ubo)

	// Draw sprites
		texture_array := make([dynamic]GL_Id, context.temp_allocator)
		gl_sdd: []GL_Sprite_Draw_Data
		{
			sdd := target.sprite_draw_data
			assert(len(sdd) < MAX_RENDER_SPRITES)
			gl_sdd = make([]GL_Sprite_Draw_Data, len(sdd), context.temp_allocator)

			for s, i in sdd {
				texture := texture_from_key(s.texture_id)
				gl_sdd[i] = GL_Sprite_Draw_Data {
					tint = s.tint,
					dims = s.dims,
					offset = s.offset,
					texture_index = texture.handle,
					uv_offset = s.uv_offset,
					uv_dims = s.uv_dims,
			}
		}

		gl.NamedBufferSubData(
			gl_state.sprite_ssbo,
			int(0),
			len(gl_sdd) * size_of(GL_Sprite_Draw_Data),
			raw_data(gl_sdd),
		)

		shader := shader_from_key(gl_state.sprite_shader)
		gl.UseProgram(shader.program)
		gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, gl_state.sprite_ssbo)
		gl.BindVertexArray(gl_state.default_vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 6 * i32(len(gl_sdd)))
	}

	// Blit to default frame buffer
	{
		render_target := render_target_from_key(curr_pass.render_target_key)
		client_dims := gl_state.begin_info.client_dims

		gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
		gl.Viewport(0, 0, client_dims.x, client_dims.y)

		gl.Enable(gl.BLEND)
		gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
		gl.Disable(gl.DEPTH_TEST)

		shader := shader_from_key(gl_state.screen_quad_shader)
		gl.UseProgram(shader.program)
		if u, ok := shader.uniforms["ScreenSize"]; ok {
			client_dims_2f32 := [2]f32{f32(client_dims.x), f32(client_dims.y)}
			gl.Uniform2fv(u.location, 1, &client_dims_2f32[0])
		}
		gl.BindTextureUnit(0, texture_from_key(render_target.color_texture).id)

		gl.BindVertexArray(gl_state.default_vao)
		gl.DrawArrays(gl.TRIANGLES, 0, 6)
	}
}

debug_render_line :: proc(debug_render_line: bc.Debug_Render_Line) {
	when ODIN_DEBUG {
		#assert(LINES_SSBO_COUNT % 2 == 0)
		assert(gl_state.debug.lines_ssbo_vertex_count < LINES_SSBO_COUNT)

		d := &gl_state.debug

		v1 := Debug_GL_Render_Line_Vertex {
			pos   = debug_render_line.a,
			color = debug_render_line.color,
		}
		v2 := Debug_GL_Render_Line_Vertex {
			pos   = debug_render_line.b,
			color = debug_render_line.color,
		}

		d.lines_vertices[d.lines_ssbo_vertex_count] = v1
		d.lines_vertices[d.lines_ssbo_vertex_count + 1] = v2
		d.lines_ssbo_vertex_count += 2
	}
}

default_shader :: proc() -> Shader_Key {
	return {}
}

setup_debug :: proc() {
	// Setup debug
	when ODIN_DEBUG {
		gl.Enable(gl.DEBUG_OUTPUT)
		gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)

		gl.DebugMessageCallback(gl_debug_callback, nil)

		gl.DebugMessageControl(
			gl.DONT_CARE,
			gl.DONT_CARE,
			gl.DEBUG_SEVERITY_NOTIFICATION,
			0,
			nil,
			false,
		)

			//odinfmt:disable
		//gl.DebugMessageInsert(gl.DEBUG_SOURCE_APPLICATION, gl.DEBUG_TYPE_OTHER, 0, gl.DEBUG_SEVERITY_ERROR, len(msg), "Debug GL test message")
		//odinfmt:enable
	}
}
