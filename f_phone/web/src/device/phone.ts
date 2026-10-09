import type { DeviceProfile } from './types';

// f_phone: iPhone Duo (lipat buku). Tertutup 674x956, dibuka 1348x956 lewat configs/phone.lua
// FoldOpenWidth - dua "halaman" 674 berdampingan. Dengan bezel 14 bodinya 702x984 (tertutup) dan
// 1376x984 (terbuka): rasio sama dengan HP asli 84,1 x 117,8 mm dan 164,6 x 117,8 mm. Tinggi
// sengaja sama dengan sd-phone asli (956) supaya tidak ada aplikasi yang terpotong ke bawah.
// Bentuk frame (bezel, sudut, kamera, tombol) ada di shell 'ios' di shell/shells.ts.
export const device: DeviceProfile = {
    id:           'phone',
    rpcAction:    null,
    calls:        true,
    payphone:     true,
    admin:        true,
    setup:        true,
    // Game tidak dipakai di server ini: tidak tampil dan kodenya tidak pernah dimuat.
    excludedApps: [
        'wordle', 'flappy', 'blocks', 'minesweeper', 'casino',
        'climber', 'connectfour', 'chess', 'battleship', 'cookie',
    ],
    defaultAlign: 'bottom-right',
    // Slider 40 (default) x sizeFactor 0,807 = skala 0,517: Duo tertutup tampil ~363x509 px di
    // layar 1080p. Slider tersimpan di tabel phone_settings (sama dengan sd-phone), jadi pemain
    // yang pernah menggeser slider di sd-phone ikut menyesuaikan.
    defaultScale: 40,
    sizeFactor:   0.807,
    screen: {
        w:      674,
        h:      956,
        bezel:  14,
        radius: 88,
        island: false,
        buttons: [
            { side: 'top',   y: 90,  h: 70, role: 'volumeUp' },
            { side: 'top',   y: 175, h: 70, role: 'volumeDown' },
            { side: 'right', y: 130, h: 36, role: 'screenshot' },
            { side: 'right', y: 200, h: 80, role: 'power' },
            { side: 'right', y: 330, h: 56, role: 'fold' },
        ],
        // Dock vertikal di kolom kanan (124 px, grid.ts SIDE_DOCK_W), ikon 4 kolom di kirinya:
        // 32 + 3*134 + 84 + 32 = 550 = 674 - 124. Dibuka jadi 8 kolom (lihat grid.ts widen).
        grid: {
            cols:      4,
            rows:      6,
            padX:      32,
            icon:      84,
            colStride: 134,
            rowY0:     8,
            rowStride: 128,
            stripTop:  70,
        },
        densities: {
            compact: { cols: 5, rows: 7, padX: 24, icon: 62 },
            large:   { cols: 3, rows: 5, padX: 36, icon: 96 },
        },
    },
};
