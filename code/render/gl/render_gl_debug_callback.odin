package render_gl

import gl "vendor:OpenGL"
import log "../../log"

// https://www.khronos.org/opengl/wiki/Debug_Output
gl_debug_callback :: proc "c" (
	source: u32,
	type: u32,
	id: u32,
	severity: u32,
	length: i32,
	message: cstring,
	userParam: rawptr,
) {
	context = gl_callback_context

	source_str := ""
	switch source {
	//odinfmt:disable
	case gl.DEBUG_SOURCE_API: source_str = "API"
	case gl.DEBUG_SOURCE_WINDOW_SYSTEM: source_str = "System"
	case gl.DEBUG_SOURCE_SHADER_COMPILER: source_str = "Shader compiler"
	case gl.DEBUG_SOURCE_THIRD_PARTY: source_str = "Third Party"
	case gl.DEBUG_SOURCE_APPLICATION: source_str = "Application"
	case gl.DEBUG_SOURCE_OTHER: source_str = "Other"
	//odinfmt:enable
	}

	type_str := ""
	switch type {
	//odinfmt:disable
	case gl.DEBUG_TYPE_ERROR: type_str = "Error"
	case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR: type_str = "Deprecated Behavior"
	case gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR: type_str = "Undefined Behavior"
	case gl.DEBUG_TYPE_PORTABILITY: type_str = "Portability"
	case gl.DEBUG_TYPE_PERFORMANCE: type_str = "Performance"
	case gl.DEBUG_TYPE_MARKER: type_str = "Marker"
	case gl.DEBUG_TYPE_PUSH_GROUP: type_str = "Push Group"
	case gl.DEBUG_TYPE_POP_GROUP: type_str = "Pop Group"
	case gl.DEBUG_TYPE_OTHER: type_str = "Other"
	//odinfmt:enable
	}

	logf := log.errorf
	switch severity {
	//odinfmt:disable
	case gl.DEBUG_SEVERITY_HIGH: logf = log.errorf
	case gl.DEBUG_SEVERITY_MEDIUM: logf = log.warnf
	case gl.DEBUG_SEVERITY_LOW: fallthrough
	case gl.DEBUG_SEVERITY_NOTIFICATION: logf = log.infof
	//odinfmt:enable
	}

	logf(.GL, "[%s] [%s] (ID: %v)\n%s", source_str, type_str, id, message)
}
