# Custom Arc UI — illenium-appearance 5.7.0

UI NUI bawaan (React bundle) diganti dengan UI baru bergaya "arc selector"
sesuai referensi screenshot.

## Yang berubah
- `web/dist/index.html` → ditulis ulang total (HTML + CSS + JS vanilla, satu file, tanpa build step).
- `web/dist/index.original.html.bak` → backup file asli. Untuk kembali ke UI lama:
  `mv index.original.html.bak index.html`
- File Lua: hanya 3 file disentuh, untuk fitur penagihan tattoo di bawah
  (`shared/config.lua`, `game/nui.lua`, `server/server.lua`) plus `game/customization.lua`
  untuk mengirim harga ke UI. Sisanya utuh.
  Semua callback NUI lama tetap dipakai persis:
  `appearance_get_locales`, `appearance_get_settings`, `appearance_get_data`,
  `appearance_change_model/component/prop/head_blend/face_feature/head_overlay/hair/eye_color`,
  `appearance_apply_tattoo`, `appearance_preview_tattoo`, `appearance_delete_tattoo`,
  `appearance_set_camera`, `appearance_rotate_camera`, `appearance_turn_around`,
  `rotate_left`, `rotate_right`, `appearance_save`, `appearance_exit`.
- Bundle React lama (`web/dist/assets/index.*.js`) dibiarkan di tempatnya, hanya tidak dipanggil lagi.

## Kontrol
| Aksi | Kontrol |
|---|---|
| Ganti nilai properti aktif | Scroll / ← → / klik angka di busur |
| Ganti properti kedua (Texture/Opacity) | Alt + Scroll |
| Pilih properti lain | Klik kotaknya di panel kanan, atau Q / E |
| Pindah baris | ↑ ↓ / klik baris di sidebar |
| Pindah tab | Tab / Shift+Tab / klik tab |
| Putar ped | **A** / **D** (sama seperti UI asli), atau ikon panah di toolbar |
| Balik badan 180° | Ikon putar di toolbar |
| Terapkan tattoo | Enter atau tombol APPLY (hover/scroll = preview) |
| Hapus tattoo terpasang | Klik chip kuning di panel kanan |
| Simpan | Enter (di luar tab Tattoos) atau tombol SAVE CUSTOMIZATION |
| Keluar | Esc atau tombol EXIT CUSTOMIZATION |

## Kustomisasi tampilan

Warna aksen ada di dua tempat dan keduanya harus diubah bersamaan:
1. `--accent` di blok `:root` (nilai hex)
2. Nilai `rgba(243, 179, 84, ...)` yang tersebar di CSS — ini versi transparan dari warna
   yang sama, dipakai untuk border, glow, dan latar kotak aktif. Ganti ketiga angka RGB-nya
   ke warna baru, biarkan angka alpha di belakang apa adanya.

Fungsi `accent()` di JS membaca `--accent` otomatis untuk mewarnai garis busur dan titiknya,
jadi bagian itu tidak perlu disentuh.
Semua di blok `:root` paling atas `index.html`:
- `--accent` → warna aksen (saat ini `#F3B354`)
- `--panel`, `--panel-line` → warna & garis panel
- `--radius`, `--font` → sudut & font

Bentuk busur diatur 4 konstanta di JS (cari `ARC_SLOTS`):
- `ARC_SLOTS` jumlah item di atas/bawah item terpilih (default 5)
- `ARC_GAP_VH` jarak vertikal antar item, dalam vh (default 5.2)
- `ARC_BOW_VH` kedalaman lengkungan, dalam vh (default 20)
- `ARC_K` kerapatan lengkungan (default 0.26)

Urutan baris pada tab Appearance ada di `OVERLAY_ORDER` (nama overlay + nama ikon).

