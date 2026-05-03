package main

import k2 "karl2d"

// asset declarations :::



// asset procedures :::

load_texture :: proc($name: string) -> k2.Texture {
    filepath :: "../images/" + name + ".png"
    return k2.load_texture_from_bytes(#load(filepath))
}

load_sound :: proc($name: string) -> k2.Audio_Buffer {
    filepath :: "../sounds/" + name + ".wav"
    return k2.load_audio_buffer_from_bytes(#load(filepath))
}

load_music :: proc($name: string) -> k2.Audio_Stream {
    filepath :: "../sounds/" + name + ".ogg"
    return k2.load_audio_stream_from_bytes(#load(filepath))
}

_ :: k2
