// lastresort_loading
// LastResort Development · https://intelnpc.com

/* =====================================================================
 * lastresort_loading — configuration
 * ---------------------------------------------------------------------
 * Every option below is consumed by index.html. Edit freely.
 * `null` on an i18n-aware field means: use the value from locales/<lang>.json.
 * ===================================================================== */

window.LR_CONFIG = {
    /* ------------------------------------------------------------------
     * Language
     * ---------------------------------------------------------------- */
    locale: 'id',              // 'en', 'hu', or any locales/<name>.json
    fallbackLocale: 'en',

    /* ------------------------------------------------------------------
     * Brand / wordmark / footer
     * Set to a string to override the locale value, or null to fall back.
     * ---------------------------------------------------------------- */
    brand: {
        preTitle: null,        // small caps line above the title
        title: null,           // big H1 — null or '' shows sv_projectName in-game
        subtitle: null,        // small caps line below the title
        footer: null           // tiny footer line at bottom of screen
    },

    /* ------------------------------------------------------------------
     * Server logo (top left, above the wordmark)
     * Drop the file into assets/img/ — the manifest already packs
     * .png / .jpg / .svg / .webp from that folder. The logo only appears
     * once the file really decodes, so a wrong path costs you the logo
     * and nothing else.
     * ---------------------------------------------------------------- */
    logo: {
        enabled: false,             // bool, default false — show the logo image at all
        src: 'assets/img/logo.png', // string — path relative to the resource root
        height: 84,                 // number px, default 84 — rendered height, the width follows the aspect ratio
        placement: 'above',         // 'above' keeps the H1 title under the logo, 'replace' hides the title
        glow: true                  // bool, default true — accent drop-shadow behind the logo
    },

    /* ------------------------------------------------------------------
     * Player name shown in the welcome line.
     * Overridden at runtime: bridge/server.lua passes the connecting name
     * via deferrals.handover (window.nuiHandoverData.name) and the
     * framework bridge pushes the character name once it loads.
     * ---------------------------------------------------------------- */
    playerName: '',

    /* ------------------------------------------------------------------
     * Server status chip (top right)
     * playersCurrent / playersMax / ping are browser-preview values only —
     * in-game they are replaced by live data from bridge/server.lua.
     * ---------------------------------------------------------------- */
    status: {
        show: true,
        online: true,          // green dot + "Online" label
        playersCurrent: 0,
        playersMax: 0,
        ping: 0
    },

    /* ------------------------------------------------------------------
     * Background video
     * Two kinds of source, in one list.
     *
     * A LOCAL FILE: drop .webm / .mp4 (H.264 + AAC) / .mkv into assets/video/.
     * Matroska (.mkv) plays as long as what is inside it is VP8, VP9 or H.264 —
     * it is the container WebM is a profile of, and the game's browser demuxes
     * both with the same code. HEVC, AV1 and AC-3 inside an .mkv do not decode,
     * so the .webm and .mp4 of the same name are tried after it. .avi, .wmv,
     * .flv, .mpg, .mov and .m2ts never play and are looked up as the .webm and
     * .mp4 of the same name instead. The player walks the list in order and
     * falls back to the gradient background if none of them load, so shipping
     * without a video file is fine.
     *
     * A REMOTE URL works too — any direct link to an .mp4 or .webm, on your
     * own web server or a CDN. Nothing has to be packed with the resource.
     * ---------------------------------------------------------------- */
    video: {
        enabled: true,
        // Played in order until one decodes. Two kinds of entry are allowed:
        //
        //   'https://cdn.example.com/bg.webm'    STREAMED from a web server
        //   'assets/video/loading.webm'          PACKED into the resource
        //
        // STREAMED vs PACKED is the choice worth thinking about, and it is not
        // about quality:
        //
        //   A packed file is part of the resource, so every player downloads
        //   all of it during the connect handshake, BEFORE the loading screen
        //   they are waiting on can even appear. A 30 MB background makes the
        //   join 30 MB heavier for everyone, every time the cache is cold.
        //
        //   A URL is fetched by the browser while the screen is already up,
        //   and it streams — playback starts on the first buffered seconds
        //   instead of the last byte. It costs your web server the bandwidth
        //   rather than your game server, nothing is in the join download,
        //   and swapping the video needs no resource restart.
        //
        // So: put the file on any web host — your own server, a CDN, object
        // storage — and paste the direct link here. Anything that serves the
        // file over https with the right content type works; it does not have
        // to be anything special.
        //
        // The shipped default is a local path only because no URL of yours can
        // be guessed. Replace it with your link.
        sources: [
            'assets/video/loading.mp4'
        ],
        autoplay: true,
        loop: true,
        muted: true,           // muted is required for autoplay everywhere
        objectFit: 'cover',    // 'cover' | 'contain'
        opacity: 1.0,
        blurPx: 0              // optional CSS blur over the video
    },

    /* ------------------------------------------------------------------
     * Background image / slideshow
     * The no-video path: one source is a static background, several
     * cross-fade as a slideshow. Drawn under the video layer, so it also
     * covers a video that never decodes — set video.enabled to false if
     * you want images only.
     * ---------------------------------------------------------------- */
    image: {
        enabled: false,        // bool, default false — draw the image layer at all
        sources: [             // string[] — one entry is a static background, several make a slideshow
            'assets/img/bg1.jpg',
            'assets/img/bg2.jpg'
        ],
        intervalMs: 9000,      // number ms, default 9000 — how long each slide is held (ignored with a single source)
        fadeMs: 1200,          // number ms, default 1200 — cross-fade length between slides
        objectFit: 'cover',    // 'cover' | 'contain', default 'cover'
        opacity: 1.0,          // number 0–1, default 1 — image layer opacity over the gradient background
        blurPx: 0,             // number px, default 0 — CSS blur over the image layer
        kenBurns: true         // bool, default true — slow zoom drift on each slide
    },

    /* ------------------------------------------------------------------
     * Music
     * One playlist. A `src` is a file this resource ships — drop .mp3 /
     * .ogg into assets/audio/ — and `title` falls back to the filename
     * when it is left out.
     * ---------------------------------------------------------------- */
    music: {
        enabled: true,
        showUI: true,          // hide the whole music panel if false
        showPlaylist: true,    // bool, default true — the track-list button next to the transport controls; false leaves only prev / play / next
        rememberVolume: true,  // bool, default true — the volume the player last set is restored on their next join; false always starts at `volume`
        autoplay: true,        // tries to play on load (gesture unlock fallback)
        volume: 50,            // 0–100 — the starting volume, and the only one used when rememberVolume is false
        loop: true,            // loop the whole playlist
        shuffle: false,
        // true = no separate music file: the background video's own soundtrack
        // is the music, and the play button only turns that sound on / off.
        // prev / next / playlist are hidden and `tracks` is ignored.
        useVideoAudio: true,
        videoTitle: 'Foreplay',  // label shown under "Now Playing"
        tracks: [],

        /* --------------------------------------------------------------
         * Visualizer — the cover art IS the spectrum.
         * The audio is routed through an analyser and the bars follow the
         * actual frequencies; where the browser will not give the page a
         * running audio context they are driven by a synthetic signal.
         * ------------------------------------------------------------ */
        visualizer: {
            enabled: true,     // bool, default true — false hides both canvases and leaves a plain cover
            bars: 14,          // number 4–48, default 14 — bars drawn in the cover square
            wave: true,        // bool, default true — the thin waveform line under the track title
            analyse: true,     // bool, default true — tap the audio for a real spectrum; false always uses the synthetic signal
            smoothing: 0.72,   // number 0–0.95, default 0.72 — analyser smoothing; higher is calmer
            sensitivity: 1.0   // number, default 1 — overall bar height multiplier
        }
    },

    /* ------------------------------------------------------------------
     * Background base (gradient under the video — visible if video fails
     * or while it loads).
     * ---------------------------------------------------------------- */
    background: {
        baseColor: '#06080d',
        // Raw CSS gradients stacked back-to-front. Use as many as you like.
        gradients: [
            'radial-gradient(ellipse 80% 60% at 20% 110%, rgba(95, 224, 255, 0.18) 0%, transparent 60%)',
            'radial-gradient(ellipse 70% 55% at 85% 105%, rgba(167, 139, 250, 0.16) 0%, transparent 60%)',
            'radial-gradient(ellipse 60% 50% at 50% -10%, rgba(244, 114, 182, 0.08) 0%, transparent 55%)',
            'linear-gradient(180deg, #080b14 0%, #06080d 60%, #04060a 100%)'
        ]
    },

    /* ------------------------------------------------------------------
     * Pattern overlay above the video
     * type: 'stripes' | 'dots' | 'hex' | 'grid' | 'none'
     * ---------------------------------------------------------------- */
    pattern: {
        enabled: true,
        type: 'stripes',
        color: 'rgba(255, 255, 255, 0.55)',
        opacity: 0.07,
        maskEdges: true,       // fade pattern toward the screen edges

        // stripes
        stripeAngle: 35,       // degrees
        stripeSpacing: 6,      // px between stripe centers
        stripeThickness: 1,    // px

        // dots
        dotSize: 1,            // px radius
        dotSpacing: 22,        // px between dots

        // hex
        hexAccent: 'rgba(95, 224, 255, 0.6)',

        // grid
        gridSpacing: 28,       // px
        gridThickness: 1       // px
    },

    /* ------------------------------------------------------------------
     * Scrim (dark vignette for readability)
     * ---------------------------------------------------------------- */
    scrim: {
        enabled: true,
        topDark: 0.55,         // 0..1 darkness at top
        midDark: 0.18,
        bottomDark: 0.78,      // darkness at bottom
        vignette: 0.55,        // edge vignette strength
        tintTop: 'rgba(95, 224, 255, 0.04)',
        tintBottom: 'rgba(167, 139, 250, 0.03)'
    },

    /* ------------------------------------------------------------------
     * Film grain
     * ---------------------------------------------------------------- */
    grain: {
        enabled: false,        // off: barely visible, but a full-screen noise layer over the video
        opacity: 0.035
    },

    /* ------------------------------------------------------------------
     * Rising particles canvas (the floaty dots)
     * ---------------------------------------------------------------- */
    particles: {
        enabled: true,
        density: 32000,        // viewport area / density = count (clamped)
        minCount: 15,
        maxCount: 25,
        sizeMin: 0.5,
        sizeMax: 1.5,
        speedMin: 0.12,        // px/frame
        speedMax: 0.47,
        haloMultiplier: 3.5,
        haloOpacity: 0.45,
        alphaMin: 0.18,
        alphaMax: 0.6,
        palette: [
            { r: 220, g: 232, b: 248, weight: 0.65 },  // soft white
            { r: 150, g: 220, b: 255, weight: 0.25 },  // pale cyan
            { r: 200, g: 180, b: 255, weight: 0.10 }   // faint lilac
        ]
    },

    /* ------------------------------------------------------------------
     * Corner brackets
     * ---------------------------------------------------------------- */
    corners: {
        enabled: true,
        color: 'rgba(95, 224, 255, 0.55)',
        size: 22,              // px
        thickness: 2,          // px
        inset: 14              // px from viewport edge
    },

    /* ------------------------------------------------------------------
     * Theme colors (applied as CSS variables)
     * ---------------------------------------------------------------- */
    theme: {
        accent:     '#f3b354',
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
    },

    /* ------------------------------------------------------------------
     * Info panel tabs (right side)
     * ---------------------------------------------------------------- */
    tabs: {
        rules: true,
        staff: true,
        news: true,            // bool, default true — the News tab; it only appears once there is something to show, so this stays harmless on a server that publishes nothing
        defaultTab: 'rules'
    },

    /* ------------------------------------------------------------------
     * Staff cards
     * tone: 'owner' | 'admin' | 'dev' | 'mod' (color theming)
     * Leave role/badge null to use the locale defaults.
     * ---------------------------------------------------------------- */
    staff: [
        { name: 'Viktor', role: null, badge: null, tone: 'owner', avatar: 'V' },
        { name: 'Dora',   role: null, badge: null, tone: 'admin', avatar: 'D' },
        { name: 'Marcus', role: null, badge: null, tone: 'dev',   avatar: 'M' },
        { name: 'Esther', role: null, badge: null, tone: 'mod',   avatar: 'E' }
    ],
    // Locale-driven defaults per tone — overridden by an explicit role/badge above.
    staffDefaults: {
        owner: { roleKey: 'roles.founder',    badgeKey: 'badges.owner' },
        admin: { roleKey: 'roles.management', badgeKey: 'badges.admin' },
        dev:   { roleKey: 'roles.scripting',  badgeKey: 'badges.dev'   },
        mod:   { roleKey: 'roles.support',    badgeKey: 'badges.mod'   }
    },

    /* ------------------------------------------------------------------
     * Socials (bottom right)
     * icon: any icon name from the bundled Lucide set (assets/lucide),
     * written without the "icon-" prefix — see lucide.dev/icons.
     * ---------------------------------------------------------------- */
    socials: [
        { icon: 'message-circle', url: 'https://discord.gg/yourserver' },
        { icon: 'globe',          url: 'https://yourserver.example'   },
        { icon: 'shopping-bag',   url: 'https://store.example'        }
    ],

    /* ------------------------------------------------------------------
     * Tips rotator (uses locales/<lang>.json → tips[])
     * A live tip list from the server wins over both of the lists below —
     * see `data/README.txt` for the file and the `lrl:tipsUrl` convar.
     * ---------------------------------------------------------------- */
    tips: {
        enabled: true,
        intervalMs: 5000,
        fadeMs: 400,
        override: null         // [] to override locale; null to use locale
    },

    /* ------------------------------------------------------------------
     * Server news / patch notes (the News tab)
     * The server feeds this list at connect time — a JSON file in data/, a
     * URL, or a push from another resource — so the notes can change without
     * anyone touching the resource. The entries below are the fallback for
     * when the server has nothing to say; leave the list empty and the tab
     * stays hidden until it does.
     * ---------------------------------------------------------------- */
    news: {
        maxItems: 8,           // number, default 8 — how many entries are rendered, newest first as they arrive
        items: [               // fallback entries: { title, date, tag, body } — body is a string or an array of lines
            // {
            //     title: 'Winter update',
            //     date: '2026-07-24',
            //     tag: 'Update',
            //     body: [
            //         'Two new legal jobs at the docks.',
            //         'Vehicle handling pass on every sports car.'
            //     ]
            // }
        ]
    },

    /* ------------------------------------------------------------------
     * Rules list (uses locales/<lang>.json → rules[])
     * Override with an array here to hard-code them across all languages.
     * ---------------------------------------------------------------- */
    rules: null,

    /* ------------------------------------------------------------------
     * Rules acceptance gate
     * The panel the player has to accept before the screen hands over. It is
     * switched on server-side — `setr lrl:rulesGate 1` — because the
     * acceptance is recorded there, per identifier; these keys only decide
     * how the panel behaves once the server asks for one. With the convar
     * unset nothing below has any effect.
     * ---------------------------------------------------------------- */
    rulesGate: {
        requireScroll: true,   // bool, default true — Accept unlocks only after the rules have been scrolled to the end
        showDecline: true,     // bool, default true — offer a Decline button, which disconnects the player
        dim: 0.72              // number 0–1, default 0.72 — how dark the loading screen behind the panel goes
    },

    /* ------------------------------------------------------------------
     * Loading progress
     * The bar is simulated until FiveM emits its first loadProgress
     * message; from that point the real load drives it and the travel
     * that is left is remapped, so the bar never jumps backwards.
     * ---------------------------------------------------------------- */
    progress: {
        simulate: true,
        intervalMs: 380,
        stepMin: 0.02,
        stepMax: 0.07,
        logHoldMs: 2500        // number ms, default 2500 — how long a game log line keeps the status row before the stage name takes it back
    },

    /* ------------------------------------------------------------------
     * Dev / preview dock (replay button)
     * ---------------------------------------------------------------- */
    devDock: false
};
