# Changelog — LastResort Loading

Newest first. Version numbers restarted at **v2.0** for the store release —
development ran to 3.5.0, and v2.0 is that same code under a cleaner number.

---

## v2.1 — 2026-08-12

### New

- **`.mkv` backgrounds play** — Matroska is the container WebM is a profile of, and CEF demuxes both with the same code, so an `.mkv` holding VP8, VP9 or H.264 is now played as it is. The manifest packs `.mkv`, `.m4v` and `.ogv` alongside `.webm` and `.mp4`
- **News and tips arrive in the connect handover** — the four newest entries and ten tips ride along with the counts, so the info panel opens on your real content
- **A third handover mode** — when a queue or whitelist owns the connection deferral the data is now *attached* to that resource's deferral instead of being dropped. Servers with a queue used to get no early data at all
- **The video chain says why it gave up** — the F8 console names the file and the media error code on every source it skips
- **An empty `brand.title` shows `sv_projectName`** — the server's own name, from the handover. Any title you set still wins

### Changed

- **`.mkv` is tried, not replaced** — the `.webm` and `.mp4` of the same name are queued *behind* it now rather than in its place, so a file with a codec CEF lacks (HEVC, AV1, AC-3) still falls through to a converted copy
- **`.mov` joined the dead-container list** — QuickTime never decoded, and it was being requested and failing
- **The handover is read once, before the first paint** — name, counts, server name, news and tips are seeded into the same variables the client bridge writes to, instead of being read in two places and half ignored
- **Faster first real numbers** — the client bridge asks on its first frame and retries every 250 ms until an answer lands (was 300 ms for three seconds, then every two seconds); news and tips retry every 500 ms for the first five seconds (was every two seconds)
- **`playerJoining` pushes stats ten times, densely at first** (was five times at 700 ms) — a push that lands before the client script registered its handler is gone, so more of them are sent while that is still possible

### Fixed

- **A packed `.mkv` was never shipped to the client** — the manifest did not pack the extension, so the request answered 404 whatever the config said
- **A large or slow video could be cut off mid-download** — the 6-second stall timeout now re-arms while bytes are still arriving, instead of firing on a source that was merely taking its time

---

## v2.0 — 2026-08-11

### New

- **Live server data** — real player count, max slots and ping in the status chip, refreshed while the screen is up
- **Personalised first frame** — the player name, counts and server name arrive through the connect handover
- **Rules gate** — an optional panel the player scrolls and accepts, remembered per identifier, re-asked when `lrl:rulesVersion` changes
- **News / patch notes tab** — from `data/news.json`, an HTTP feed (`lrl:newsUrl`), the `SetNews` export or `config.js`
- **Live tips** — same four sources, locale list as fallback
- **Music track list** — every queued track, click to jump, volume follows the player across joins
- **Real spectrum visualizer** — the cover art bars and the waveform follow the actual audio
- **Manual shutdown** — the page fades and the music ramps down before the NUI is released
- **`lastresort_loading:finished` event and `IsLoadingScreenDone` export** — both report done when the screen never showed
- **Image or slideshow background** — cross-fade and Ken Burns drift, also the safety net under a video that fails
- **Server logo** — above the wordmark, or in place of the title
- **New config blocks** — `brand`, `background`, `corners`, `scrim`, `grain`, `tabs`, `staffDefaults`, `devDock`, `fallbackLocale`
- **New config options** — `music.showUI`, `status.show`, pattern tuning, video `objectFit` / `opacity` / `blurPx`, tips and progress tuning
- **Console commands** — `lrl_reload` and `lrl_rules_reset`, both ACE-gated
- **`welcomeAnon`** — added to the eight locales that were missing it

### Changed

- **Renamed `lrr_loading` → `lastresort_loading`** — folder, manifest name, footer strings in all 10 locales
- **No external requests** — Font Awesome and the iconify CDN replaced by a local Lucide subset
- **Smarter deferrals** — the bridge only takes the deferral when no queue, whitelist or txAdmin gate is running (`lrl:useDeferrals` forces it either way)
- **Faster page** — pre-rendered particle halos, transform-only animations, device pixel ratio capped at 1.5
- **Instant first paint** — the welcome line and chip draw on fallbacks, then re-render when the locale lands
- **Container fallback** — an `.mkv` / `.avi` / `.wmv` / `.flv` / `.mpg` / `.m2ts` source is looked up as the `.webm` and `.mp4` of the same name
- **Social links** open through `openUrl` with a clipboard fallback — `target=_blank` is inert in a loading-screen CEF
- **Accessibility** — suite `--lr-*` tokens, `prefers-reduced-motion`, visible focus rings

### Fixed

- **A connection could hang** — `deferrals.handover()` ran outside the `pcall`, so `done()` was unreachable if it threw
- **`SetLoadingScreenHandoverData` does not exist** — the call threw on every connect and is gone
- **An out-of-range music volume** threw `IndexSizeError` and killed the rest of boot
- **The status chip could stay on placeholder numbers** — stats were sent once and never replayed
- **A one-entry playlist stranded on a dead track** — failures are counted now
- **A missing or undecodable track** is skipped, and `loop: false` is honoured on the last track
- **The info panel hung below centre** — its animation ended on `transform: none`
- **The shipped video default** pointed at a file that was neither in the package nor playable
- **`setPlayerName` before the locale loaded** was dropped; it is buffered now
- **`defaultTab`** is validated against the tabs that are actually enabled

### Removed

- **The YouTube integration, in full** — background branch, playlist tracks, `nui/yt.html`, both config blocks, `ytTrack` / `ytPlaylist` in all 10 locales, and the `yt-dlp` recipe

  **Why:** Cfx.re warned another creator under the Platform License Agreement for "unauthorized use of third-party IP: YouTube integration". It never worked inside FiveM anyway — a loading screen is served from `https://cfx-nui-<resource>/`, a hostname that does not exist on the internet, so YouTube answers with error 153. Remove any YouTube link left in your `config.js`.
- **The `bridge/examples/` folder** — it called the non-existent `SetLoadingScreenHandoverData`

  **If you copied that snippet into one of your own resources, delete the line.** It throws on every connect, and taking this folder out does not stop your copy.
- **Fake placeholder stats** (87/128 players, 24 ms) from the shipped `config.js`

---

## v1.0 — Initial release (as `lrr_loading`)

- **Background video** — local MP4 / WebM with a multi-source fallback chain
- **Music player** — local MP3 / OGG with playlist, shuffle, loop, volume slider and gesture-unlock autoplay
- **Particle canvas** — configurable palette, density, speed and size
- **Four pattern overlays** — fine stripes, dots, hex grid, square grid, with edge masking, or off
- **Progress bar** — animated, with stage labels and live percentage
- **Tips rotator**, plus Rules and Staff tabs with colour-coded role cards (owner / admin / dev / mod)
- **Status chip** — online state, current / max players, ping — and a social links row
- **Framework auto-detection** — Qbox / QBCore / ESX / vRP, with a FiveM display-name fallback on standalone
- **10 translations** — en, hu, de, fr, it, es, pt-BR, pl, cs, nl
- **One config file** — `config.js`; no dependencies
