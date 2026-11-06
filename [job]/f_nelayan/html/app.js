const $ = (id) => document.getElementById(id);
let D = null;            // menu payload dari server
let busy = false;

const rupiah = (n) => 'Rp ' + Math.floor(n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({ ok: false, msg: 'Server tidak merespons.' }));
}

function showMsg(text, ok) {
    $('msg').textContent = text || '';
    $('msg').classList.toggle('ok', !!ok);
    $('msg').classList.toggle('hidden', !text);
}

/* ---------------- menu Syahbandar + kru ---------------- */
const icon = (id) => `<svg class="ic"><use href="#${id}"/></svg>`;

function render() {
    const crew = D.crew;
    const isLeader = !crew || crew.leader === D.me;
    const started = crew && crew.phase === 'work';
    const editable = isLeader && !started;

    // daftar ikan: harga + peluang di spot dekat / jauh
    $('prices').innerHTML = (D.fish || []).map((f) => {
        const where = [f.near ? `dekat ${f.near}%` : '', f.far ? `jauh ${f.far}%` : ''].filter(Boolean).join(' · ');
        return `<div class="row"><svg class="ic t-accent">${f.rare ? '<use href="#i-star"/>' : '<use href="#i-fish"/>'}</svg>
            <span class="t">${esc(f.label)}${f.rare ? ' <span class="chip">Langka</span>' : ''}<small>${esc(where)}</small></span>
            <span class="d">${rupiah(f.price)}</span></div>`;
    }).join('');
    $('price-info').textContent = `Jenis ikan acak tiap tarikan. Spot jauh lebih sering dapat ikan mahal. Tarikan sempurna (3/3) +${D.perfectBonus}%.`;
    $('nets').textContent = `${D.nets} buah`;
    $('net-info').textContent = `Rusak setelah ${D.netUses} kali dapat ikan · beli ${rupiah(D.netPrice)} di Syahbandar`;

    // kru
    const members = crew ? crew.members : [{ id: D.me, name: 'Kamu', sold: 0 }];
    $('crew-count').textContent = `(${members.length}/${D.maxCrew})`;
    $('crew').innerHTML = members.map((m) => {
        const lead = crew ? m.id === crew.leader : true;
        const extra = started ? `${m.sold || 0} peti terjual` : `ID ${m.id}`;
        const right = editable && crew && !lead
            ? `<button class="b b-sm b-red-tint" data-kick="${m.id}">Keluarkan</button>`
            : `<span class="d">${esc(extra)}</span>`;
        return `<div class="row"><span class="sq" style="--c:${lead ? '#f3b354' : '#5e5ce6'}">${icon(lead ? 'i-crown' : 'i-user')}</span>
            <span class="t">${esc(m.name)}${m.id === D.me ? ' <span class="chip">Kamu</span>' : ''}<small>${lead ? 'Ketua' : 'Anggota'}</small></span>
            ${right}</div>`;
    }).join('');
    $('crew-info').textContent = `Kapal muat ${D.perPlayer} peti per orang (${members.length} orang = ${D.perPlayer * members.length} peti). Tangkapan dibagi rata, tiap orang memuat bagiannya ke bison sendiri.`;

    // ajak pemain
    $('near-wrap').classList.toggle('hidden', !editable);
    const full = crew && crew.members.length >= D.maxCrew;
    $('near').innerHTML = (D.nearby || []).map((p) => `<div class="row"><span class="sq">${icon('i-user')}</span>
        <span class="t">${esc(p.name)}<small>ID ${p.id}</small></span>
        ${p.invited ? '<span class="chip info">Diajak</span>' : `<button class="cap tint" data-invite="${p.id}" ${full ? 'disabled' : ''}>${icon('i-plus')}Ajak</button>`}</div>`).join('');

    // status + tombol
    let status = '';
    if (started) status = `Sedang melaut · spot ${crew.spot ? crew.spot.label : '-'} · bagianmu terjual ${crew.sold} peti (${rupiah(crew.earned)})`;
    else if (crew && !isLeader) status = 'Menunggu ketua memulai melaut.';
    $('status').textContent = status;
    $('status').classList.toggle('hidden', !status);

    $('start').classList.toggle('hidden', !editable);
    $('start').disabled = busy;
    $('start').textContent = busy ? 'Menyiapkan kapal...' : crew && crew.members.length > 1 ? `Mulai Melaut (${crew.members.length} orang)` : 'Mulai Melaut';

    $('leave').classList.toggle('hidden', !crew);
    $('leave').textContent = !isLeader ? 'Keluar Kru' : started ? 'Selesai Kerja' : 'Bubarkan';
    $('leave').style.flex = editable ? '' : '1';
    if ($('leave').dataset.confirm === '1') $('leave').textContent = 'Yakin? Ikan hangus';
}

function load(data) {
    D = data;
    render();
}

$('near').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-invite]');
    if (!b || b.disabled || busy) return;
    busy = true;
    b.disabled = true;
    const res = await post('invite', { id: Number(b.dataset.invite) });
    busy = false;
    if (res && res.ok && res.data) {
        showMsg('Ajakan terkirim.', true);
        load(res.data);
    } else {
        showMsg((res && res.msg) || 'Gagal mengajak pemain.');
        render();
    }
});

