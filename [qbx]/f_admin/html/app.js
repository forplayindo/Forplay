'use strict';
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_admin';
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const ic = (n) => `<svg class="ic"><use href="#i-${n}"/></svg>`;
const rp = (n) => 'Rp ' + Math.floor(n || 0).toLocaleString('id-ID');
const ini = (s) => String(s || '?').split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
const ROLE_LABEL = { owner: 'Owner', admin: 'Admin', support: 'Support' };
const IMG_ITEM = 'nui://ox_inventory/web/images/';
const IMG_VEH = 'nui://f_vehimages/images/';

const post = (name, data) =>
    fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) }).then((r) => r.json()).catch(() => null);
const req = (name, data) => post('req', { name, data });
const act = (name, data) => post('act', { name, data });

let S = null;      // sesi dari server: role, me, can, stats, state
let page = 'home';
let toastT;
const can = (k) => !!(S && S.can[k]);
const isOwner = () => S && S.role === 'owner';

function toast(text, bad) {
    const t = $('#toast');
    t.className = 'toast ' + (bad ? 'bad' : 'ok');
    t.textContent = text;
    clearTimeout(toastT);
    toastT = setTimeout(() => t.classList.add('hidden'), 3500);
}

// hasil callback server: tampilkan pesan, kembalikan true kalau berhasil
function done(r, okMsg) {
    if (!r) { toast('Tidak ada respon server.', true); return false; }
    if (r.msg || (r.ok && okMsg)) toast(r.msg || okMsg, !r.ok);
    return !!r.ok;
}

function img(src, label, cls = '') {
    return `<img class="${cls}" src="${src}" loading="lazy" alt="" onerror="this.outerHTML='<div class=&quot;ph ${cls}&quot;>${esc(String(label || '?')[0]).toUpperCase()}</div>'">`;
}

// ---------------------------------------------------------------- navigasi
const PAGES = [
    { id: 'home', t: 'Ringkasan', i: 'home', sub: 'Mode staff & aksi cepat', ok: () => true },
    { id: 'players', t: 'Pemain', i: 'users', sub: 'Pemain online', ok: () => true },
    { id: 'items', t: 'Beri Item', i: 'box', sub: 'Kirim item ke pemain · tercatat di Discord', ok: () => can('give.item') },
    { id: 'veh', t: 'Kendaraan', i: 'car', sub: 'Spawn sementara, beri ke garasi, kendaraan saat ini', ok: () => ['vehicle.spawn', 'give.vehicle', 'vehicle.fix', 'vehicle.delete', 'vehicle.save', 'vehicle.tune', 'vehicle.plate'].some(can) },
    { id: 'reports', t: 'Laporan', i: 'flag', sub: 'Laporan warga dari /lapor', ok: () => can('reports.manage') },
    { id: 'pets', t: 'Pengajuan Hewan', i: 'heart', sub: 'Setujui / tolak pemain yang ingin memiliki hewan peliharaan', ok: () => S.role === 'owner' || S.role === 'admin' },
    { id: 'server', t: 'Server', i: 'server', sub: 'Cuaca, waktu, radio, stash, pengumuman', ok: () => ['server.weather', 'server.time', 'server.radio', 'server.stash', 'server.announce'].some(can) },
    { id: 'bans', t: 'Daftar Ban', i: 'ban', sub: 'Ban HWID dari panel & anti-cheat', ok: () => can('player.unban') },
    { id: 'dev', t: 'Developer', i: 'code', sub: 'Koordinat & entity', ok: () => can('dev.tools') },
    { sep: 'Owner', ok: isOwner },
    { id: 'staff', t: 'Staff', i: 'shield', sub: 'Angkat / ubah / copot Admin & Support', ok: isOwner },
    { id: 'perms', t: 'Daftar Command', i: 'key', sub: 'Atur command & aksi yang boleh untuk Admin dan Support', ok: isOwner },
    { id: 'logs', t: 'Log Discord', i: 'send', sub: 'Webhook & jenis log', ok: isOwner },
];

function renderNav() {
    const rc = S.stats.reports || 0;
    $('#nav').innerHTML = PAGES.filter((p) => p.ok()).map((p) => p.sep
        ? `<div class="sep-h">${p.sep}</div>`
        : `<button data-p="${p.id}" class="${p.id === page ? 'active' : ''}">${ic(p.i)}${p.t}${p.id === 'reports' && rc ? `<span class="bubble">${rc}</span>` : ''}${p.id === 'pets' && S.stats.pets ? `<span class="bubble">${S.stats.pets}</span>` : ''}</button>`).join('');
}

$('#nav').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-p]');
    if (b) go(b.dataset.p);
});

function go(id) {
    const p = PAGES.find((x) => x.id === id && !x.sep && x.ok()) || PAGES[0];
    page = p.id;
    $('#pgTitle').textContent = p.t;
    $('#pgSub').textContent = p.sub;
    renderNav();
    closeModal();
    const el = $('#page');
    el.className = 'body' + (['players', 'items', 'veh'].includes(page) ? ' flush' : '') + (page === 'perms' ? ' flush col' : '') + (page === 'reports' ? ' chat' : '');
    el.onclick = el.oninput = el.onchange = el.onkeydown = null;
    el.innerHTML = '<div class="empty">Memuat…</div>';
    R[page](el);
}

// tombol dengan izin
const pbtn = (k, label, icon, a, cls = '', on = false) => can(k)
    ? `<button data-act="${a}" class="${cls}${on ? ' on' : ''}">${ic(icon)}${label}</button>`
    : `<button class="${cls}" disabled title="Tidak punya izin">${ic(icon)}${label}<svg class="ic lk"><use href="#i-lock"/></svg></button>`;

const R = {};

// ---------------------------------------------------------------- modal
// extra(e): klik lain di dalam modal (mis. tombol tambahan)
function modal(html, onOk, okLabel = 'Kirim', extra) {
    $('#modal').innerHTML = `<div class="modal-bg"><div class="modal">${html}
        <div class="row2"><button class="b b-gray" data-m="x">Batal</button><button class="b b-filled" data-m="ok">${okLabel}</button></div></div></div>`;
    $('#modal').onclick = async (e) => {
        if (extra && extra(e)) return;
        const b = e.target.closest('[data-m]');
        if (e.target.classList.contains('modal-bg') || (b && b.dataset.m === 'x')) return closeModal();
        if (b && b.dataset.m === 'ok' && !b.disabled) {
            b.disabled = true;
            const r = await onOk();
            b.disabled = false;
            if (r !== false) closeModal();
        }
    };
    const f = $('#modal').querySelector('input,textarea');
    if (f) f.focus();
}
function closeModal() { $('#modal').innerHTML = ''; }
const modalOpen = () => !!$('#modal').innerHTML;

function modalText(title, ph, cb, okLabel) {
    modal(`<h2>${title}</h2><textarea id="mt" maxlength="300" placeholder="${ph}"></textarea>`, () => {
        const v = $('#mt').value.trim();
        if (!v) { toast('Isi dulu.', true); return false; }
        return cb(v);
    }, okLabel);
}