## Catatan
- Tidak ada field **Fade** rambut: callback `appearance_change_hair` di Lua hanya menerima style/color/highlight/texture, jadi kalau Fade ditambahkan di UI dia tidak akan berefek apa pun.
- Bahasa UI tetap mengikuti `illenium-appearance:locale` (termasuk `id`), karena label diambil dari `locales/*.lua`.
- Blacklist drawable/texture per job/gang tetap dihormati (nilai yang diblokir dilewati saat scroll).
- Section yang dimatikan lewat `Config.DisableComponents` / `DisableProps` / `NewCharacterSections` otomatis tidak muncul.


## Kalau tampilannya beda saat dipasang di FiveM

**Panel terlihat solid, tidak transparan.**
Penyebabnya `backdrop-filter: blur()`. CEF (browser internal FiveM) sering menggambarnya
sebagai blok abu-abu solid, bukan blur. Properti itu sudah dibuang seluruhnya dari file ini,
jadi transparansi sekarang murni dari nilai alpha pada `--panel`. Mau lebih transparan lagi,
turunkan angka terakhirnya:

```css
--panel: rgba(12, 12, 12, .60);   /*  .60 -> .40 = lebih tembus pandang  */
```

**Semua kotak terasa lebih besar dibanding di preview.**
Ukuran UI memakai satuan `vh`, jadi dia ikut tinggi viewport NUI. Viewport itu belum tentu
sama dengan resolusi monitor: kalau Windows display scaling bukan 100%, atau game jalan di
resolusi non-standar, CEF memberi viewport lebih pendek sehingga semua elemen terlihat
membesar. Ini diatur dari satu baris:

```css
--ui-scale: 1;     /*  0.85 kalau kebesaran, 1.15 kalau kekecilan  */
```

Ubah nilainya, `restart illenium-appearance`, lihat hasilnya. Biasanya 0.8-0.9 pas untuk
display scaling 125-150%.

**Font terlihat lain dari preview.**
Rajdhani dan Inter ditarik dari Google Fonts. Kalau klien atau jaringannya memblokir
fonts.googleapis.com, browser jatuh ke font sistem yang metriknya lebih lebar, sehingga
teks dan baris ikut melebar. Solusinya: unduh kedua font, taruh di `web/dist/fonts/`,
daftarkan lewat `@font-face`, tambahkan foldernya ke blok `files` di `fxmanifest.lua`,
lalu hapus tag `<link>` ke Google Fonts.


## Tattoo: uang dipotong saat save, bukan saat apply

Aslinya `appearance_apply_tattoo` langsung memanggil `payForTattoo` setiap kali tombol APPLY
ditekan, dan uang itu **tidak dikembalikan** kalau tattoonya dilepas lagi. Jadi mencoba tiga
tattoo sebelum memilih satu berarti membayar tiga kali.

Sekarang ada opsi di `shared/config.lua`:

```lua
Config.ChargeTattoosOnSave = true   -- tagih sekali saat SAVE
                                    -- false = perilaku asli (tagih tiap APPLY)
```

Saat `true`:
- APPLY dan hapus sebanyak apa pun tidak memotong uang.
- Saat SAVE CUSTOMIZATION, server menghitung tattoo yang **ada di hasil akhir tapi belum ada
  sebelum sesi dimulai**, lalu memotong totalnya sekali lewat callback baru
  `illenium-appearance:server:payForTattoos`.
- Kalau uang tidak cukup: pemain dapat notifikasi, bagian tattoo dikembalikan ke kondisi awal,
  tapi perubahan lain (baju, rambut, wajah) tetap tersimpan.
- Keluar lewat EXIT CUSTOMIZATION = tidak ditagih sama sekali.

Perbandingan dilakukan sebagai multiset per (zona + nama tattoo), jadi tattoo sama yang
dipasang dua kali tetap dihitung dua, dan tattoo lama yang sudah dimiliki pemain tidak
ditagih ulang. Harga per tattoo tetap dari `Config.TattooCost`, atau key `cost` di
`shared/tattoos.lua` kalau tattoo itu punya harga sendiri.


## Harga tattoo di UI

Script aslinya tidak pernah mengirim harga ke NUI — `Config.TattooCost` hanya dipakai di
`lib.showTextUI` depan pintu toko dan header menu ox_lib, jadi begitu menu terbuka pemain
tidak tahu lagi harganya. Sekarang `getAppearanceSettings()` di `game/customization.lua`
ikut mengirim:

