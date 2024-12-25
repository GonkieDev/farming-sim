package build_win32

import input "../input"
import win32 "core:sys/windows"

button_from_wparam :: proc "contextless" (wparam: win32.WPARAM) -> input.Button_Enum {
	result: input.Button_Enum = .Invalid
	
	// odinfmt:disable
	switch wparam {
	case win32.VK_LBUTTON: result = .MouseLeft
	case win32.VK_RBUTTON: result = .MouseRight
	case win32.VK_MBUTTON: result = .MouseMiddle
	case win32.VK_XBUTTON1: result = .MouseX1
	case win32.VK_XBUTTON2: result = .MouseX2

	case win32.VK_BACK: result = .Backspace
	case win32.VK_TAB: result = .Tab
	case win32.VK_RETURN: result = .Enter
	case win32.VK_SHIFT: result = .Shift
	case win32.VK_CONTROL: result = .Ctrl
	case win32.VK_MENU: result = .Alt
	case win32.VK_ESCAPE: result = .Escape
	case win32.VK_SPACE: result = .Space
	case win32.VK_PRIOR: result = .PageUp
	case win32.VK_NEXT: result = .PageDown
	case win32.VK_END: result = .End
	case win32.VK_HOME: result = .Home
	case win32.VK_LEFT: result = .Left
	case win32.VK_RIGHT: result = .Right
	case win32.VK_UP: result = .Up
	case win32.VK_DOWN: result = .Down
	case win32.VK_DELETE: result = .Delete

	case '1': result = .ONE 
	case '2': result = .TWO 
	case '3': result = .THREE
	case '4': result = .FOUR
	case '5': result = .FIVE
	case '6': result = .SIX
	case '7': result = .SEVEN
	case '8': result = .EIGHT
	case '9': result = .NINE

	case 'A': result = .A
	case 'B': result = .B
	case 'C': result = .C
	case 'D': result = .D
	case 'E': result = .E
	case 'F': result = .F
	case 'G': result = .G
	case 'H': result = .H
	case 'I': result = .I
	case 'J': result = .J
	case 'K': result = .K
	case 'L': result = .L
	case 'M': result = .M
	case 'N': result = .N
	case 'O': result = .O
	case 'P': result = .P
	case 'Q': result = .Q
	case 'R': result = .R
	case 'S': result = .S
	case 'T': result = .T
	case 'U': result = .U
	case 'V': result = .V
	case 'W': result = .W
	case 'X': result = .X
	case 'Y': result = .Y
	case 'Z': result = .Z

	case win32.VK_F1: result = .F1
	case win32.VK_F2: result = .F2
	case win32.VK_F3: result = .F3
	case win32.VK_F4: result = .F4
	case win32.VK_F5: result = .F5
	case win32.VK_F6: result = .F6
	case win32.VK_F7: result = .F7
	case win32.VK_F8: result = .F8
	case win32.VK_F9: result = .F9
	case win32.VK_F10: result = .F10
	case win32.VK_F11: result = .F11
	case win32.VK_F12: result = .F12
	case win32.VK_F13: result = .F13
	case win32.VK_F14: result = .F14
	case win32.VK_F15: result = .F15
	case win32.VK_F16: result = .F16
	case win32.VK_F17: result = .F17
	case win32.VK_F18: result = .F18
	case win32.VK_F19: result = .F19
	case win32.VK_F20: result = .F20
	case win32.VK_F21: result = .F21
	case win32.VK_F22: result = .F22
	case win32.VK_F23: result = .F23
	case win32.VK_F24: result = .F24

	case win32.VK_OEM_PLUS: result = .Equals
	case win32.VK_OEM_MINUS: result = .Minus
	case win32.VK_OEM_COMMA: result = .Comma
	case win32.VK_OEM_PERIOD: result = .Period
	case win32.VK_OEM_1: result = .Semicolon
	case win32.VK_OEM_2: result = .ForwardSlash
	case win32.VK_OEM_3: result = .Backtick
	case win32.VK_OEM_4: result = .BracketRight
	case win32.VK_OEM_6: result = .BracketLeft
	case win32.VK_OEM_7: result = .Quote
	}
	// odinfmt:enable
	return result
}
