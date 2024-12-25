package game

import "core:math"

PI_f32 :: f32(math.PI)
PI_2_f32 :: f32(math.PI / 2.0)
PI_3_f32 :: f32(math.PI / 3.0)
PI_4_f32 :: f32(math.PI / 4.0)

v2 :: [2]f32
v3 :: [3]f32
v4 :: [4]f32

m3 :: matrix[3, 3]f32
m4 :: matrix[4, 4]f32

//odinfmt:disable
world_up  	:: v3{0.0, 1.0, 0.0}
world_fwd 	:: v3{0.0, 0.0, 1.0}
world_right :: v3{1.0, 0.0, 0.0}
//odinfmt:enable