```lua
cost            = Config.TattooCost      -- harga default per tattoo
chargePerTattoo = Config.ChargePerTattoo
chargeOnSave    = Config.ChargeTattoosOnSave
```

Di UI muncul tiga tempat:
- **PRICE** di panel kanan, harga tattoo yang sedang disorot di busur
- **ON SAVE** di bawah daftar chip, total yang akan dipotong saat save — naik-turun otomatis
  saat pemain memasang atau melepas tattoo
- Baris biaya di modal konfirmasi save, misal `Tattoos: 2 × — $200`

Harga per tattoo bisa dibedakan dengan menambah key `cost` pada entri di `shared/tattoos.lua`:

```lua
{ name = "TAT_AR_000", label = "Turbulence", cost = 250, ... }
```

UI membaca `cost` itu kalau ada, kalau tidak jatuh ke `Config.TattooCost`. Kalau
`Config.ChargePerTattoo = false`, semua tampilan harga otomatis hilang.


## Catatan penting: bentuk payload tattoo

Tiga callback tattoo di `game/nui.lua` mengharapkan bentuk data yang BERBEDA. Salah satu
saja tertukar, `setTattoos()` di `game/util.lua` akan meng-iterasi string sebagai tabel dan
melempar `attempt to index a nil value (local 'tattoo')` di baris 267 — dan karena
`ClearPedDecorations()` sudah terlanjur jalan di awal fungsi itu, SEMUA tattoo di ped ikut
hilang.

| Callback | Payload yang benar |
|---|---|
| `appearance_apply_tattoo` | `{ tattoo = <1 tattoo>, updatedTattoos = <map lengkap> }` |
| `appearance_preview_tattoo` | `{ data = <map lengkap>, tattoo = <1 tattoo> }` |
| `appearance_delete_tattoo` | `<map lengkap setelah dihapus>` — **bukan** tattoo yang dihapus |

"Map lengkap" = objek berisi seluruh zona, contoh:
`{ ZONE_TORSO = [ ... ], ZONE_HEAD = [ ... ], ZONE_LEFT_ARM = [ ... ] }`

## Kalau tattoo hilang saat save

Kalau `Config.ChargeTattoosOnSave = true` dan pembayaran gagal (uang kurang, atau
`Framework.RemoveMoney` menolak), bagian tattoo dikembalikan ke kondisi awal sementara
perubahan lain tetap tersimpan. Selain notifikasi ke pemain, sekarang ada baris di console
client:

```
[illenium-appearance] pembayaran tattoo gagal, N tattoo dikembalikan ke kondisi awal
```

Kalau baris itu muncul, masalahnya di uang/framework, bukan di UI.


## Jebakan: map tattoo kosong dikirim sebagai `[]`

Saat pemain belum punya tattoo, `PED_TATTOOS` di Lua adalah tabel kosong, dan `json.encode`
mengubahnya jadi `[]` — yang di JavaScript menjadi **Array**, bukan Object. Menaruh properti
bernama pada Array tidak menimbulkan error:

```js
var t = [];              // dari Lua
t["ZONE_TORSO"] = [];
t["ZONE_TORSO"].push(tattoo);
t.ZONE_TORSO.length      // 1  -> terlihat benar
JSON.stringify(t)        // "[]" -> ISINYA HILANG saat dikirim balik
```

Inilah kenapa tattoo bisa "hilang saat apply" sekaligus "tidak tersimpan saat save":
payload-nya memang kosong, jadi `setTattoos()` menjalankan `ClearPedDecorations()` lalu
tidak memasang apa-apa.

Karena itu semua map tattoo di UI dilewatkan `tattooMap()` dulu supaya selalu jadi objek
biasa dengan seluruh zona terisi array, dan penyalinan memakai `cloneTattoos()`, bukan
`JSON.parse(JSON.stringify(...))` yang justru ikut membuang isinya.
