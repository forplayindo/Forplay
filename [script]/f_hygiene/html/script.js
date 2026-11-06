function setBar(key, value, invertColor) {
    const fill = document.getElementById('fill-' + key);
    if (!fill) return;
    value = Math.max(0, Math.min(100, value));
    fill.style.width = value + '%';

    const ratio = invertColor ? value : (100 - value);
    let color;
    if (ratio < 50) color = '#4caf50';
    else if (ratio < 80) color = '#ffb300';
    else color = '#e53935';
    fill.style.backgroundColor = color;

    const pct = document.getElementById('pct-' + key);
    if (pct) pct.textContent = Math.round(value) + '%';
}

// dengung lalat: satu loop, volume diatur dari client (jarak ke player kotor terdekat), dihaluskan biar tidak loncat
const fliesAudio = new Audio('sounds/flies.wav');
fliesAudio.loop = true;
fliesAudio.volume = 0;
let fliesTarget = 0;

setInterval(() => {
    const cur = fliesAudio.volume;
    if (cur === fliesTarget) return;
    const next = Math.abs(fliesTarget - cur) < 0.02 ? fliesTarget : cur + (fliesTarget - cur) * 0.2;
    fliesAudio.volume = Math.max(0, Math.min(1, next));
    if (fliesAudio.volume === 0) fliesAudio.pause();
}, 50);

function setFliesVolume(volume) {
    fliesTarget = Math.max(0, Math.min(1, volume || 0));
    if (fliesTarget > 0 && fliesAudio.paused) fliesAudio.play().catch(() => {});
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'update') {
        setBar('mandi', data.mandi, true);
        setBar('kencing', data.kencing, true);
        setBar('poop', data.poop, true);
    } else if (data.action === 'visibility') {
        document.getElementById('hygiene-hud').classList.toggle('hidden', !data.visible);
    } else if (data.action === 'flies') {
        setFliesVolume(data.volume);
    } else if (data.action === 'keybind') {
        const el = document.getElementById('hg-keybind');
        if (el) el.textContent = data.key;
    }
});
