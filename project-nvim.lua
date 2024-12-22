local build_debug_cmd = "build.bat debug "

local open_url = "start msedge "

local commands = {

	--
	-- Builds ---------------------------------------------------
	--
	BuildDebug = {
		cmd = build_debug_cmd,
		key = "<F8>",
		errorformat = "Odin",
	},

	BuildRelease = {
		cmd = "build.bat release",
		errorformat = "Odin",
		key = "<F9>",
	},

	--
	-- Run ------------------------------------------------------
	--
	Run = {
		cmd = "build.bat run",
		key = "<F2>",
	},

	RunDebugger = {
		cmd = "pushd bin && raddbg game.exe && popd",
		key = "<F1>",
	},

	--
	-- Misc -----------------------------------------------------
	--
	OdinDocsOverview = { cmd = open_url .. "https://odin-lang.org/docs/overview/", key = "<leader>do" },
	OdinDocsPackages = { cmd = open_url .. "https://odin-lang.org/docs/packages/", key = "<leader>dp" },
	OdinDocsRaylib = { cmd = open_url .. "https://pkg.odin-lang.org/vendor/raylib", key = "<leader>dr" },
	OdinDocsOpenGL = { cmd = open_url .. "https://pkg.odin-lang.org/vendor/OpenGL", key = "<leader>dg" },

	OpenDebugger = { cmd = "raddbg -profile:debugger.raddbg_profile" },
}

return { commands = commands, version = 1 }