// ================================================================ RINGKASAN
R.home = async (el) => {
    const st = S.state || {};
    const q = (k, s, t, d, i, c) => `<button data-self="${s}" class="${st[s] ? 'on' : ''}" ${can(k) ? '' : 'disabled'}><span class="sq" style="--c:${c}">${ic(i)}</span><span>${t}<small>${d}</small></span></button>`;
    const a = (k, s, t, d, i, c) => `<button data-do="${s}" ${can(k) ? '' : 'disabled'}><span class="sq" style="--c:${c}">${ic(i)}</span><span>${t}<small>${d}</small></span></button>`;
    const draw = () => {
        const s = S.stats;
        el.innerHTML = `
            <div class="stats">
                <div class="stat"><small>Pemain online</small><b class="num">${s.players}<span class="t-muted" style="font-size:14px"> / ${s.maxPlayers}</span></b></div>
                <div class="stat"><small>Staff online</small><b class="num">${s.staff}</b></div>
                <div class="stat"><small>Laporan terbuka</small><b class="num ${s.reports ? 't-orange' : ''}">${s.reports}</b></div>
                <div class="stat"><small>Uptime server</small><b class="num">${Math.floor(s.uptime / 60)}j ${s.uptime % 60}m</b></div>
            </div>
            <div class="sec"><div class="group-h">Mode staff</div><div class="qa">
                ${q('self.noclip', 'noclip', 'Noclip', 'Terbang tembus objek', 'ghost', 'var(--purple)')}
                ${q('self.godmode', 'god', 'God Mode', 'Tidak bisa mati', 'star', 'var(--accent)')}
                ${q('self.invisible', 'invis', 'Tidak Terlihat', 'Pemain lain tak melihat', 'eye', 'var(--teal)')}
                ${q('self.names', 'names', 'Nama Pemain', 'ID & nama di kepala', 'tag', 'var(--blue)')}
                ${q('self.blips', 'blips', 'Blip Pemain', 'Semua pemain di peta', 'pin', 'var(--green)')}
                ${q('self.vehgod', 'vehgod', 'Godmode Kendaraan', 'Kendaraan tidak rusak', 'shield', 'var(--orange)')}
                ${q('self.ammo', 'ammo', 'Amunisi Tak Terbatas', 'Tidak perlu reload', 'gun', 'var(--red)')}
                ${q('self.cuff', 'cuff', 'Borgol', 'Borgol / lepas diri sendiri', 'link', 'var(--gray)')}
            </div></div>
            <div class="sec"><div class="group-h">Aksi cepat</div><div class="qa cols3">
                ${a('player.revive', 'revself', 'Revive Diri', 'Hidup + darah penuh', 'heart', 'var(--red)')}
                ${a('player.revive', 'healself', 'Heal Diri', 'Darah & armor penuh', 'heart', 'var(--green)')}
                ${a('self.teleport', 'tpm', 'Ke Waypoint', 'Teleport ke tanda peta', 'pin', 'var(--orange)')}
                ${a('self.teleport', 'back', 'Kembali', 'Ke posisi sebelum teleport', 'return', 'var(--gray)')}
                ${a('vehicle.fix', 'fix', 'Perbaiki Kendaraan', 'Kendaraan yang dinaiki', 'wrench', 'var(--gray)')}
                ${a('vehicle.delete', 'dv', 'Hapus Kendaraan', 'Dinaiki / terdekat 5 m', 'trash', 'var(--red)')}
                ${a('server.announce', 'announce', 'Pengumuman', 'Ke tab Pengumuman chat', 'msg', 'var(--blue)')}
                ${a('self.ped', 'ped', 'Ganti Model Ped', 'Contoh a_m_m_soucent_04', 'user', 'var(--purple)')}
                ${a('self.weapons', 'weapons', 'Beri Semua Senjata', 'Per kategori ke diri sendiri', 'gun', 'var(--red)')}
            </div></div>
            <div class="notice">${{
                owner: 'Kamu <b>Owner</b>: akses penuh termasuk uang. Atur staff di <b>Staff</b>, izin di <b>Daftar Command</b>.',
                admin: 'Kamu <b>Admin</b>: semua fitur kecuali memberi/mengatur uang. Setiap aksi tercatat di Discord.',
                support: 'Kamu <b>Support</b>: bantu & pantau kota. Noclip/teleport kebal anti-cheat, setiap aksi tercatat di Discord.',
            }[S.role]}</div>`;
    };
    draw();
    el.onclick = async (e) => {
        const s = e.target.closest('[data-self]');
        if (s && !s.disabled) {
            const r = await act('self', { k: s.dataset.self });
            if (r && r.ok) { S.state = r.state; s.classList.toggle('on', r.on); }
            else if (r && r.msg) toast(r.msg, true);
            return;
        }
        const d = e.target.closest('[data-do]');
        if (!d || d.disabled) return;
        switch (d.dataset.do) {
            case 'revself': return done(await req('player_act', { act: 'revive', id: S.me.id }));
            case 'healself': return done(await req('player_act', { act: 'heal', id: S.me.id }));
            case 'tpm': return done(await act('tpm'));
            case 'back': return done(await req('self_back'));
            case 'fix': return done(await act('fix'));
            case 'dv': return done(await act('dv'));
            case 'announce': return modalText('Pengumuman kota', 'Isi pengumuman… (tampil di tab Pengumuman sebagai Admin)', async (v) => done(await act('announce', { text: v })) || false);
            case 'ped': return modal(`<h2>Ganti Model Ped</h2><input id="pm" placeholder="a_m_m_soucent_04">
                <button class="b b-gray b-block" id="pedReset">${ic('return')} Kembalikan karakter asli</button>`, async () => done(await act('ped', { model: $('#pm').value.trim() })) || false, 'Ganti',
                (ev) => { if (!ev.target.closest('#pedReset')) return false; act('pedreset').then((r) => done(r)); closeModal(); return true; });
            case 'weapons': return modal(`<h2>Beri Semua Senjata</h2><select id="wc">${S.weapons.map((w) => `<option value="${w}">${w.toUpperCase()}</option>`).join('')}</select>
                <p class="hint t-muted">Ke tas kamu sendiri. Tercatat di Discord.</p>`, async () => done(await req('weapons', { cat: $('#wc').value })) || false, 'Ambil');
        }
    };
    const r = await req('home');
    if (r && r.ok && page === 'home') { S.stats = r.stats; renderNav(); draw(); }
};

// ================================================================ PEMAIN
let players = [], selP = null, pq = '', pDetail = null;

async function loadPlayers() {
    const r = await req('players');
    if (r && r.ok) players = r.players;
    return players;
}

const playerOpts = (sel) => players.map((p) => `<option value="${p.id}" ${p.id === sel ? 'selected' : ''}>[${p.id}] ${esc(p.name)}</option>`).join('');

R.players = async (el) => {
    el.innerHTML = `
        <div class="plist">
            <div class="pbar"><label class="search">${ic('search')}<input id="pq" placeholder="Cari nama, ID, citizenid" value="${esc(pq)}"></label>
                <button class="icon-btn" id="pRef" title="Muat ulang">${ic('refresh')}</button></div>
            <div class="scroll" id="plRows"><div class="empty">Memuat…</div></div>
        </div>
        <div class="pdetail" id="pDet"><div class="empty">Pilih pemain</div></div>`;
    await loadPlayers();
    if (page !== 'players') return;
    if (selP && !players.some((p) => p.id === selP)) selP = null;
    rows();
    if (selP) det();
    el.oninput = (e) => { if (e.target.id === 'pq') { pq = e.target.value; rows(); } };
    el.onclick = async (e) => {
        if (e.target.closest('#pRef')) { await loadPlayers(); rows(); if (selP) det(); return; }
        const r = e.target.closest('.prow');
        if (r) { selP = +r.dataset.id; rows(); det(); return; }
        const b = e.target.closest('button[data-act]');
        if (b && !b.disabled) playerAct(b.dataset.act);
    };
};

function rows() {
    const q = pq.toLowerCase();
    const list = players.filter((p) => !q || String(p.id) === q || p.name.toLowerCase().includes(q) || String(p.cid).toLowerCase().includes(q) || String(p.ooc).toLowerCase().includes(q));
    $('#plRows').innerHTML = list.map((p) => `
        <button class="prow ${p.id === selP ? 'sel' : ''}" data-id="${p.id}">
            <span class="id">${p.id}</span>
            <span class="t"><b>${esc(p.name)} ${p.role ? `<span class="role ${p.role}">${ROLE_LABEL[p.role]}</span>` : ''}</b><small>${esc(p.job)} · ${esc(p.ooc)}</small></span>
            ${p.dead ? '<span class="chip red">Pingsan</span>' : ''}
            <span class="ping">${p.ping}ms</span>
        </button>`).join('') || '<div class="empty">Tidak ada pemain</div>';
}

