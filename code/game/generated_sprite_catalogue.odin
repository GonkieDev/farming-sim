package game

import build_config "engine:build_config"

@(private = "file")
A :: build_config.ASSETS_PATH



//odinfmt:disable

player_asset_sprite := Asset_Sprite {
	frames = {
		0 = {
			base = { fp = A + "player/South_0_non_mod.png" },
			mods = {
				{ fp = A + "player/South_0_mod_0.png" },
				{ fp = A + "player/South_0_mod_1.png" },
				{ fp = A + "player/South_0_mod_2.png" },
			},
		},
	},
	mod_colors = {
		{
			0 = {1.0, 0.0, 0.0, 1.0},
			1 = {0.0, 1.0, 0.0, 1.0},
			2 = {0.0, 0.0, 1.0, 1.0},
			3 = {1.0, 1.0, 1.0, 1.0},
		},
	},
}

//odinfmt:enable
