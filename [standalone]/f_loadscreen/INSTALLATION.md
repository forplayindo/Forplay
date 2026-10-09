# Installation — lastresort_loading

1. **Drop the resource.** Place the `lastresort_loading/` folder into your server's `resources/` directory. Keep the folder name exactly `lastresort_loading`.

2. **Ensure it early.** Add the following line to `server.cfg` — early, before anything that touches the loading screen:

   ```cfg
   ensure lastresort_loading
   ```

3. **Only one loadscreen.** Only one resource may declare `loadscreen`. Stop or remove any previous loading-screen resource so it doesn't compete with `lastresort_loading`.

4. **Point it at your assets.**
   - Put your background video in `assets/video/` (`.webm`, `.mp4` or `.mkv`) and list it in `config.js` under `video.sources`. Sources are tried in order — put your most compatible format last as the safety net.
   - No video? Put your images in `assets/img/` and list them in `config.js` under `image.sources` with `image.enabled: true` — one file is a static background, several cross-fade as a slideshow. Set `video.enabled: false` if you want images only.
   - Put your logo in `assets/img/` and point `logo.src` at it with `logo.enabled: true`.
   - Put your music in `assets/audio/` (`.mp3` / `.ogg`) and list the files in `config.js` under `music.tracks`.
   - The manifest already packs these asset folders with glob patterns, so no `fxmanifest.lua` edit is needed for new files.
   - While you are in `config.js`, set your `locale`, brand strings, theme colors, status chip, staff cards and social links — everything lives in this one file.

5. **Optional — connect-time handover.** Nothing to set. This is what makes the
   screen open on the real player name, the real counts and your real news
   instead of placeholders: the data is attached to the connection before the
   page exists, because the client script that pushes live numbers cannot start
   until the player has downloaded the resources.

   Only one resource can own the connection deferral, so the server bridge
   checks on the first connect whether a queue, whitelist or txAdmin gate is
   running. If none is, it takes the deferral for a single frame. If one is, it
   attaches the same data to the deferral that resource already holds without
   taking one, so nothing competes for the connection and the data is still
   early. It prints which side it picked. Force the decision if you disagree:

   ```cfg
   setr lrl:useDeferrals 1    # always take the deferral
   setr lrl:useDeferrals 0    # send no handover data at all
   ```

   With it off the player name, the stats and the news arrive from the client
   bridge later in the load instead — the screen works either way, it just
   starts out on config values.

6. **Optional — publish news and tips from the server.** Nothing to set for the
   defaults: with `data/news.json` and `data/tips.json` absent, the screen shows
   the `news.items` array from `config.js` and the tips from the locale file,
   and the News tab stays hidden until there is something in it. To publish live
   content, read `data/README.txt` — the short version is a JSON file in
   `data/`, or a URL you already serve:

   ```cfg
   setr lrl:newsUrl "https://example.com/news.json"
   setr lrl:tipsUrl "https://example.com/tips.json"
   setr lrl:contentRefreshMinutes 5    # 0 fetches once at startup
   ```

   Both files are re-read while the server runs — save one and the next player
   to connect sees it. `lrl_reload` in the console applies everything at once.

7. **Optional — ask for a rules acceptance.** Off by default. Switch it on
   server-side, because that is where the acceptance is recorded:

   ```cfg
   setr lrl:rulesGate 1        # ask connecting players to accept the rules
   setr lrl:rulesVersion 1     # bump this and everyone is asked again
   setr lrl:rulesMode version  # 'version' asks once per version, 'always' every join
   ```

   The rules shown are the ones the Rules tab already uses (`config.js` `rules`,
   or the locale file); `rulesGate` in `config.js` decides whether the player has
   to scroll to the end and whether a Decline button is offered. Acceptances are
   stored in `data/rules_accepted.json`, keyed by identifier. Grant your admins
   the two console commands if you want them usable in-game:

   ```cfg
   add_ace group.admin command.lrl_reload allow
   add_ace group.admin command.lrl_rules_reset allow
   ```

8. **Restart.** Restart the server (or start the resource). The loading screen takes effect on the **next client connect**.