async function det() {
    const id = selP;
    const r = await req('player', { id });
    if (id !== selP || page !== 'players') return;
    if (!r || !r.ok) { $('#pDet').innerHTML = `<div class="empty">${esc(r?.msg || 'Gagal memuat')}</div>`; return; }
    const p = pDetail = r.player;
    const me = p.id === S.me.id;
    $('#pDet').innerHTML = `
        <div class="phead">
            <div class="av">${ini(p.name)}</div>
            <div><h2>${esc(p.name)} ${p.role ? `<span class="role ${p.role}">${ROLE_LABEL[p.role]}</span>` : ''}</h2>
                <small>ID ${p.id} · ${esc(p.ooc)} · ${esc(p.cid)} · bucket ${p.bucket}</small></div>
        </div>
        <div class="kv">
            <div><small>Job</small><b>${esc(p.job)}</b></div>
            <div><small>Gang</small><b>${esc(p.gang ?? '-')}</b></div>
            <div><small>Uang tunai</small><b>${rp(p.cash)}</b></div>
            <div><small>Bank</small><b>${rp(p.bank)}</b></div>
            <div><small>Darah / Armor</small><b>${p.hp} / ${p.armor ?? 0}</b></div>
            <div><small>Makan / Minum</small><b>${p.food ?? '-'}% / ${p.water ?? '-'}%</b></div>
            <div><small>Stres</small><b>${p.stress ?? '-'}%</b></div>
            <div><small>Ping</small><b>${p.ping} ms</b></div>
            <div><small>No HP</small><b>${esc(p.phone ?? '-')}</b></div>
            <div><small>Radio</small><b>${esc(p.radio ?? '-')}</b></div>
            <div><small>Rep. Crafting / Dealer</small><b>${p.repc ?? 0} / ${p.repd ?? 0}</b></div>
            <div><small>Status</small><b>${[p.dead && 'Pingsan', p.frozen && 'Beku', p.muted && 'Mute'].filter(Boolean).join(', ') || 'Normal'}</b></div>
        </div>
        <small class="t-muted">${esc(p.license)} · ${esc(p.discord)}</small>
        <div class="gh">Bantuan</div>
        <div class="btns">
            ${me ? '' : pbtn('player.goto', 'Datangi', 'arrow-in', 'goto')}
            ${me ? '' : pbtn('player.bring', 'Tarik', 'arrow-out', 'bring')}
            ${me ? '' : pbtn('player.spectate', 'Spectate', 'eye', 'spectate')}
            ${pbtn('player.freeze', p.frozen ? 'Cairkan' : 'Bekukan', 'snow', 'freeze', '', p.frozen)}
            ${pbtn('player.revive', 'Revive', 'heart', 'revive')}
            ${pbtn('player.revive', 'Heal', 'heart', 'heal')}
            ${me ? '' : pbtn('player.dm', 'Pesan', 'msg', 'dm')}
            ${pbtn('vehicle.fix', 'Perbaiki Mobil', 'wrench', 'fixveh')}
            ${p.canBack ? pbtn('player.goto', 'Kembalikan', 'return', 'sendback') : ''}
            ${me ? '' : pbtn('player.sitveh', 'Duduk di Mobil', 'chair', 'sitveh')}
            ${pbtn('player.bucket', 'Routing Bucket', 'layers', 'bucket')}
            ${pbtn('player.mute', p.muted ? 'Unmute' : 'Mute', 'mute', 'mute', '', p.muted)}
        </div>
        <div class="gh">Data pemain</div>
        <div class="btns">
            ${pbtn('give.item', 'Beri Item', 'box', 'giveitem')}
            ${pbtn('give.vehicle', 'Beri Mobil', 'car', 'giveveh')}
            ${pbtn('give.money', 'Uang', 'cash', 'money')}
            ${pbtn('player.setjob', 'Job / Gang', 'briefcase', 'setjob')}
            ${pbtn('player.inventory', 'Inventaris', 'box', 'inventory')}
            ${pbtn('player.clothing', 'Pakaian', 'shirt', 'clothing')}
            ${pbtn('player.setdata', 'Ubah Data', 'edit', 'setdata')}
        </div>
        ${me ? '' : `<div class="gh">Sanksi</div>
        <div class="btns">
            ${pbtn('player.kick', 'Kick', 'arrow-out', 'kick', 'red')}
            ${pbtn('player.ban', 'Ban', 'ban', 'ban', 'red')}
            ${pbtn('player.kill', 'Bunuh', 'skull', 'kill', 'red')}
        </div>`}
        ${isOwner() ? '' : '<p class="hint t-muted" style="margin-top:12px">Tombol terkunci = tidak diizinkan untuk role kamu (diatur Owner di Daftar Command). Sanksi tidak bisa ke staff setara/lebih tinggi.</p>'}`;
}

async function pa(a, extra) {
    const r = await req('player_act', Object.assign({ act: a, id: pDetail.id }, extra || {}));
    const ok = done(r);
    if (ok && r.gone) { selP = null; await loadPlayers(); if (page === 'players') { rows(); $('#pDet').innerHTML = '<div class="empty">Pilih pemain</div>'; } }
    else if (ok && page === 'players') det();
    return ok;
}

function playerAct(a) {
    const p = pDetail;
    if (!p) return;
    const n = esc(p.name);
    switch (a) {
        case 'giveitem': selTarget = p.id; return go('items');
        case 'giveveh': selTarget = p.id; return go('veh');
        case 'money': return modalMoney(p);
        case 'setjob': return modalJob(p);
        case 'setdata': return modalData(p);
        case 'bucket': return modal(`<h2>Routing bucket ${n}</h2><input id="rb" type="number" min="0" value="${p.bucket}"><p class="hint t-muted">0 = dunia normal.</p>`,
            () => pa('bucket', { bucket: +$('#rb').value || 0 }), 'Pindahkan');
        case 'dm': return modalText(`Pesan ke ${n}`, 'Tulis pesan… (pemain melihat "Pesan dari Staff")', (v) => pa('dm', { text: v }));
        case 'kick': return modalText(`Kick ${n}`, 'Alasan kick', (v) => pa('kick', { text: v }), 'Kick');
        case 'ban': return modalBan(p);
        case 'kill': return modal(`<h2>Bunuh ${n}?</h2><p class="hint t-muted">Tercatat di Discord.</p>`, () => pa('kill'), 'Bunuh');
        default: return pa(a);
    }
}

function modalBan(p) {
    modal(`<h2>Ban ${esc(p.name)}</h2>
        <div class="row2"><label><span>Jam</span><input id="bh" type="number" min="0" value="0"></label><label><span>Hari</span><input id="bd" type="number" min="0" value="3"></label><label><span>Bulan</span><input id="bm" type="number" min="0" value="0"></label></div>
        <label class="check"><input type="checkbox" id="bperm"><span style="margin:0">Permanen</span></label>
        <label><span>Alasan</span><textarea id="br" maxlength="200" placeholder="Alasan ban"></textarea></label>
        <p class="hint t-muted">Disimpan: semua identifier + hardware token PC. Akun baru dari PC yang sama ikut tertolak. Tidak perlu ban ulang di txAdmin.</p>`, () => {
        const reason = $('#br').value.trim();
        if (!reason) { toast('Isi alasan ban.', true); return false; }
        return pa('ban', { text: reason, perm: $('#bperm').checked, hours: +$('#bh').value || 0, days: +$('#bd').value || 0, months: +$('#bm').value || 0 });
    }, 'Ban');
}

function modalData(p) {
    const sl = (id, t, v) => `<label><span>${t}</span><div class="range"><input id="${id}" type="range" min="0" max="100" value="${v || 0}" oninput="this.nextElementSibling.textContent=this.value+'%'"><b class="num">${v || 0}%</b></div></label>`;
    modal(`<h2>Ubah data ${esc(p.name)}</h2>
        <div class="row2"><label><span>Nama depan</span><input id="dfn" maxlength="24" value="${esc(p.firstname || '')}"></label><label><span>Nama belakang</span><input id="dln" maxlength="24" value="${esc(p.lastname || '')}"></label></div>
        ${sl('dfo', 'Makan', p.food)}${sl('dwa', 'Minum', p.water)}${sl('dst', 'Stres', p.stress)}${sl('dar', 'Armor', p.armor)}
        <div class="row2"><label><span>No HP</span><input id="dph" maxlength="15" value="${esc(p.phone === '-' ? '' : p.phone)}"></label><label><span>Radio (frekuensi)</span><input id="dra" type="number" min="0" value="${p.radio === '-' ? '' : esc(p.radio)}"></label></div>
        <div class="row2"><label><span>Rep. Crafting</span><input id="drc" type="number" min="0" value="${p.repc || 0}"></label><label><span>Rep. Dealer</span><input id="drd" type="number" min="0" value="${p.repd || 0}"></label></div>`, async () => {
        const r = await req('set_data', {
            id: p.id, firstname: $('#dfn').value.trim(), lastname: $('#dln').value.trim(),
            food: +$('#dfo').value, water: +$('#dwa').value, stress: +$('#dst').value, armor: +$('#dar').value,
            phone: $('#dph').value.trim(), radio: $('#dra').value === '' ? null : +$('#dra').value, repc: +$('#drc').value, repd: +$('#drd').value,
        });
        if (done(r)) { det(); return true; }
        return false;
    }, 'Simpan');
}

function modalMoney(p) {
    modal(`<h2>Uang ${esc(p.name)}</h2>
        <p class="hint t-muted">Tunai ${rp(p.cash)} · Bank ${rp(p.bank)}</p>
        <div class="row2"><label><span>Jenis</span><select id="mty"><option value="cash">Tunai</option><option value="bank">Bank</option></select></label>
            <label><span>Aksi</span><select id="mac"><option value="give">Beri</option><option value="set">Atur jadi</option><option value="remove">Kurangi</option></select></label></div>
        <label><span>Jumlah (Rp)</span><input id="mam" type="number" min="0" placeholder="50000"></label>
        <p class="hint t-muted">Khusus Owner. Tercatat di Discord.</p>`, async () => {
        const r = await req('money', { id: p.id, kind: $('#mty').value, act: $('#mac').value, amount: +$('#mam').value || 0 });
        if (done(r)) { det(); return true; }
        return false;
    }, 'Simpan');
}

