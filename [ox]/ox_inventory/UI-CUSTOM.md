# Custom UI — ox_inventory 2.47.9

Tampilan inventory dirombak mengikuti desain referensi: panel dengan ikon + nama pemain,
slot gelap membulat, kolom tengah berisi logo + jumlah + USE/GIVE, tombol close di pojok
kanan atas, dan weight bar bersegmen di bawah tiap panel.

Folder `web/build` sudah berisi hasil build, jadi resource ini bisa langsung dipakai
(tidak perlu `npm install` kecuali kamu mau mengubah UI lagi).

## Ganti logo (saat ini masih dummy)

`web/src/components/utils/icons/InventoryIcons.tsx`

```ts
const LOGO_URL = ''; // kosong = pakai mark placeholder "LOGO"
```

Isi dengan salah satu:

- `const LOGO_URL = 'images/logo.png';` — taruh file `logo.png` di `web/images/`
  (folder itu sudah ikut di `fxmanifest.lua` lewat `web/images/*.png`).
- `const LOGO_URL = 'https://cdn-kamu.com/logo.png';` — logo dari CDN.

Lalu build ulang: `cd web && npm install --legacy-peer-deps && npm run build`.

## Nama pemain di header

Header kiri memakai `label` yang dikirim server (biasanya nama karakter). Kalau framework
tidak mengisinya, `Utils.getCharacterName()` jatuh ke `GetPlayerName()`. Mau pakai sumber
nama sendiri (mis. `firstname lastname` dari framework), panggil sekali di resource lain:

```lua
exports.ox_inventory:setCharacterNameMethod(function()
    local data = exports.qbx_core:GetPlayerData()
    return ('%s %s'):format(data.charinfo.firstname, data.charinfo.lastname)
end)
```

## Ubah warna & ukuran

`web/src/index.scss` bagian paling atas:

