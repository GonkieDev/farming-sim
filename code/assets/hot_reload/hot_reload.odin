package hot_reload

import "core:os"
import "core:strings"

import "engine:build_config"

when build_config.HOT_RELOAD {
	Hot_Reload :: struct {
		filepath: string,
		time:     os.File_Time,
	}
} else {
	Hot_Reload :: struct {}
}

hot_reload_from_filepath :: proc(filepath: string) -> Hot_Reload {
	when build_config.HOT_RELOAD {
		time, _ := os.last_write_time_by_name(filepath)
		return Hot_Reload{filepath = strings.clone(filepath), time = time}
	} else {
		return Hot_Reload{}
	}
}

check_reload :: proc(hot_reload: ^Hot_Reload) -> bool {
	when build_config.HOT_RELOAD {
		time, err := os.last_write_time_by_name(hot_reload.filepath)
		if err == nil {
			if time != hot_reload.time {
				hot_reload.time = time
				return true
			}
		}
	}
	return false
}

hot_reload_destroy :: proc(hot_reload: ^Hot_Reload) {
	when build_config.HOT_RELOAD {
		delete(hot_reload.filepath)
	}
}
