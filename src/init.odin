package main

import k2 "karl2d"

init :: proc() {
    k2.init(SCREEN_WIDTH, SCREEN_HEIGHT, NAME, options={ window_mode=.Windowed_Resizable })

    game.tex = new(Game_Textures)
    game.tex.player    = load_texture("player")
    game.tex.tiles     = load_texture("tiles")
    game.tex.builds    = load_texture("builds")
    game.tex.scanline  = load_texture("scanline")
    game.tex.horde     = load_texture("horde")
    game.tex.explosion = load_texture("explosion")

    game.snd = new(Game_Sounds)
    game.snd.artillery       = load_sound("artillery")
    game.snd.game_over       = load_sound("game_over")
    game.snd.house_destroyed = load_sound("house_destroyed")
    game.snd.landmower_music = load_music("landmower")

    game_init()
}

game_init :: proc() {
    k2.play_audio_stream(game.snd.landmower_music)
    k2.set_audio_stream_volume(game.snd.landmower_music, 0.5)
    k2.set_audio_stream_loop(game.snd.landmower_music, true)

    for &tile in game.world {
        tile.kind = .Barren
    }

    center           := i32x2{ WORLD_WIDTH/4, WORLD_HEIGHT/2 }
    base_size        := i32x2{ 16, 15 }
    base_start       := center - base_size/2
    base_end         := center + base_size/2
    base_start_index := tile_index(base_start)
    base_end_index   := base_start_index + int(WORLD_WIDTH*(base_size.y-1))

    game.player_tpos = center

    // initialize left of flow map and mountain range :::
    for y in i32(0)..<WORLD_HEIGHT {
        for x in i32(0)..<base_end.x {
            index := tile_index({ x, y })
            game.world[index].kind = .Rocks
            game.flow_map[index]   = f32x2{ 1, 0 }
        }
    }

    // initialize right top of flow map :::
    for y in i32(0)..=base_start.y {
        for x in base_end.x..=WORLD_WIDTH {
            game.flow_map[tile_index({ x, y })] = f32x2{ 0, 1 }
        }
    }

    // initialize right bottom of flow map :::
    for y in base_end.y..<WORLD_HEIGHT {
        for x in base_end.x..<WORLD_WIDTH {
            game.flow_map[tile_index({ x, y })] = f32x2{ 0, -1 }
        }
    }
    
    // initialize right center of flow map :::
    for y in (base_start.y + 1)..<base_end.y {
        for x in base_end.x..<WORLD_WIDTH {
            game.flow_map[tile_index({ x, y })] = f32x2{ -1, 0 }
        }
    }

    // initialize base walls :::
    for i in 0..<int(base_size.x) {
        game.world[base_start_index+i].kind = .Rocks
        game.world[base_end_index+i].kind = .Rocks
    }

    for i in 0..<int(base_size.y) {
        game.world[base_start_index + WORLD_WIDTH*i].kind = .Rocks
    }

    // initialize base center :::
    for y in i32(1)..<(base_size.y-1) {
        for x in i32(1)..<base_size.x {
            index := tile_index(base_start+i32x2{x, y})
            game.world[index].kind = .Alive
            game.flow_map[index] = f32x2 { -1, 0 }
        }    
    }

    game.buildings[{28, 32-6}] = Building { kind=.Artillery, pos={28, 32-6} }
    game.buildings[{28, 32-3}] = Building { kind=.Artillery, pos={28, 32-3} }
    game.buildings[{28, 32-0}] = Building { kind=.Artillery, pos={28, 32-0} }
    game.buildings[{28, 32+3}] = Building { kind=.Artillery, pos={28, 32+3} }
    game.buildings[{28, 32+6}] = Building { kind=.Artillery, pos={28, 32+6} }

    game.buildings[{26, 32-5}] = Building { kind=.Artillery, pos={26, 32-5} }
    game.buildings[{26, 32-2}] = Building { kind=.Artillery, pos={26, 32-2} }
    game.buildings[{26, 32+2}] = Building { kind=.Artillery, pos={26, 32+2} }
    game.buildings[{26, 32+5}] = Building { kind=.Artillery, pos={26, 32+5} }

    game.buildings[{31, 32-6}] = Building { kind=.House, pos={31, 32-6} }
    game.buildings[{31, 32-5}] = Building { kind=.House, pos={31, 32-5} }
    game.buildings[{31, 32-4}] = Building { kind=.House, pos={31, 32-4} }
    game.buildings[{31, 32-3}] = Building { kind=.House, pos={31, 32-3} }
    game.buildings[{31, 32-2}] = Building { kind=.House, pos={31, 32-2} }
    game.buildings[{31, 32-1}] = Building { kind=.House, pos={31, 32-1} }
    game.buildings[{31, 32-0}] = Building { kind=.House, pos={31, 32-0} }
    game.buildings[{31, 32+1}] = Building { kind=.House, pos={31, 32+1} }
    game.buildings[{31, 32+2}] = Building { kind=.House, pos={31, 32+2} }
    game.buildings[{31, 32+3}] = Building { kind=.House, pos={31, 32+3} }
    game.buildings[{31, 32+4}] = Building { kind=.House, pos={31, 32+4} }
    game.buildings[{31, 32+5}] = Building { kind=.House, pos={31, 32+5} }
    game.buildings[{31, 32+6}] = Building { kind=.House, pos={31, 32+6} }
}
