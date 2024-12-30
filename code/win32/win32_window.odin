package build_win32

import win32 "core:sys/windows"

import build_config "../build_config"
import input "../input"
import log "../log"

GL_FORCE_VSYNC :: #config(GL_FORCE_VSYNC, false)

// @gl_remove
wglChoosePixelFormatARB: win32.ChoosePixelFormatARBType
wglCreateContextAttribsARB: win32.CreateContextAttribsARBType
wglSwapIntervalEXT: win32.SwapIntervalEXTType

_win32_window_class_name: [^]u16
@(init)
_ :: proc() {
	_win32_window_class_name = win32.L("ZauraxFarmerWindowClass")
}

_win32_window_style_default ::
	(win32.WS_OVERLAPPED |
		win32.WS_SYSMENU |
		win32.WS_CAPTION |
		win32.WS_MAXIMIZEBOX |
		win32.WS_MINIMIZEBOX |
		win32.WS_THICKFRAME |
		win32.WS_VISIBLE)

_win32_window_style_extended_default :: win32.WS_EX_APPWINDOW
_win32_window_default_dpi: f32 : 96.0

window_init :: proc() -> bool {
	// Register window class
	{
		// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-wndclassexw
		wcex := win32.WNDCLASSEXW {
			cbSize        = size_of(win32.WNDCLASSEXW),
			style         = win32.CS_OWNDC | win32.CS_HREDRAW | win32.CS_VREDRAW,
			lpfnWndProc   = win32_window_callback,
			cbClsExtra    = 0, // extra bytes to allocate following the window-class structure
			cbWndExtra    = 0, // extra bytes to allocate following the window instance
			hInstance     = win32_state.win32_hinstance,
			hIcon         = win32.LoadIconA(nil, win32.IDI_APPLICATION),
			hCursor       = win32.LoadCursorA(nil, win32.IDC_ARROW),
			hbrBackground = nil,
			lpszMenuName  = nil,
			lpszClassName = _win32_window_class_name,
			hIconSm       = nil,
		}
		if win32.RegisterClassExW(&wcex) == 0 {
			log.error(.Window, "Failed to register window class")
			return false
		}
	}

	if win32.SetProcessDpiAwarenessContext(win32.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) ==
	   win32.FALSE {
		log.error(.Window, "Failed to set DPI awareness context (err: ", win32.GetLastError(), ")")
	}

	gl_init_dummy_context() or_return

	return true
}

window_shutdown :: proc() {
	gl_shutdown()

	if win32_state.hwnd != nil {
		if win32_state.dc != nil do win32.ReleaseDC(win32_state.hwnd, win32_state.dc)
		win32.DestroyWindow(win32_state.hwnd)
	}
}

client_dims_from_style :: proc(dims: [2]u32, style: win32.UINT, ex_style: win32.UINT) -> [2]u32 {
	border_rect := win32.RECT{0, 0, 0, 0}
	win32.AdjustWindowRectEx(&border_rect, style, false, ex_style)
	client := dims
	client.x += u32(border_rect.right - border_rect.left)
	client.y += u32(border_rect.bottom - border_rect.top)
	return client
}

window_create :: proc(title: string, initial_client_dims: [2]i32) -> bool {
	window_style := _win32_window_style_default
	window_style_ex := _win32_window_style_extended_default

	client_size := [2]u32{u32(initial_client_dims.x), u32(initial_client_dims.y)}
	client_size = client_dims_from_style(client_size, window_style, window_style_ex)

	win32_state.hwnd = win32.CreateWindowExW(
		window_style_ex,
		_win32_window_class_name,
		raw_data(win32.utf8_to_utf16(title)),
		//intrinsics.constant_utf16_cstring("NICE GAME"),
		window_style,
		win32.CW_USEDEFAULT,
		win32.CW_USEDEFAULT,
		i32(client_size.x),
		i32(client_size.y),
		nil,
		nil,
		win32_state.win32_hinstance,
		nil,
	)

	if win32_state.hwnd == nil {
		log.errorf(.Window, "CreateWindowExW failed (err: %v)", win32.GetLastError())
		return false
	}
	win32_state.dc = win32.GetDC(win32_state.hwnd)
	if win32_state.dc == nil {
		log.errorf(.Window, "GetDC failed (err: %v)", win32.GetLastError())
		return false
	}

	gl_init_window() or_return

	return true
}

