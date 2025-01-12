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

	-- BuildRelease = {
	-- 	cmd = "build.bat release",
	-- 	errorformat = "Odin",
	-- 	key = "<F9>",
	-- },

	BuildAsepriteExporter = {
		cmd = ".\\tools\\aseprite_exporter\\build.bat debug",
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

	RunAsepriteExporter = {
		cmd = ".\\tools\\aseprite_exporter\\aseprite_exporter.exe assets/player.aseprite assets/exported_sprites/",
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
	AsepriteExporterOpenDebugger = { cmd = "raddbg --project:aseprite_exporter.raddbg_project" },
	-- PackageAsepritePlugin = { cmd = "aseprite_plugin\\package_aseprite_plugin.bat", key = "<F3>" },
}

return { commands = commands, version = 1 }