let jobsCache = null;
async function modalJob(p) {
    if (!jobsCache) {
        const r = await req('jobs');
        if (!r || !r.ok) return done(r);
        jobsCache = r;
    }
    let kind = 'job';
    const list = () => jobsCache[kind === 'job' ? 'jobs' : 'gangs'];
    const gradeOpts = (name) => (list().find((j) => j.name === name)?.grades || []).map((g) => `<option value="${g.level}">${g.level} · ${esc(g.name)}</option>`).join('');
    const nameOpts = () => list().map((j) => `<option value="${esc(j.name)}">${esc(j.label)} (${esc(j.name)})</option>`).join('');
    modal(`<h2>Job / Gang ${esc(p.name)}</h2>
        <div class="seg" id="jg"><button class="active" data-t="job">Job</button><button data-t="gang">Gang</button></div>
        <label><span>Nama</span><select id="jn">${nameOpts()}</select></label>
        <label><span>Grade</span><select id="jgd"></select></label>`, async () => {
        const r = await req('set_job', { id: p.id, kind, name: $('#jn').value, grade: +$('#jgd').value || 0 });
        if (done(r)) { det(); return true; }
        return false;
    }, 'Simpan');
    $('#jgd').innerHTML = gradeOpts($('#jn').value);
    $('#jn').onchange = () => { $('#jgd').innerHTML = gradeOpts($('#jn').value); };
    $('#jg').onclick = (e) => {
        const b = e.target.closest('button');
        if (!b) return;
        kind = b.dataset.t;
        $('#jg').querySelectorAll('button').forEach((x) => x.classList.toggle('active', x === b));
        $('#jn').innerHTML = nameOpts();
        $('#jgd').innerHTML = gradeOpts($('#jn').value);
    };
}

// ================================================================ BERI ITEM
let selTarget = null, cart = [], iq = '', itemsCache = null;
const LIMIT = 150;

R.items = async (el) => {
    el.innerHTML = `
        <div class="split2">
            <div class="l">
                <label class="search" style="width:auto;margin-bottom:12px">${ic('search')}<input id="iq" placeholder="Cari item (nama atau kode)" value="${esc(iq)}"></label>
                <div class="igrid" id="igrid"><div class="empty">Memuat…</div></div>
            </div>
            <div class="r">
                <div class="group-h" style="padding-top:0">Penerima</div>
                <div class="target"><select id="tgt"></select></div>
                <div class="group-h">Keranjang</div>
                <div class="cart" id="cart"></div>
                <div class="group-h">Pratinjau log Discord</div>
                <div class="logprev" id="lp"></div>
                <button class="b b-filled b-block" id="sendItems">${ic('send')} Kirim ke pemain</button>
            </div>
        </div>`;
    const [r] = await Promise.all([itemsCache ? null : req('items'), loadPlayers()]);
    if (r && r.ok) itemsCache = r.items;
    if (page !== 'items') return;
    if (!players.some((p) => p.id === selTarget)) selTarget = players[0]?.id ?? null;
    $('#tgt').innerHTML = playerOpts(selTarget);
    grid(); cartR();
    el.oninput = (e) => {
        if (e.target.id === 'iq') { iq = e.target.value; grid(); }
        if (e.target.dataset.q) { const c = cart.find((x) => x.n === e.target.dataset.q); c.c = Math.max(1, Math.min(10000, +e.target.value || 1)); lp(); }
    };
    el.onchange = (e) => { if (e.target.id === 'tgt') { selTarget = +e.target.value; lp(); } };
    el.onclick = async (e) => {
        const it = e.target.closest('.it');
        if (it) {
            const i = itemsCache.find((x) => x.n === it.dataset.n);
            const c = cart.find((x) => x.n === i.n);
            if (c) c.c++; else cart.push({ n: i.n, l: i.l, c: 1 });
            it.classList.add('sel'); cartR(); return;
        }
        const rm = e.target.closest('[data-rm]');
        if (rm) { cart = cart.filter((x) => x.n !== rm.dataset.rm); grid(); cartR(); return; }
        const send = e.target.closest('#sendItems');
        if (send && !send.disabled) {
            if (!cart.length) return toast('Keranjang kosong.', true);
            if (!selTarget) return toast('Pilih penerima.', true);
            send.disabled = true;
            const res = await req('give_items', { id: selTarget, items: cart.map((c) => ({ n: c.n, c: c.c })) });
            send.disabled = false;
            if (done(res)) { cart = []; grid(); cartR(); }
        }
    };
};

function grid() {
    if (!itemsCache) return;
    const q = iq.toLowerCase();
    const list = itemsCache.filter((i) => !q || i.n.includes(q) || i.l.toLowerCase().includes(q));
    $('#igrid').innerHTML = list.slice(0, LIMIT).map((i) => `<button class="it ${cart.some((c) => c.n === i.n) ? 'sel' : ''}" data-n="${esc(i.n)}">${img(IMG_ITEM + i.n + '.png', i.l)}<span>${esc(i.l)}</span><small class="t-muted">${esc(i.n)}</small></button>`).join('')
        + (list.length > LIMIT ? `<div class="more" style="grid-column:1/-1">+${list.length - LIMIT} item lain, ketik untuk mencari</div>` : '')
        || '<div class="empty" style="grid-column:1/-1">Tidak ada item</div>';
}

function cartR() {
    $('#cart').innerHTML = cart.map((c) => `
        <div class="row-c">${img(IMG_ITEM + c.n + '.png', c.l)}<span class="t">${esc(c.l)}</span>
            <input type="number" min="1" value="${c.c}" data-q="${esc(c.n)}">
            <button class="icon-btn close" data-rm="${esc(c.n)}">${ic('x')}</button></div>`).join('') || '<div class="empty" style="padding:16px">Klik item di kiri untuk menambah</div>';
    lp();
}

function lp() {
    const p = players.find((x) => x.id === selTarget);
    $('#lp').innerHTML = `<b>${esc(S.me.name)}</b> memberikan ${cart.map((c) => `${esc(c.l.toLowerCase())}${c.c > 1 ? ' x' + c.c : ''}`).join(', ') || '…'} ke <b>${esc(p ? `${p.name} (ID ${p.id})` : '-')}</b>
        <span class="ts">${ROLE_LABEL[S.role]} · ID ${S.me.id} → ID ${selTarget ?? '-'}</span>`;
}

// ================================================================ KENDARAAN
let vq = '', selV = null, vehCache = null, garages = [], selGarage = 'motelgarage';

R.veh = async (el) => {
    el.innerHTML = `
        <div class="split2">
            <div class="l">
                <label class="search" style="width:auto;margin-bottom:12px">${ic('search')}<input id="vq" placeholder="Cari kendaraan (nama, merek atau spawn code)" value="${esc(vq)}"></label>
                <div class="igrid" id="vgrid"><div class="empty">Memuat…</div></div>
            </div>
            <div class="r">
                <div class="group-h" style="padding-top:0">Dipilih</div>
                <div class="target" id="vsel"></div>
                <button class="b b-tinted b-block" id="vSpawn" ${can('vehicle.spawn') ? '' : 'disabled'}>${ic('bolt')} Spawn sementara</button>
                <div class="group-h">Beri ke garasi pemain</div>
                <div class="target"><select id="vtgt"></select></div>
                <div class="target"><select id="vgar"></select></div>
                <p class="hint t-muted">Plat otomatis format <b>F 1234 R</b>. Kunci fisik didapat pemain saat kendaraan pertama kali dikeluarkan dari garasi. Tercatat di Discord.</p>
                <button class="b b-filled b-block" id="vGive" ${can('give.vehicle') ? '' : 'disabled'}>${ic('send')} Beri kendaraan</button>
                <div class="group-h">Kendaraan yang kamu naiki</div>
                <div class="qa cols3">
                    <button data-v="fix" ${can('vehicle.fix') ? '' : 'disabled'}><span class="sq" style="--c:var(--gray)">${ic('wrench')}</span>Perbaiki</button>
                    <button data-v="clean" ${can('vehicle.fix') ? '' : 'disabled'}><span class="sq" style="--c:var(--teal)">${ic('broom')}</span>Bersihkan</button>
                    <button data-v="dv" ${can('vehicle.delete') ? '' : 'disabled'}><span class="sq" style="--c:var(--red)">${ic('trash')}</span>Hapus</button>
                    <button data-v="save" ${can('vehicle.save') ? '' : 'disabled'}><span class="sq" style="--c:var(--green)">${ic('garage')}</span>Beli</button>
                    <button data-v="tune" ${can('vehicle.tune') ? '' : 'disabled'}><span class="sq" style="--c:var(--purple)">${ic('gauge')}</span>Tuning</button>
                    <button data-v="plate" ${can('vehicle.plate') ? '' : 'disabled'}><span class="sq" style="--c:var(--blue)">${ic('plate')}</span>Plat</button>
                </div>
            </div>
        </div>`;
    const [r] = await Promise.all([vehCache ? null : req('vehicles'), loadPlayers()]);
    if (r && r.ok) { vehCache = r.vehicles; garages = r.garages; }
    if (page !== 'veh') return;
    if (!players.some((p) => p.id === selTarget)) selTarget = players[0]?.id ?? null;
    $('#vtgt').innerHTML = playerOpts(selTarget);
    $('#vgar').innerHTML = garages.map((g) => `<option value="${esc(g.name)}" ${g.name === selGarage ? 'selected' : ''}>Garasi: ${esc(g.label)}</option>`).join('') || '<option value="motelgarage">Garasi: Motel Parking</option>';
    vgrid(); vsel();
    el.oninput = (e) => { if (e.target.id === 'vq') { vq = e.target.value; vgrid(); } };
    el.onchange = (e) => {
        if (e.target.id === 'vtgt') selTarget = +e.target.value;
        if (e.target.id === 'vgar') selGarage = e.target.value;
    };
    el.onclick = async (e) => {
        const v = e.target.closest('.it');
        if (v) { selV = v.dataset.n; el.querySelectorAll('#vgrid .it').forEach((x) => x.classList.toggle('sel', x === v)); vsel(); return; }
        const sp = e.target.closest('#vSpawn');
        if (sp && !sp.disabled) { if (!selV) return toast('Pilih kendaraan dulu.', true); return done(await req('veh_spawn', { model: selV })); }
        const gv = e.target.closest('#vGive');
        if (gv && !gv.disabled) {
            if (!selV) return toast('Pilih kendaraan dulu.', true);
            if (!selTarget) return toast('Pilih pemain.', true);
            gv.disabled = true;
            done(await req('give_vehicle', { id: selTarget, model: selV, garage: $('#vgar').value }));
            gv.disabled = false;
            return;
        }
        const b = e.target.closest('[data-v]');
        if (!b || b.disabled) return;
        switch (b.dataset.v) {
            case 'fix': return done(await act('fix'));
            case 'clean': return done(await act('fix', { clean: true }));
            case 'dv': return done(await act('dv'));
            case 'tune': return done(await act('tune'));
            case 'plate': return modal(`<h2>Ganti Plat</h2><input id="np" placeholder="F 1234 R" maxlength="8" style="text-transform:uppercase"><p class="hint t-muted">Maks. 8 karakter. Kalau kendaraan milik pemain, plat di garasi ikut berubah.</p>`,
                async () => done(await req('veh_plate', { plate: $('#np').value })) || false, 'Ganti');
            case 'save': {
                const r = await req('veh_save', {});
                if (r && r.confirm) return modal(`<h2>Beli Kendaraan</h2><p>${esc(r.msg)}</p>`, async () => done(await req('veh_save', { force: true })) || false, 'Ganti pemilik');
                return done(r);
            }
        }
    };
};