win32_window_callback :: proc "system" (
	hwnd: win32.HWND,
	msg: win32.UINT,
	wparam: win32.WPARAM,
	lparam: win32.LPARAM,
) -> win32.LRESULT {
	context = saved_context

	result: win32.LRESULT

	switch msg {

	case win32.WM_CLOSE:
		win32_state.running = false


	// NOTE: SYSKEYUP/DOWN is alt + key up/down
	//case win32.WM_SYSKEYUP:
	//	fallthrough
	//case win32.WM_SYSKEYDOWN:
	//	fallthrough
	case win32.WM_KEYUP:
		fallthrough
	case win32.WM_KEYDOWN:
		if wparam == win32.VK_ESCAPE {
			win32.PostQuitMessage(0)
			win32_state.running = false
			break
		}

		button := button_from_wparam(wparam)
		if button == .Invalid {
			result = win32.DefWindowProcW(hwnd, msg, wparam, lparam)
			break
		}

		// NOTE:
		// According to msdn:
		// (30) Previous key state
		//			- keydown: 1 means it was down, 0 means it was up
		//			- keyup: always 1
		// (31) Transition state
		//			- keydown: always 0
		//			- keyup: always 1
		is_down := (u64(lparam) & (1 << 31)) == 0
		was_down := (u64(lparam) & (1 << 30)) != 0
		if was_down != is_down {
			input.process_button(&win32_state.input_state, button, is_down)
		}

	case win32.WM_SIZE:
		if wparam == win32.SIZE_MINIMIZED {
			win32_state.window_is_minimized = true
			unlock_and_show_cursor()
		} else {
			win32_state.window_client_dims = {i32(win32.LOWORD(lparam)), i32(win32.HIWORD(lparam))}
			win32_state.window_is_minimized = false
		}

	case win32.WM_SETFOCUS:
		//lock_and_hide_cursor()
		win32_state.window_is_focused = true
		result = win32.DefWindowProcW(hwnd, msg, wparam, lparam)

	case win32.WM_KILLFOCUS:
		unlock_and_show_cursor()
		win32_state.window_is_focused = false
		result = win32.DefWindowProcW(hwnd, msg, wparam, lparam)

	// Raw Input
	// https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-input
	case win32.WM_INPUT:
		if win32.GET_RAWINPUT_CODE_WPARAM(wparam) == .RIM_INPUT {
			process_raw_input(lparam)

			// must call DefWindowProcW according to docs
			result = win32.DefWindowProcW(hwnd, msg, wparam, lparam)
		} else {
			// ocurred whilst application was not in foreground
		}

	case:
		result = win32.DefWindowProcW(hwnd, msg, wparam, lparam)
	}
	return result
}

process_raw_input :: proc(lparam: win32.LPARAM) {
	size: u32
	res: u32

	res = win32.GetRawInputData(
		transmute(win32.HRAWINPUT)lparam,
		win32.RID_INPUT,
		nil,
		&size,
		size_of(win32.RAWINPUTHEADER),
	)
	if res != 0 {
		log.error(.Win32, "GetRawInputData failed.")
		return
	}

	lpb := make([]win32.BYTE, size, context.temp_allocator)

	res = win32.GetRawInputData(
		transmute(win32.HRAWINPUT)lparam,
		win32.RID_INPUT,
		raw_data(lpb),
		&size,
		size_of(win32.RAWINPUTHEADER),
	)
	if res != size {
		log.error(.Win32, "GetRawInputData did not return correct size")
		return
	}

	raw := cast(^win32.RAWINPUT)raw_data(lpb)
	switch raw.header.dwType {
	case win32.RIM_TYPEKEYBOARD:
		assert(false)

	case win32.RIM_TYPEMOUSE:
		mouse := raw.data.mouse

		if mouse.usFlags & win32.MOUSE_ATTRIBUTES_CHANGED != 0 {
			panic("Mouse attributes changed not handed")
		}

		v := [2]i32{i32(mouse.lLastX), i32(mouse.lLastY)}
		// NOTE: assume relative
		input.process_mouse_movement_delta(&win32_state.input_state, v)
		if mouse.usFlags & win32.MOUSE_MOVE_ABSOLUTE != 0 {
			// TODO: test this somehow ...
			input.process_mouse_movement_absolute_pos(&win32_state.input_state, v)
		}

	case:
		assert(false)
	}

}

