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

	BuildAsepriteExporter = {
		cmd = ".\\code\\aseprite_exporter\\build.bat debug",
		errorformat = "Odin",
		key = "<F10>",
	},

	--
	-- Run ------------------------------------------------------
	--
	Run = {
		cmd = "build.bat run",
		key = "<F2>",
	},

	RunAsepriteExporter = {
		cmd = ".\\code\\aseprite_exporter\\build.bat run",
		errorformat = "Odin",
		key = "<F1>",
	},

	--
	-- Misc -----------------------------------------------------
	--
	OdinDocsOverview = { cmd = open_url .. "https://odin-lang.org/docs/overview/", key = "<leader>do" },
	OdinDocsPackages = { cmd = open_url .. "https://odin-lang.org/docs/packages/", key = "<leader>dp" },
	OdinDocsRaylib = { cmd = open_url .. "https://pkg.odin-lang.org/vendor/raylib", key = "<leader>dr" },
	OdinDocsOpenGL = { cmd = open_url .. "https://pkg.odin-lang.org/vendor/OpenGL", key = "<leader>dg" },

	OpenDebugger = { cmd = "raddbg --project:farming-sim.raddbg_project" },
	-- PackageAsepritePlugin = { cmd = "aseprite_plugin\\package_aseprite_plugin.bat", key = "<F3>" },
}

return { commands = commands, version = 1 }
