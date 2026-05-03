package main

import k2 "karl2d"

_ :: k2

// game declaration :::

game: Game

Game :: struct {
    game_over           : bool,
    game_restart_timer  : f32,
    houses_destroyed    : int,
    zombies_killed      : int,

    movement_initial    : [2]bool,
    movement_state      : Movement_State,
    movement_delay_acc  : f32,
    player_tpos         : i32x2,

    selection_kind      : Selection_Kind,
    selection_index     : [Selection_Kind]int,
    selected_building   : ^Building,

    since_start         : f32,
    next_horde_spawn    : f32,
    spawn_amount        : int,
    acc_shake_mag       : f32,
    acc_shake_dir       : f32x2,
    acc_shake_offset    : f32x2,

    world               : [WORLD_WIDTH*WORLD_HEIGHT]Tile,
    flow_map            : [WORLD_WIDTH*WORLD_HEIGHT]f32x2,
    buildings           : map[i32x2]Building,
    horde               : [dynamic]Zombie,
    explosions          : [dynamic]Explosion,
    zombies_to_despawn  : [dynamic]int,
    explosions_to_remove: [dynamic]int,
    scanlines_to_remove : [dynamic]i32x2,
    other_scanlines     : [dynamic]i32x2,
    scanlines           : [dynamic]i32x2,
    playing_sounds      : [dynamic]k2.Sound,
    scanlines_anim      : Anim,

    tex                 : ^Game_Textures,
    snd                 : ^Game_Sounds,
}

Game_Textures :: struct {
    player   : k2.Texture,
    tiles    : k2.Texture,
    builds   : k2.Texture,
    scanline : k2.Texture,
    horde    : k2.Texture,
    explosion: k2.Texture,
}

Game_Sounds :: struct {
    artillery      : k2.Audio_Buffer,
    game_over      : k2.Audio_Buffer,
    house_destroyed: k2.Audio_Buffer,
    landmower_music: k2.Audio_Stream,
}

Movement_State :: enum {
    Slow,
    Fast,
}

Anim :: struct {
    acc  : f32,
    index: int,
}

Anim_Blueprint :: struct {
    size     : f32x2,
    offset   : int,
    frames   : int,
    threshold: f32,
}

Selection_Kind :: enum {
    None,
    Build,
    Building_Selected,
}

Tile :: struct {
    kind: Tile_Kind,
}

Tile_Kind :: enum {
    Empty,
    Alive,
    Barren,
    Rocks,
}

Building :: struct {
    kind            : Building_Kind,
    anim            : Anim,
    pos             : i32x2,
    play_anim       : bool,
    artillery_target: i32x2,
    artillery_cd    : f32,
}

Building_Kind :: enum {
    Ruins,
    House,
    Artillery,
}

Zombie :: struct {
    anim : Anim,
    pos  : f32x2,
    speed: f32,
}

Explosion :: struct {
    fuse    : f32,
    affected: bool,
    anim    : Anim,
    tpos    : i32x2,
    pos     : f32x2,
}

// game procs :::

anim_bp :: proc(offset, frames: int, threshold: f32, size := f32x2(16)) -> Anim_Blueprint {
    return { offset=offset, frames=frames, threshold=threshold, size=size }
}

tick_anim :: proc(anim_bp: Anim_Blueprint, anim: ^Anim) -> bool {
    anim.acc  += k2.get_frame_time()
    diff      := anim.acc - anim_bp.threshold
    increment := diff >= 0
   
    amount   := 1 if increment else 0
    anim.acc  = 0 if increment else anim.acc

    anim.index += amount
    anim.index = anim.index % anim_bp.frames
    return increment && anim.index == 0
}

draw_anim :: proc(texture: k2.Texture, anim_bp: Anim_Blueprint, anim: Anim, pos: f32x2) {
    draw_atlas(texture, anim_bp.offset + anim.index, pos, anim_bp.size)
}

draw_atlas :: proc(texture: k2.Texture, index: int, pos: f32x2, size := f32x2(16)) {
    x := f32(index)*(size.x+2) + 1
    source := Rect { x=x, y=1, w=size.x, h=size.y }
    k2.draw_texture_rect(texture, source, pos)
}

draw_tile :: proc(tile: Tile_Kind, pos: f32x2) {
    draw_atlas(game.tex.tiles, int(tile), pos)
}

tile_index :: proc(tpos: i32x2) -> int {
    return int(tpos.y*WORLD_WIDTH + tpos.x)
}

world_pos :: proc(tpos: i32x2) -> f32x2 {
    return f32x2 { f32(tpos.x)*16, f32(tpos.y)*16 }
}

world_pos_center :: proc(tpos: i32x2) -> f32x2 {
    return world_pos(tpos)+16/2
}

tile_pos :: proc(pos: f32x2) -> i32x2 {
    return i32x2 { i32((pos.x+8)/16), i32((pos.y+8)/16) }
}