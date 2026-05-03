package main

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import k2 "karl2d"

// update proc :::

update :: proc() {
    dt := k2.get_frame_time()
    defer if !game.game_over do game.since_start += dt

    print_frame: {
        if true do break print_frame
        print(1/dt)
    }

    // inputs :::

    input_move_left  := k2.key_is_held(.A) || k2.key_is_held(.Left)
    input_move_right := k2.key_is_held(.D) || k2.key_is_held(.Right)
    input_move_up    := k2.key_is_held(.W) || k2.key_is_held(.Up)
    input_move_down  := k2.key_is_held(.S) || k2.key_is_held(.Down)

    input_select           := k2.key_went_down(.Space) || k2.key_went_down(.Enter)
    input_cancel_selection := k2.key_went_down(.Escape)

    if game.game_over {
        game.game_restart_timer += dt
        if game.game_restart_timer >= 10 {
            // TODO: use pool and init in init
            delete(game.buildings)
            delete(game.horde)
            delete(game.explosions)
            delete(game.zombies_to_despawn)
            delete(game.explosions_to_remove)
            delete(game.scanlines_to_remove)
            delete(game.other_scanlines)
            delete(game.scanlines)
            for sound in game.playing_sounds {
                k2.destroy_sound(sound)
            }
            delete(game.playing_sounds)
            tex := game.tex
            snd := game.snd
            game = {}
            game.tex = tex
            game.snd = snd
            game_init()
        }
    }

    // anims :::

    ruins_anim_bp     := anim_bp(offset=0, frames=1, threshold=f32(32))
    house_anim_bp     := anim_bp(offset=1, frames=1, threshold=f32(32))
    artillery_anim_bp := anim_bp(offset=2, frames=4, threshold=f32(1)/8)
    scanline_anim_bp  := anim_bp(offset=2, frames=4, threshold=f32(1)/6)
    horde_anim_bp     := anim_bp(offset=0, frames=3, threshold=f32(1)/4, size={ 4, 7 })
    explosion_anim_bp := anim_bp(offset=0, frames=3, threshold=f32(1)/8)

    // cleanup :::

    clear(&game.zombies_to_despawn)
    clear(&game.explosions_to_remove)

    clear(&game.scanlines_to_remove)
    clear(&game.other_scanlines)
    clear(&game.scanlines)

    #reverse for sound, i in game.playing_sounds {
        if !k2.sound_is_playing(sound) {
            k2.destroy_sound(sound)
            unordered_remove(&game.playing_sounds, i)        
        }
    } 

    // game over condition :::
    if game.houses_destroyed  >= 4 && !game.game_over {
        game.game_over = true
        for sound in game.playing_sounds {
            k2.set_sound_volume(sound, 0.01)
        }

        k2.set_audio_stream_volume(game.snd.landmower_music, 0.05)

        sound := k2.create_sound_from_audio_buffer(game.snd.game_over)
        append(&game.playing_sounds, sound)
        k2.play_sound(sound)
    }

    // horde spawn :::
    horde_spawn: {
        next_next_horde_spawn: f32
        if game.since_start >= 360 {
            game.spawn_amount = 24
            next_next_horde_spawn = 1.5            
        } else if game.since_start >= 180 {
            game.spawn_amount = 18
            next_next_horde_spawn = 2            
        } else if game.since_start >= 120 {
            game.spawn_amount = 12
            next_next_horde_spawn = 2.5            
        } else if game.since_start >= 60 {
            game.spawn_amount = 5
            next_next_horde_spawn = 4
        } else {
            game.spawn_amount = 3
            next_next_horde_spawn = 5
        }
    
        game.next_horde_spawn -= dt
        if game.next_horde_spawn <= 0 {
            game.next_horde_spawn += next_next_horde_spawn
            for i in 0..<game.spawn_amount {
                x := rand.float32_range(45*16, 60*16)
                y := rand.float32_range(25*16.5, (WORLD_HEIGHT-25.5)*16)
                speed := rand.float32_range(2.5, 3.5)
                append(&game.horde, Zombie { pos={ x, y }, anim={ index=i % horde_anim_bp.frames }, speed=speed })
            }
        }
    }

    // player movement :::
    player_movement: if !game.game_over {
        movement: i32x2
        if input_move_left {
            movement.x -= 1
        }
        if input_move_right {
            movement.x += 1
        }
        if input_move_up {
            movement.y -= 1
        }
        if input_move_down {
            movement.y += 1
        }

        for i in 0..<2 {
            if movement[i] != 0 && !game.movement_initial[i] {
                game.player_tpos[i] += movement[i]
                game.movement_initial[i] = true                
            }
        }

        if movement != {} {
            threshold: f32
            next_state: Movement_State
            switch game.movement_state {
            case .Slow:
                next_state = .Fast
                threshold = 1.0/3
            case .Fast:
                next_state = .Fast
                threshold = 1.0/30
            }

            if game.movement_delay_acc >= threshold {
                game.player_tpos += movement
                game.movement_delay_acc = 0
                game.movement_state = next_state
            }

            game.movement_delay_acc += dt
        } else {
            game.movement_delay_acc = 0 
            game.movement_state = .Slow
            game.movement_initial = {}
        }
        game.player_tpos.x = clamp(game.player_tpos.x, 25, 52)
        game.player_tpos.y = clamp(game.player_tpos.y, 26, 38)
    }

    // camera :::

    game.acc_shake_offset *= 0.9
    game.acc_shake_offset += game.acc_shake_dir * game.acc_shake_mag
    game.acc_shake_mag = max(game.acc_shake_mag-dt, 0)

    camera := k2.Camera {
        zoom   = f32(k2.get_screen_height()) / PIXEL_HEIGHT,
        target = world_pos_center(game.player_tpos),
        offset = k2.get_screen_size()/2 + game.acc_shake_offset*0.2
    }

    k2.set_camera(camera)
    k2.set_scissor_rect(nil)

    // selection :::

    if !game.game_over && input_select {
        switch game.selection_kind {
        case .None:
            building := &game.buildings[game.player_tpos]
            if building != nil {
                switch building.kind {
                case .Ruins, .House:
                case .Artillery:
                    game.selection_kind = .Building_Selected
                    game.selected_building = building
                }
            }
        case .Build:
        case .Building_Selected:
            switch game.selected_building.kind {
            case .Ruins, .House:
            case .Artillery:
                game.selected_building.artillery_target = game.player_tpos
                input_cancel_selection = true
            }
        }
    }
    
    if !game.game_over && input_cancel_selection {
        game.selection_kind = .None
        game.selected_building = nil
    }

    if game.selection_kind == .Building_Selected && game.selected_building.kind == .Artillery {
        if game.selected_building.artillery_target != {} {
            for y in i32(-2)..=2 {
                for x in i32(-2)..=2 {
                    append(&game.scanlines_to_remove, game.selected_building.artillery_target + i32x2{ x, y })
                }
            }
        }
        for y in i32(-2)..=2 {
            for x in i32(-2)..=2 {
                append(&game.scanlines, game.player_tpos + i32x2{ x, y })
            }
        }
    }

    // handle buildings :::
    for _, &building in game.buildings {
        if game.selection_kind == .Building_Selected && building.artillery_target != {} {
            for y in i32(-2)..=2 {
                for x in i32(-2)..=2 {
                    append(&game.other_scanlines, building.artillery_target + i32x2{ x, y })
                }
            }
        }
        switch building.kind {
        case .Ruins, .House:
        case .Artillery:
            if building.artillery_target == {} do continue
            if building.artillery_cd >= 1 {
                x := rand.int32_range(-2, 3)
                y := rand.int32_range(-2, 3)
                building.artillery_cd -= 2 + rand.float32()*2
                target := building.artillery_target-{ x, y }
                append(&game.explosions, Explosion { fuse=artillery_anim_bp.threshold*2.5, pos=world_pos_center(target), tpos=target })
                sound := k2.create_sound_from_audio_buffer(game.snd.artillery)
                k2.play_sound(sound)
                k2.set_sound_pitch(sound, rand.float32_range(0.9, 1.1))
                if !game.game_over {
                    k2.set_sound_volume(sound, rand.float32_range(0.2, 0.35))
                } else {
                    k2.set_sound_volume(sound, 0.01)                
                }
                append(&game.playing_sounds, sound)
                building.play_anim = true
            }
            if building.play_anim {
                if tick_anim(artillery_anim_bp, &building.anim) {
                    building.play_anim = false
                }
            }
            building.artillery_cd += dt
        }
    }

    // handle horde :::
    for &zombie, zombie_i in game.horde {
        tick_anim(horde_anim_bp, &zombie.anim)
        tpos := tile_pos(zombie.pos)
        dir := game.flow_map[tile_index(tpos)]
        zombie.pos += dir * dt * zombie.speed
        building := &game.buildings[tpos]
        if building != nil && (building.kind == .House || building.kind == .Ruins)  {
            if (building.kind == .House) {
                game.houses_destroyed += 1
                sound := k2.create_sound_from_audio_buffer(game.snd.house_destroyed)
                k2.play_sound(sound)
                if game.game_over {
                    k2.set_sound_volume(sound, 0.01)                
                }
                append(&game.playing_sounds, sound)
            }
            building.kind = .Ruins
            append(&game.zombies_to_despawn, zombie_i)
        }
    }

    // handle explosions :::
    for &explosion, explosion_i in game.explosions {
        explosion.fuse -= dt
        if !explosion.affected && explosion.fuse <= 0 {
            game.acc_shake_mag = min(game.acc_shake_mag + 1, 2)
            shake_x := rand.float32_range(-1, 1)
            game.acc_shake_dir = f32x2{ shake_x, 1-shake_x }
            explosion.affected = true
            target_building := &game.buildings[explosion.tpos]
            if target_building != nil && target_building.kind == .House {
                target_building.kind = .Ruins
                game.houses_destroyed += 1
                sound := k2.create_sound_from_audio_buffer(game.snd.house_destroyed)
                k2.play_sound(sound)
                if game.game_over {
                    k2.set_sound_volume(sound, 0.01)                
                }
                append(&game.playing_sounds, sound)

            }
            for &zombie, zombie_i in game.horde {
                if linalg.length2(explosion.pos - zombie.pos) <= 16*16 {
                    append(&game.zombies_to_despawn, zombie_i)
                    if !game.game_over {
                        game.zombies_killed += 1
                    }
                }
            }
        }
        if explosion.affected && tick_anim(explosion_anim_bp, &explosion.anim) {
            append(&game.explosions_to_remove, explosion_i)            
        }
    }

    // remove explosions :::
    #reverse for i in game.explosions_to_remove {
        ordered_remove(&game.explosions, i)
    }

    // remove zombies :::
    #reverse for i in game.zombies_to_despawn {
        unordered_remove(&game.horde, i)
    }

    tick_anim(scanline_anim_bp, &game.scanlines_anim)

    // draw world :::
    draw_world: {
        i: int
        x, y: f32
        
        for _ in 0..<WORLD_HEIGHT {
            for _ in 0..<WORLD_WIDTH {
                tile := game.world[i]
                draw_tile(tile.kind, { x, y })
                x += 16
                i += 1
            }
            y += 16
            x = 0
        }
    }

    // draw scanlines :::
    draw_scanlines: {
        for tpos in game.other_scanlines {
            draw_atlas(game.tex.scanline, 1, world_pos(tpos))
        }
        for tpos in game.scanlines_to_remove {
            draw_atlas(game.tex.scanline, 0, world_pos(tpos))
        }
        for tpos in game.scanlines {
            draw_anim(game.tex.scanline, scanline_anim_bp, game.scanlines_anim, world_pos(tpos))
        }
    }

    // draw buildings :::
    draw_buildings: {
        for _, building in game.buildings {
            bp: Anim_Blueprint
            switch building.kind {
            case .Ruins    : bp = ruins_anim_bp
            case .House    : bp = house_anim_bp
            case .Artillery: bp = artillery_anim_bp
            }
            draw_anim(game.tex.builds, bp, building.anim, world_pos(building.pos))
        }
    }

    // draw horde :::
    draw_horde: {
        for zombie in game.horde {
            draw_anim(game.tex.horde, horde_anim_bp, zombie.anim, zombie.pos)
        }
    }

    // draw explosions :::
    draw_explosions: {
        for explosion in game.explosions {
            if explosion.affected {
                draw_anim(game.tex.explosion, explosion_anim_bp, explosion.anim, explosion.pos-{8, 8})            
            }
        }
    }

    // draw player :::
    draw_player: {
        draw_atlas(game.tex.player, int(game.selection_kind), world_pos(game.player_tpos))
    }

    debug_flow: {
        if true do break debug_flow
        for y in i32(0)..<WORLD_HEIGHT {
            for x in i32(0)..<WORLD_WIDTH {
                center := world_pos_center({x, y})
                tail := center + game.flow_map[tile_index({x, y})]*1
                head := center + game.flow_map[tile_index({x, y})]*5
                k2.draw_line(center, head, 0.5, k2.GREEN)
                k2.draw_line(center, tail, 1, k2.RED)
            }   
        }
    }

    // draw ui :::
    draw_ui: {
        k2.set_camera(nil)

        text_center :: proc(text: string, height: f32, font_size: f32) {
            k2.draw_text(text, f32x2 { (SCREEN_WIDTH-k2.measure_text(text, font_size).x)/2, height }, font_size, { 195, 195, 195, 255 })
        }

        if game.game_over {
                k2.draw_rect({ x=256, y=256, w=SCREEN_WIDTH-512, h=SCREEN_HEIGHT-512 }, { 0, 0, 0, 200 })
                k2.draw_rect_outline({ x=256, y=256, w=SCREEN_WIDTH-512, h=SCREEN_HEIGHT-512 }, 4, { 90, 90, 90, 255 })

                cursor_y := f32(280)
                text_center("Game Over", cursor_y, 32)
                cursor_y += 32+16
                text_center(fmt.tprintf("Zombies disinfected: %v", game.zombies_killed), cursor_y, 24)
                cursor_y += 24+6
                text_center(fmt.tprintf("Survived for: %f", game.since_start), cursor_y, 24)
                cursor_y += 24+16
                text_center(fmt.tprintf("Will restart in: %f", 10-game.game_restart_timer), cursor_y, 24)

        } else {
            houses_destroyed_str := fmt.tprintf("Lost houses: %v/%v", game.houses_destroyed, 4)
            k2.draw_text(houses_destroyed_str, {SCREEN_WIDTH-k2.measure_text(houses_destroyed_str, 32).x-16, 16}, 32, k2.WHITE)
            k2.draw_text(fmt.tprintf("Zombies disinfected: %v", game.zombies_killed), {16, 16}, 32, k2.WHITE)
            show_fps: {
                if true do break show_fps
                k2.draw_text(fmt.tprintf("FPS: %f", 1/dt), { 16, SCREEN_HEIGHT-48 }, 32, k2.WHITE)            
            }
        }
    }
}
