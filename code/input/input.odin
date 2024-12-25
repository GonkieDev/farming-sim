package input

Button :: struct {
	half_transitions: u8,
	is_down:          b8,
}

// TODO: handle DPI & DPI changes
Mouse :: struct {
	delta:        [2]i32,
	absolute_pos: [2]i32,
}

Input :: struct {
	buttons: [Button_Enum]Button,
	mouse:   Mouse,
}

Input_State :: struct {
	inputs: [2]Input,
	curr:   ^Input,
	prev:   ^Input,
}

init :: proc(is: ^Input_State) {
	is.curr = &is.inputs[0]
	is.prev = &is.inputs[0]
}

next_frame :: proc(is: ^Input_State) {
	is.prev, is.curr = is.curr, is.prev

	// Copy/reset button data
	for &prev, i in is.prev.buttons {
		curr := &is.curr.buttons[i]
		curr.half_transitions = 0
		curr.is_down = prev.is_down
	}

	is.curr.mouse = {
		absolute_pos = is.prev.mouse.absolute_pos,
	}

}

process_button :: proc(is: ^Input_State, button_enum: Button_Enum, is_down: bool) {
	button := &is.curr.buttons[button_enum]

	// Check if button did in fact change state
	//assert(is_down != bool(button.is_down))
	assert(button.half_transitions < 0xff)

	if is_down == bool(button.is_down) do return
	button.is_down = b8(is_down)
	button.half_transitions += 1
}

process_mouse_movement_delta :: proc(is: ^Input_State, delta: [2]i32) {
	m := &is.curr.mouse
	m.delta += delta
	m.absolute_pos += delta
}
process_mouse_movement_absolute_pos :: proc(is: ^Input_State, absolute_pos: [2]i32) {
	m := &is.curr.mouse
	m.absolute_pos = absolute_pos
	m.delta += m.absolute_pos - is.prev.mouse.absolute_pos
}

is_down :: proc(is: ^Input_State, button_enum: Button_Enum) -> bool {
	button := is.curr.buttons[button_enum]
	return bool(button.is_down)
}
