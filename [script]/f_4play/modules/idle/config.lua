-- Animasi idle: diputar saat pemain diam (tanpa input gerak) beberapa detik.
-- File animasi di stream/idle (move_m@ / move_f@generic_idles@std.ycd).
IdleConfig = {
    Delay = 8000,             -- ms diam sebelum animasi idle pertama
    Cooldown = { 6000, 12000 }, -- jeda acak (ms) antar animasi idle selama tetap diam
    SkipArmed = true,         -- tidak idle saat memegang senjata

    Male = { dict = 'move_m@generic_idles@std', clips = { 'idle_a', 'idle_b', 'idle_c', 'idle_d' } },
    Female = { dict = 'move_f@generic_idles@std', clips = { 'idle_a', 'idle_b', 'idle_c' } },
}
