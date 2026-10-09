# f_chat

Chat berbasis channel untuk server roleplay. Dibuat standalone, dengan bridge otomatis ke
**QBox (qbx_core)**, QBCore, dan ESX untuk pengecekan job, grade, dan staff.

Resource ini menggantikan resource `chat` bawaan (`provide 'chat'`), dan tetap melayani
event lama `chat:addMessage`, `chat:addSuggestion`, `chat:clear`, sehingga script lain
yang mengirim pesan ke chat tetap jalan tanpa diubah.

---

## Pasang

1. Letakkan folder ini di `resources/[local]/f_chat` (atau folder mana pun yang kamu pakai).
2. Di `server.cfg`, **matikan chat bawaan lalu jalankan yang ini**:

   ```cfg
   # ensure chat          <- beri komentar / hapus
   ensure f_chat
   ```

   Kalau `chat` ikut dijalankan lewat `[cfx-default]`, biarkan saja — `provide 'chat'`
   membuat f_chat mengambil alih. Yang penting f_chat dijalankan **setelah** `qbx_core`.

3. Beri izin staff lewat ACE:

   ```cfg
   add_ace group.admin nxchat.staff allow
   add_principal identifier.license:xxxxxxxx group.admin
   ```

4. Restart server. Tekan **T** untuk membuka chat, **Z** untuk langsung ke OOC.

---

## Kompatibilitas QBox

| Yang dibaca | Dari mana |
|---|---|
| Nama karakter | `exports.qbx_core:GetPlayer(src).PlayerData.charinfo` |
| Job & grade | `PlayerData.job.name`, `PlayerData.job.grade.level` |
| Staff | ACE `nxchat.staff`, `group.admin`, atau `exports.qbx_core:HasPermission` |
| Update job | event `qbx_core:client:onJobUpdate` → daftar channel di-refresh otomatis |

Semua akses framework dibungkus `pcall`, jadi kalau `qbx_core` belum siap saat start,
resource tidak crash — hanya jatuh ke mode standalone sampai player pertama masuk.

---

## Channel

Semua channel didefinisikan di `config.lua`. Tambah channel baru = tambah satu tabel;
command, alias, warna, ikon, radius, dan izinnya langsung terdaftar saat restart.

```lua
{
    id         = 'taxi',
    label      = 'Taxi radio',
    tag        = 'TAXI',
    command    = 'taxi',
    aliases    = { 'tx' },
    color      = '#E6C34A',
    icon       = 'radio',
    radius     = nil,                    -- nil = seluruh server
    webhook    = 'https://discord.com/api/webhooks/...',
    permission = { type = 'grade', jobs = { 'taxi' }, minGrade = 2 },
}
```

`permission.type` yang tersedia: `open`, `job`, `grade`, `staff`, `ace`.
Tambahkan `staffOnlyView = true` agar hanya pengirim dan staff yang melihat (dipakai `/report`).

Ikon yang sudah ada: `speech`, `globe`, `hand`, `eye`, `dice`, `radio`, `shield`,
`megaphone`, `flag`, `info`. Menambah ikon baru cukup menambahkan satu entri path SVG di
`ICONS` pada `html/app.js`.

---

## Yang sudah jalan

- Channel tanpa batas, dengan command, warna, ikon, radius suara, dan izin per channel
- Chat lokal jadi default — ketik langsung tanpa perintah, tidak perlu `/local`
- Dua tab di atas pesan: **Global** (local, try, dispatch, staff, ads, announce, report) dan **OOC**
- `/announce` — staff yang sedang punya job aktif, pengumuman ke seluruh server, tag & warna ikut job
  (police biru, ambulance/ems merah, cafe hijau, job lain warna default). Jeda 20 detik per pemain.
- `/announceadmin` — staff tanpa perlu job, selalu tampil sebagai "Admin Announcement" warna ungu
- Tema + pemilih warna aksen bebas, sudut, kerapatan, ukuran, sisi layar, font — tersimpan per pemain (KVP)
- Reaksi emoji, mention `@nama` dengan sorotan, indikator mengetik, slow mode
- Bubble 3D di atas kepala untuk `/try`. `/me` dan `/do` sengaja **tidak ada** di f_chat — keduanya ditangani resource `sd-3dme` (bubble 3D saja, tidak masuk chat)
- Moderasi staff: hapus, edit, mute (`/mute [id] [menit]`, `/unmute [id]`)
- Badge pemain (`/tag [id] [label] [hex]`)
- Pesan otomatis terjadwal, log Discord per channel, filter kata
- Autocomplete `/` yang juga menampung suggestion dari resource lain

## Yang belum ada

- Pencarian GIF (butuh API key Giphy/Tenor)
- Foto layar dalam game (butuh `screenshot-basic`)
- Penyimpanan riwayat chat ke database — sekarang riwayat hanya di memori server

---

## Untuk script lain

```lua
-- dari sisi server
exports.f_chat:SendMessage(source, 'staff', 'Pesan dari script lain')

-- cara lama tetap bekerja
TriggerClientEvent('chat:addMessage', source, {
    color = { 224, 164, 88 },
    args  = { 'Bank', 'Saldo kamu $4.200' }
})
```

## Font

UI memakai font sistem sebagai fallback. Kalau ingin tampilan persis seperti preview,
taruh `Inter-Variable.woff2` dan `BarlowSemiCondensed-Variable.woff2` di `html/fonts/`.
Tanpa file itu pun UI tetap rapi, hanya bentuk hurufnya mengikuti sistem.

## Tampilan (Glass HUD)

UI memakai gaya glassmorphism futuristik. **Jangan menambahkan `backdrop-filter`** — CEF FiveM tidak bisa
membaca layar game di belakang NUI, jadi efek itu digambar sebagai kotak hitam. Efek kaca dibuat dari
gradien transparan, highlight tepi, dan glow.

- Seberapa tembus pandang: ubah `--a-msg` (pesan), `--a-bar` (composer), `--a-pop` (popup) di `html/style.css`
  (0 = bening, 1 = solid; jangan di bawah ~0.4 supaya teks tetap terbaca di atas langit terang).
- Warna kaca mengikuti tema yang dipilih pemain; glow pesan dan garis di bawah composer mengikuti warna channel.

---

## Soft Blur (redesign)

Tampilan chat disamakan dengan HUD 0r-hud-v3: panel datar transparan tanpa emboss/glow,
dengan **blur asli dari layar game** di belakang pesan, kolom ketik, tab, dan popup
(`html/blur.js`, teknik WebGL game-view seperti screenshot-basic).

- Berjalan di GPU → **tidak menambah resmon Lua**. Diproses hanya di area panel.
- Chat idle / tersembunyi → loop blur diam (0 kerja GPU).
- Mode otomatis: kalau 0r-hud-v3 jalan, chat **ikut mode `/hudblur`**. Kalau tidak,
  chat mengukur FPS sendiri dan mematikan blur di bawah 30 FPS.
- Player bisa pilih sendiri: `/chatblur auto | high | medium | low | off`.
- Kalau shader tidak didukung GPU, blur mati otomatis dan chat tetap tampil normal.
- Atur di `config.lua` → `Config.Blur`.

---

## Catatan export `chat`

Resource ini `provide 'chat'`, tetapi FiveM tidak otomatis mengalihkan `exports.chat:xxx` ke resource yang
provide. Supaya script seperti qbx_core tidak error *"No such export addMessage in resource chat"*,
semua export (`addMessage`, `addSuggestion`, `removeSuggestion`, `clear`, `isOpen`) juga didaftarkan atas
nama `chat` di `client/main.lua` dan `server/main.lua`.