function vgrid() {
    if (!vehCache) return;
    const q = vq.toLowerCase();
    const list = vehCache.filter((v) => !q || v.m.includes(q) || v.n.toLowerCase().includes(q) || v.b.toLowerCase().includes(q));
    $('#vgrid').innerHTML = list.slice(0, LIMIT).map((v) => `<button class="it v ${v.m === selV ? 'sel' : ''}" data-n="${esc(v.m)}">${img(IMG_VEH + v.m + '.webp', v.n, 'v')}<span>${esc(v.n)}</span><small class="t-muted">${esc(v.m)} · ${esc(v.c)}</small></button>`).join('')
        + (list.length > LIMIT ? `<div class="more" style="grid-column:1/-1">+${list.length - LIMIT} kendaraan lain, ketik untuk mencari</div>` : '')
        || '<div class="empty" style="grid-column:1/-1">Tidak ada kendaraan</div>';
}

function vsel() {
    const v = vehCache && vehCache.find((x) => x.m === selV);
    $('#vsel').innerHTML = v
        ? `<div class="sq" style="--c:var(--accent)">${ic('car')}</div><div class="t" style="flex:1;min-width:0"><b>${esc(v.n)}</b><small class="t-muted" style="display:block">${esc(v.b)} · ${esc(v.m)} · ${esc(v.c)}</small></div>`
        : '<span class="t-muted" style="font-size:13px">Klik kendaraan di kiri</span>';
}

// ================================================================ LAPORAN
let repOpen = null, repData = null;
const repStatus = (r) => r.claimed ? `<span class="chip blue">${esc(r.claimed)}</span>` : '<span class="chip orange">Baru</span>';

R.reports = async (el) => {
    if (repOpen === null) {
        const r = await req('reports');
        if (page !== 'reports' || repOpen !== null) return;
        if (!r || !r.ok) return done(r);
        el.innerHTML = r.reports.length ? `<div class="group">${r.reports.map((x) => `
            <button class="row" data-ro="${x.id}">
                <div class="t"><b>#${x.id} · ${esc(x.from)}</b> <small style="display:inline">${x.pid ? 'ID ' + x.pid : 'offline'} · ${esc(x.cat)} · ${x.ago} mnt lalu</small>
                    ${x.unread ? `<span class="bubble" style="margin-left:4px">${x.unread}</span>` : ''}
                    <small>${x.last.w ? esc(x.from.split(' ')[0]) : esc((x.last.who || 'Staff').split(' · ')[0])}: ${esc(x.last.t)}</small></div>
                ${repStatus(x)}<svg class="ic chev"><use href="#i-chev"/></svg>
            </button>`).join('')}</div>` : '<div class="empty">Tidak ada laporan terbuka</div>';
    } else {
        const r = repData || await req('report_open', { id: repOpen });
        repData = null;
        if (page !== 'reports') return;
        if (!r || !r.ok) { repOpen = null; done(r); return R.reports(el); }
        const x = r.report;
        const keep = $('#rin') ? $('#rin').value : '';
        el.innerHTML = `
            <div class="rchat">
                <div class="rchat-h">
                    <button class="icon-btn" data-ra="back" title="Kembali">${ic('back')}</button>
                    <div class="t" style="flex:1;min-width:0"><b>#${x.id} · ${esc(x.from)}</b><small class="t-muted" style="display:block">${x.pid ? 'ID ' + x.pid : 'offline'} · ${esc(x.ooc)} · ${esc(x.cat)}${x.target ? ` · terlapor ID ${x.target}` : ''}</small></div>
                    ${repStatus(x)}
                    <button class="b b-sm b-gray" data-ra="goto" ${can('player.goto') && x.pid ? '' : 'disabled'}>Datangi</button>
                    <button class="b b-sm b-gray" data-ra="bring" ${can('player.bring') && x.pid ? '' : 'disabled'}>Tarik</button>
                    ${x.claimed ? '' : '<button class="b b-sm b-tinted" data-ra="claim">Tangani</button>'}
                    <button class="b b-sm b-green-tint" data-ra="close">Selesai</button>
                </div>
                <div class="rthread" id="rth">${x.msgs.map((m) => m.w
                    ? `<div class="bub in"><span class="who">${esc(x.from)}</span>${esc(m.t)}<small>${m.at}</small></div>`
                    : `<div class="bub out"><span class="who">${esc(m.who)}</span>${esc(m.t)}<small>${m.at}</small></div>`).join('')}</div>
                <div class="rreply"><input id="rin" maxlength="250" placeholder="Balas ke ${esc(x.from)}… (warga melihat kamu sebagai &quot;Staff&quot;)"><button class="b b-sm b-filled" data-ra="send">${ic('send')} Kirim</button></div>
            </div>`;
        $('#rin').value = keep;
        $('#rth').scrollTop = $('#rth').scrollHeight;
        el.dataset.pid = x.pid || '';
    }
    el.onclick = async (e) => {
        const o = e.target.closest('[data-ro]');
        if (o) { repOpen = +o.dataset.ro; return R.reports(el); }
        const b = e.target.closest('[data-ra]');
        if (!b || b.disabled) return;
        const pid = +el.dataset.pid;
        switch (b.dataset.ra) {
            case 'back': repOpen = null; return R.reports(el);
            case 'goto': return done(await req('player_act', { act: 'goto', id: pid }));
            case 'bring': return done(await req('player_act', { act: 'bring', id: pid }));
            case 'claim': { const r = await req('report_claim', { id: repOpen }); if (done(r, 'Laporan kamu tangani')) { repData = r; R.reports(el); } return; }
            case 'close': { const r = await req('report_close', { id: repOpen }); if (done(r)) { repOpen = null; R.reports(el); } return; }
            case 'send': {
                const v = $('#rin').value.trim();
                if (!v) return;
                b.disabled = true;
                const r = await req('report_reply', { id: repOpen, text: v });
                b.disabled = false;
                if (r && r.ok) { $('#rin').value = ''; repData = r; R.reports(el); } else done(r);
            }
        }
    };
    el.onkeydown = (e) => { if (e.key === 'Enter' && e.target.id === 'rin') el.querySelector('[data-ra="send"]').click(); };
};

// ================================================================ SERVER
const WEATHER = [['EXTRASUNNY', 'Cerah terik'], ['CLEAR', 'Cerah'], ['NEUTRAL', 'Netral'], ['SMOG', 'Kabut asap'], ['FOGGY', 'Berkabut'], ['OVERCAST', 'Mendung'],
    ['CLOUDS', 'Berawan'], ['CLEARING', 'Mulai cerah'], ['RAIN', 'Hujan'], ['THUNDER', 'Badai petir'], ['SNOW', 'Salju'], ['BLIZZARD', 'Badai salju'],
    ['SNOWLIGHT', 'Salju ringan'], ['XMAS', 'Natal'], ['HALLOWEEN', 'Halloween']];

