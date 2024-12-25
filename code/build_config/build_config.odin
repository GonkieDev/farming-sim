package build_config

GL_VERSION :: [2]i32{4, 6}

// Relative to exe path
ROOT_PATH :: "../"
ASSETS_PATH :: ROOT_PATH + "assets/"
SHADERS_PATH :: ASSETS_PATH + "shaders/"

HOT_RELOAD :: #config(HOT_RELOAD, true)
