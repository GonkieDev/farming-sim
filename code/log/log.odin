package game_log

import "base:runtime"
import "core:fmt"
import core_log "core:log"

import win32 "core:sys/windows"

Logger :: core_log.Logger
Level :: core_log.Level

LogLocation :: enum {
	Test,
	TrackingAllocator,
	Window,
	Win32,
	Game,
	GL,
	Atlas,
	Sprite,
	SpriteMeta,
}

create_logger :: proc() -> Logger {
	// TODO: @log file logger
	// TODO: @log disable/enable log locations
	return core_log.create_console_logger()
}

end_logger :: proc(_: Logger) {
	debug(.Test, "Logging finished")
}

log_actual :: proc(
	level: Level,
	log_location: LogLocation,
	args: ..any,
	sep := " ",
	location := #caller_location,
) {
	logger := context.logger
	if logger.procedure == nil || logger.procedure == core_log.nil_logger_proc {
		return
	}
	if level < logger.lowest_level {
		return
	}
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	str := fmt.tprint(..args, sep = sep) //NOTE(Hoej): While tprint isn't thread-safe, no logging is.
	str = fmt.tprintf("[%v] %s", log_location, str)
	logger.procedure(logger.data, level, str, logger.options, location)

	when ODIN_OS == .Windows {
		win32.OutputDebugStringW(
			raw_data(
				win32.utf8_to_utf16(fmt.tprintf("%s\n", str), allocator = context.temp_allocator),
			),
		)
	}
}

log_actualf :: proc(
	level: Level,
	log_location: LogLocation,
	fmt_str: string,
	args: ..any,
	location := #caller_location,
) {
	logger := context.logger
	if logger.procedure == nil || logger.procedure == core_log.nil_logger_proc {
		return
	}
	if level < logger.lowest_level {
		return
	}
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	str := fmt.tprintf(fmt_str, ..args)
	str = fmt.tprintf("[%v] %s", log_location, str)
	logger.procedure(logger.data, level, str, logger.options, location)

	when ODIN_OS == .Windows {
		win32.OutputDebugStringW(
			raw_data(
				win32.utf8_to_utf16(fmt.tprintf("%s\n", str), allocator = context.temp_allocator),
			),
		)
		win32.OutputDebugStringW(win32.L("\n"))
	}
}

debug :: proc(log_location: LogLocation, args: ..any, sep := " ", location := #caller_location) {
	when ODIN_DEBUG {
		log_actual(.Debug, log_location, ..args, sep = sep, location = location)
	}
}

info :: proc(log_location: LogLocation, args: ..any, sep := " ", location := #caller_location) {
	log_actual(.Info, log_location, ..args, sep = sep, location = location)
}

warn :: proc(log_location: LogLocation, args: ..any, sep := " ", location := #caller_location) {
	log_actual(.Warning, log_location, ..args, sep = sep, location = location)
}

error :: proc(log_location: LogLocation, args: ..any, sep := " ", location := #caller_location) {
	log_actual(.Error, log_location, ..args, sep = sep, location = location)
}

debugf :: proc(
	log_location: LogLocation,
	fmt_str: string,
	args: ..any,
	location := #caller_location,
) {
	when ODIN_DEBUG {
		log_actualf(.Debug, log_location, fmt_str, ..args, location = location)
	}
}

infof :: proc(
	log_location: LogLocation,
	fmt_str: string,
	args: ..any,
	location := #caller_location,
) {
	log_actualf(.Info, log_location, fmt_str, ..args, location = location)
}

warnf :: proc(
	log_location: LogLocation,
	fmt_str: string,
	args: ..any,
	location := #caller_location,
) {
	log_actualf(.Warning, log_location, fmt_str, ..args, location = location)
}

errorf :: proc(
	log_location: LogLocation,
	fmt_str: string,
	args: ..any,
	location := #caller_location,
) {
	log_actualf(.Error, log_location, fmt_str, ..args, location = location)
}