R.server = async (el) => {
    const w = await req('world');
    if (page !== 'server') return;
    const W = w && w.ok ? w : { weather: 'CLEAR', hour: 12, minute: 0 };
    const dis = (k) => can(k) ? '' : 'disabled';
    el.innerHTML = `
        <div class="grid2">
            <div>
                <div class="group-h">Cuaca</div>
                <div class="filters" id="wx">${WEATHER.map((x) => `<button data-w="${x[0]}" class="${x[0] === W.weather ? 'active' : ''}" ${dis('server.weather')}>${x[1]}</button>`).join('')}</div>
                <div class="group" style="margin-top:10px">
                    <div class="row"><span class="t">Pemadaman listrik</span><button class="switch ${W.blackout ? 'on' : ''}" id="bo" ${dis('server.weather')}></button></div>
                </div>
                <div class="group-h" style="margin-top:16px">Waktu</div>
                <div class="group">
                    <div class="row"><span class="t">Jam</span>
                        <select id="hh" style="width:110px;height:32px" ${dis('server.time')}>${Array.from({ length: 24 }, (_, h) => `<option value="${h}" ${h === W.hour ? 'selected' : ''}>${String(h).padStart(2, '0')}:00</option>`).join('')}</select>
                        <button class="b b-sm b-tinted" id="setT" ${dis('server.time')}>Terapkan</button></div>
                    <div class="row"><span class="t">Bekukan waktu</span><button class="switch ${W.freeze ? 'on' : ''}" id="fz" ${dis('server.time')}></button></div>
                </div>
                <div class="group-h" style="margin-top:16px">Pengumuman kota</div>
                <div class="group form-box">
                    <textarea id="an" maxlength="300" placeholder="Isi pengumuman… (tampil di tab Pengumuman sebagai Admin)" ${dis('server.announce')}></textarea>
                    <button class="b b-tinted b-block" id="anB" ${dis('server.announce')}>${ic('msg')} Kirim pengumuman</button>
                </div>
            </div>
            <div>
                <div class="group-h">Daftar radio</div>
                <div class="group form-box">
                    <div style="display:flex;gap:8px"><input id="fq" type="number" min="0" step="0.1" placeholder="Frekuensi, mis. 100" style="flex:1" ${dis('server.radio')}><button class="b b-sm b-tinted" id="fqB" ${dis('server.radio')}>Cari</button></div>
                    <div id="fqR" class="t-muted" style="font-size:13px">Masukkan frekuensi untuk melihat siapa saja di dalamnya.</div>
                </div>
                <div class="group-h" style="margin-top:16px">Buka stash</div>
                <div class="group form-box" style="flex-direction:row">
                    <input id="st" placeholder="Nama stash, mis. police_evidence" style="flex:1" ${dis('server.stash')}><button class="b b-sm b-tinted" id="stB" ${dis('server.stash')}>Buka</button>
                </div>
            </div>
        </div>`;
    el.onclick = async (e) => {
        const wb = e.target.closest('[data-w]');
        if (wb && !wb.disabled) {
            if (done(await req('weather', { weather: wb.dataset.w }))) el.querySelectorAll('#wx button').forEach((x) => x.classList.toggle('active', x === wb));
            return;
        }
        const t = e.target.closest('button');
        if (!t || t.disabled) return;
        switch (t.id) {
            case 'bo': { const on = !t.classList.contains('on'); if (done(await req('weather', { blackout: on }))) t.classList.toggle('on', on); return; }
            case 'fz': { const on = !t.classList.contains('on'); if (done(await req('time', { freeze: on }))) t.classList.toggle('on', on); return; }
            case 'setT': return done(await req('time', { hour: +$('#hh').value, minute: 0 }));
            case 'anB': {
                const v = $('#an').value.trim();
                if (!v) return toast('Isi pengumuman.', true);
                if (done(await act('announce', { text: v }))) $('#an').value = '';
                return;
            }
            case 'fqB': {
                const r = await req('radio', { freq: +$('#fq').value });
                if (!r || !r.ok) return done(r);
                $('#fqR').innerHTML = r.list.length
                    ? `<div class="group">${r.list.map((p) => `<div class="row"><span class="t">[${p.id}] ${esc(p.name)}<small>${esc(p.ooc)}</small></span><span class="d">${r.freq}</span></div>`).join('')}</div>`
                    : `Tidak ada yang di frekuensi ${r.freq}.`;
                return;
            }
            case 'stB': return done(await req('stash', { name: $('#st').value }));
        }
    };
};

// ================================================================ DAFTAR BAN
let bq = '', bansCache = [], armedBan = null;

R.bans = async (el) => {
    el.innerHTML = `
        <div class="toolbar" style="padding:0 0 10px"><label class="search">${ic('search')}<input id="bq" placeholder="Cari nama, license, alasan" value="${esc(bq)}"></label>
            <small class="t-muted">Ban mencocokkan semua identifier + hardware token (HWID). Akun baru dari PC yang sama ikut tertolak.</small></div>
        <table class="ptable"><thead><tr><th>Pemain</th><th>Alasan</th><th>Sumber</th><th>Identitas</th><th>Sampai</th><th class="c"></th></tr></thead><tbody id="bRows"><tr><td colspan="6"><div class="empty">Memuat…</div></td></tr></tbody></table>`;
    const r = await req('bans');
    if (page !== 'bans') return;
    if (!r || !r.ok) return done(r);
    bansCache = r.bans;
    const draw = () => {
        const q = bq.toLowerCase();
        $('#bRows').innerHTML = bansCache.filter((b) => !q || `${b.name} ${b.license} ${b.reason}`.toLowerCase().includes(q)).map((b) => `
            <tr><td><b>#${b.id} ${esc(b.name)}</b><small class="t-muted">${esc(b.license || '-')}</small></td>
                <td>${esc(b.reason)}<small class="t-muted">oleh ${esc(b.banned_by)}</small></td>
                <td><span class="chip ${b.origin === 'Panel' ? 'accent' : 'red'}">${esc(b.origin)}</span></td>
                <td><small class="t-muted" style="font-size:12px">${b.ids} ID · ${b.hw} HWID${b.alts ? ` · <span class="t-orange">${b.alts} akun baru tertolak</span>` : ''}</small></td>
                <td class="num">${esc(b.until_text)}</td>
                <td class="c"><button class="b b-sm b-green-tint ${armedBan === b.id ? 'armed' : ''}" data-unban="${b.id}">${armedBan === b.id ? 'Yakin?' : 'Cabut'}</button></td></tr>`).join('')
            || '<tr><td colspan="6"><div class="empty">Tidak ada ban aktif</div></td></tr>';
    };
    draw();
    el.oninput = (e) => { if (e.target.id === 'bq') { bq = e.target.value; draw(); } };
    el.onclick = async (e) => {
        const u = e.target.closest('[data-unban]');
        if (!u) return;
        const id = +u.dataset.unban;
        if (armedBan !== id) { armedBan = id; return draw(); }
        armedBan = null;
        if (done(await req('unban', { id }))) { bansCache = bansCache.filter((b) => b.id !== id); }
        draw();
    };
};

// ================================================================ PENGAJUAN HEWAN
let armedPet = null; // { id, approve } klik pertama = konfirmasi
R.pets = async (el) => {
    el.innerHTML = `
        <div class="toolbar" style="padding:0 0 10px"><small class="t-muted">Hewan di f_petshop tidak dibeli: pemain mencoba dulu lalu mengajukan. Setelah disetujui hewan langsung jadi miliknya. Support tidak bisa membuka halaman ini.</small></div>
        <table class="ptable"><thead><tr><th>Pemain</th><th>Hewan</th><th>Nama hewan</th><th>Hewan dimiliki</th><th>Diajukan</th><th class="c"></th></tr></thead><tbody id="petRows"><tr><td colspan="6"><div class="empty">Memuat…</div></td></tr></tbody></table>`;
    const r = await req('pets');
    if (page !== 'pets') return;
    if (!r || !r.ok) return done(r);
    let rows = r.requests || [];
    const draw = () => {
        S.stats.pets = rows.length;
        renderNav();
        $('#petRows').innerHTML = rows.map((x) => {
            const armA = armedPet && armedPet.id === x.id && armedPet.approve;
            const armR = armedPet && armedPet.id === x.id && !armedPet.approve;
            return `<tr><td><b>${esc(x.player_name)}</b><small class="t-muted">${esc(x.citizenid)}</small></td>
                <td>${esc(x.icon)} ${esc(x.label)}${x.color ? `<small class="t-muted">${esc(x.color)}</small>` : ''}</td>
                <td><b>${esc(x.name)}</b></td>
                <td class="num">${x.owned}/${r.max}</td>
                <td class="num">${esc(x.when)}</td>
                <td class="c" style="white-space:nowrap">
                    <button class="b b-sm b-green-tint ${armA ? 'armed' : ''}" data-pet="${x.id}" data-ok="1">${armA ? 'Yakin?' : 'Setujui'}</button>
                    <button class="b b-sm b-red-tint ${armR ? 'armed' : ''}" data-pet="${x.id}" data-ok="0">${armR ? 'Yakin?' : 'Tolak'}</button>
                </td></tr>`;
        }).join('') || '<tr><td colspan="6"><div class="empty">Tidak ada pengajuan</div></td></tr>';
    };
    draw();
    el.onclick = async (e) => {
        const b = e.target.closest('[data-pet]');
        if (!b) return;
        const id = +b.dataset.pet, approve = b.dataset.ok === '1';
        if (!armedPet || armedPet.id !== id || armedPet.approve !== approve) { armedPet = { id, approve }; return draw(); }
        armedPet = null;
        if (done(await req('pets_decide', { id, approve }))) rows = rows.filter((x) => x.id !== id);
        draw();
    };
};