9. **Verify.** Connect with a client and confirm:
   - The loading screen appears with your video playing and music audible (if autoplay is blocked, the first click or keypress starts playback).
   - The progress bar advances with stage labels and a percentage.
   - The status chip shows the real player count, slot count and your ping (live values arrive from the server a couple of seconds in; in a plain browser preview you only see the `config.js` placeholder values).
   - On ESX / QBCore / Qbox / vRP the welcome line fills in with the character name; on standalone it shows the FiveM display name.
   - The track-list button next to Next opens the queue, the playing track is highlighted, and clicking a row jumps to it. Drag the volume, rejoin, and the slider comes back where you left it.
   - With `lrl:newsUrl` or `data/news.json` set, a News tab appears in the info panel with your entries.
   - With `lrl:rulesGate 1`, the rules panel appears a second or two into the load and the screen waits on it. Run `lrl_rules_reset me` from the console to be asked again on your next connect.
   - The screen fades out and the music ramps to silence as you spawn in, instead of vanishing in one frame. That fade is owned by `loadscreen_manual_shutdown 'yes'` in `fxmanifest.lua` — comment the line out to hand the shutdown back to FiveM.

## Troubleshooting

**The background is black and no video plays.** Open the F8 console: the page
names the file and the reason on every source it gives up on — `video source
failed` with a media error code, or `video timed out`.

Check the filename in `config.js` under `video.sources` against the file in
`assets/video/`, exactly, including case. Then check the container. `.webm`,
`.mp4` (H.264/AAC) and `.mkv` are packed by the manifest and play; `.avi`,
`.wmv`, `.flv`, `.mpg`, `.mov` and `.m2ts` never play, and a source in one of
those is looked up as the `.webm` and `.mp4` of the same name instead.

An `.mkv` is played as it is — Matroska is the container WebM is a profile of
— but only for what is inside it: VP8, VP9 and H.264 decode, HEVC (H.265), AV1
and AC-3 audio do not. If the console reports a failure on your `.mkv`, that is
the codec, and re-wrapping is usually instant and lossless:

```bash
ffmpeg -i loading.mkv -c copy loading.mp4
```

If you want a guaranteed-visible background regardless, enable `image` as well:
it renders underneath and shows through when no video source decodes.

**No music.** Browsers block autoplay until the page has been interacted with.
The first click or keypress starts playback — this is a browser policy, not a
bug. Confirm the file is listed in `music.tracks` and lives in `assets/audio/`,
and that `music.volume` is between 0 and 100.

**The visualizer bars move but do not follow the music.** That is the fallback
signal: the browser would not hand the page a running audio context, so the
audio could not be tapped. It is retried after the first click. Set
`music.visualizer.analyse: false` to always use the fallback, or
`enabled: false` to hide the visualizer entirely.

**Players are stuck at "connecting".** Two resources are fighting over the
connection deferral. The bridge stops taking one on its own for anything that
looks like a queue, a whitelist or a connect gate — it attaches its data to
that resource's deferral instead — so this only happens with
`setr lrl:useDeferrals 1` forced on, or with a gate whose resource name gives
nothing away. Set `setr lrl:useDeferrals 0` and let that resource own it.

**The counts and the name only appear halfway through the load.** That is the
handover being off or not reaching the page. Check the console line the bridge
prints on the first connect, and that `lrl:useDeferrals` is not set to `0`.

**The screen never goes away.** `loadscreen_manual_shutdown 'yes'` means this
resource owns the shutdown. If you have modified `bridge/handover.lua` and the
fade never completes, comment that manifest line out to hand the shutdown back
to FiveM while you debug.

**The rules panel never appears.** It only appears when the server asks for
one. Check `setr lrl:rulesGate 1` is in `server.cfg`, that this identifier has
not already accepted the current `lrl:rulesVersion` (`lrl_rules_reset me`), and
the client console: the gate prints why it stepped aside if
`loadscreen_manual_shutdown` is off or the page could not open its return
channel. `ui_page 'nui/callbacks.html'` in `fxmanifest.lua` is what makes that
channel possible — the resource cannot be answered without it.

**The News tab is missing.** It is only built when there is news to show.
Confirm `data/news.json` parses (a bad file is reported in the server console),
or that `lrl:newsUrl` answers 200 with JSON, or put entries in `news.items` in
`config.js`. `lrl_reload` re-reads everything and prints what it found.

**Fonts or icons look wrong.** Every font and icon is served from
`assets/fonts/` and `assets/lucide/`. If they fall back, a `files{}` glob in
`fxmanifest.lua` was edited — restore the `assets/fonts/*` and `assets/lucide/*`
entries.

## Upgrading from lrr_loading

This resource was previously named `lrr_loading`. If you were running that version:

1. Remove the old `lrr_loading/` folder from `resources/`.
2. Replace `ensure lrr_loading` with `ensure lastresort_loading` in `server.cfg`.
3. Copy your customized `config.js`, locale edits and `assets/` files into the new folder.

## Support

- Website: [intelnpc.com](https://intelnpc.com)
- Email: [help@intelnpc.com](mailto:help@intelnpc.com)
- Tebex: [fivem-last-resort.tebex.io](https://fivem-last-resort.tebex.io)