window_pump_events :: proc() {
	for {
		msg: win32.MSG
		if win32.PeekMessageW(&msg, win32_state.hwnd, 0, 0, win32.PM_REMOVE) {
			win32.TranslateMessage(&msg)
			win32.DispatchMessageW(&msg)
		} else {
			break
		}
	}
}

// @gl_remove
gl_init_dummy_context :: proc() -> bool {
	class_name := win32.L("DummyGLContextClass")

	wcex := win32.WNDCLASSEXW {
		cbSize        = size_of(win32.WNDCLASSEXW),
		style         = win32.CS_OWNDC | win32.CS_HREDRAW | win32.CS_VREDRAW,
		lpfnWndProc   = win32_window_callback,
		cbClsExtra    = 0, // extra bytes to allocate following the window-class structure
		cbWndExtra    = 0, // extra bytes to allocate following the window instance
		hInstance     = win32_state.win32_hinstance,
		hIcon         = win32.LoadIconA(nil, win32.IDI_APPLICATION),
		hCursor       = win32.LoadCursorA(nil, win32.IDC_ARROW),
		hbrBackground = nil,
		lpszMenuName  = nil,
		lpszClassName = class_name,
		hIconSm       = nil,
	}

	if win32.RegisterClassExW(&wcex) == 0 {
		log.error(.GL, "Failed to register window class")
		return false
	}

	//odinfmt:disable
	hwnd := win32.CreateWindowExW(
		win32.WS_EX_OVERLAPPEDWINDOW, class_name, win32.L("DummyGLWindow"), win32.WS_OVERLAPPEDWINDOW,
		win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT,
		nil, nil, win32_state.win32_hinstance, nil)
	// odinfmt:enable
	defer win32.DestroyWindow(hwnd)

	if hwnd == nil {
		log.error(.GL, "Failed to create GL dummy window")
		return false
	}

	dc := win32.GetDC(hwnd)
	if dc == nil {
		log.error(.GL, "Failed to get dummy window dc")
		return false
	}
	defer win32.ReleaseDC(hwnd, dc)

	pfd := win32.PIXELFORMATDESCRIPTOR {
		nSize      = size_of(win32.PIXELFORMATDESCRIPTOR),
		nVersion   = 1,
		dwFlags    = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL | win32.PFD_DOUBLEBUFFER,
		iPixelType = win32.PFD_TYPE_RGBA,
		cColorBits = 32,
		cAlphaBits = 8,
		cDepthBits = 24,
	}
	pixel_format := win32.ChoosePixelFormat(dc, &pfd)
	if pixel_format == 0 {
		log.error(.GL, "Failed to get a pixel format")
		return false
	}

	if !win32.SetPixelFormat(dc, pixel_format, &pfd) {
		log.error(.GL, "Failed to set the pixel format")
		return false
	}

	rc := win32.wglCreateContext(dc)
	if rc == nil {
		log.error(.GL, "Failed to create fake rendering context")
		return false
	}
	defer win32.wglDeleteContext(rc)

	if !win32.wglMakeCurrent(dc, rc) {
		log.error(.GL, "wglMakeCurrent failed")
		return false
	}

	win32.gl_set_proc_address(&wglChoosePixelFormatARB, "wglChoosePixelFormatARB")
	win32.gl_set_proc_address(&wglCreateContextAttribsARB, "wglCreateContextAttribsARB")
	win32.gl_set_proc_address(&wglSwapIntervalEXT, "wglSwapIntervalEXT")

	win32.wglMakeCurrent(dc, nil)

	return true
}