$('crew').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-kick]');
    if (!b || busy) return;
    busy = true;
    b.disabled = true;
    const data = await post('kick', { id: Number(b.dataset.kick) });
    busy = false;
    if (data && data.maxCrew) {
        showMsg('Anggota dikeluarkan.', true);
        load(data);
    } else {
        render();
    }
});

$('refresh').addEventListener('click', async () => {
    const data = await post('refresh');
    if (data && data.maxCrew) load(data);
});

$('start').addEventListener('click', async () => {
    if (busy || $('start').disabled) return;
    busy = true;
    render();
    const res = await post('start');
    busy = false;
    if (!res || !res.ok) {
        showMsg((res && res.msg) || 'Gagal memulai.');
        render();
    }
});

$('leave').addEventListener('click', async () => {
    if (busy) return;
    const crew = D && D.crew;
    // ketua yang sedang melaut: ikan yang belum dijual hangus, minta konfirmasi sekali
    if (crew && crew.phase === 'work' && crew.leader === D.me && $('leave').dataset.confirm !== '1') {
        $('leave').dataset.confirm = '1';
        showMsg('Selesai kerja membubarkan kru dan mengembalikan kapal. Peti yang belum dijual hangus. Tekan lagi untuk lanjut.');
        render();
        return;
    }
    busy = true;
    const data = await post('leave');
    busy = false;
    $('leave').dataset.confirm = '';
    showMsg('');
    if (data && data.maxCrew) load(data);
    else post('close');
});

const close = () => post('close');
$('close').addEventListener('click', close);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });

/* ---------------- HUD progres ---------------- */
function renderHud(h) {
    if (!h) return $('hud').classList.add('hidden');
    $('h-title').textContent = h.title;
    $('h-sub').textContent = h.sub || '';
    $('h-rows').innerHTML = (h.rows || []).map(([l, v]) => `<div class="hud-row"><span>${esc(l)}</span><b>${esc(v)}</b></div>`).join('');
    $('h-earned').textContent = rupiah(h.earned);
    $('h-tip').textContent = h.tip || '';
    $('h-tip').classList.toggle('hidden', !h.tip);
    $('hud').classList.remove('hidden');
}

/* ---------------- tarik-ulur jaring ---------------- */
// penanda bolak-balik; tiap putaran zona hijau acak. [E] ditangkap Lua lalu dikirim sebagai 'pullHit'.
const P = { on: false };

function pullRound() {
    const w = P.cfg.zone * 100;
    P.zoneStart = 8 + Math.random() * (84 - w);
    $('pull-zone').style.left = P.zoneStart + '%';
    $('pull-zone').style.width = w + '%';
    $('pull-round').textContent = `${P.round + 1}/${P.cfg.rounds}`;
    $('pull').querySelector('.pull-bar').classList.remove('hit', 'miss');
    P.roundStart = performance.now();
    P.locked = false;
}

function pullFrame(t) {
    if (!P.on) return;
    // posisi 0..100 bolak-balik, kecepatan = sapuan penuh per detik x speed
    const phase = ((t - P.t0) / 1000) * P.cfg.speed;
    const x = phase % 2 < 1 ? (phase % 1) * 100 : (1 - (phase % 1)) * 100;
    P.x = x;
    $('pull-cursor').style.left = x + '%';
    // tidak menekan 4 detik = meleset
    if (!P.locked && t - P.roundStart > 4000) pullResult(false);
    requestAnimationFrame(pullFrame);
}

function pullResult(ok) {
    P.locked = true;
    if (ok) P.hits++;
    $('pull').querySelector('.pull-bar').classList.add(ok ? 'hit' : 'miss');
    $('pull-dots').children[P.round].className = ok ? 'ok' : 'no';
    P.round++;
    setTimeout(() => {
        if (!P.on) return;
        if (P.round >= P.cfg.rounds) {
            P.on = false;
            $('pull').classList.add('hidden');
            post('pullDone', { hits: P.hits });
        } else {
            pullRound();
        }
    }, 450);
}

function pullStart(cfg) {
    P.cfg = cfg; P.on = true; P.round = 0; P.hits = 0; P.t0 = performance.now();
    $('pull-dots').innerHTML = '<i></i>'.repeat(cfg.rounds);
    $('pull').classList.remove('hidden');
    pullRound();
    requestAnimationFrame(pullFrame);
}

function pullHit() {
    if (!P.on || P.locked) return;
    const z0 = P.zoneStart, z1 = P.zoneStart + P.cfg.zone * 100;
    pullResult(P.x >= z0 && P.x <= z1);
}

window.addEventListener('message', ({ data }) => {
    if (data.action === 'hud') return renderHud(data.data);
    if (data.action === 'pull') return pullStart(data.data);
    if (data.action === 'pullHit') return pullHit();
    if (data.action === 'open') {
        showMsg('');
        $('leave').dataset.confirm = '';
        load(data.data);
        $('panel').classList.remove('hidden');
    } else if (data.action === 'update') {
        load(data.data);
    } else if (data.action === 'close') {
        $('panel').classList.add('hidden');
    }
});