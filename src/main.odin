package main

import "core:fmt"

import k2 "karl2d"

// constants :::

NAME :: "karljam"

PIXEL_WIDTH   :: 320
PIXEL_HEIGHT  :: 240

SCREEN_WIDTH  :: PIXEL_WIDTH*4
SCREEN_HEIGHT :: PIXEL_HEIGHT*4

WORLD_WIDTH   :: 128
WORLD_HEIGHT  :: 64

// lifecycle hooks :::

main :: proc() {
    init()
    for step() {}
    shutdown()
}

shutdown :: proc() {
    k2.shutdown()
}

step :: proc() -> bool {
    if !k2.update() do return false

    k2.clear(k2.BLACK)
    update()
    k2.present()
    k2.update_audio_stream(game.snd.landmower_music)
    free_all(context.temp_allocator)

    return true
}

// redeclarations :::

print  :: fmt.println
printf :: fmt.printfln

f32x2      :: k2.Vec2
f32x3      :: k2.Vec3
f32x4      :: k2.Vec4
i32x2      :: [2]i32
f32mat4x4  :: k2.Mat4
Rect       :: k2.Rect

_ :: k2