gl_init_window :: proc() -> bool {
	//odinfmt:disable
	pixel_attribs := [?]i32 {
		win32.WGL_DRAW_TO_WINDOW_ARB, 1,
		win32.WGL_SUPPORT_OPENGL_ARB, 1,
		win32.WGL_DOUBLE_BUFFER_ARB, 1,
		win32.WGL_SWAP_METHOD_ARB, win32.WGL_SWAP_COPY_ARB,
		win32.WGL_PIXEL_TYPE_ARB, win32.WGL_TYPE_RGBA_ARB,
		win32.WGL_ACCELERATION_ARB, win32.WGL_FULL_ACCELERATION_ARB,
		win32.WGL_COLOR_BITS_ARB, 32,
		win32.WGL_ALPHA_BITS_ARB, 8,
		win32.WGL_DEPTH_BITS_ARB, 24,
		0,
	}
	//odinfmt:enable

	pixel_format: i32 = 0
	num_pixel_formats: win32.UINT32 = 0
	if !wglChoosePixelFormatARB(
		win32_state.dc,
		&pixel_attribs[0],
		nil,
		1,
		&pixel_format,
		&num_pixel_formats,
	) {
		log.error(.GL, "Failed to choose a pixel format")
		return false
	}

	pfd: win32.PIXELFORMATDESCRIPTOR
	win32.DescribePixelFormat(win32_state.dc, pixel_format, size_of(pfd), &pfd)

	if !win32.SetPixelFormat(win32_state.dc, pixel_format, &pfd) {
		log.error(.GL, "Failed to set pixel format")
		return false
	}

	//odinfmt:disable
	gl_attribs := [?]i32{
		win32.WGL_CONTEXT_MAJOR_VERSION_ARB, build_config.GL_VERSION[0],
		win32.WGL_CONTEXT_MINOR_VERSION_ARB, build_config.GL_VERSION[1],
		win32.WGL_CONTEXT_PROFILE_MASK_ARB, win32.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
		0, 0, // for debug
		0,
	}
	//odinfmt:enable
	when ODIN_DEBUG {
		gl_attribs[len(gl_attribs) - 3] = win32.WGL_CONTEXT_FLAGS_ARB
		gl_attribs[len(gl_attribs) - 2] = win32.WGL_CONTEXT_DEBUG_BIT_ARB
	}

	win32_state.rc = wglCreateContextAttribsARB(win32_state.dc, nil, &gl_attribs[0])

	if !win32.wglMakeCurrent(win32_state.dc, win32_state.rc) {
		log.error(.GL, "Failed to make the current context")
		return false
	}

	when GL_FORCE_VSYNC {
		wglSwapIntervalEXT(1)
	}

	return true
}

gl_shutdown :: proc() {
	if win32_state.dc != nil {
		win32.wglMakeCurrent(win32_state.dc, nil)
		if win32_state.rc != nil do win32.wglDeleteContext(win32_state.rc)
	}
}

_win32_show_cursor_set_to_target_val :: proc(x: i32) {
	val := win32.ShowCursor(true)
	for val > x {
		val = win32.ShowCursor(false)
	}
	for val < x {
		val = win32.ShowCursor(true)
	}
}

lock_and_hide_cursor :: proc() {
	if !win32_state.window_is_focused do return

	// Hide
	_win32_show_cursor_set_to_target_val(-1)

	// Lock
	{
		client_rect: win32.RECT
		win32.GetWindowRect(win32_state.hwnd, &client_rect)

		client_rect_half_dims :=
			[2]i32 {
				(client_rect.right - client_rect.left),
				(client_rect.bottom - client_rect.top),
			} /
			2
		client_rect_top_left := [2]i32{client_rect.left, client_rect.top}
		client_rect_center := client_rect_top_left + client_rect_half_dims

		clip_half_dims := [2]i32{10, 10} / 2
		clip := win32.RECT {
			client_rect_center.x - clip_half_dims.x,
			client_rect_center.y - clip_half_dims.y,
			client_rect_center.x + clip_half_dims.x,
			client_rect_center.y + clip_half_dims.y,
		}
		win32.ClipCursor(&clip)
	}
}

unlock_and_show_cursor :: proc() {
	// Show
	_win32_show_cursor_set_to_target_val(0)

	// Unlock
	win32.ClipCursor(nil)
}

import "core:fmt"
