# lastresort_loading

**A free, fully configurable FiveM loading screen by LastResort Development.**

Local MP4 / WebM background video, a music player that takes local MP3 / OGG files and draws a real spectrum from them, a rising particle canvas, pattern overlays, an animated progress bar with stage labels and a clean glass-panel UI — backdrop blur, vignette scrim and film grain. The framework is auto-detected: drop it onto ESX, QBCore, Qbox, vRP or a standalone server and the player's **character name** appears in the welcome line with zero edits.

Everything is driven by a single `config.js`. No build step, no framework, no markup edits.

- **Resource name:** `lastresort_loading`
- **Version:** 2.1.0
- **Author:** LastResort Development — [intelnpc.com](https://intelnpc.com)
- **Price:** Free — [Download on Tebex](https://fivem-last-resort.tebex.io)
- **Dependencies:** None

---

## Specifications

| | |
|---|---|
| **Code is accessible** | Yes for everything you configure: `config.js`, `locales/*.json`, the news and tips you publish in `data/`, the media you drop into `assets/`, and this documentation are all left readable (`escrow_ignore`). The page logic is escrowed. |
| **Subscription-based** | No |
| **Lines of code** | ~3,100 (HTML/CSS/JS page plus two small Lua bridge files) |
| **Requirements** | None. No framework, no database, no `ox_lib`. Framework detection is opt-in and degrades to the FiveM display name. |
| **Support** | Yes |

---

## Performance

A loading screen runs while the client is streaming the entire map, so it is
the one UI where wasted work is felt directly — it competes with asset
streaming for the same frame.

| Scenario | Cost | Workload |
|---|---|---|
| **Particles off, no video** | negligible | CSS animation only, all on compositable properties (`transform`, `opacity`). No canvas, no render loop. |
| **Default** — particles on, video playing | one canvas pass per frame over ~60 particles | Each particle's halo is pre-rendered once into an offscreen canvas and blitted with `drawImage`, so a frame costs blits rather than gradient allocations. Device pixel ratio is capped at 1.5. |
| **Server bridge** | one request per 2s per connecting client | Rate-limited server-side to one reply per second per player. |

The page is not measured with `resmon` — it runs in the loading-screen NUI
before the client is in a session, where `resmon` is not available. Judge it
instead in the browser: open `index.html` directly and record a performance
profile. Lower `particles.count`, or set `particles.enabled` to `false`, on
servers where clients are streaming from slow disks.

---

## Escrow and licensing

- **What stays open.** `config.js`, every file in `locales/`, everything in
  `data/` and `assets/`, and the markdown documentation. That is every file this
  README asks you to edit.
- **`You lack the required entitlement`.** This means the server is running
  the resource under an account that has not been granted it. Grant it at
  [keymaster.fivem.net/asset-grants](https://keymaster.fivem.net/asset-grants)
  to the server key you actually boot with, then restart the resource.
- **Licence.** Unlimited servers on your own account, with lifetime updates
  including major versions. Redistribution or resale is not permitted.

---

## Features

- **Background video — a local MP4 / WebM file, or a direct URL to one.** Sources are tried in order, so a list is its own fallback chain, and a video that never decodes leaves the image layer or the gradient background showing
- **Static image or slideshow background** for servers that don't want video — cross-fade, Ken Burns drift, and it doubles as the safety net under a video that never decodes
- **Server logo** image above the wordmark, or in place of the title entirely
- **Rules acceptance gate** — an optional panel the player has to scroll and accept before the screen hands over, recorded server-side per identifier so it is asked once, or once per rules version
- **Server news / patch notes tab** — published from a JSON file, an HTTP feed or another resource, so the notes change without anyone touching the loading screen
- **Live tips** from the server through the same routes, with the locale list as the fallback
- **Music player** — drop `.mp3` / `.ogg` into `assets/audio/` and list them; transport, track list, shuffle, loop and a volume that follows the player across joins
- **Real spectrum visualizer** — the cover art is an analyser reading the audio that is actually playing, with a waveform line under the track title; audio the browser will not let the page tap falls back to a synthetic signal rather than sitting still
- Animated **rising particle canvas** — weighted color palette, density, speed, size, halo and alpha all configurable
- Four **pattern overlays** (fine stripes, dots, hex grid, square grid) with edge masking — or off entirely
- Smooth **animated progress bar** with stage labels, live percentage and real FiveM load events (simulated fallback for preview)
- **Tips rotator**, **Rules** and **Staff** tabs with color-coded role cards (owner / admin / dev / mod)
- **Live server status chip** — online state plus the real player count, slot count and ping, fed by the server bridge while the screen is up
- **Social links** row — Discord, website, store, any icon from the bundled Lucide set
- **Auto character name** in the welcome line on Qbox / QBCore / ESX / vRP, FiveM display name as fallback
- **10 translations** out of the box — add your own with a single JSON file
- Glass-panel look: backdrop blur, configurable scrim, film grain, gradient background stack and corner brackets
- **Graceful handover** — the screen fades out and the music ramps to silence before the NUI is released, instead of the engine cutting the frame away mid-bar
- One `config.js` for every knob

---

## Install

1. Place the `lastresort_loading/` folder into your server's `resources/` directory.
2. Add `ensure lastresort_loading` to `server.cfg` **early** — before anything that touches the loading screen.
3. Put your video in `assets/video/` and your music in `assets/audio/`, then reference them in `config.js`.
4. Restart. The screen takes effect on the next client connect.

```cfg
ensure lastresort_loading        # add this early
```

> **Only one loadscreen.** Only one resource may declare `loadscreen`. Stop any previous loading-screen resource so it doesn't compete with `lastresort_loading`.

See [INSTALLATION.md](INSTALLATION.md) for the step-by-step guide.

---

## Video & music

### Background video — a local file or a URL

The background video tries `video.sources` **in order** — the first source that plays is shown. If a source errors, the next one is tried; if none work, the video layer hides and the configurable gradient background shows instead. List as many sources as you like and put your most compatible format last as the safety net.

```js
video: {
    enabled: true,
    sources: [
        'assets/video/loading.mkv',
        'assets/video/loading.webm',
        'assets/video/loading.mp4'
    ],
    autoplay: true,
    loop: true,
    muted: true,           // muted is required for autoplay everywhere
    objectFit: 'cover',    // 'cover' | 'contain'
    opacity: 1.0,
    blurPx: 0              // optional CSS blur over the video
}
```

**Prefer `.webm` (VP9).** Every Chromium build decodes it, including the one inside FiveM; H.264 in `.mp4` depends on how that build was compiled.

#### Stream it, or pack it

A source is either a **URL** or a **path inside the resource**, and the difference is worth a moment.

A packed file is part of the resource, so **every player downloads all of it during the connect handshake — before the loading screen they are waiting on can appear.** A 30 MB background makes the join 30 MB heavier for everyone with a cold cache.

A URL is fetched by the browser while the screen is already up, and it **streams**: playback starts on the first buffered seconds instead of the last byte. Nothing is in the join download, the bandwidth is your web server's rather than your game server's, and swapping the video later needs no resource restart.

```js
sources: [ 'https://cdn.example.com/loading.webm' ]
```

Any host that serves the file over https with a `video/webm` or `video/mp4` content type works — your own web server, a CDN, object storage. It does not need byte-range support; a loading screen never seeks.

Use a packed file for a short, small clip. Use a URL for anything else.

Drop files into `assets/video/` — the manifest packs `.webm`, `.mp4`, `.mkv`, `.m4v` and `.ogv`, so no manifest edit is needed. A container the manifest does not pack is never shipped to the client at all, and the request for it answers 404.

**`.mkv` plays.** Matroska is the container WebM is a profile of, and CEF demuxes both with the same code, so an `.mkv` holding VP8, VP9 or H.264 is played as it is. What decides it is the codec inside, not the extension: HEVC (H.265), AV1, AC-3 and DTS do not decode. An `.mkv` source is therefore tried first and the `.webm` and `.mp4` of the same name are queued **behind** it, so a file CEF cannot decode still falls through to a converted copy if you keep one.

Re-wrapping an `.mkv` that already holds H.264 is lossless and instant — no re-encode, so nothing is lost:

```bash
ffmpeg -i loading.mkv -c copy loading.mp4                              # re-wrap, seconds
ffmpeg -i loading.mkv -c:v libvpx-vp9 -crf 34 -b:v 0 -an loading.webm  # re-encode, safest
```

Dropping the audio track (`-an`) is worth doing either way: the video is muted, so every byte of its audio is downloaded and thrown away.

`.avi`, `.wmv`, `.flv`, `.mpg`, `.mov` and `.m2ts` never play. A source in one of those is not requested at all — the page looks up the `.webm` and the `.mp4` of the same name instead, so an older config keeps its video after you re-encode the file.

If a video does not appear, the F8 console names the file and the reason: `video source failed` with the media error code, or `video timed out`. A source that is genuinely still downloading is never cut off — the timeout re-arms as long as bytes keep arriving.

### Image background — static or slideshow

Not every server wants a video. Set `image.enabled` and list your files: **one source is a static background, several cross-fade as a slideshow** with an optional slow Ken Burns zoom.

```js
image: {
    enabled: false,        // draw the image layer at all
    sources: [
        'assets/img/bg1.jpg',
        'assets/img/bg2.jpg'
    ],
    intervalMs: 9000,      // how long each slide is held (ignored with a single source)
    fadeMs: 1200,          // cross-fade length between slides
    objectFit: 'cover',    // 'cover' | 'contain'
    opacity: 1.0,
    blurPx: 0,             // optional CSS blur over the image layer
    kenBurns: true         // slow zoom drift on each slide
}
```

Drop the files into `assets/img/` — the manifest already packs `.png`, `.jpg`, `.svg` and `.webp` from there. The image layer is drawn **under** the video layer, so it is also what shows if a video is configured but never decodes. For images only, set `video.enabled: false`.

### Server logo

```js
logo: {
    enabled: false,
    src: 'assets/img/logo.png',
    height: 84,            // rendered height in px, the width follows the aspect ratio
    placement: 'above',    // 'above' keeps the H1 title under the logo, 'replace' hides the title
    glow: true             // accent drop-shadow behind the logo
}
```

The logo appears in the top-left, above the wordmark. It is only shown once the file has really decoded — a wrong path costs you the logo and nothing else, never a broken-image icon on the screen.

### Music

```js
music: {
    enabled: true,
    showUI: true,          // hide the whole music panel if false
    autoplay: true,        // tries to play on load (gesture unlock fallback)
    volume: 50,            // 0–100
    loop: true,            // loop the whole playlist
    shuffle: false,
    tracks: [
        { title: 'Last Resort', src: 'assets/audio/last_resort.mp3' }
    ],
    visualizer: {
        enabled: true,
        bars: 14,
        wave: true,
        analyse: true,
        smoothing: 0.72,
        sensitivity: 1.0
    }
}
```

A `src` is a file this resource ships — drop `.mp3` / `.ogg` into `assets/audio/` and list the path. `title` can be left out, in which case the filename is shown.

The controls are previous / play-pause / next, a draggable volume slider and a **track list** — the button next to Next opens the whole queue, the track that is playing is highlighted, and clicking any row jumps straight to it. With `loop: false` playback stops after the last track; with `shuffle: true` the order is randomized once per load and the list shows that order. A track whose file is missing, or in a container the game's browser cannot decode, is skipped instead of stalling the playlist.

The **volume follows the player**. Whatever they drag the slider to is stored client-side (`SetResourceKvp`, so a cleared browser cache cannot lose it) and restored on their next connect — `music.volume` is only the starting point for someone who has never touched it. Set `rememberVolume: false` to always start at your configured volume, and `showPlaylist: false` to keep only the transport controls.

#### Visualizer

The cover art is the spectrum. The audio is routed through an `AnalyserNode` and the bars follow the frequencies that are actually sounding, with a thin waveform line under the track title. Where the browser will not hand the page a running audio context the same bars are driven by a synthetic signal instead — the panel reads as alive either way, which is the entire job of a visualizer on a loading screen.

| Key           | Type    | Default | Notes                                                                     |
| ------------- | ------- | ------- | ------------------------------------------------------------------------- |
| `enabled`     | bool    | `true`  | `false` hides both canvases and leaves a plain cover square.               |
| `bars`        | number  | `14`    | 4–48. Bars drawn in the cover square.                                     |
| `wave`        | bool    | `true`  | The waveform line under the track title.                                  |
| `analyse`     | bool    | `true`  | Tap the audio for a real spectrum. `false` always uses the synthetic signal. |
| `smoothing`   | number  | `0.72`  | 0–0.95 analyser smoothing — higher is calmer.                             |
| `sensitivity` | number  | `1.0`   | Overall bar height multiplier.                                            |

The audio is only ever re-routed through the analyser once the browser has given the page a *running* audio context. If it will not, the tap is skipped and retried after the player's first click — a visualizer is never worth risking silent music for.

> **Autoplay note.** Browsers block audible autoplay until the user interacts. The player ships a gesture-unlock fallback — the first click or keypress starts playback at your configured volume.

---

## config.js reference

The whole screen is driven by one object, `window.LR_CONFIG`. These are the top-level keys:

| Key              | Type          | Notes                                                                                             |
| ---------------- | ------------- | ------------------------------------------------------------------------------------------------- |
| `locale`         | string        | Active language code (`en`, `hu`, `de`, …) — matches a file in `locales/`.                        |
| `fallbackLocale` | string        | Used when the active locale file is missing or fails to load.                                     |
| `brand`          | object        | `preTitle`, `title`, `subtitle`, `footer` — `null` falls back to the locale strings. A `null` or empty `title` is filled with the server's own `sv_projectName` in-game, so leaving it alone is a valid choice; any value you set wins. |
| `logo`           | object        | Server logo image: `enabled`, `src`, `height`, `placement` (`'above'` \| `'replace'`), `glow`.    |
| `playerName`     | string        | Static welcome-line name. Overridden at runtime by the framework bridge / handover data.          |
| `status`         | object        | Status chip: `show`, `online`, `playersCurrent`, `playersMax`, `ping`.                            |
| `video`          | object        | `enabled`, ordered `sources` chain (packed files and/or direct URLs), `autoplay`, `loop`, `muted`, `objectFit`, `opacity`, `blurPx`. |
| `image`          | object        | Static image / slideshow background: `enabled`, `sources`, `intervalMs`, `fadeMs`, `objectFit`, `opacity`, `blurPx`, `kenBurns`. |
| `music`          | object        | `enabled`, `showUI`, `showPlaylist`, `rememberVolume`, `autoplay`, `volume` (0–100), `loop`, `shuffle`, `tracks` playlist, `visualizer`. |
| `background`     | object        | `baseColor` + stacked CSS `gradients` shown under the video (and while it loads).                 |
| `pattern`        | object        | `type`: `'stripes'` \| `'dots'` \| `'hex'` \| `'grid'` \| `'none'`, plus color, opacity, `maskEdges` and per-type tuning. |
| `scrim`          | object        | Readability vignette: `topDark`, `midDark`, `bottomDark`, `vignette`, `tintTop`, `tintBottom`.    |
| `grain`          | object        | Film grain overlay: `enabled`, `opacity`.                                                         |
| `particles`      | object        | Rising particle canvas: density, count clamps, size / speed / alpha ranges, halo, weighted palette. |
| `corners`        | object        | Corner bracket frame: `color`, `size`, `thickness`, `inset`.                                      |
| `theme`          | object        | Accent, line and text colors applied as CSS variables — one block drives every accent.            |
| `tabs`           | object        | Toggle the `rules` / `news` / `staff` tabs and set `defaultTab`.                                  |
| `staff`          | array         | Staff cards: `{ name, role, badge, tone, avatar }` with color-coded role badges.                  |
| `staffDefaults`  | object        | Locale-driven default role / badge per tone (`owner`, `admin`, `dev`, `mod`).                     |
| `socials`        | array         | `{ icon, url }` — Discord, website, store or any bundled Lucide icon name.                        |
| `tips`           | object        | Tips rotator: `enabled`, `intervalMs`, `fadeMs`, `override` (null = locale tips). A live list from the server wins over both. |
| `news`           | object        | News tab fallback: `maxItems` and an `items` array of `{ title, date, tag, body }`. The server's list wins. |
| `rules`          | array \| null | Hard-coded rules list, or `null` to pull them from the locale file.                               |
| `rulesGate`      | object        | Acceptance panel look and feel: `requireScroll`, `showDecline`, `dim`. Switched on server-side with `lrl:rulesGate`. |
| `progress`       | object        | Simulated-progress tuning (`simulate`, `intervalMs`, `stepMin`, `stepMax`) plus `logHoldMs`. The first real FiveM `loadProgress` event takes the bar over automatically. |
| `devDock`        | boolean       | Shows a small preview dock with a Replay button — for browser preview only.                       |

Every key is documented inline in `config.js`. On i18n-aware fields, `null` means "use the value from `locales/<lang>.json`".

### Theme

Theme colors are CSS variables set from one block — change the accent and the progress bar, particles halo, pattern tint and panel borders all move together:

```js
theme: {
    accent:     '#5fe0ff',
    accent2:    '#a78bfa',
    accent3:    '#f472b6',
    accentSoft: 'rgba(95, 224, 255, 0.16)',
    accentGlow: 'rgba(95, 224, 255, 0.4)',
    text:       '#f4f7fb',
    muted:      '#a8b0c2',
    faint:      '#6f7891',
    line:       'rgba(255, 255, 255, 0.08)',
    lineStrong: 'rgba(255, 255, 255, 0.16)',
    ok:         '#34d399',
    bg:         '#06080d'
}
```

---

## Server data bridge

Two bridge scripts feed the screen real data. No snippets to copy, no config to edit.

`bridge/server.lua` (a `server_script`):

- On `playerConnecting` it attaches everything the screen can be told that early — the connecting player's name, the current player count, the slot count, the server name, and the newest news entries and tips — to the connection through `deferrals.handover()`, exposed to the page as `window.nuiHandoverData`. **This is what the first frame is drawn from.** The client script that pushes the live numbers cannot start until the player has downloaded the resources, which is most of the way through the join; until then the handover is the only data the page has, so the screen opens on real content instead of placeholders that get corrected later.
- The payload rides in the connect handshake, so it is deliberately small: the four newest news entries trimmed to six lines each, and ten tips. The client bridge replaces all of it with the full lists the moment it is up.
- Only one resource can own the connection deferral, so the bridge scans the running resources on the first connect and picks one of three modes, printing which once:
  - **Take** — nothing that holds connections (a queue, a whitelist, txAdmin's `monitor`) is running, so the bridge defers for a single frame, hands over and releases.
  - **Attach** — something else owns the deferral. The payload is attached to the deferral that resource already holds, without deferring: the screen still gets its data early and nothing competes for the connection.
  - **Off** — `setr lrl:useDeferrals 0`. Nothing is attached and the data arrives from the client bridge later, as it did before.

  The scan is redone whenever a resource starts or stops. `setr lrl:useDeferrals 1` forces the take, `0` forces off.
- While the loading screen is visible it answers stat requests with the live player count, `sv_maxclients` and the client's real ping (rate-limited per player), and on `playerJoining` it pushes the stats unprompted — ten times, densely at first, because a push that lands before the client script has registered its handler is simply gone.

`bridge/handover.lua` (a `client_script`) requests those stats on its very first frame and retries every 250 ms until an answer lands, then settles to every 2 seconds while the screen is up. Server news and tips are requested on the same pattern. It also detects the framework and pushes the FiveM display name into the welcome line immediately — so the line is never blank — then swaps in the character name once the framework loads it.

| Framework                | Detected | Name shown                            |
| ------------------------ | -------- | ------------------------------------- |
| Qbox                     | auto     | Character name (charinfo)             |
| QBCore                   | auto     | Character name (charinfo)             |
| ESX                      | auto     | Character name (firstName + lastName) |
| vRP                      | auto     | Character identity                    |
| Standalone / unsupported | fallback | FiveM display name                    |

How it reaches the UI (all handled inside `index.html`):

- `window.nuiHandoverData` — read once, before anything is drawn. The name, the counts, the server name, the news and the tips it carries are seeded into the same variables the client bridge's messages write to, so there is one path from data to screen and nothing renders twice.
- A `setPlayerName` loading-screen message updates the name live while the screen is showing.
- With a name the line reads the locale's `welcome` string ("Welcome back,") plus the name; without one it shows `welcomeAnon` ("Welcome").
- `playerName` in `config.js` can force a static name; leave it empty in normal use.

---

## Server news, patch notes & live tips

The News tab and the tip rotator are **content, not code**. Four sources feed
them and the highest one that answers wins, so you can start with the array in
`config.js` and move up to a live feed later without editing the page:

| # | Source | Changes without | Good for |
|---|---|---|---|
| 1 | `exports.lastresort_loading:SetNews({...})` / `SetTips({...})`, or the `lastresort_loading:setNews` / `:setTips` **server** events | a restart | a Discord bot, an admin panel, another resource |
| 2 | `setr lrl:newsUrl "https://…"` / `setr lrl:tipsUrl "https://…"` | touching the resource at all | a web panel, a gist, anything that serves JSON |
| 3 | `data/news.json` / `data/tips.json` | a restart | editing a file over FTP |
| 4 | `news.items` in `config.js`, `tips` in the locale file | — | the fallback a fresh install ships with |

Both files are re-read while the server runs, so saving one is enough for the
next player who connects. `lrl_reload` in the console applies everything at
once. A URL feed is polled every `lrl:contentRefreshMinutes` (5 by default,
`0` fetches once at startup).

```json
[
  {
    "tag": "Update",
    "date": "2026-07-24",
    "title": "Winter update",
    "body": [
      "Two new legal jobs at the docks.",
      "Vehicle handling pass on every sports car."
    ]
  }
]
```

Every field is optional as long as an entry has a title or a body; `body` may
also be one string with newlines. A bare array of strings works for tips. A
document with both a `"news"` and a `"tips"` key set as `lrl:newsUrl` fills
both lists from one endpoint. Everything is length-capped and stripped of
non-strings server-side before it is sent, and rendered as text — a feed you do
not control cannot inject markup into the screen.

**The News tab only exists once there is something in it.** A server that
publishes nothing shows the panel exactly as it always did.

---

## Rules acceptance gate

An optional panel the player has to scroll through and accept before the
loading screen hands over. It is off by default and switched on **server-side**,
because that is where the acceptance is recorded:

```cfg
setr lrl:rulesGate 1        # ask for an acceptance
setr lrl:rulesVersion 1     # bump this and everyone is asked again
setr lrl:rulesMode version  # 'version' asks once per version, 'always' asks every join
```

The rules shown are the same list the Rules tab uses — `config.js` `rules`, or
the locale file. The acceptance is stored in `data/rules_accepted.json` keyed by
the player's `license:` identifier (falling back to `fivem:`, `discord:`,
`steam:`), together with the version they accepted and when. The client never
decides whether it owes an acceptance and never supplies the version it is
recorded under: the server answers both, so a modified client can skip its own
panel but not the record.

```js
rulesGate: {
    requireScroll: true,   // Accept unlocks only after the rules are scrolled to the end
    showDecline: true,     // offer a Decline button, which disconnects the player
    dim: 0.72              // how dark the loading screen behind the panel goes
}
```

Decline disconnects with the `gateDeclined` line from the locale pack the page
is showing, in the player's own language. The panel appears within a second or
two of connecting, so in practice it is answered long before the map has
finished streaming and nothing is ever held up.

Two console commands, both restricted to `command.<name>` ACE (the console
always has it):

```cfg
add_ace group.admin command.lrl_reload allow
add_ace group.admin command.lrl_rules_reset allow
```

```
lrl_reload                     # re-read news and tips from every source now
lrl_rules_reset all            # ask everyone again
lrl_rules_reset 3              # ask server id 3 again
lrl_rules_reset me             # ask yourself again — the fastest way to re-test the panel
lrl_rules_reset license:abc…   # ask one identifier again
```

The screen is never held open for a gate that cannot be answered: if the page
has not opened its return channel, or `loadscreen_manual_shutdown` is off, the
gate is skipped and the reason is printed to the client console.

---

## Convars

| Convar | Default | Effect |
|---|---|---|
| `lrl:useDeferrals` | auto | Who owns the connection deferral. `auto` takes it when nothing else holds connections and otherwise attaches the handover data to the deferral that resource already owns. `1` always takes it, `0` sends no handover data at all. |
| `lrl:rulesGate` | `0` | `1` asks connecting players to accept the rules. |
| `lrl:rulesVersion` | `1` | Bumping it asks everyone again. |
| `lrl:rulesMode` | `version` | `version` asks once per version, `always` asks every join. |
| `lrl:newsUrl` | — | JSON endpoint for the news list. |
| `lrl:tipsUrl` | — | JSON endpoint for the tip list. |
| `lrl:contentRefreshMinutes` | `5` | How often the feeds are polled. `0` fetches once at startup. |

---

## Shutdown & handover API

`loadscreen_manual_shutdown 'yes'` in `fxmanifest.lua` means the screen belongs to this resource instead of the engine. Once the session starts, `bridge/handover.lua` fades the page out and ramps the music down to silence before it calls `ShutdownLoadingScreen()` and `ShutdownLoadingScreenNui()` — the player sees a clean fade instead of a frame ripped away mid-bar. Comment that manifest line out to hand the shutdown back to FiveM; everything else keeps working.

Other resources can wait for that moment. Both surfaces are **client-side**, and both report done when the screen was never shown at all — a mid-session restart of this resource, for example — so nothing can ever wait forever:

```lua
-- Fired once, when the loading screen is done.
AddEventHandler('lastresort_loading:finished', function()
    -- safe to take over the screen now
end)

-- Or ask at any point.
local done = exports.lastresort_loading:IsLoadingScreenDone()
```

A resource that only *optionally* integrates should treat a missing `lastresort_loading` as "already done":

```lua
local function loadingDone()
    local state = GetResourceState('lastresort_loading')
    if state ~= 'started' and state ~= 'starting' then return true end
    local ok, res = pcall(function() return exports.lastresort_loading:IsLoadingScreenDone() end)
    return (not ok) or res == true
end
```

### Progress bar

The bar is simulated until FiveM emits its first `loadProgress` message; from there the real load drives it and the travel that is left is remapped, so control passes over without the bar ever jumping backwards. A game log line owns the status row for `progress.logHoldMs` (2500 ms by default) before the stage name takes it back.

---

## Particles & patterns

### Rising particles

An animated canvas of softly glowing dots drifting upward. Count is derived from viewport area divided by `density`, clamped between `minCount` and `maxCount`; colors are picked from a weighted RGB palette.

```js
particles: {
    enabled: true,
    density: 24000,        // viewport area / density = count (clamped)
    minCount: 50,
    maxCount: 120,
    sizeMin: 0.5,
    sizeMax: 1.5,
    speedMin: 0.12,        // px/frame
    speedMax: 0.47,
    haloMultiplier: 3.5,
    haloOpacity: 0.45,
    alphaMin: 0.18,
    alphaMax: 0.6,
    palette: [
        { r: 220, g: 232, b: 248, weight: 0.65 },
        { r: 150, g: 220, b: 255, weight: 0.25 },
        { r: 200, g: 180, b: 255, weight: 0.10 }
    ]
}
```

### Pattern overlays

Layer one of four patterns over the video, with optional edge masking, or set `type: 'none'` for a clean flat look. All types share `color` and `opacity`; each has its own tuning keys:

```js
pattern: {
    enabled: true,
    type: 'stripes',       // 'stripes' | 'dots' | 'hex' | 'grid' | 'none'
    color: 'rgba(255, 255, 255, 0.55)',
    opacity: 0.07,
    maskEdges: true,       // fade pattern toward the screen edges

    stripeAngle: 35, stripeSpacing: 6, stripeThickness: 1,   // stripes
    dotSize: 1, dotSpacing: 22,                              // dots
    hexAccent: 'rgba(95, 224, 255, 0.6)',                    // hex
    gridSpacing: 28, gridThickness: 1                        // grid
}
```

---

## Tips, rules, staff, status & socials

### Tips rotator

Tips come from the locale file (`tips[]`) and rotate with a fade. Set `tips.override` to an array to hard-code them across all languages, or feed them live from the server — see [Server news, patch notes & live tips](#server-news-patch-notes--live-tips), which takes over the rotation the moment it arrives:

```js
tips: { enabled: true, intervalMs: 5000, fadeMs: 400, override: null }
```

### Rules, news & staff tabs

Three tabs in the info panel — toggle any of them and pick the default:

```js
tabs: { rules: true, staff: true, news: true, defaultTab: 'rules' }
```

Rules come from the locale file, or set `rules: [ ... ]` in `config.js` to hard-code them. Staff cards are color-coded by `tone` — the four tones map to badge colors out of the box, and role / badge labels fall back to the locale when left `null`:

```js
staff: [
    { name: 'Viktor', role: null, badge: null, tone: 'owner', avatar: 'V' },
    { name: 'Dora',   role: null, badge: null, tone: 'admin', avatar: 'D' },
    { name: 'Marcus', role: null, badge: null, tone: 'dev',   avatar: 'M' },
    { name: 'Esther', role: null, badge: null, tone: 'mod',   avatar: 'E' }
]
```

### Server status chip

The chip in the top corner shows online state, player count and ping. In-game the numbers are live — seeded from the connect-time handover so the chip opens on the real count, then refreshed by the server bridge while the screen is up. The config values are only used when previewing `index.html` in a plain browser:

```js
status: {
    show: true,
    online: true,          // green dot + "Online" label
    playersCurrent: 0,     // preview only — live in-game
    playersMax: 0,         // preview only — live in-game
    ping: 0                // preview only — live in-game
}
```

### Socials

Any name from the bundled [Lucide](https://lucide.dev/icons) set works, written without the `icon-` prefix — the whole icon font ships inside `assets/lucide/`, so nothing is fetched at runtime. A loading screen has no tab to open into, so a click hands the URL to the game's own browser (`openUrl`); in a plain browser preview the link is copied to the clipboard instead and the icon flashes green:

```js
socials: [
    { icon: 'message-circle', url: 'https://discord.gg/yourserver' },
    { icon: 'globe',          url: 'https://yourserver.example'   },
    { icon: 'shopping-bag',   url: 'https://store.example'        }
]
```

---

## Translations

Ten translations ship out of the box. Every UI string — rules, tips, progress stages, tab labels, staff roles / badges and the welcome line — comes from a locale file in `locales/`. Switch the active language with the `locale` key.

| Language          | Code    |
| ----------------- | ------- |
| English (default) | `en`    |
| Hungarian         | `hu`    |
| German            | `de`    |
| French            | `fr`    |
| Italian           | `it`    |
| Spanish           | `es`    |
| Portuguese (BR)   | `pt-BR` |
| Polish            | `pl`    |
| Czech             | `cs`    |
| Dutch             | `nl`    |

**Add your own:** copy `locales/en.json` to `locales/<code>.json`, translate the values, and set `locale: '<code>'` in `config.js`. If a locale file is missing or fails to load, the screen falls back to `fallbackLocale`.

---

## Compatibility

- **FiveM / Cfx.re** — any artifact with a `loadscreen` slot.
- **Frameworks:** ESX, QBCore, Qbox and vRP auto-detected; standalone works with the display-name fallback.
- **No dependencies** — nothing else to ensure.
- Only one resource may declare `loadscreen`; stop other loading screens before enabling this one.
- Ships with `loadscreen_manual_shutdown 'yes'` — the resource fades the screen out and releases it itself. Comment the line out in `fxmanifest.lua` to give the shutdown back to FiveM. The rules gate needs it: without it the engine owns the shutdown and the screen cannot be held open, so the gate steps aside and says so in the console.
- Ships with a blank `ui_page` (`nui/callbacks.html`). NUI callbacks are only routed to a resource that declares one, and the loading screen has to be able to call the client script back for the acceptance and the remembered volume. It draws nothing and never takes focus.
- Runs alongside all other LastResort Development resources with no conflicts — it only occupies the loading-screen slot and does nothing in-game after loading.
- Fonts (Inter, JetBrains Mono, Saira Condensed) and icons (Lucide) ship inside the resource — the screen makes no external request at all and looks identical on a filtered, slow or fully offline network.

---

## Support & license

**lastresort_loading is a free resource.** Full source, no obfuscation, no license check. Distributed per Tebex terms — re-uploads, paid resales and removal of attribution are not allowed.

- **Website:** [intelnpc.com](https://intelnpc.com)
- **Support:** [help@intelnpc.com](mailto:help@intelnpc.com)
- **Tebex store:** [fivem-last-resort.tebex.io](https://fivem-last-resort.tebex.io)

© LastResort Development. All rights reserved.