// ================================================================ DEVELOPER
R.dev = async (el) => {
    const r = await act('dev');
    if (page !== 'dev' || !r || !r.ok) return;
    const D = r.dev, P = r.pos;
    const sw = (k, t) => `<div class="row"><span class="t">${t}</span><button class="switch ${D[k] ? 'on' : ''}" data-dv="${k}"></button></div>`;
    el.innerHTML = `
        <div class="grid2">
            <div><div class="group-h">Koordinat saya (saat panel dibuka)</div>
                <div class="group">
                    <div class="row"><span class="t">vector2</span><span class="d">${P.x}, ${P.y}</span><button class="icon-btn" data-c="vec2">${ic('copy')}</button></div>
                    <div class="row"><span class="t">vector3</span><span class="d">${P.x}, ${P.y}, ${P.z}</span><button class="icon-btn" data-c="vec3">${ic('copy')}</button></div>
                    <div class="row"><span class="t">vector4</span><span class="d">${P.x}, ${P.y}, ${P.z}, ${P.h}</span><button class="icon-btn" data-c="vec4">${ic('copy')}</button></div>
                    <div class="row"><span class="t">Heading</span><span class="d">${P.h}</span><button class="icon-btn" data-c="heading">${ic('copy')}</button></div>
                </div>
                <p class="group-f">Juga lewat command /vec2 /vec3 /vec4 /heading. Z sudah dikurangi 1 (posisi kaki).</p>
            </div>
            <div><div class="group-h">Tampilan</div>
                <div class="group">${sw('coords', 'Tampilkan koordinat di layar')}${sw('vehinfo', 'Info kendaraan yang dinaiki')}</div>
                <div class="group-h" style="margin-top:16px">Entity view</div>
                <div class="group">
                    ${sw('freeaim', 'Freeaim laser ([E] salin info, [G] hapus)')}${sw('objects', 'Objek terdekat')}${sw('vehicles', 'Kendaraan terdekat')}${sw('peds', 'Ped terdekat')}
                    <div class="row"><span class="t">Jarak</span><div class="range" style="width:200px"><input type="range" min="5" max="100" step="5" value="${D.dist}" id="evd"><b class="num" id="evdv">${D.dist} m</b></div></div>
                </div>
            </div>
        </div>`;
    el.onclick = async (e) => {
        const s = e.target.closest('[data-dv]');
        if (s) { const x = await act('devtoggle', { k: s.dataset.dv }); if (x && x.ok) s.classList.toggle('on', !!x.dev[s.dataset.dv]); return; }
        const c = e.target.closest('[data-c]');
        if (c) done(await act('copy', { kind: c.dataset.c }), c.dataset.c + ' disalin');
    };
    el.oninput = (e) => { if (e.target.id === 'evd') $('#evdv').textContent = e.target.value + ' m'; };
    el.onchange = (e) => { if (e.target.id === 'evd') act('devdist', { m: +e.target.value }); };
};

// ================================================================ STAFF (Owner)
let staffData = null, addRole = 'support', armedDel = null;

function staffResult(res) {
    if (!res || !res.ok) return toast(res?.msg || 'Gagal.', true), false;
    staffData = res;
    if (res.msg) toast(res.msg);
    return true;
}

R.staff = async (el) => {
    el.innerHTML = '<div class="empty">Memuat…</div>';
    if (!staffResult(await req('staff_list')) || page !== 'staff') return;
    drawStaff(el);
    el.onclick = async (e) => {
        const r = e.target.closest('#addR button');
        if (r) { addRole = r.dataset.r; el.querySelectorAll('#addR button').forEach((x) => x.classList.toggle('active', x === r)); return; }
        const del = e.target.closest('[data-del]');
        if (del) {
            const uid = +del.dataset.del;
            if (armedDel !== uid) { // klik pertama mempersenjatai, klik kedua menghapus
                armedDel = uid;
                el.querySelectorAll('[data-del]').forEach((x) => x.classList.toggle('armed', +x.dataset.del === uid));
                return toast('Klik sekali lagi untuk mencopot.');
            }
            armedDel = null;
            if (staffResult(await req('staff_remove', { uid }))) drawStaff(el);
            return;
        }
        if (e.target.closest('#addBtn')) {
            const target = $('#addP').value, identifier = $('#addL').value.trim();
            const data = identifier ? { identifier, name: $('#addN').value.trim(), role: addRole } : { target: +target, role: addRole };
            if (!identifier && !target) return toast('Pilih pemain atau isi identifier.', true);
            if (staffResult(await req('staff_add', data))) drawStaff(el);
        }
    };
    el.onchange = async (e) => {
        const s = e.target.closest('[data-role]');
        if (s && staffResult(await req('staff_role', { uid: +s.dataset.role, role: s.value }))) drawStaff(el);
    };
};

function drawStaff(el) {
    const d = staffData;
    const owners = d.owners.map((o) => `
        <div class="row"><div class="av">${esc((o.name[0] || '?').toUpperCase())}</div>
            <div class="t"><b>${esc(o.name)}</b> <span class="chip green">Online</span><small>ID ${o.id}</small></div>
            <span class="role owner">Owner</span></div>`).join('');
    const staff = d.staff.map((s) => `
        <div class="row">
            <div class="av">${esc((s.name[0] || '?').toUpperCase())}</div>
            <div class="t"><b>${esc(s.name)}</b> ${s.online ? `<span class="chip green">Online · ID ${s.online}</span>` : ''}
                <small>${esc(s.ids[0] || '')}${s.ids.length > 1 ? ` +${s.ids.length - 1}` : ''} · oleh ${esc(s.by || '-')}</small></div>
            <select class="sm" data-role="${s.uid}">
                <option value="admin" ${s.role === 'admin' ? 'selected' : ''}>Admin</option>
                <option value="support" ${s.role === 'support' ? 'selected' : ''}>Support</option>
            </select>
            <button class="icon-btn close" data-del="${s.uid}" title="Copot">${ic('trash')}</button>
        </div>`).join('');
    el.innerHTML = `
        <div class="grid2">
            <div>
                <div class="group-h">Staff terdaftar</div>
                <div class="group">
                    ${owners}
                    <div class="row"><div class="av">${ic('lock')}</div><div class="t"><b>Owner lain</b><small>Diatur di server.cfg (group.owner)</small></div><span class="role owner">Owner</span></div>
                    ${staff}
                </div>
                ${d.staff.length ? '' : '<p class="group-f">Belum ada Admin / Support.</p>'}
                <p class="group-f">Tidak perlu edit server.cfg. Perubahan langsung aktif tanpa restart.</p>
            </div>
            <div>
                <div class="group-h">Tambah staff</div>
                <div class="group form-box">
                    <label><span>Pemain online</span><select id="addP">
                        <option value="">— pilih pemain —</option>
                        ${d.players.map((p) => `<option value="${p.id}">[${p.id}] ${esc(p.name)} (${esc(p.ooc)})</option>`).join('')}
                    </select></label>
                    <label><span>Atau identifier pemain offline (license2: / license: / fivem: / discord:)</span><input id="addL" placeholder="license2:xxxxxxxx"></label>
                    <label><span>Nama (untuk identifier offline)</span><input id="addN" placeholder="mis. Budi" maxlength="40"></label>
                    <label><span>Role</span>
                        <div class="seg" id="addR"><button data-r="admin" class="${addRole === 'admin' ? 'active' : ''}">Admin</button><button data-r="support" class="${addRole === 'support' ? 'active' : ''}">Support</button></div></label>
                    <button class="b b-filled b-block" id="addBtn">${ic('plus')} Angkat jadi staff</button>
                </div>
                <div class="group-h" style="margin-top:16px">Akses txAdmin (diatur manual di web txAdmin)</div>
                <div class="group">
                    <div class="row"><span class="role admin">Admin</span><span class="t">Semua kecuali kelola admin, pengaturan & Ban</span></div>
                    <div class="row"><span class="role support">Support</span><span class="t">Main: Player Mode, Teleport, Vehicle, Show IDs · Players: Spectate, DM, Warn, Kick, Freeze, Heal</span></div>
                </div>
            </div>
        </div>`;
}

// ================================================================ DAFTAR COMMAND (Owner)
let permData = null, cq = '', cf = 'all', showPublic = false;

