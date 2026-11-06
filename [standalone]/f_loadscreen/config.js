// f_loadscreen — konfigurasi
// null pada teks = ambil dari locales/<locale>.json

window.FLS_CONFIG = {
    locale: 'id',
    fallbackLocale: 'en',

    brand: {
        preTitle: null,        // baris kecil di atas judul
        title: null,           // judul besar — null/'' = pakai sv_projectName
        subtitle: null,        // baris di bawah judul
        footer: null           // teks kecil paling bawah
    },

    // logo server di kiri atas (taruh file di assets/img/)
    logo: {
        enabled: false,
        src: 'assets/img/logo.png',
        height: 84,
        placement: 'above',    // 'above' = di atas judul, 'replace' = ganti judul
        glow: true
    },

    playerName: '',            // hanya untuk preview browser; in-game diisi otomatis

    // chip status kanan atas (angka di sini hanya untuk preview browser)
    status: { show: true, online: true, playersCurrent: 0, playersMax: 0, ping: 0 },

    // video latar — file lokal (assets/video/) atau URL langsung .mp4/.webm
    // URL lebih ringan: tidak ikut diunduh saat join, langsung stream
    video: {
        enabled: true,
        sources: ['assets/video/loading.mp4'],
        loop: true,
        objectFit: 'cover',
        opacity: 1.0,
        blurPx: 0
    },

    // gambar / slideshow latar (di bawah video)
    image: {
        enabled: false,
        sources: ['assets/img/bg1.jpg', 'assets/img/bg2.jpg'],
        intervalMs: 9000,
        fadeMs: 1200,
        objectFit: 'cover',
        opacity: 1.0,
        blurPx: 0,
        kenBurns: true
    },

    music: {
        enabled: true,
        showUI: true,
        showPlaylist: true,
        rememberVolume: true,  // volume terakhir pemain diingat (KVP client)
        autoplay: true,
        volume: 50,            // 0–100
        loop: true,
        shuffle: false,
        // true = suara video latar jadi musiknya; tracks diabaikan
        useVideoAudio: false,
        videoTitle: '4PLAY',
        // { src: 'assets/audio/lagu.mp3', title: 'Judul' }
        tracks: [
            { src: 'assets/audio/4play-audio.mp3', title: '4PLAY' }
        ],

        visualizer: {
            enabled: true,
            bars: 14,          // 4–48
            wave: true,
            analyse: true,     // false = selalu sinyal sintetis
            smoothing: 0.72,
            sensitivity: 1.0,
            fps: 30            // dibatasi supaya ringan
        }
    },

    background: {
        baseColor: '#06080d',
        gradients: [
            'radial-gradient(ellipse 80% 60% at 20% 110%, rgba(95, 224, 255, 0.18) 0%, transparent 60%)',
            'radial-gradient(ellipse 70% 55% at 85% 105%, rgba(167, 139, 250, 0.16) 0%, transparent 60%)',
            'radial-gradient(ellipse 60% 50% at 50% -10%, rgba(244, 114, 182, 0.08) 0%, transparent 55%)',
            'linear-gradient(180deg, #080b14 0%, #06080d 60%, #04060a 100%)'
        ]
    },

    // 'stripes' | 'dots' | 'hex' | 'grid' | 'none'
    pattern: {
        enabled: true,
        type: 'stripes',
        color: 'rgba(255, 255, 255, 0.55)',
        opacity: 0.07,
        maskEdges: true,
        stripeAngle: 35, stripeSpacing: 6, stripeThickness: 1,
        dotSize: 1, dotSpacing: 22,
        hexAccent: 'rgba(95, 224, 255, 0.6)',
        gridSpacing: 28, gridThickness: 1
    },

    scrim: {
        enabled: true,
        topDark: 0.55,
        midDark: 0.18,
        bottomDark: 0.78,
        vignette: 0.55,
        tintTop: 'rgba(95, 224, 255, 0.04)',
        tintBottom: 'rgba(167, 139, 250, 0.03)'
    },

    grain: { enabled: false, opacity: 0.035 },

    particles: {
        enabled: true,
        density: 32000,        // luas layar / density = jumlah
        minCount: 15,
        maxCount: 25,
        sizeMin: 0.5, sizeMax: 1.5,
        speedMin: 0.12, speedMax: 0.47,   // px per frame @60fps
        haloMultiplier: 3.5,
        haloOpacity: 0.45,
        alphaMin: 0.18, alphaMax: 0.6,
        fps: 30,
        palette: [
            { r: 220, g: 232, b: 248, weight: 0.65 },
            { r: 150, g: 220, b: 255, weight: 0.25 },
            { r: 200, g: 180, b: 255, weight: 0.10 }
        ]
    },

    corners: { enabled: true, color: 'rgba(95, 224, 255, 0.55)', size: 22, thickness: 2, inset: 14 },

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

    tabs: { rules: true, staff: true, news: true, defaultTab: 'rules' },

    // tone: 'owner' | 'admin' | 'dev' | 'mod'
    staff: [
        { name: 'Viktor', role: null, badge: null, tone: 'owner', avatar: 'V' },
        { name: 'Dora',   role: null, badge: null, tone: 'admin', avatar: 'D' },
        { name: 'Marcus', role: null, badge: null, tone: 'dev',   avatar: 'M' },
        { name: 'Esther', role: null, badge: null, tone: 'mod',   avatar: 'E' }
    ],
    staffDefaults: {
        owner: { roleKey: 'roles.founder',    badgeKey: 'badges.owner' },
        admin: { roleKey: 'roles.management', badgeKey: 'badges.admin' },
        dev:   { roleKey: 'roles.scripting',  badgeKey: 'badges.dev'   },
        mod:   { roleKey: 'roles.support',    badgeKey: 'badges.mod'   }
    },

    // icon: message-circle, discord, globe, shopping-bag, youtube, instagram, tiktok, link
    socials: [
        { icon: 'message-circle', url: 'https://discord.gg/yourserver' },
        { icon: 'globe',          url: 'https://yourserver.example'   },
        { icon: 'shopping-bag',   url: 'https://store.example'        }
    ],

    // tips dari data/tips.json (server) menang atas daftar ini
    tips: { enabled: true, intervalMs: 5000, fadeMs: 400, override: null },

    // berita dari data/news.json (server) menang atas items di sini
    news: {
        maxItems: 8,
        items: [
            // { title: 'Update musim dingin', date: '2026-07-24', tag: 'Update', body: ['Baris 1', 'Baris 2'] }
        ]
    },

    rules: null,               // array untuk override locale

    // panel setuju peraturan — diaktifkan dari server: setr fls:rulesGate 1
    rulesGate: { requireScroll: true, showDecline: true, dim: 0.72 },

    progress: {
        simulate: true,
        intervalMs: 380,
        stepMin: 0.02,
        stepMax: 0.07,
        logHoldMs: 2500
    }
};
