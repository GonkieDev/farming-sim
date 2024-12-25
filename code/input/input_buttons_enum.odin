package input

//odinfmt:disable
Button_Mod :: enum {
	Shift, ShiftLeft, ShiftRight,
	Alt, AltLeft, AltRight,
	Ctrl, CtrlLeft, CtrlRight,
	Caps,
}
//odinfmt:enable


//odinfmt:disable
Button_Enum :: enum {
	Invalid,

	// Mouse
	MouseLeft, MouseRight, MouseMiddle, MouseX1, MouseX2,

	A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
	ZERO, ONE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE,
	F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
	F13, F14, F15, F16, F17, F18, F19, F20, F21, F22, F23, F24,

	Tab,
	Backspace,
	Enter,
	Caps,
	Space,
	Escape,

	Shift, ShiftLeft, ShiftRight,
	Ctrl, CtrlLeft, CtrlRight,
	Alt, AltLeft, AltRight,

	Equals, Minus,

	Insert, PageUp, PageDown, Delete, Home, End,
	PrintScreen, ScrollLock, PauseBreak,


	Up, Right, Left, Down,

	BracketRight, BracketLeft,
	Comma,
	Period,
	Semicolon,
	Backtick,
	ForwardSlash,
	Quote,

	Numpad0, Numpad1, Numpad2, Numpad3, Numpad4, Numpad5, Numpad6, Numpad7, Numpad8, Numpad9,
	NumpadMultiply, NumpadPlus, NumpadMinus, NumpadSlash, NumpadDecimal,
}
//odinfmt:enable