| Variabel | Fungsi |
| --- | --- |
| `$accent`, `$accentBright`, `$accentDeep` | warna aksen (#f3b354, ikon, tombol close, weight bar, durability) |
| `$slotColor`, `$slotBorder` | warna slot |
| `$gridCols`, `$gridRows` | jumlah kolom & baris yang terlihat (sisanya scroll) |
| `$gridSize`, `$gridGap` | ukuran slot dan jarak antar slot (satuan `vh`) |
| `$mainFont` | font (default Poppins, dimuat di `web/index.html`) |
| `$uiScale` | **ukuran keseluruhan UI**. 1 = versi besar awal, 0.82 = sekarang, 0.5 = setengah |
| `$textScale` | ukuran huruf (0.78 sekarang) — naikkan kalau teks terasa kekecilan |

Cukup ubah `$uiScale` lalu build ulang; semua panel, slot, tombol, logo, dan hotbar ikut
menyesuaikan.

## Fokus saat inventory dibuka

Blur layar game bawaan ox (`TriggerScreenblurFadeIn`) **dimatikan secara default** karena
efek post-process itu memakan GPU di PC kelas bawah. Nyalakan lagi kalau mau:

```
setr inventory:screenblur true
```

Tidak ada layer peredup di UI. Sebagai gantinya, semua teks duduk di atas panel gelap
sendiri (`$panelPlate`) supaya tetap terbaca di siang hari: header (ikon, nama, deskripsi,
dan berat), header hotbar, dan tombol close. Atur di `web/src/index.scss`:

```scss
$panelPlate: rgba(14, 17, 19, 0.93); /* naikkan ke 1 kalau mau benar-benar pekat */
$slotColor: rgba(20, 23, 26, 0.84);  /* kepekatan slot */
```

## Hotbar (quick action 1-5)

Quick action punya slotnya sendiri, terpisah dari 5 slot pertama inventory. Yang dipakai
adalah **5 slot terakhir** inventory pemain (default: slot 46-50 dari 50):

- Slot itu disembunyikan dari grid inventory, jadi hanya bisa diisi dengan cara menyeret
  item ke bar bawah. Mengisi slot mana pun di grid tidak lagi mengubah isi quick action.
- Item hasil pickup / `addItem` tidak pernah masuk ke slot ini (`Inventory.GetEmptySlot`
  dan `GetSlotForItem` di `modules/inventory/server.lua` melewatinya), begitu juga
  fast-move ctrl+klik.
- Karena slot ini tetap bagian dari inventory pemain, isinya ikut tersimpan ke database
  seperti biasa — tidak ada penyimpanan tambahan.
- Tombol 1-5 memakai slot tersebut (`client.lua`, keybind `hotkey1`-`hotkey5`).
- Alt + klik pada slot hotbar langsung memakai itemnya; item bisa diseret keluar kembali
  ke inventory.

Jumlah slotnya diatur convar: `setr inventory:hotbarslots 5` (0 = matikan, slot kembali
semua ke grid). Nilainya dikirim ke UI saat init dan dipakai oleh `store/hotbar.ts`.

Hotbar tampil sebagai barisan slot saja, tanpa judul atau ikon. Saat inventory dibuka ia
ikut tampil (tidak hilang setelah 3 detik) lewat prop `alwaysVisible` di
`components/inventory/index.tsx`. Posisinya diatur `.hotbar-wrapper.is-docked
{ bottom: 13vh; }` (saat inventory terbuka) dan `.hotbar-wrapper { bottom: 3vh; }`
(saat hanya di-toggle), ditambah `padding-bottom` pada `.inventory-wrapper` di
`index.scss`.

Tombol close berada di atas panel kanan (GROUND), rata kanan mengikuti lebar panel —
lihat `.inventory-panel-topbar` di `index.scss`.

## Header panel

Satu baris berisi: ikon, nama + keterangan singkat, lalu berat di kanan (angka kg dan
progress bar pendek, tanpa tulisan "WEIGHT"). Footer berat yang dulu di bawah grid sudah
dihapus. Lebar blok beratnya diatur `.inventory-panel-weight { width: 19vh * $uiScale; }`,
jumlah tick-nya lewat prop `segments` pada `<WeightBar />` (default 24).

Keterangan di bawah nama panel:

- Inventory pemain, toko, crafting, pemain lain → teks locale (`ui_player_description`, dst)
- Ground dan stash/bagasi → **id inventory** (mis. `drop-482913`), karena lebih berguna
  untuk identifikasi; kalau id kosong baru memakai teks locale.

## Teks panel

Semua teks memakai locale, jadi bisa diubah tanpa menyentuh kode — lihat key baru di
`locales/en.json` dan `locales/id.json`:

`ui_inventory`, `ui_weight`, `ui_ground`, `ui_player`, `ui_shop`, `ui_crafting`,
`ui_storage`, `ui_player_inventory`, `ui_player_description`, `ui_ground_description`,
`ui_otherplayer_description`, `ui_shop_description`, `ui_crafting_description`,
`ui_storage_description`.

Bahasa lain (de, fr, dll) belum punya key ini dan otomatis memakai teks bawaan Inggris.

## File yang diubah / ditambah

```
client.lua                                        label inventory kiri = nama karakter, keybind 1-5 -> slot hotbar
init.lua                                          shared.hotbarslots / shared.firsthotbarslot
modules/inventory/server.lua                      slot hotbar tidak diisi otomatis
modules/utils/client.lua                          Utils.getCharacterName + export override
locales/en.json, locales/id.json                  key UI baru
web/index.html                                    font Poppins
web/src/index.scss                                tema baru (seluruh tampilan)
web/src/App.tsx                                   data dummy untuk preview di browser (dev only)
web/src/components/inventory/InventoryGrid.tsx    header panel + footer weight
web/src/components/inventory/LeftInventory.tsx    prop side
web/src/components/inventory/RightInventory.tsx   prop side
web/src/components/inventory/InventoryControl.tsx logo + input + USE/GIVE
web/src/components/inventory/CloseButton.tsx      (baru) tombol close pojok kanan atas
web/src/components/inventory/InventoryHotbar.tsx  header hotbar + badge tombol 1-5
web/src/components/inventory/index.tsx            memasang CloseButton
web/src/components/utils/WeightBar.tsx            mode segmented + warna durability teal
web/src/components/utils/icons/InventoryIcons.tsx (baru) ikon panel, close, logo dummy
web/src/store/hotbar.ts                           (baru) jumlah slot quick action
web/src/dnd/onDrop.ts                             fast-move melewati slot quick action
web/build/*                                       hasil build terbaru
```

Logika inventory (drag & drop, hotbar, shop, crafting, context menu, tooltip) tidak diubah.
