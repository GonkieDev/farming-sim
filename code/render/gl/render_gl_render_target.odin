package render_gl

import gl "vendor:OpenGL"

import bc "engine:render/backend_common"

RenderTarget_Key :: bc.RenderTarget_Key
Render_Pass_Flags :: bc.Render_Pass_Flags

render_target_resize :: proc(
	render_target_key: RenderTarget_Key,
	dims: [2]i32,
) -> (
	success: bool,
) {
	render_target := render_target_from_key(render_target_key)
	if dims != render_target.dims {
		texture_destroy(render_target.color_texture)
		if .DepthStencil in render_target.flags do texture_destroy(render_target.depth_texture)

		gl.DeleteFramebuffers(1, &render_target.framebuffer)

		render_target^ = render_target_create_inner(render_target.flags, dims) or_return
	}

	success = true
	return
}

render_target_create_inner :: proc(
	flags: Render_Pass_Flags,
	dims: [2]i32,
) -> (
	gl_render_target: GL_RenderTarget,
	success: bool,
) {
	gl_render_target = GL_RenderTarget {
		flags = flags,
		dims  = dims,
	}

	gl_render_target.color_texture = texture_upload_from_data(
		dims.x,
		dims.y,
		0,
		0,
		false,
		nil,
	) or_return
	if .DepthStencil in flags {
		gl_render_target.depth_texture = texture_upload_from_data(
			dims.x,
			dims.y,
			0,
			0,
			false,
			nil,
			is_depth_stencil = true,
		) or_return
	}

	gl.CreateFramebuffers(1, &gl_render_target.framebuffer)
	gl.NamedFramebufferTexture(
		gl_render_target.framebuffer,
		gl.COLOR_ATTACHMENT0,
		texture_from_key(gl_render_target.color_texture).id,
		0,
	)
	if .DepthStencil in flags {
		gl.NamedFramebufferTexture(
			gl_render_target.framebuffer,
			gl.DEPTH_ATTACHMENT,
			texture_from_key(gl_render_target.depth_texture).id,
			0,
		)
	}

	when ODIN_DEBUG {
		status := gl.CheckNamedFramebufferStatus(gl_render_target.framebuffer, gl.FRAMEBUFFER)
		assert(status == gl.FRAMEBUFFER_COMPLETE)
	}

	success = true
	return
}

render_target_create :: proc(
	flags: Render_Pass_Flags,
	dims: [2]i32,
) -> (
	render_target_key: RenderTarget_Key,
	success: bool,
) {
	gl_render_target := render_target_create_inner(flags, dims) or_return
	{
		render_target_key = u64(len(gl_state.render_targets))
		append(&gl_state.render_targets, gl_render_target)
	}

	success = true
	return
}

render_target_from_key :: proc(render_target_key: RenderTarget_Key) -> ^GL_RenderTarget {
	res := &gl_state.render_targets[render_target_key]
	return res
}
