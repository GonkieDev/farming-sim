package build_win32

import "base:runtime"
import "core:mem"
import win32 "core:sys/windows"
import "core:time"

import game "../game"
import input "../input"
import log "../log"
import render "../render"

//
// Globals
//

win32_state: ^Win32_State
saved_context: runtime.Context

//
// Structs
//
Win32_State :: struct {
	running:             bool,
	window_client_dims:  [2]i32,
	input_state:         input.Input_State,
	window_is_minimized: b16,
	window_is_focused:   b16,

	// win32
	win32_hinstance:     win32.HINSTANCE,
	hwnd:                win32.HWND,
	dc:                  win32.HDC,
	rc:                  win32.HGLRC,
}

//
//
//
main :: proc() {

	//
	// Logger Setup
	//
	context.logger = log.create_logger()
	defer log.end_logger(context.logger)
	log.debug(.Test, "Log test")

	//
	// Tracking Allocator setup
	//
	when ODIN_DEBUG {
		default_allocator := context.allocator
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, default_allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
	}

	reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
		err := false
		for _, value in a.allocation_map {
			log.errorf(.TrackingAllocator, "%v: Leaked %v bytes\n", value.location, value.size)
			err = true
		}
		mem.tracking_allocator_clear(a)
		return err
	}

	defer {
		free_all(context.temp_allocator)
		when ODIN_DEBUG {
			if reset_tracking_allocator(&tracking_allocator) {
				// This line is mainly here so i can  put a breakpoint on debugger
				log.error(.TrackingAllocator, "Leaked bytes (read above)")
			}
		}
	}

	//
	// Init win32 state
	//

	saved_context = context

	win32_state = new(Win32_State)
	if win32_state == nil {
		log.error(.Win32, "Failed to allocate memory for win32 state")
		return
	}
	defer free(win32_state)

	// Fill state
	win32_state^ = {
		running            = true,
		window_is_focused  = true,
		//window_client_dims = {1792, 1008},
		window_client_dims = {1280, 720},
	}
	win32_state.win32_hinstance = cast(win32.HINSTANCE)win32.GetModuleHandleW(nil)


	win32.timeBeginPeriod(1)
	defer win32.timeEndPeriod(1)

	//
	// Init layers
	//
	input.init(&win32_state.input_state)

	if !window_init() do return
	window_title :: "Farming Sim" + " (DEBUG)" when ODIN_DEBUG else ""
	defer window_shutdown()
	if !window_create(window_title, win32_state.window_client_dims) do return

	// Raw input mouse
	{
		rid := win32.RAWINPUTDEVICE {
			usUsagePage = 0x01, // HID_USAGE_PAGE_GENERIC
			usUsage     = 0x02, // HID_USAGE_GENERIC_MOUSE
			// NOTE(gsp): when RIDEV_NOLEGACY is on we get no legacy mouse messages, we still want those tho
			// for window resizing / closing / etc.
			//dwFlags     = win32.RIDEV_NOLEGACY, // adds mouse and also ignores legacy mouse messages
			hwndTarget  = win32_state.hwnd,
			//hwndTarget  = nil,
		}

		if win32.RegisterRawInputDevices(&rid, 1, size_of(rid)) == win32.FALSE {
			log.error(.Win32, "Failed to register raw input device: %x", win32.GetLastError())
			return
		}
	}

	defer render.shutdown()
	if !render.init() do return

	//
	// Game init
	//
	defer game.shutdown()
	if !game.init(win32_state.window_client_dims) do return

	//
	free_all(context.temp_allocator)

	//
	// Update loop
	//
	dt := f32(0)
	for win32_state.running {

		// dt stuff
		tick_start := time.tick_now()
		defer {
			frame_duration := time.tick_since(tick_start)
			dt = f32(time.duration_seconds(frame_duration))
		}

		//
		defer free_all(context.temp_allocator)

		input.next_frame(&win32_state.input_state)
		window_pump_events()

		game_update_out: game.Update_Out
		{
			game_update_in := game.Update_In {
				dt          = dt,
				input_state = &win32_state.input_state,
			}
			game_update_out = game.update(game_update_in)
		}

		// Lock mouse
		if game_update_out.moused_locked_to_center {
			lock_and_hide_cursor()
		} else {
			unlock_and_show_cursor()
		}

		game.render(win32_state.window_client_dims)

		win32.SwapBuffers(win32_state.dc)
	}
}