R.perms = async (el) => {
    el.innerHTML = '<div class="empty">Memuat…</div>';
    const res = await req('perms_list');
    if (page !== 'perms') return;
    if (!res || !res.ok) return toast(res?.msg || 'Gagal memuat.', true);
    permData = res;
    el.innerHTML = `
        <div class="perm-top">
            <label class="search">${ic('search')}<input id="cq" placeholder="Cari command atau aksi" value="${esc(cq)}"></label>
            <div class="filters" id="cf">
                <button data-f="all" class="${cf === 'all' ? 'active' : ''}">Semua</button>
                <button data-f="s" class="${cf === 's' ? 'active' : ''}">Boleh Support</button>
                <button data-f="noa" class="${cf === 'noa' ? 'active' : ''}">Dicabut dari Admin</button>
                <button data-f="lock" class="${cf === 'lock' ? 'active' : ''}">Khusus Owner</button>
            </div>
            <span class="spacer"></span><small class="num" id="ccount"></small>
        </div>
        <div class="pwrap" id="pwrap"></div>`;
    drawPerms();
    el.oninput = (e) => { if (e.target.id === 'cq') { cq = e.target.value; drawPerms(); } };
    el.onclick = async (e) => {
        const f = e.target.closest('[data-f]');
        if (f) { cf = f.dataset.f; el.querySelectorAll('#cf button').forEach((x) => x.classList.toggle('active', x === f)); return drawPerms(); }
        if (e.target.closest('tr.fold')) { showPublic = !showPublic; return drawPerms(); }
        const sw = e.target.closest('.switch[data-k]');
        if (!sw || sw.disabled) return;
        const col = sw.dataset.c, key = sw.dataset.k;
        const tr = sw.closest('tr');
        tr.querySelectorAll('.switch').forEach((x) => (x.disabled = true));
        const r = await req('perms_set', { key, col, value: !sw.classList.contains('on') });
        tr.querySelectorAll('.switch').forEach((x) => (x.disabled = false));
        if (!r || !r.ok) return toast(r?.msg || 'Gagal menyimpan.', true);
        // ubah baris ini saja → posisi scroll tetap
        const row = findRow(key);
        if (row) { row.a = r.a; row.s = r.s; }
        tr.querySelector('[data-c="a"]').classList.toggle('on', r.a);
        tr.querySelector('[data-c="s"]').classList.toggle('on', r.s);
        toast(`Disimpan · ${row ? row.name : key}: Admin ${r.a ? '✓' : '✗'} · Support ${r.s ? '✓' : '✗'}`);
    };
};

function findRow(key) {
    for (const g of permData.groups) for (const r of g.rows) if (r.key === key) return r;
}

function drawPerms() {
    const q = cq.toLowerCase();
    let n = 0;
    const match = (r) => (!q || r.name.toLowerCase().includes(q) || (r.help || '').toLowerCase().includes(q))
        && (cf === 'all' || (cf === 's' && r.s) || (cf === 'noa' && !r.a && !r.money) || (cf === 'lock' && r.money));
    const cell = (r, c) => r.money
        ? `<span class="lockchip">${ic('lock')}Owner</span>`
        : `<button class="switch ${r[c] ? 'on' : ''}" data-k="${esc(r.key)}" data-c="${c}"></button>`;

    let body = permData.groups.map((g) => {
        const rows = g.rows.filter(match);
        n += rows.length;
        if (!rows.length) return '';
        return `<tr class="grp"><td colspan="3">${esc(g.name)}</td></tr>` + rows.map((r) => `
            <tr><td><code>${esc(r.name)}</code>${r.unknown ? ' <span class="lockchip">belum terpindai</span>' : ''}<small class="t-muted">${esc(r.help)}</small></td>
                <td class="c">${cell(r, 'a')}</td><td class="c">${cell(r, 's')}</td></tr>`).join('');
    }).join('');

    if (cf === 'all') {
        const pub = permData.public.filter((p) => !q || p.name.includes(q) || (p.help || '').toLowerCase().includes(q));
        if (pub.length) {
            body += `<tr class="grp fold"><td colspan="3">${showPublic ? '▾' : '▸'} Command umum — semua pemain (${pub.length})</td></tr>`;
            if (showPublic || q) body += pub.map((p) => `
                <tr><td><code>/${esc(p.name)}</code> <small class="t-muted" style="display:inline">${esc(p.res)}</small><small class="t-muted">${esc(p.help)}</small></td>
                    <td class="c"><span class="lockchip">Semua</span></td><td class="c"><span class="lockchip">Semua</span></td></tr>`).join('');
        }
    }

    $('#pwrap').innerHTML = `
        <div class="notice" style="margin-bottom:10px">Centang = boleh. Dicabut dari Admin = admin diblok walau mengetik command langsung. Command uang selalu <b>khusus Owner</b>. Support tidak bisa melebihi Admin. Perubahan langsung aktif tanpa restart.</div>
        <table class="ptable"><thead><tr><th>Command / aksi</th><th class="c">Admin</th><th class="c">Support</th></tr></thead><tbody>${body || '<tr><td colspan="3"><div class="empty">Tidak ada hasil</div></td></tr>'}</tbody></table>`;
    $('#ccount').textContent = n + ' item';
}

// ================================================================ LOG DISCORD (Owner)
R.logs = async (el) => {
    const r = await req('logs_get');
    if (page !== 'logs') return;
    if (!r || !r.ok) return done(r);
    const chip = (c) => c.own ? '<span class="chip green">Terhubung</span>'
        : c.hook ? '<span class="chip">Ikut utama</span>' : '<span class="chip red">Belum diisi</span>';
    el.innerHTML = `
        <div class="grid2">
            <div>
                <div class="group-h">Webhook per channel</div>
                <div class="group">${r.channels.map((c) => `
                    <div class="row"><span class="t">${esc(c.label)}<small><code>set ${esc(c.convar)} "…"</code></small></span>
                        ${chip(c)}<button class="b b-sm b-tinted" data-test="${c.key}" ${c.hook ? '' : 'disabled'}>Uji</button></div>`).join('')}
                </div>
                <p class="group-f">Diatur di server.cfg, perlu restart f_admin setelah diubah. Channel yang kosong ikut webhook utama. URL tidak pernah dikirim ke client dan log tidak disimpan di database.</p>
                <div class="group-h" style="margin-top:16px">Contoh pesan</div>
                <div style="display:flex;flex-direction:column;gap:6px">
                    <div class="logprev"><b>Sandi</b> memberikan perban x2, pistol ke <b>Budi Santoso (ID 1)</b><span class="ts">Admin · ID 3 → ID 1 · 21:14</span></div>
                    <div class="logprev" style="border-color:#f0b232"><b>Dewi</b> menyalakan noclip<span class="ts">Support · ID 9 · 21:16</span></div>
                    <div class="logprev" style="border-color:#f23f43"><b>Sandi</b> ban <b>Fajar Nugroho (ID 14)</b> 3 hari: RDM berulang<span class="ts">Admin · ID 3 → ID 14 · 21:20</span></div>
                </div>
            </div>
            <div>
                ${r.channels.map((c) => {
                    const ks = r.kinds.filter((k) => k.ch === c.key);
                    return ks.length ? `<div class="group-h">Jenis log · ${esc(c.label)}</div>
                        <div class="group" style="margin-bottom:14px">${ks.map((k) => `<div class="row"><span class="t">${esc(k.label)}</span><button class="switch ${k.on ? 'on' : ''}" data-lg="${k.key}"></button></div>`).join('')}</div>` : '';
                }).join('')}
            </div>
        </div>`;
    el.onclick = async (e) => {
        const s = e.target.closest('[data-lg]');
        if (s) {
            const x = await req('logs_set', { key: s.dataset.lg, on: !s.classList.contains('on') });
            if (x && x.ok) s.classList.toggle('on', x.on); else done(x);
            return;
        }
        const t = e.target.closest('[data-test]');
        if (t && !t.disabled) done(await req('logs_test', { ch: t.dataset.test }));
    };
};

// ---------------------------------------------------------------- buka / tutup
function close() {
    closeModal();
    $('#app').classList.add('hidden');
    post('close');
}

window.addEventListener('message', (e) => {
    const m = e.data;
    if (m.action === 'open') {
        S = m.data;
        $('#meName').textContent = S.me.name;
        $('#meAv').textContent = (S.me.name[0] || '?').toUpperCase();
        $('#meRole').className = 'role ' + S.role;
        $('#meRole').textContent = ROLE_LABEL[S.role];
        $('#app').classList.remove('hidden');
        go(page);
    } else if (m.action === 'close') {
        closeModal();
        $('#app').classList.add('hidden');
        if (window.laporHide) window.laporHide();
    } else if (m.action === 'reports' && S) {
        S.stats.reports = m.count;
        renderNav();
        if (page === 'reports' && !modalOpen()) R.reports($('#page'));
    }
});

document.addEventListener('click', (e) => { if (e.target.closest('[data-close]')) close(); });
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || $('#app').classList.contains('hidden')) return;
    if (modalOpen()) closeModal(); else close();
});
